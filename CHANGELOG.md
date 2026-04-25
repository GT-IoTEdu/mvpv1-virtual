# Mudanças no IoT-EDU

Resumo das mudanças aplicadas desde o estado inicial do repositório, agrupadas
por área. Cada item aponta para os arquivos relevantes, sem entrar em detalhes
do que o código já documenta por si.

## 1. Deploy: docker compose → scripts `.sh`

Migração completa do orquestrador de produção: o deploy não usa mais
`docker compose`. Cada host agora roda um script bash que chama `docker run`
diretamente, com nomes/redes/volumes explícitos.

- `scripts/lib-deploy.sh` — biblioteca compartilhada (build, db, app
  containers, IDS, Caddy attach, backup, healthcheck, smoke).
- `scripts/a9-deploy.sh` — `iotedu.anonshield.org` no a9 (Caddy em container,
  containers ficam na mesma rede docker).
- `scripts/guasca-deploy.sh` — `mvp.iotedu.org` no guasca (Caddy nativo, app
  publica em `127.0.0.1:8000/3000`).
- `scripts/testes-deploy.sh` — `testes.iotedu.org` (staging) também no guasca,
  porta `127.0.0.1:8001/3001`, project/network/volume isolados.

Por que: simplicidade. Compose adicionava uma camada de abstração que estava
mais atrapalhando (port conflict, names diferentes por overlay, comportamento
do `condition: service_healthy` em versões diferentes da CLI) do que ajudando.
`docker run` no shell é a unidade mínima que faz o que precisamos.

Os arquivos `docker-compose.yml`, `compose.a9.yml` e `compose.guasca.yml`
**continuam no repo apenas como conveniência para subir local**. Nenhum
workflow de CI/CD os usa.

## 2. CI/CD em duas máquinas + staging

Workflows do GitHub Actions:

- `.github/workflows/deploy-a9.yml` — push em `main` → rsync e
  `a9-deploy.sh` no a9. Depois roda pytest + jest contra
  `iotedu.anonshield.org` (consultivos, não bloqueiam o deploy).
- `.github/workflows/deploy-guasca.yml` — idem para guasca/`mvp.iotedu.org`.
- `.github/workflows/deploy-testes.yml` — push em `testes` → rsync e
  `testes-deploy.sh` no guasca. Mesma lógica de testes consultivos. Sem
  scans de vulnerabilidade pra ser rápido (eles ficam só no main).
- `.github/workflows/quality.yml` — Trivy (filesystem + imagens), Gitleaks,
  Bandit, Ruff, npm audit. Trigger só em `main` + PR pra `main` + cron diário
  06:00. Tudo consultivo (`continue-on-error: true`) e SARIF vai pra aba
  Security do GitHub.
- `.github/dependabot.yml` — pip/npm com agrupamento de minor/patch (1 PR só
  por ecossistema), docker mensal, github-actions agrupados, limites baixos
  pra não inundar de branches.

Concorrência por grupo (não rodam dois deploys do mesmo host em paralelo) e
flock no host (segunda invocação falha rápido com mensagem clara).

## 3. Autenticação multi-IdP (OIDC)

`backend/auth/iotedu_auth.py` é um router OIDC genérico que descobre
provedores via env (`IDP_<NAME>_DISCOVERY_URL`, `IDP_<NAME>_CLIENT_ID`,
`IDP_<NAME>_CLIENT_SECRET`, `IDP_<NAME>_REDIRECT_URI`,
`IDP_<NAME>_POST_LOGOUT_URI`). Hoje rodamos com dois providers simultâneos:

- `iotedu` → `idp.iotedu.org` (Keycloak no guasca).
- `anonshield` → `idp.anonshield.org` (Keycloak no a9).

Rotas: `/api/auth/{provider}/{login,callback,logout,me}` e
`/api/auth/providers` (lista o que está configurado).

