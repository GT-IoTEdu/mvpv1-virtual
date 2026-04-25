# Instalação em domínio + servidor novos

Como subir o IoT-EDU numa máquina Linux nova com domínio próprio.
Maioria do trabalho está num único script — só sobra DNS, secrets e
config dos IdPs (que são manuais por natureza).

**Tempo**: ~10 min do bootstrap + ~10 min de Keycloak/Google + 5 min
de build = ~25 min total na primeira vez.

---

## Caminho rápido (3 comandos + 3 painéis externos)

### Passo 1 — DNS (1 min, painel do seu provedor de DNS)

Cria um A record apontando o domínio (ex.: `app.exemplo.com`) pro IP
público da máquina. Se for ter Keycloak no mesmo host, cria também
`idp.exemplo.com` com o mesmo IP.

> **Cloudflare**: deixa "DNS only" (cinza), não "Proxied" (laranja) —
> ACME do Caddy precisa do tráfego direto.

### Passo 2 — Bootstrap da máquina (1 comando, ~5 min)

```bash
ssh user@maquina-nova
git clone https://github.com/GT-IoTEdu/mvpv1-virtual.git ~/iotedu
bash ~/iotedu/scripts/bootstrap-new-host.sh app.exemplo.com
```

O script faz tudo o que pode ser automatizado:
- Instala Docker se faltar
- Instala Caddy nativo (modo padrão) **ou** sobe Caddy como container (modo `CADDY_MODE=container`)
- Adiciona vhost de `app.exemplo.com` (no Caddyfile do sistema ou no Caddy do container)
- Gera `backend/.env` com placeholders + secrets aleatórios pra DB e sessão
- Cria alias `iotedu-deploy` no `~/.bashrc`

**Opções de Caddy:**

```bash
# Caddy nativo (padrão) — apt install caddy, vhost em /etc/caddy/Caddyfile
bash ~/iotedu/scripts/bootstrap-new-host.sh app.exemplo.com

# Caddy em container — host fica só com docker, ZERO instalação extra
CADDY_MODE=container bash ~/iotedu/scripts/bootstrap-new-host.sh app.exemplo.com

# Com IDS
ENABLE_IDS=yes bash ~/iotedu/scripts/bootstrap-new-host.sh app.exemplo.com
```

**Diferença prática**: o modo container mantém o host limpo (só Docker
instalado), Caddy roda como `${PROJECT}-caddy-1`, com volumes nomeados
pra persistir cert TLS entre reboots. Vhost gerado em `~/iotedu/.caddy/Caddyfile`
e montado read-only no container. Mesma funcionalidade, mesmo cert
automático Let's Encrypt — só não polui o sistema base.

### Passo 3 — Configurar OAuth providers (manual, ~10 min)

Não dá pra automatizar — exige login nos painéis externos. Faz só os
que for usar.

**Google OAuth** (`console.cloud.google.com` → APIs & Services → Credentials):
- Authorized JS origins: `https://app.exemplo.com`
- Authorized redirect URI: `https://app.exemplo.com/api/auth/google/callback`
- Copia Client ID e Secret

**Keycloak (admin do seu IdP)**:
- Cria realm (ex.: `iotedu`)
- Cria client `iotedu-web` (OpenID Connect, client auth on, standard flow)
- Valid redirect URIs: `https://app.exemplo.com/api/auth/iotedu/callback`
- Valid post logout: `https://app.exemplo.com/`
- Web origins: `https://app.exemplo.com`
- Aba Credentials → copia Client Secret

### Passo 4 — Preencher `.env` com os secrets (3 min)

```bash
nano ~/iotedu/backend/.env
```

Os campos `MYSQL_*` e `SESSION_SECRET_KEY` já vieram preenchidos. Você
preenche:
- `GOOGLE_CLIENT_ID` + `GOOGLE_CLIENT_SECRET` (se usar Google)
- `IDP_IOTEDU_DISCOVERY_URL` + `IDP_IOTEDU_CLIENT_SECRET` (se usar Keycloak)
- `SUPERUSER_ACCESS` (emails admin separados por vírgula)

### Passo 5 — Deploy (1 comando, ~5 min)

```bash
newgrp docker      # só se Docker foi instalado agora
source ~/.bashrc   # pega o alias
iotedu-deploy
```

Pronto. App em `https://app.exemplo.com`.

Próximos deploys:

```bash
iotedu-deploy
```

(faz `git pull` e re-roda o script com cache de build aproveitado).

---

## O que cada peça faz

| Componente | Onde | Pra quê |
|---|---|---|
| **Docker** | host | engine de containers |
| **Caddy** | host (systemd) | reverse proxy + cert TLS automático |
| **MySQL container** | docker | DB persistente em volume nomeado |
| **Backend container** | docker | FastAPI + uvicorn em :8000 |
| **Frontend container** | docker | Next.js produção em :3000 |
| **SSE container** | docker | streaming de logs IDS |
| **(opcional) Zeek/Suricata/Snort** | docker host network | IDS no `bridge-tap` |
| **(opcional) pfSense VM** | VirtualBox | gateway simulado pro IDS observar |

Caddy escuta 80/443, proxia `/api/*`, `/auth/*`, `/docs`, `/openapi.json`,
`/health` pro backend (`localhost:8000`) e o resto pro frontend
(`localhost:3000`).

---

## Backup do MySQL

O deploy script instala automaticamente um cron diário às 03:00 que
roda `scripts/backup-mysql.sh`. Backups gzipados ficam em
`~/iotedu/backups/`. Retenção 7 dias.

---

## Troubleshooting

### Caddy retorna 502
Backend ou frontend offline:
```bash
docker ps | grep iotedu
docker logs <project>-backend-1 | tail -30
```

### Cert TLS não emite
```bash
sudo journalctl -u caddy --since '5 min ago' | grep -i 'cert\|acme'
```
Causas: DNS não propagou ainda, Cloudflare em Proxied mode, porta 80/443 fechada.

### `invalid redirect_uri` ao logar
A URI no provider OAuth não bate exatamente com a do `.env`. Confere
trailing slash, http vs https, subdomínio.

### Deploy trava em "sondando"
Backend não veio up. Olha os logs:
```bash
docker logs <project>-backend-1
```
Geralmente é `.env` faltando algum campo obrigatório, ou DB sem espaço.

### Re-rodar bootstrap
O script é idempotente — pode rodar quantas vezes quiser:
```bash
bash ~/iotedu/scripts/bootstrap-new-host.sh app.exemplo.com
```

---

## Pra automatizar via CI/CD (deploy a cada push)

Ver `DEPLOY.md`.
