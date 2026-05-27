"""
OSA Observatory -- api/security.py
Sprint 17 -- Pont de compatibilité JWT

Ce fichier conserve intégralement la logique X-Api-Key Sprint 14
(validate_standard_access / validate_premium_access / validate_expert_access)
pour que les routers existants (countries.py, predictive.py, eparticipation.py,
tokens.py) continuent de fonctionner sans aucune modification.

Ajout Sprint 17 : réexport des dépendances JWT depuis api.auth pour
les nouveaux routers qui souhaitent consommer des Bearer tokens.

Stratégie de migration (après la période de grâce de 90 jours) :
    Remplacer dans chaque router :
        from api.security import validate_standard_access
    par :
        from api.routers.auth import require_standard
    puis supprimer ce fichier.
"""

import hashlib
import logging
from datetime import date
from fastapi import Header, HTTPException
from sqlalchemy import text
from api.db import SessionLocal

# -- Imports JWT (nouveaux routers uniquement) --
from api.routers.auth import (                           # noqa: F401
    get_current_token,
    require_standard,
    require_premium,
    require_expert,
)

log = logging.getLogger("osa_security")


def _hash_key(raw_key: str) -> str:
    """SHA-256 de la clé reçue -- jamais la clé en clair."""
    return hashlib.sha256(raw_key.encode("utf-8")).hexdigest()


def _validate_access(raw_key: str | None, required_level: str) -> dict:
    """
    Validation générique par niveau d'accès -- logique Sprint 14 inchangée.

    required_level : STANDARD | PREMIUM | EXPERT
    Hiérarchie : EXPERT >= PREMIUM >= STANDARD

    Retourne le dict de la clé si valide.
    Lève HTTPException 401 ou 403 sinon.
    """
    if not raw_key:
        raise HTTPException(status_code=401, detail="Missing API key -- X-Api-Key header required")

    hashed = _hash_key(raw_key)

    db = SessionLocal()
    try:
        row = db.execute(text("""
            SELECT
                api_key_id,
                access_class,
                effective_access_class,
                access_granted,
                rate_limit_per_hour,
                requests_today,
                last_reset_date,
                owner_label,
                affiliation_id,
                institution_name,
                affiliation_status
            FROM mg.v_api_key_status
            WHERE api_key_hash = :hashed
        """), {"hashed": hashed}).mappings().fetchone()

        if not row:
            raise HTTPException(status_code=403, detail="Invalid API key")

        if not row["access_granted"]:
            raise HTTPException(
                status_code=403,
                detail="API key inactive, expired, or affiliation suspended"
            )

        level_hierarchy = {"STANDARD": 1, "PREMIUM": 2, "EXPERT": 3}
        effective     = row["effective_access_class"] or "STANDARD"
        required_rank = level_hierarchy.get(required_level, 1)
        effective_rank = level_hierarchy.get(effective, 1)

        if effective_rank < required_rank:
            raise HTTPException(
                status_code=403,
                detail=f"Insufficient access level -- {required_level} required, {effective} granted. "
                       f"Upgrade at open.osa-observatory.org/subscribe"
            )

        today         = date.today()
        last_reset    = row["last_reset_date"]
        requests_today = row["requests_today"] or 0
        rate_limit    = row["rate_limit_per_hour"] or 500

        if last_reset != today:
            db.execute(text("""
                UPDATE mg.api_key_registry
                SET requests_today = 1,
                    last_reset_date = :today,
                    last_used_at = NOW()
                WHERE api_key_hash = :hashed
            """), {"today": today, "hashed": hashed})
        else:
            if requests_today >= rate_limit:
                raise HTTPException(
                    status_code=429,
                    detail=f"Rate limit exceeded -- {rate_limit} requests/day. Resets at midnight UTC."
                )
            db.execute(text("""
                UPDATE mg.api_key_registry
                SET requests_today = requests_today + 1,
                    last_used_at = NOW()
                WHERE api_key_hash = :hashed
            """), {"hashed": hashed})

        db.commit()
        return dict(row)

    finally:
        db.close()


def validate_standard_access(x_api_key: str = Header(default=None)) -> dict:
    """Dependency FastAPI -- Couche 1 -- Affilié standard S1."""
    return _validate_access(x_api_key, "STANDARD")


def validate_premium_access(x_api_key: str = Header(default=None)) -> dict:
    """Dependency FastAPI -- Couche 2 -- Affilié premium S2."""
    return _validate_access(x_api_key, "PREMIUM")


def validate_expert_access(x_api_key: str = Header(default=None)) -> dict:
    """Dependency FastAPI -- Expert interne OSA."""
    return _validate_access(x_api_key, "EXPERT")


def generate_api_key() -> tuple[str, str]:
    """
    Génère une nouvelle clé API et son hash SHA-256.
    Retourne (raw_key, hashed_key).
    La raw_key n'est jamais stockée -- à transmettre une seule fois à l'affilié.
    """
    import secrets
    raw_key = f"osa_{secrets.token_urlsafe(32)}"
    hashed  = _hash_key(raw_key)
    return raw_key, hashed
