"""OIDC login multi-provider (Keycloak / qualquer OIDC compliant).

Discovery por env: cada provider declara IDP_<NAME>_DISCOVERY_URL
(+CLIENT_ID/CLIENT_SECRET/REDIRECT_URI/POST_LOGOUT_URI). O nome do
provider vira o segmento de URL (`/api/auth/<name>/login`) e o valor
do campo `provider` no postMessage do callback.

Backwards-compat: variáveis IOTEDU_* legadas continuam registrando o
provider 'iotedu'.
"""
import logging
import os
import re
from datetime import datetime
from typing import Optional
from urllib.parse import urlencode

import httpx
from authlib.integrations.starlette_client import OAuth, OAuthError
from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import HTMLResponse, RedirectResponse

import config as app_config
from db.enums import UserPermission
from db.models import User
from db.session import SessionLocal

logger = logging.getLogger(__name__)
router = APIRouter()


def _discover_providers() -> dict[str, dict]:
    cfg: dict[str, dict] = {}
    pattern = re.compile(r"^IDP_([A-Z0-9]+)_DISCOVERY_URL$")
    for key, val in os.environ.items():
        m = pattern.match(key)
        if not m or not val:
            continue
        name = m.group(1).lower()
        prefix = f"IDP_{m.group(1)}"
        cfg[name] = {
            "discovery_url": val,
            "client_id": os.getenv(f"{prefix}_CLIENT_ID"),
            "client_secret": os.getenv(f"{prefix}_CLIENT_SECRET"),
            "redirect_uri": os.getenv(f"{prefix}_REDIRECT_URI"),
            "post_logout_uri": os.getenv(f"{prefix}_POST_LOGOUT_URI"),
        }

    if "iotedu" not in cfg and os.getenv("IOTEDU_DISCOVERY_URL"):
        cfg["iotedu"] = {
            "discovery_url": os.getenv("IOTEDU_DISCOVERY_URL"),
            "client_id": os.getenv("IOTEDU_CLIENT_ID"),
            "client_secret": os.getenv("IOTEDU_CLIENT_SECRET"),
            "redirect_uri": os.getenv("IOTEDU_REDIRECT_URI"),
            "post_logout_uri": os.getenv("IDP_CLIENT_POST_LOGOUT_URI"),
        }
    return cfg


PROVIDERS = _discover_providers()
oauth = OAuth()
for _name, _c in PROVIDERS.items():
    if _c["discovery_url"] and _c["client_id"] and _c["client_secret"]:
        oauth.register(
            name=_name,
            server_metadata_url=_c["discovery_url"],
            client_id=_c["client_id"],
            client_secret=_c["client_secret"],
            client_kwargs={"scope": "openid email profile", "code_challenge_method": "S256"},
        )
        logger.info("OIDC provider registered: %s", _name)
    else:
        logger.warning("OIDC %s: env incomplete; /login will 503", _name)


def _client(provider: str):
    client = getattr(oauth, provider, None)
    if client is None:
        raise HTTPException(status_code=404, detail=f"unknown OIDC provider '{provider}'")
    return client


def _provision_user(db, claims: dict, request: Request) -> User:
    sub = claims.get("sub")
    email = (claims.get("email") or "").strip().lower()
    name = claims.get("name") or claims.get("preferred_username")
    picture = claims.get("picture")

    if not sub or not email:
        raise HTTPException(status_code=400, detail="OIDC claims missing sub or email")
    if claims.get("email_verified") is False:
        raise HTTPException(status_code=403, detail="Email não verificado no IdP")

    user = db.query(User).filter(User.keycloak_sub == sub).first()
    if user is None:
        # Mesmo email pode existir em IdPs diferentes (ex: super@iotedu.org tanto
        # no realm iotedu quanto no realm anonshield, com `sub` distinto). Trata
        # como o mesmo user — sobrescreve `keycloak_sub` com o do login atual.
        user = db.query(User).filter(User.email == email).first()

    admin_emails = {e.strip().lower() for e in (app_config.SUPERUSER_ACCESS or "").split(",") if e.strip()}
    is_admin = email in admin_emails

    if user is None:
        user = User(
            email=email,
            nome=name,
            instituicao="IoTEdu" if is_admin else None,
            permission=UserPermission.SUPERUSER if is_admin else UserPermission.USER,
            keycloak_sub=sub,
            picture=picture,
            is_active=True,
        )
    else:
        if not user.is_active:
            raise HTTPException(status_code=403, detail="Conta desativada")
        if user.email != email:
            user.email = email
        if name:
            user.nome = name
        if picture:
            user.picture = picture
        if user.keycloak_sub != sub:
            user.keycloak_sub = sub
        if is_admin and user.permission != UserPermission.SUPERUSER:
            user.permission = UserPermission.SUPERUSER
            if not user.instituicao:
                user.instituicao = "IoTEdu"

    user.ultimo_login = datetime.utcnow()
    db.add(user)
    db.commit()
    db.refresh(user)

    if not user.institution_id and not is_admin:
        try:
            from services_firewalls.institution_config_service import InstitutionConfigService
            from services_firewalls.request_utils import get_client_ip
            client_ip = get_client_ip(request)
            if client_ip:
                detected = InstitutionConfigService.get_institution_by_ip(client_ip)
                if detected:
                    user.institution_id = detected
                    db.commit()
                    db.refresh(user)
        except Exception as exc:
            logger.warning("OIDC %s: institution detection failed: %s", "_provisioning", exc)

    return user


