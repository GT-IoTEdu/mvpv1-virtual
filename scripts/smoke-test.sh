#!/usr/bin/env bash
# Smoke test pós-deploy. Falha (exit !=0) se qualquer endpoint
# crítico estiver fora do esperado. Usado em a9-deploy.sh e
# guasca-deploy.sh — falha do smoke = deploy falhou.
set -uo pipefail

BASE_URL="${1:?usage: smoke-test.sh https://host}"
BASE_URL="${BASE_URL%/}"
FAIL=0

probe() {
    local desc="$1" url="$2" want_code="$3"
    local code
    code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 10 "$url" 2>/dev/null || echo 000)
    if [ "$code" = "$want_code" ]; then
        printf '  \033[32m✓\033[0m %-40s %s -> %s\n' "$desc" "$url" "$code"
    else
        printf '  \033[31m✗\033[0m %-40s %s -> %s (esperava %s)\n' "$desc" "$url" "$code" "$want_code"
        FAIL=$((FAIL+1))
    fi
}

probe_redirect_to() {
    local desc="$1" url="$2" want_host="$3"
    local target
    target=$(curl -sS -o /dev/null -w '%{redirect_url}' --max-time 10 "$url" 2>/dev/null || echo "")
    if [[ "$target" == *"$want_host"* ]]; then
        printf '  \033[32m✓\033[0m %-40s -> %s\n' "$desc" "$want_host"
    else
        printf '  \033[31m✗\033[0m %-40s -> %s (esperava %s)\n' "$desc" "$target" "$want_host"
        FAIL=$((FAIL+1))
    fi
}

echo "=== smoke test against $BASE_URL ==="

# Fundamentos
probe "frontend root"        "$BASE_URL/"                            200
probe "backend health"       "$BASE_URL/health"                      200
probe "backend api docs"     "$BASE_URL/docs"                        200
probe "openapi schema"       "$BASE_URL/openapi.json"                200

# Auth endpoints (sem session → 401)
probe "providers list"       "$BASE_URL/api/auth/providers"          200

# Login redirects: cada provider deve retornar 302 pra IdP correto
probe "iotedu login (302)"   "$BASE_URL/api/auth/iotedu/login"       302
probe "anonshield login (302)" "$BASE_URL/api/auth/anonshield/login" 302
probe "google login (307)"   "$BASE_URL/api/auth/google/login"       307

probe_redirect_to "iotedu → idp.iotedu.org" "$BASE_URL/api/auth/iotedu/login" "idp.iotedu.org"
probe_redirect_to "anonshield → idp.anonshield.org" "$BASE_URL/api/auth/anonshield/login" "idp.anonshield.org"
probe_redirect_to "google → accounts.google.com" "$BASE_URL/api/auth/google/login" "accounts.google.com"

# Discovery dos IdPs precisam estar reachable (senão login quebra)
probe "idp.iotedu.org discovery"     "https://idp.iotedu.org/realms/iotedu/.well-known/openid-configuration"     200
probe "idp.anonshield.org discovery" "https://idp.anonshield.org/realms/anonshield/.well-known/openid-configuration" 200

if [ $FAIL -eq 0 ]; then
    echo "=== smoke test OK ==="
    exit 0
fi
echo "=== smoke test FALHOU ($FAIL falhas) ==="
exit 1
