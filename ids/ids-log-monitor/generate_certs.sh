#!/bin/bash
# Gera certificado autoassinado para o ids-log-monitor em 192.168.59.103
# Uso: ./generate_certs.sh   ou   bash generate_certs.sh
# Gera: server.crt e server.key na pasta ids-log-monitor (ou no diretório atual)

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

KEY_FILE="server.key"
CRT_FILE="server.crt"

echo "Gerando chave privada (2048 bits)..."
openssl genrsa -out "$KEY_FILE" 2048

echo "Gerando certificado autoassinado para 192.168.59.103 e localhost (válido 365 dias)..."
openssl req -new -x509 -key "$KEY_FILE" -out "$CRT_FILE" -days 365 \
  -subj "/CN=192.168.59.103/O=IDS Log Monitor/C=BR" \
  -addext "subjectAltName=IP:192.168.59.103,IP:127.0.0.1,DNS:localhost"

echo ""
echo "Pronto. Arquivos gerados:"
echo "  Certificado: $DIR/$CRT_FILE"
echo "  Chave:       $DIR/$KEY_FILE"
echo ""
echo "Para subir o SSE com TLS no servidor 192.168.59.103:"
echo "  export SSE_TLS_CERT_FILE=$DIR/$CRT_FILE"
echo "  export SSE_TLS_KEY_FILE=$DIR/$KEY_FILE"
echo "  export SSE_PORT=8443"
echo "  python -m uvicorn sse_server:app --host 0.0.0.0 --port 8443"
echo ""
echo "No backend, use a URL: https://192.168.59.103:8443"