def _state_key_prefix(provider: str) -> str:
    return f"_state_{provider}_"


@router.get("/providers", summary="Lista IdPs configurados")
async def list_providers():
    return {"providers": [
        {"name": n, "configured": bool(c["client_id"] and c["client_secret"])}
        for n, c in PROVIDERS.items()
    ]}


@router.get("/{provider}/login", summary="Inicia login OIDC")
async def login(provider: str, request: Request):
    client = _client(provider)
    cfg = PROVIDERS[provider]
    if not cfg["redirect_uri"]:
        raise HTTPException(status_code=503, detail=f"redirect_uri not set for {provider}")
    # Limpa estado OIDC de TODOS os providers + id_token + auth_provider.
    # Acumular states de múltiplas tentativas (ex: usuário troca de IdP)
    # estoura o limite de 4KB do cookie e produz mismatching_state.
    for k in list(request.session.keys()):
        if k.startswith("_state_") or k in ("id_token", "auth_provider"):
            request.session.pop(k, None)
    return await client.authorize_redirect(request, cfg["redirect_uri"])


@router.get("/{provider}/callback", summary="Callback OIDC")
async def callback(provider: str, request: Request):
    client = _client(provider)
    try:
        token = await client.authorize_access_token(request)
    except OAuthError as exc:
        logger.warning("OIDC %s callback error: %s", provider, exc)
        raise HTTPException(status_code=400, detail=f"OIDC error: {exc.error}")

    claims = token.get("userinfo") or {}
    if not claims:
        try:
            resp = await client.userinfo(token=token)
            claims = dict(resp)
        except Exception as exc:
            logger.error("OIDC %s userinfo fetch failed: %s", provider, exc)
            raise HTTPException(status_code=502, detail="Failed to fetch userinfo")

    with SessionLocal() as db:
        user = _provision_user(db, claims, request)
        permission = user.permission.value if user.permission else "USER"
        request.session["email"] = user.email
        request.session["auth_provider"] = provider
        if token.get("id_token"):
            request.session["id_token"] = token["id_token"]

        return HTMLResponse(f"""
        <script>
          if (window.opener) {{
            window.opener.postMessage({{
              provider: {repr(provider)},
              user_id: {user.id},
              name: {repr(user.nome or "")},
              email: {repr(user.email)},
              picture: {repr(user.picture or "")},
              permission: {repr(permission)}
            }}, "*");
            window.close();
          }} else {{
            window.location.href = "/";
          }}
        </script>
        """)


@router.get("/{provider}/logout", summary="Logout RP-initiated no IdP")
async def logout(provider: str, request: Request):
    cfg = PROVIDERS.get(provider)
    id_token = request.session.get("id_token")
    request.session.clear()
    if not cfg or not cfg["discovery_url"]:
        return RedirectResponse(url="/")

    try:
        async with httpx.AsyncClient(timeout=10) as client:
            meta = (await client.get(cfg["discovery_url"])).json()
        end_session = meta.get("end_session_endpoint")
    except Exception as exc:
        logger.warning("OIDC %s discovery fetch failed: %s", provider, exc)
        end_session = None

    if not end_session:
        return RedirectResponse(url=cfg.get("post_logout_uri") or "/")

    params = {"client_id": cfg["client_id"]}
    if id_token:
        params["id_token_hint"] = id_token
    if cfg.get("post_logout_uri"):
        params["post_logout_redirect_uri"] = cfg["post_logout_uri"]
    return RedirectResponse(url=f"{end_session}?{urlencode(params)}")


@router.get("/{provider}/me", summary="Usuário autenticado via OIDC")
async def me(provider: str, request: Request, email: Optional[str] = None):
    _client(provider)
    user_email = email or request.session.get("email")
    if not user_email:
        raise HTTPException(status_code=401, detail="Não autenticado")
    with SessionLocal() as db:
        user = db.query(User).filter(User.email == user_email).first()
        if not user or not user.is_active:
            raise HTTPException(status_code=403, detail="Conta inativa ou inexistente")
        return user.to_dict()
