# IDS Log Monitor – SSE Server

Servidor SSE que envia alertas dos IDS (Suricata, Snort, Zeek) para o backend. Roda **no mesmo servidor dos IDS** (ex.: 192.168.59.103). Suporta **TLS** e **assinatura HMAC** para maior segurança.

## Onde roda

- **Servidor:** mesmo host dos IDS (ex.: **192.168.59.103**), com acesso aos logs do Suricata, Snort e Zeek.
- **Backend:** conecta a esse host via `http://192.168.59.103:8001` ou `https://192.168.59.103:8443` (com TLS).

## Segurança

### TLS (HTTPS)

Para rodar com HTTPS no servidor 192.168.59.103:

1. **Gerar certificados** (no servidor ou na sua máquina, com OpenSSL):
   ```bash
   # No servidor (Linux) – script incluído
   cd ids-log-monitor
   chmod +x generate_certs.sh
   bash generate_certs.sh
   ```
   **Não precisa de `sudo`** para gerar `server.crt`/`server.key` no seu diretório (`~/Documents`).

### Erro: `sudo: unable to execute ./generate_certs.sh: No such file or directory`

Geralmente é um destes pontos:

1. **Finais de linha Windows (CRLF)** – o shebang vira `#!/bin/bash\r` e o kernel não acha o interpretador.
   ```bash
   sed -i 's/\r$//' generate_certs.sh
   chmod +x generate_certs.sh
   bash generate_certs.sh
   ```
   Ou: `sudo apt install -y dos2unix && dos2unix generate_certs.sh`

2. **Não use `sudo` para este script** – `openssl` escreve na pasta atual; com `sudo` ainda podem aparecer problemas de path ou permissões desnecessários.

3. **Rodar com bash explicitamente** (evita depender do shebang):
   ```bash
   bash generate_certs.sh
   ```
   Isso gera `server.crt` e `server.key` na pasta (válidos para 192.168.59.103 e localhost).

   **Manual (qualquer SO):**
   ```bash
   openssl genrsa -out server.key 2048
   openssl req -new -x509 -key server.key -out server.crt -days 365 \
     -subj "/CN=192.168.59.103/O=IDS Log Monitor/C=BR" \
     -addext "subjectAltName=IP:192.168.59.103,DNS:localhost"
   ```

2. **Variáveis de ambiente** (opcional):
   - `SSE_TLS_CERT_FILE`: caminho do certificado (ex.: `./server.crt`)
   - `SSE_TLS_KEY_FILE`: caminho da chave (ex.: `./server.key`)
   - `SSE_PORT`: porta (ex.: `8443`)

3. **Execução no servidor 192.168.59.103**:
   ```bash

   uvicorn sse_server:app --host 0.0.0.0 --port 8443 --ssl-certfile=server.crt --ssl-keyfile=server.key
   ```

4. No **frontend** (`Cadastro de Instituição`), use a URL com HTTPS: `https://192.168.59.103:8443` nas URLs Suricata/Snort/Zeek da instituição.
5. Com **certificado autoassinado** e verificação TLS ativa (`IDS_SSE_TLS_VERIFY=true`, padrão):
   - Copie o ficheiro `server.crt` (o mesmo que o Uvicorn usa) da máquina **192.168.59.103** para o PC onde corre o backend.
   - No `backend/.env`:
     ```env
     IDS_SSE_TLS_VERIFY=true
     IDS_SSE_TLS_CAFILE=C:\caminho\para\server.crt
     ```
     (No Linux use o caminho absoluto, ex.: `/home/user/certs/server.crt`.)
   - Alternativa **menos segura** (só testes / rede fechada): `IDS_SSE_TLS_VERIFY=false`.

### HMAC (assinatura dos eventos)

Cada payload SSE é assinado com **HMAC-SHA256** usando a **API key** do cliente como segredo. O backend verifica a assinatura e rejeita eventos adulterados.

- **Servidor (ids-log-monitor):** adiciona o campo `signature` em cada evento.
- **Backend:** usa a mesma API key para verificar e remove o campo antes de processar.
- **Compatibilidade:** se o servidor não enviar `signature`, o backend aceita o evento (comportamento anterior).

Nenhuma configuração extra é necessária: a mesma chave usada em `?api_key=...` é usada para assinar/verificar.

## Uso

- Endpoints: `/sse/alerts` (Suricata), `/sse/snort`, `/sse/zeek`, `/sse/all`.
- Autenticação: `?api_key=<chave>` (ver `API_KEYS` em `sse_server.py`).
- Health: `GET /health`.
