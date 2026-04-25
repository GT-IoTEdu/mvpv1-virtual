#!/usr/bin/env python3
"""
Script para iniciar o servidor FastAPI
"""

import uvicorn
import os
import sys

# Adicionar o diretório pai ao path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Carregar variáveis de ambiente
from dotenv import load_dotenv
load_dotenv()

mysql_user = os.getenv("MYSQL_USER")
mysql_password = os.getenv("MYSQL_PASSWORD")
backend_host = os.getenv("BACKEND_HOST", "0.0.0.0")
backend_port = int(os.getenv("BACKEND_PORT", "8000"))
backend_reload = os.getenv("BACKEND_RELOAD", "false").lower() in ("1", "true", "yes")

if not mysql_user or not mysql_password:
    print("❌ ERRO: MYSQL_USER e MYSQL_PASSWORD devem estar definidos no arquivo .env")
    sys.exit(1)

print("✅ Configurações OK! Iniciando servidor...")
print("=" * 50)

if __name__ == "__main__":
    uvicorn.run(
        "backend.main:app",
        host=backend_host,
        port=backend_port,
        reload=backend_reload,
        log_level="info",
        proxy_headers=True,
        forwarded_allow_ips="*",
    )
