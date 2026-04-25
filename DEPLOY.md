# Deploy & Operações — wticifes2026-iotedu

Source-of-truth: **https://github.com/GT-IoTEdu/mvpv1-virtual**
Branch: `main` — todo push dispara deploy automático nos hosts abaixo.

---

## Hosts em produção

| Host | Domínio | IP | Função |
|---|---|---|---|
| `a9` (`android09.unihacker.club`) | `iotedu.anonshield.org` | `200.132.136.128` | App IoTEdu + IdP AnonShield (Keycloak realm `anonshield`) |
| `guasca` (`guasca.unihacker.club`) | `mvp.iotedu.org` | `200.132.136.127` | App IoTEdu (segunda instância) + IdP IoTEdu (Keycloak realm `iotedu` em `idp.iotedu.org`) |

Ambos rodam **a mesma aplicação** com configs específicas via `.env` por
host. IdPs são separados — cada um com seu domínio e realm.

---

## CI/CD — o que dispara automaticamente

Todo `git push` em `main` do `GT-IoTEdu/mvpv1-virtual` aciona, em
paralelo, dois workflows:

```
.github/workflows/deploy-a9.yml      → host a9     (rsync + ssh deploy)
.github/workflows/deploy-guasca.yml  → host guasca (rsync + ssh deploy)
```

Cada workflow:

1. Faz `actions/checkout` no runner do GitHub.
2. Carrega chave SSH dedicada do secret (`A9_SSH_PRIVATE_KEY` /
   `GUASCA_SSH_PRIVATE_KEY`) com `known_hosts` pinado.
3. `rsync -az --delete` o repo pra `/home/cristhian/<repo>/` no host,
   excluindo `.git`, `backend/.env`, `.env`, `ids/logs/` e
   `.deploy.lock`.
4. SSH no host e executa `bash scripts/<host>-deploy.sh`.

O script de deploy:

1. `flock` em `.deploy.lock` (evita concorrência se 2 pushes batem
   simultâneo).
2. `docker compose up -d --build` dos serviços listados.
3. `docker image prune -f` (limpa camadas órfãs).
4. Health-check com retry contra `/health` por até 60s.

### Mudanças que **propagam** no push

| Mudança | a9 | guasca |
|---|---|---|
| `backend/**` (FastAPI, migrations) | ✅ rebuild + restart | ✅ rebuild + restart |
| `frontend/**` (Next.js, public/) | ✅ rebuild + restart | ✅ rebuild + restart |
| `ids/rules/site_zeek/*.zeek` | ✅ se bridge-tap existir | ✅ se bridge-tap existir |
| `ids/rules/rules_suricata/*` | ✅ se bridge-tap existir | ✅ se bridge-tap existir |
| `ids/rules/rules_snort/*` | ✅ se bridge-tap existir | ✅ se bridge-tap existir |
| `ids/implementation/*/Dockerfile` | ✅ rebuild | ✅ rebuild |
| `ids/ids_log_monitor/*` (SSE) | ✅ | ✅ |
| `compose.a9.yml` / `compose.guasca.yml` | ✅ | ✅ |
| `.github/workflows/*.yml` | aplicado no push seguinte | aplicado no push seguinte |
| `scripts/*.sh` | rsync mas só executa quando o deploy roda | idem |

> Os IDS containers só sobem **se a bridge-tap existir** no host (o
> `scripts/<host>-deploy.sh` faz `ip link show bridge-tap` e inclui
> `zeek/suricata_ids/snort_ids` na lista de serviços só nesse caso).
> Sem bridge, deploy continua mas IDS são pulados sem erro.

### Mudanças que **NÃO** propagam (intencional)

| Item | Onde fica | Como mudar |
|---|---|---|
| `backend/.env` (segredos) | em cada host | SSH manual, edita inline |
| `.env` raiz (interpolação MySQL) | em cada host | idem |
| Caddyfile do anonshield | `/home/cristhian/anonshield_deploy/web/Caddyfile` (a9) | edição manual + `docker exec web-caddy-1 caddy reload` |
| Caddyfile do guasca | `/etc/caddy/Caddyfile` (guasca) | edição manual + `sudo systemctl reload caddy` |
| pfSense VM (rules, NAT, aliases) | dentro da VM | webui da VM, salva no disco da VM |
| DNS Cloudflare | painel Cloudflare | manual |
| Usuários do Keycloak | DB do Keycloak | API admin (`/admin/realms/<realm>/users`) ou webui em `https://<idp>/admin` |
| Kernel modules + bridge-tap + systemd | host kernel | `sudo bash scripts/setup-host.sh` (one-shot) |

