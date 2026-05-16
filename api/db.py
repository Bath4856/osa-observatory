from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
from api.config import settings

DATABASE_URL = (
    f"postgresql+psycopg2://{settings.DB_USER}:"
    f"{settings.DB_PASSWORD}@{settings.DB_HOST}:"
    f"{settings.DB_PORT}/{settings.DB_NAME}"
)

engine = create_engine(
    DATABASE_URL,
    pool_pre_ping=True,
    pool_size=10,
    max_overflow=20,
)

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def check_db_connection() -> bool:
    """Vérifie que la base est accessible — utilisé au démarrage."""
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        return True
    except Exception:
        return False
