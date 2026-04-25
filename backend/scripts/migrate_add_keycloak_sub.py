#!/usr/bin/env python3
from sqlalchemy import create_engine, text
import os
import sys

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import config

COLUMN = "keycloak_sub"
INDEX = "ix_users_keycloak_sub"


def migrate():
    engine = create_engine(
        f"mysql://{config.MYSQL_USER}:{config.MYSQL_PASSWORD}@{config.MYSQL_HOST}/{config.MYSQL_DB}"
    )
    with engine.connect() as conn:
        exists = conn.execute(
            text(
                "SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS "
                "WHERE TABLE_SCHEMA=:db AND TABLE_NAME='users' AND COLUMN_NAME=:c"
            ),
            {"db": config.MYSQL_DB, "c": COLUMN},
        ).fetchone()

        if exists:
            print(f"ℹ️ Coluna '{COLUMN}' já existe")
        else:
            conn.execute(text(f"ALTER TABLE users ADD COLUMN {COLUMN} VARCHAR(255) NULL"))
            conn.execute(text(f"CREATE UNIQUE INDEX {INDEX} ON users ({COLUMN})"))
            conn.commit()
            print(f"✅ Coluna '{COLUMN}' e índice único adicionados")


if __name__ == "__main__":
    migrate()