Logout RP-initiated com `id_token_hint` armazenado na sessão; rotas de logout
chamam o `end_session_endpoint` do provider correto.

## 4. Frontend — login redesenhado

`frontend/app/login/page.tsx` agora tem 4 caminhos:

- **CAFe** (federação acadêmica) — card grande no topo com logo. Primário.
- **Google** — botão dentro do card secundário.
- **IdP IoTEdu** — favicon Wi-Fi do IoT-EDU (`/idp-iotedu.svg`).
- **IdP AnonShield** — escudo (`/idp-anonshield.svg`).

Ativação por feature flag (`PROVIDERS_ENABLED`) — desligar um provider é
trocar `true` por `false`.

## 5. Persistência e segurança operacional

- **Healthcheck `/health` faz ping no MySQL.** Backend retorna 503 se o DB
  não responde — Caddy sinaliza outage real, não 200 enganoso.
  (`backend/main.py`)
- **Backup automático do MySQL.** Cron instalado pelo deploy:
  `scripts/backup-mysql.sh` roda 03:00 todo dia, dump comprimido, retenção
  configurável (`RETAIN_DAYS`, padrão 7).
- **Healthcheck do container db** com `mysqladmin ping`, `start_period: 30s`.
- **`restart: unless-stopped`** em todos os containers de aplicação.
- **`proxy_headers=True`/`forwarded_allow_ips="*"`** no uvicorn — Caddy
  termina TLS, backend respeita `X-Forwarded-Proto` (corrige o
  `OAuth 2 MUST utilize https` que estava bloqueando o login Google).
- **Multi-superuser** via `SUPERUSER_ACCESS` (lista por vírgula em vez de um
  único email).

## 6. Frontend — Dockerfile manifest-first + build no build-time

`frontend/Dockerfile` faz `COPY package.json package-lock.json* && npm install`
**antes** de copiar o resto do código. Layer cache de `node_modules` é
preservado entre deploys que não mexem em deps. `npm run build` roda no
`docker build` — não no `start.sh` — pra que o container suba em segundos
em vez de ~60s.

Mesmo padrão para o backend (`requirements.txt` antes do código).

## 7. Smoke + testes

- `scripts/smoke-test.sh` — 14 probes contra a URL do deploy (200/302/307,
  redirect targets pros 3 IdPs, discovery URLs dos Keycloaks). Falha aqui
  faz o deploy falhar.
- `tests/api.test.js` — suíte Jest com fetch nativo, 14 testes por rota.
- `backend/testes/test_routes.py` — equivalente em pytest com classes
  Happy/Bad/External, mesma cobertura.

CI roda os dois em modo consultivo (sumário do run + warning, nunca bloqueia
deploy). Resultados aparecem no GITHUB_STEP_SUMMARY e na aba Checks via
`dorny/test-reporter` (quando o jest gera junit.xml).

## 8. Branch model

```
testes  →  PR pra main  →  main
   ↓                          ↓
testes.iotedu.org        a9 + guasca (paralelo)
                          mvp.iotedu.org
                          iotedu.anonshield.org
```

- `testes` é a branch de iteração rápida (sem scans pesados).
- `main` segue como branch de produção; convenção é mergear via PR de `testes`.
- Push em feature branches não dispara nada — economiza CI minutes.

> **Branch protection no main não está habilitada.** O GitHub bloqueia
> branch protection / rulesets para repositórios privados em plano Free
> (HTTP 403: *"Upgrade to GitHub Pro or make this repository public"*).
> Repo é privado intencionalmente, então a regra "merge só via PR" é
> seguida por convenção (não tem enforcement automático). Para ativar
> protection, ou tornar o repo público, ou subir o plano da org pra Pro/Team.

## 9. Setup-host idempotente

`scripts/setup-host.sh` provisiona uma máquina nova em uma execução: docker,
módulos do VirtualBox, OVA do bridge-tap, systemd unit. Idempotente — pode
rodar de novo sem efeito colateral.
