import hashlib
from fastapi import Header, HTTPException
from sqlalchemy import text
from api.db import SessionLocal


def _hash_key(raw_key: str) -> str:
    """SHA-256 de la clé reçue — comparé au hash stocké en base."""
    return hashlib.sha256(raw_key.encode("utf-8")).hexdigest()


def validate_expert_access(x_api_key: str = Header(default=None)) -> bool:
    """
    Dependency FastAPI pour les endpoints EXPERT.
    La clé reçue est hachée avant comparaison avec mg.api_key_registry.
    """
    if not x_api_key:
        raise HTTPException(status_code=401, detail="Missing API key")

    hashed = _hash_key(x_api_key)

    db = SessionLocal()
    try:
        query = text("""
            SELECT 1
            FROM mg.api_key_registry
            WHERE api_key_hash = :hashed
              AND is_active = TRUE
              AND (expires_at IS NULL OR expires_at > NOW())
        """)
        result = db.execute(query, {"hashed": hashed}).fetchone()
    finally:
        db.close()

    if not result:
        raise HTTPException(status_code=403, detail="Invalid or expired API key")

    return True
