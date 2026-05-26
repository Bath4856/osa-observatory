"""
OSA Observatory -- Sprint 14
Module securite -- Validation tokens API par niveau d acces

3 niveaux :
  validate_standard_access  -- Couche 1 -- affilies S1
  validate_premium_access   -- Couche 2 -- affilies S2
  validate_expert_access    -- Couche 2+ -- usage interne OSA (legacy)

Architecture :
  - Cle API recue dans header X-Api-Key
  - Hash SHA-256 compare a mg.api_key_registry
  - Affiliation verifiee via mg.v_api_key_status
  - Rate limiting verifie et mis a jour
"""

import hashlib
import logging
from fastapi import Header, HTTPException
from sqlalchemy import text
from api.db import SessionLocal

log = logging.getLogger("osa_security")


def _hash_key(raw_key: str) -> str:
    """SHA-256 de la cle recue -- jamais la cle en clair."""
    return hashlib.sha256(raw_key.encode("utf-8")).hexdigest()


def _validate_access(raw_key: str | None, required_level: str) -> dict:
    """
    Validation generique par niveau d acces.

    required_level : STANDARD | PREMIUM | EXPERT
    Hierarchie : EXPERT >= PREMIUM >= STANDARD

    Retourne le dict de la cle si valide.
    Leve HTTPException 401 ou 403 sinon.
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

        # Verification du niveau d acces
        # Hierarchie : EXPERT >= PREMIUM >= STANDARD
        level_hierarchy = {"STANDARD": 1, "PREMIUM": 2, "EXPERT": 3}
        effective = row["effective_access_class"] or "STANDARD"
        required_rank = level_hierarchy.get(required_level, 1)
        effective_rank = level_hierarchy.get(effective, 1)

        if effective_rank < required_rank:
            raise HTTPException(
                status_code=403,
                detail=f"Insufficient access level -- {required_level} required, {effective} granted. "
                       f"Upgrade at open.osa-observatory.org/subscribe"
            )

        # Rate limiting -- reset si nouveau jour
        from datetime import date
        today = date.today()
        last_reset = row["last_reset_date"]
        requests_today = row["requests_today"] or 0
        rate_limit = row["rate_limit_per_hour"] or 500

        if last_reset != today:
            # Nouveau jour -- reset compteur
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
    """
    Dependency FastAPI -- Couche 1 -- Affilie standard S1.
    Scores ISA absolus + pentes + actions souveraines.
    """
    return _validate_access(x_api_key, "STANDARD")


def validate_premium_access(x_api_key: str = Header(default=None)) -> dict:
    """
    Dependency FastAPI -- Couche 2 -- Affilie premium S2.
    Simulations CENTRAL/STRESS + IC P5-P95 + AMAR complet.
    """
    return _validate_access(x_api_key, "PREMIUM")


def validate_expert_access(x_api_key: str = Header(default=None)) -> dict:
    """
    Dependency FastAPI -- Expert interne OSA.
    Toutes couches -- usage interne.
    Legacy compatible avec Sprint 12.
    """
    return _validate_access(x_api_key, "EXPERT")


def generate_api_key() -> tuple[str, str]:
    """
    Genere une nouvelle cle API et son hash SHA-256.
    Retourne (raw_key, hashed_key).
    La raw_key n est jamais stockee -- a transmettre une seule fois a l affilié.
    """
    import secrets
    raw_key = f"osa_{secrets.token_urlsafe(32)}"
    hashed  = _hash_key(raw_key)
    return raw_key, hashed
