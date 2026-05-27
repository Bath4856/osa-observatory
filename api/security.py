"""
OSA Observatory -- api/security.py
Sprint 17 -- Pont de compatibilite JWT + X-Api-Key

Ce fichier accepte deux mecanismes d'authentification :
  1. Bearer JWT   (Sprint 17) -- via Authorization: Bearer <token>
  2. X-Api-Key    (Sprint 14) -- via header X-Api-Key (transition 90 jours)

Les routers Sprint 14-16 importent validate_*_access sans modification.
Le pont detecte automatiquement le mecanisme utilise.

Apres la fin de la periode de grace (90 jours, aout 2026) :
  - Supprimer la branche X-Api-Key de _validate_access()
  - security.py devient un simple alias vers auth.py
"""

import hashlib
import logging
import os
from datetime import date
from typing import Optional

import jwt as pyjwt
from fastapi import Header, HTTPException, Request
from sqlalchemy import text

from api.db import SessionLocal

# Import des dependances JWT depuis auth.py
from api.routers.auth import (                           # noqa: F401
    get_current_token,
    require_standard,
    require_premium,
    require_expert,
)

log = logging.getLogger("osa_security")

_LEVEL_HIERARCHY = {"STANDARD": 1, "PREMIUM": 2, "EXPERT": 3}


def _hash_key(raw_key: str) -> str:
    """SHA-256 de la cle recue -- jamais la cle en clair."""
    return hashlib.sha256(raw_key.encode("utf-8")).hexdigest()


def _extract_bearer_token(authorization: Optional[str]) -> Optional[str]:
    """Extrait le token JWT depuis le header Authorization: Bearer."""
    if authorization and authorization.startswith("Bearer "):
        return authorization[7:]
    return None


def _validate_jwt_claims(token: str, required_level: str) -> dict:
    """
    Valide les claims JWT sans reverifier la signature
    (auth.py fait la verification complete sur les routes /auth/*).
    Verifie le niveau d'acces et que l'affiliation est active en base.
    Retourne un dict compatible avec ce que les routers attendent.
    """
    try:
        claims = pyjwt.decode(
            token,
            options={"verify_signature": False, "verify_exp": False},
            algorithms=["HS256"],
        )
    except pyjwt.DecodeError:
        raise HTTPException(status_code=401, detail="Bearer token invalide.")

    # Verifier expiration manuellement
    import time
    exp = claims.get("exp", 0)
    if exp and exp < time.time():
        raise HTTPException(
            status_code=401,
            detail="Bearer token expire -- renouveler via POST /auth/refresh.",
            headers={"X-OSA-Error": "TOKEN_EXPIRED"},
        )

    # Verifier le niveau d'acces
    access_level = claims.get("access_level", "STANDARD")
    required_rank = _LEVEL_HIERARCHY.get(required_level, 1)
    effective_rank = _LEVEL_HIERARCHY.get(access_level, 0)

    if effective_rank < required_rank:
        raise HTTPException(
            status_code=403,
            detail=(
                f"Acces {required_level} requis, niveau {access_level} accorde. "
                f"Contacter le Secretariat technique OSA."
            ),
        )

    # Verifier que l'affiliation est active en base
    affiliation_id = claims.get("affiliation_id")
    if affiliation_id is not None:
        db = SessionLocal()
        try:
            row = db.execute(text(
                "SELECT status FROM rf.affiliations WHERE affiliation_id = :id"
            ), {"id": affiliation_id}).fetchone()
        finally:
            db.close()

        if not row:
            raise HTTPException(status_code=403, detail="Affiliation introuvable.")
        if row[0] != "ACTIVE":
            raise HTTPException(
                status_code=403,
                detail=f"Affiliation suspendue ou expiree ({row[0]}).",
            )

    # Retourner un dict compatible avec les routers existants
    return {
        "affiliation_id":       affiliation_id,
        "effective_access_class": access_level,
        "access_granted":       True,
        "institution_name":     claims.get("institution", ""),
        "affiliation_status":   "ACTIVE",
        "_auth_method":         "JWT",
    }


def _validate_access(raw_key: Optional[str], required_level: str, authorization: Optional[str] = None) -> dict:
    """
    Validation generique par niveau d'acces.
    Accepte Bearer JWT (Sprint 17) ou X-Api-Key (Sprint 14).

    Priorite : X-Api-Key si present, sinon Bearer JWT.
    (Un affilie ne devrait pas envoyer les deux simultanement.)

    required_level : STANDARD | PREMIUM | EXPERT
    """
    # ── Chemin Bearer JWT ──────────────────────────────────────────────────
    token = _extract_bearer_token(authorization)
    if token and not raw_key:
        return _validate_jwt_claims(token, required_level)

    # ── Chemin X-Api-Key (transition Sprint 14) ───────────────────────────
    if not raw_key:
        raise HTTPException(
            status_code=401,
            detail="Authentification requise -- X-Api-Key header ou Authorization: Bearer.",
        )

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
        effective      = row["effective_access_class"] or "STANDARD"
        required_rank  = level_hierarchy.get(required_level, 1)
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


def validate_standard_access(
    x_api_key:     Optional[str] = Header(default=None, alias="X-Api-Key"),
    authorization: Optional[str] = Header(default=None, alias="Authorization"),
) -> dict:
    """Dependency FastAPI -- Couche 1 -- Affilie standard S1. JWT ou X-Api-Key."""
    return _validate_access(x_api_key, "STANDARD", authorization)


def validate_premium_access(
    x_api_key:     Optional[str] = Header(default=None, alias="X-Api-Key"),
    authorization: Optional[str] = Header(default=None, alias="Authorization"),
) -> dict:
    """Dependency FastAPI -- Couche 2 -- Affilie premium S2. JWT ou X-Api-Key."""
    return _validate_access(x_api_key, "PREMIUM", authorization)


def validate_expert_access(
    x_api_key:     Optional[str] = Header(default=None, alias="X-Api-Key"),
    authorization: Optional[str] = Header(default=None, alias="Authorization"),
) -> dict:
    """Dependency FastAPI -- Expert interne OSA. JWT ou X-Api-Key."""
    return _validate_access(x_api_key, "EXPERT", authorization)


def generate_api_key() -> tuple[str, str]:
    """
    Genere une nouvelle cle API et son hash SHA-256.
    Retourne (raw_key, hashed_key).
    La raw_key n'est jamais stockee -- a transmettre une seule fois a l'affilie.
    """
    import secrets
    raw_key = f"osa_{secrets.token_urlsafe(32)}"
    hashed  = _hash_key(raw_key)
    return raw_key, hashed
