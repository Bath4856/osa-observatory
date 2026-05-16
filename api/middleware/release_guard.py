from fastapi import HTTPException
from sqlalchemy import text
from api.db import SessionLocal

VALID_RELEASE_STATUSES = {"ACTIVE_CANDIDATE", "ACTIVE_RELEASE"}


def validate_release_status() -> None:
    """
    Vérifie que la release courante est dans un état valide.
    À appeler dans chaque endpoint avant de servir des données.
    Corrigé : db.close() dans finally pour éviter les fuites de connexion.
    """
    db = SessionLocal()
    try:
        query = text("""
            SELECT release_status
            FROM pub.v_isa_release_manifest
            LIMIT 1
        """)
        result = db.execute(query).fetchone()
    finally:
        db.close()

    if not result:
        raise HTTPException(
            status_code=503,
            detail="Release manifest unavailable — base de données non initialisée"
        )

    if result[0] not in VALID_RELEASE_STATUSES:
        raise HTTPException(
            status_code=503,
            detail=f"Release non active : {result[0]}"
        )
