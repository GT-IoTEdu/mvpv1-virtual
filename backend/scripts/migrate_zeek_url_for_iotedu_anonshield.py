#!/usr/bin/env python3
"""Realinha zeek_base_url para o nome de serviço Docker desta deploy.

O seed em create_institutions_simple.py grava http://host.docker.internal:8001
porque foi pensado para um SSE rodando no host. No deploy iotedu-anonshield,
o SSE roda como container `sse_server` na mesma rede do backend, então o
backend precisa alcançá-lo por DNS de serviço.
"""
from sqlalchemy import create_engine, text
import os
import sys

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import config

PLACEHOLDER = "http://host.docker.internal:8001"
TARGET = os.getenv("SSE_BASE_URL", "http://sse_server:8001")


def migrate():
    engine = create_engine(
        f"mysql://{config.MYSQL_USER}:{config.MYSQL_PASSWORD}@{config.MYSQL_HOST}/{config.MYSQL_DB}"
    )
    with engine.connect() as conn:
        result = conn.execute(
            text("UPDATE institutions SET zeek_base_url=:t WHERE zeek_base_url=:p"),
            {"t": TARGET, "p": PLACEHOLDER},
        )
        conn.commit()
        if result.rowcount:
            print(f"realigned {result.rowcount} institution(s) zeek_base_url -> {TARGET}")
        else:
            print(f"no row needed realignment (target already {TARGET} or empty)")


if __name__ == "__main__":
    migrate()