---

## Configurando um host novo (igual a9 ou guasca)

> Estimativa: ~15 min (sem download da OVA do pfSense).

### Pré-requisitos

- Servidor Debian/Ubuntu com SSH habilitado
- Acesso `sudo`
- Domínio público apontando pro IP do servidor (Cloudflare DNS-only)
- Docker já instalado (`docker --version`)
- Caddy a instalar (o `setup-host.sh` aceita Apache/nginx, mas
  documentação assume Caddy)

### Passo 1 — Bootstrap do host (1× com sudo)

```bash
ssh <novo-host>
sudo bash scripts/setup-host.sh                # cria bridge-tap, vboxdrv, systemd
                                               # Use SKIP_VM=1 se não vai rodar pfSense
```

### Passo 2 — Configurar Caddy (1× com sudo)

Caddyfile mínimo em `/etc/caddy/Caddyfile`:

```caddy
seu-dominio.org {
    handle /api/*       { reverse_proxy localhost:8000 }
    handle /auth/*      { reverse_proxy localhost:8000 }
    handle /docs*       { reverse_proxy localhost:8000 }
    handle /openapi.json { reverse_proxy localhost:8000 }
    handle /health      { reverse_proxy localhost:8000 }
    handle              { reverse_proxy localhost:3000 }
}
```

```bash
sudo systemctl reload caddy
```

### Passo 3 — Criar `.env` do backend

```bash
mkdir -p ~/<repo-dir>/backend
cat > ~/<repo-dir>/backend/.env <<'EOF'
MYSQL_USER=...
MYSQL_PASSWORD=...
MYSQL_ROOT_PASSWORD=...
MYSQL_HOST=db
MYSQL_DB=...

DEBUG=False
SECRET_KEY=$(openssl rand -base64 48)
JWT_SECRET_KEY=$(openssl rand -base64 48)
ALLOWED_HOSTS=seu-dominio.org,localhost,127.0.0.1
CORS_ALLOWED_ORIGINS=https://seu-dominio.org

GOOGLE_CLIENT_ID=...
GOOGLE_CLIENT_SECRET=...
GOOGLE_REDIRECT_URI=https://seu-dominio.org/api/auth/google/callback

IDP_IOTEDU_DISCOVERY_URL=https://idp.iotedu.org/realms/iotedu/.well-known/openid-configuration
IDP_IOTEDU_CLIENT_ID=iotedu-web
IDP_IOTEDU_CLIENT_SECRET=...
IDP_IOTEDU_REDIRECT_URI=https://seu-dominio.org/api/auth/iotedu/callback
IDP_IOTEDU_POST_LOGOUT_URI=https://seu-dominio.org/

IDP_ANONSHIELD_DISCOVERY_URL=https://idp.anonshield.org/realms/anonshield/.well-known/openid-configuration
IDP_ANONSHIELD_CLIENT_ID=iotedu-web
IDP_ANONSHIELD_CLIENT_SECRET=...
IDP_ANONSHIELD_REDIRECT_URI=https://seu-dominio.org/api/auth/anonshield/callback
IDP_ANONSHIELD_POST_LOGOUT_URI=https://seu-dominio.org/

SUPERUSER_ACCESS=superuser@iotedu.org,superuser@anonshield.org
NEXT_PUBLIC_API_BASE=
FRONTEND_URL=http://frontend:3000
IDS_SSE_TLS_VERIFY=False
AUTH_STRICT_SESSION=False
EOF
chmod 600 ~/<repo-dir>/backend/.env

# .env raiz pro compose interpolar MYSQL_*:
grep -E '^MYSQL_' ~/<repo-dir>/backend/.env > ~/<repo-dir>/.env
chmod 600 ~/<repo-dir>/.env
```

### Passo 4 — Cadastrar redirect URIs nos IdPs

Em cada Keycloak (idp.iotedu.org e idp.anonshield.org), adicionar ao
client `iotedu-web`:
- `https://seu-dominio.org/api/auth/iotedu/callback`
- `https://seu-dominio.org/api/auth/anonshield/callback`

E `webOrigins`: `https://seu-dominio.org`

### Passo 5 — Setup do CI/CD

5a. Gerar chave SSH dedicada no host:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/deploy_ci -N '' -C 'github-actions deploy'
printf 'restrict %s\n' "$(cat ~/.ssh/deploy_ci.pub)" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

