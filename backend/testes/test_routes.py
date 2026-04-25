"""
Testes de contrato HTTP contra o deploy ao vivo.
Foca em status codes e presença de campos-chave — nada de parsear
payload interno. Baixa manutenção: só quebra quando uma rota é
removida ou seu status muda. Espelha os testes Jest em tests/api.test.js.

    BASE_URL=https://iotedu.anonshield.org pytest backend/testes/test_routes.py -v
    BASE_URL=https://mvp.iotedu.org        pytest backend/testes/test_routes.py -v
"""
import os
import pytest
import requests


BASE = os.environ.get("BASE_URL", "https://iotedu.anonshield.org").rstrip("/")


def get(path: str, **kw):
    return requests.get(f"{BASE}{path}", allow_redirects=False, timeout=10, **kw)


class TestHappyPath:
    def test_root_renders(self):
        assert get("/").status_code == 200

    def test_health_returns_healthy_with_db_ok(self):
        r = get("/health")
        assert r.status_code == 200
        body = r.json()
        assert body["status"] == "healthy"
        assert body["db"] == "ok"

    def test_docs_available(self):
        assert get("/docs").status_code == 200

    def test_openapi_schema_has_paths(self):
        r = get("/openapi.json")
        assert r.status_code == 200
        assert "paths" in r.json()

    def test_providers_list_includes_both_idps(self):
        r = get("/api/auth/providers")
        assert r.status_code == 200
        names = {p["name"] for p in r.json()["providers"]}
        assert "iotedu" in names
        assert "anonshield" in names

    def test_iotedu_login_redirects_to_idp_iotedu(self):
        r = get("/api/auth/iotedu/login")
        assert r.status_code == 302
        assert "idp.iotedu.org" in r.headers["location"]

    def test_anonshield_login_redirects_to_idp_anonshield(self):
        r = get("/api/auth/anonshield/login")
        assert r.status_code == 302
        assert "idp.anonshield.org" in r.headers["location"]

    def test_google_login_redirects_to_google(self):
        r = get("/api/auth/google/login")
        assert r.status_code == 307
        assert "accounts.google.com" in r.headers["location"]

    def test_iotedu_login_uses_pkce_s256(self):
        r = get("/api/auth/iotedu/login")
        loc = r.headers["location"]
        assert "code_challenge=" in loc
        assert "code_challenge_method=S256" in loc
        assert "state=" in loc
        assert "nonce=" in loc


class TestBadPath:
    def test_unknown_route_returns_404(self):
        assert get("/api/this-route-does-not-exist").status_code == 404

    def test_unknown_oidc_provider_returns_404(self):
        assert get("/api/auth/no-such-provider/login").status_code == 404

    def test_me_without_session_returns_401(self):
        assert get("/api/auth/me").status_code == 401

    def test_oidc_me_without_session_returns_401(self):
        assert get("/api/auth/iotedu/me").status_code == 401

    def test_callback_without_state_returns_400(self):
        # Acessar callback diretamente sem code/state ou com state inválido
        r = get("/api/auth/iotedu/callback?code=fake&state=fake")
        # 400 (mismatching_state) é o esperado — NUNCA deve ser 200/302
        assert r.status_code == 400


class TestExternalDependencies:
    """IdPs precisam estar acessíveis — se um IdP cair, login quebra."""

    def test_idp_iotedu_discovery_reachable(self):
        r = requests.get(
            "https://idp.iotedu.org/realms/iotedu/.well-known/openid-configuration",
            timeout=10,
        )
        assert r.status_code == 200
        assert r.json()["issuer"] == "https://idp.iotedu.org/realms/iotedu"

    def test_idp_anonshield_discovery_reachable(self):
        r = requests.get(
            "https://idp.anonshield.org/realms/anonshield/.well-known/openid-configuration",
            timeout=10,
        )
        assert r.status_code == 200
        assert r.json()["issuer"] == "https://idp.anonshield.org/realms/anonshield"
