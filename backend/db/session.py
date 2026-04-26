from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session
from contextlib import contextmanager

# Suporte a execução tanto via pacote (python -m backend.db.create_tables)
# quanto via import direto a partir da pasta backend
try:
    from .. import config  # type: ignore
except ImportError:  # fallback quando executado a partir do backend diretamente
    import config  # type: ignore

# Configuração do banco de dados MySQL
DATABASE_URL = f"mysql+pymysql://{config.MYSQL_USER}:{config.MYSQL_PASSWORD}@{config.MYSQL_HOST}/{config.MYSQL_DB}"

# pool_pre_ping: SQLAlchemy testa cada conexão do pool antes de usar e
# descarta as mortas (MySQL fecha idle após wait_timeout, default 8h).
# Sem isso, /health degrada após 8h+ uptime com BrokenPipeError.
# pool_recycle: força reciclagem antes do servidor cortar.
engine = create_engine(
    DATABASE_URL,
    echo=False,
    pool_pre_ping=True,
    pool_recycle=3600,
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

@contextmanager
def get_db_session():
    """
    Context manager para obter uma sessão do banco de dados.
    Garante que a sessão seja fechada adequadamente.
    
    Usage:
        with get_db_session() as db:
            # usar db aqui
            pass
    """
    session = SessionLocal()
    try:
        yield session
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()

def get_db():
    """
    Dependency para FastAPI que retorna uma sessão do banco de dados.
    """
    session = SessionLocal()
    try:
        yield session
    finally:
        session.close() 