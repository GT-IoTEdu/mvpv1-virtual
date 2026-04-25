"""OIDC login via Keycloak (idp.anonshield.org realm anonshield).

Espelha o padrão do google_auth.py: popup OAuth, postMessage para o opener.
Configurado por env (IOTEDU_*), agnóstico ao IDP — funciona com qualquer
provider OIDC compliant trocando IOTEDU_DISCOVERY_URL.
"""
import logging
import os
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

PROVIDER = "iotedu"
DISCOVERY_URL = os.getenv("IOTEDU_DISCOVERY_URL")
CLIENT_ID = os.getenv("IOTEDU_CLIENT_ID")
CLIENT_SECRET = os.getenv("IOTEDU_CLIENT_SECRET")
REDIRECT_URI = os.getenv("IOTEDU_REDIRECT_URI")
POST_LOGOUT_URI = os.getenv("IDP_CLIENT_POST_LOGOUT_URI")

oauth = OAuth()
if DISCOVERY_URL and CLIENT_ID and CLIENT_SECRET:
    oauth.register(
        name=PROVIDER,
        server_metadata_url=DISCOVERY_URL,
        client_id=CLIENT_ID,
        client_secret=CLIENT_SECRET,
        client_kwargs={"scope": "openid email profile", "code_challenge_method": "S256"},
    )
else:
    logger.warning("OIDC iotedu: env incomplete; /login will return 503")


def _ensure_configured():
    if PROVIDER not in oauth._registry:
        raise HTTPException(status_code=503, detail="OIDC provider not configured")


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
        user = db.query(User).filter(User.email == email).first()
        if user is not None and user.keycloak_sub and user.keycloak_sub != sub:
            raise HTTPException(status_code=409, detail="Email já vinculado a outra identidade")

    admin_email = (app_config.SUPERUSER_ACCESS or "").lower()
    is_admin = bool(admin_email) and email == admin_email

    if user is None:
        user = User(
            email=email,
            nome=name,
            instituicao="IoT-EDU" if is_admin else None,
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
        if not user.keycloak_sub:
            user.keycloak_sub = sub
        if is_admin and user.permission != UserPermission.SUPERUSER:
            user.permission = UserPermission.SUPERUSER
            if not user.instituicao:
                user.instituicao = "IoT-EDU"

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
            logger.warning("OIDC iotedu: institution detection failed: %s", exc)

    return user


@router.get("/login", summary="Inicia login OIDC (Keycloak)")
async def login(request: Request):
    _ensure_configured()
    if not REDIRECT_URI:
        raise HTTPException(status_code=503, detail="IOTEDU_REDIRECT_URI not set")
    stale = [k for k in list(request.session.keys()) if k.startswith("_state_iotedu_")]
    for k in stale:
        request.session.pop(k, None)
    if stale:
        logger.info("OIDC iotedu login: cleared %d stale state(s)", len(stale))
    return await oauth.iotedu.authorize_redirect(request, REDIRECT_URI)


@router.get("/callback", summary="Callback OIDC")
async def callback(request: Request):
    _ensure_configured()
    state_keys = [k for k in request.session.keys() if k.startswith("_state_iotedu_")]
    logger.info("OIDC iotedu callback: state in URL=%s; session has %d state(s): %s",
                request.query_params.get("state"), len(state_keys), state_keys)
    try:
        token = await oauth.iotedu.authorize_access_token(request)
    except OAuthError as exc:
        logger.warning("OIDC iotedu callback error: %s", exc)
        raise HTTPException(status_code=400, detail=f"OIDC error: {exc.error}")

    claims = token.get("userinfo") or {}
    if not claims:
        try:
            resp = await oauth.iotedu.userinfo(token=token)
            claims = dict(resp)
        except Exception as exc:
            logger.error("OIDC iotedu userinfo fetch failed: %s", exc)
            raise HTTPException(status_code=502, detail="Failed to fetch userinfo")

    with SessionLocal() as db:
        user = _provision_user(db, claims, request)
        permission = user.permission.value if user.permission else "USER"
        request.session["email"] = user.email
        request.session["auth_provider"] = PROVIDER

        return HTMLResponse(f"""
        <script>
          if (window.opener) {{
            window.opener.postMessage({{
              provider: "{PROVIDER}",
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


@router.get("/logout", summary="Logout RP-initiated no IdP")
async def logout(request: Request):
    """Encerra a sessão local e redireciona ao end_session_endpoint do IdP."""
    request.session.clear()
    if PROVIDER not in oauth._registry:
        return RedirectResponse(url="/")

    try:
        async with httpx.AsyncClient(timeout=10) as client:
            meta = (await client.get(DISCOVERY_URL)).json()
        end_session = meta.get("end_session_endpoint")
    except Exception as exc:
        logger.warning("OIDC iotedu: discovery fetch failed: %s", exc)
        end_session = None

    if not end_session:
        return RedirectResponse(url=POST_LOGOUT_URI or "/")

    params = {"client_id": CLIENT_ID}
    if POST_LOGOUT_URI:
        params["post_logout_redirect_uri"] = POST_LOGOUT_URI
    return RedirectResponse(url=f"{end_session}?{urlencode(params)}")


@router.get("/me", summary="Usuário autenticado via OIDC")
async def me(request: Request, email: Optional[str] = None):
    user_email = email or request.session.get("email")
    if not user_email:
        raise HTTPException(status_code=401, detail="Não autenticado")
    with SessionLocal() as db:
        user = db.query(User).filter(User.email == user_email).first()
        if not user or not user.is_active:
            raise HTTPException(status_code=403, detail="Conta inativa ou inexistente")
        return user.to_dict()