5b. Configurar secrets no repo `GT-IoTEdu/mvpv1-virtual` (via `gh secret set`):

```bash
PRIVKEY=$(ssh <host> 'cat ~/.ssh/deploy_ci')
KH=$(ssh-keyscan -t ed25519,ecdsa,rsa <host> 2>/dev/null)
gh secret set <HOST>_SSH_PRIVATE_KEY --repo GT-IoTEdu/mvpv1-virtual --body "$PRIVKEY"
gh secret set <HOST>_KNOWN_HOSTS    --repo GT-IoTEdu/mvpv1-virtual --body "$KH"
gh secret set <HOST>_HOST           --repo GT-IoTEdu/mvpv1-virtual --body "<dns>"
gh secret set <HOST>_USER           --repo GT-IoTEdu/mvpv1-virtual --body "<linux user>"
```

5c. Adicionar `.github/workflows/deploy-<host>.yml` (copie de
`deploy-a9.yml` ou `deploy-guasca.yml`).

### Passo 6 — Primeiro deploy

```bash
git push origin main      # CI roda, app sobe automaticamente
```

Daqui pra frente, qualquer push em main propaga sozinho.

---

## Cheat-sheet ops

| Quero... | Comando |
|---|---|
| Ver containers do app no a9 | `ssh a9 'docker ps --filter name=iotedu-anonshield-'` |
| Ver containers no guasca | `ssh guasca 'docker ps --filter name=iotedu-mvp-'` |
| Logs do backend (a9) | `ssh a9 'docker logs --tail=50 -f iotedu-anonshield-backend-1'` |
| Logs do backend (guasca) | `ssh guasca 'docker logs --tail=50 -f iotedu-mvp-backend'` |
| Forçar redeploy sem commit | `gh workflow run deploy-a9.yml --repo GT-IoTEdu/mvpv1-virtual --ref main` |
| Listar workflow runs | `gh run list --repo GT-IoTEdu/mvpv1-virtual --limit 5` |
| Editar `.env` do a9 | `ssh a9 'nano /home/cristhian/wticifes2026-iotedu/backend/.env'` (depois `docker restart iotedu-anonshield-backend-1`) |
| Editar `.env` do guasca | `ssh guasca 'nano /home/cristhian/mvpv1-virtual/backend/.env'` (depois `docker restart iotedu-mvp-backend`) |

---

## Estrutura dos arquivos relevantes

```
.github/workflows/
  deploy-a9.yml              workflow do push → a9
  deploy-guasca.yml          workflow do push → guasca

scripts/
  setup-host.sh              one-shot por host (sudo): vbox, bridge-tap, systemd
  a9-deploy.sh               executado via ssh pelo workflow do a9
  guasca-deploy.sh           executado via ssh pelo workflow do guasca

docker-compose.yml           base — comum a todos os hosts (db, backend, frontend, IDS)
compose.a9.yml               overlay específico do a9 (project iotedu-anonshield)
compose.guasca.yml           overlay específico do guasca (project iotedu-mvp)

backend/auth/iotedu_auth.py  OIDC multi-provider (registry IDP_<NAME>_*)
backend/auth/google_auth.py  Google OAuth
backend/scripts/migrate_*.py migrations idempotentes (rodam no boot via start.sh)
```

---

## Decisões arquiteturais (porquê)

- **Rsync em vez de `git pull` no servidor:** o repo é privado e
  GitHub do GT-IoTEdu desabilita deploy keys em nível de org. O runner
  da Action tem o repo (via `actions/checkout`); rsync é a forma menos
  hacky de levar pro servidor.
- **`docker compose` em vez de docker run:** parity entre dev e CI,
  reaproveita o `docker-compose.yml` upstream sem fork. Plugin v2 foi
  instalado via curl em `~/.docker/cli-plugins/` para o user (sem sudo).
- **Build do Next.js no Dockerfile (não no boot):** janela de 502 no
  deploy cai de ~60s pra ~1s ao custo de `docker build` ~50s mais
  longo quando frontend muda. Trade-off vale.
- **IDS opt-in via bridge-tap:** se a infra de captura não foi
  provisionada (host sem `setup-host.sh`), o deploy ainda funciona;
  só o stack de IDS é pulado.
- **Multi-IdP via env `IDP_<NAME>_*`:** N providers OIDC sem alterar
  código — basta adicionar 5 envs e o registry detecta. Cada provider
  tem seu próprio `/api/auth/<name>/{login,callback,logout,me}`.
