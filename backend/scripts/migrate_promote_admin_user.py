#!/usr/bin/env python3
"""Promove admin@iotedu.org a ADMIN com institution_id da Unipampa seed.

Idempotente: roda no boot do backend. Só atualiza se a linha existir e
ainda não estiver no estado alvo. O usuário só é criado em users após
seu primeiro login OIDC, então a primeira execução pode não fazer nada.
"""
from sqlalchemy import create_engine, text
import os
import sys

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import config

ADMIN_EMAIL = os.getenv("ADMIN_AUTO_PROMOTE_EMAIL", "admin@iotedu.org")
DEFAULT_INSTITUTION = os.getenv("ADMIN_DEFAULT_INSTITUTION_ID", "1")


def migrate():
    engine = create_engine(
        f"mysql://{config.MYSQL_USER}:{config.MYSQL_PASSWORD}@{config.MYSQL_HOST}/{config.MYSQL_DB}"
    )
    with engine.connect() as conn:
        result = conn.execute(
            text(
                "UPDATE users "
                "SET permission='ADMIN', institution_id=:inst "
                "WHERE email=:email "
                "AND (permission != 'ADMIN' OR institution_id IS NULL)"
            ),
            {"email": ADMIN_EMAIL, "inst": int(DEFAULT_INSTITUTION)},
        )
        conn.commit()
        if result.rowcount:
            print(f"promoted {ADMIN_EMAIL} to ADMIN (institution_id={DEFAULT_INSTITUTION})")
        else:
            print(f"no promotion needed (user '{ADMIN_EMAIL}' not in DB yet or already ADMIN)")


if __name__ == "__main__":
    migrate()
