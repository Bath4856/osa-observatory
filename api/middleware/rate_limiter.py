"""
OSA Observatory -- Rate Limiting Middleware
Sprint 17 -- 27 mai 2026
Correctif du 13 juillet 2026 -- collision de nom de table resolue.

Architecture :
    @app.middleware("http") -- plus leger que BaseHTTPMiddleware
    Deux passes :
      1. Pre-requete  : verifier les compteurs (bloquer si depasse)
      2. Post-requete : incrementer les compteurs + enregistrer l'usage

Profils et quotas :
    PUBLIC (sans token)     : 60 req/heure par IP     (fenetre glissante)
    STANDARD (JWT)          : 500 req/jour par aff_id (fenetre fixe)
    PREMIUM (JWT)           : 2000 req/jour par aff_id (fenetre fixe)
    EXPERT (JWT)            : illimite
    /auth/otp/request       : 5 req/heure par IP      (fenetre glissante)
    X-Api-Key (transition)  : gere par security.py (rate_limit_per_hour)

Backend : mg.api_rate_limit_counters (PostgreSQL)
    Upsert sur fenetre courante uniquement.
    Taille stable. Migration Redis possible sans changer l'interface.

    Correctif du 13 juillet 2026 : la table portait a l'origine le nom
    mg.rate_limit_counters, entree en collision avec une table homonyme
    creee plus tard (Sprint 30, schema differe -- key_type/key_value/
    endpoint/count, utilisee par check_rate_limit() dans
    api/routers/affiliation.py, restreinte a /auth/login et
    /affiliation/request). Depuis cette collision, ce middleware echouait
    silencieusement sur chaque requete (fail-open) -- aucune limite
    PUBLIC/STANDARD/PREMIUM/EXPERT n'etait donc plus appliquee sur
    l'ensemble de l'API. Corrige en migrant vers une table dediee,
    mg.api_rate_limit_counters (meme schema, nom distinct). Cf. finding
    GAF correspondant pour le detail complet.

Headers RFC 6585 retournes :
    X-RateLimit-Limit     : quota du profil
    X-RateLimit-Remaining : requetes restantes
    X-RateLimit-Reset     : timestamp Unix de reinitialisation
    Retry-After           : secondes a attendre (si 429)
"""

import asyncio
import logging
import os
import time
from datetime import datetime, timezone, timedelta
from typing import Optional

import jwt as pyjwt
from fastapi import Request, Response
from fastapi.responses import JSONResponse
from sqlalchemy import text

from api.db import SessionLocal
from api.middleware.telemetry import _write_usage_sync

log = logging.getLogger("osa_ratelimit")

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
def _rl_enabled() -> bool:
    return os.environ.get("OSA_RL_ENABLED", "true").lower() == "true"

def _public_rph() -> int:
    return int(os.environ.get("OSA_RL_PUBLIC_RPH", "60"))

def _standard_rpd() -> int:
    return int(os.environ.get("OSA_RL_STANDARD_RPD", "500"))

def _premium_rpd() -> int:
    return int(os.environ.get("OSA_RL_PREMIUM_RPD", "2000"))

def _otp_rph() -> int:
    return int(os.environ.get("OSA_RL_OTP_RPH", "5"))

# Endpoints completement exempts du rate limiting
_EXEMPT_PATHS = frozenset({
    "/health",
    "/docs",
    "/redoc",
    "/openapi.json",
    "/metrics",
    "/",
})

# ---------------------------------------------------------------------------
# Extraction de l'identifiant et du profil depuis la requete
# ---------------------------------------------------------------------------
def _get_client_ip(request: Request) -> str:
    """
    Lit l'IP reelle en tenant compte des reverse proxies.
    X-Forwarded-For en priorite (Nginx/load balancer).
    """
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded:
        # Prendre la premiere IP (client reel, pas les proxies intermediaires)
        return forwarded.split(",")[0].strip()
    if request.client:
        return request.client.host
    return "unknown"


def _extract_jwt_claims(request: Request) -> Optional[dict]:
    """
    Extrait les claims JWT depuis le header Authorization sans verifier
    la signature (la verification est faite par auth.py).
    Retourne None si pas de Bearer token ou token malforme.
    """
    auth_header = request.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        return None
    token = auth_header[7:]
    try:
        return pyjwt.decode(
            token,
            options={"verify_signature": False, "verify_exp": False},
            algorithms=["HS256"],
        )
    except pyjwt.DecodeError:
        return None


def _has_api_key(request: Request) -> bool:
    """Detecte si la requete utilise le mecanisme X-Api-Key (transition Sprint 14)."""
    return bool(request.headers.get("X-Api-Key"))


def _get_profile(request: Request) -> tuple[str, str, int]:
    """
    Determine le profil de rate limiting de la requete.
    Retourne (profile, identifier, limit).

    Profiles :
      EXPERT   : illimite
      PREMIUM  : 2000 req/jour par affiliation_id
      STANDARD : 500 req/jour par affiliation_id
      PUBLIC   : 60 req/heure par IP
      LEGACY   : gere par security.py (X-Api-Key), bypass ici
    """
    # X-Api-Key : bypass (gere par security.py)
    if _has_api_key(request):
        return "LEGACY", "legacy", 0

    # Bearer JWT : extraire les claims
    claims = _extract_jwt_claims(request)
    if claims:
        access_level = claims.get("access_level", "STANDARD")
        affiliation_id = claims.get("affiliation_id")
        identifier = f"aff:{affiliation_id}" if affiliation_id else f"aff:internal"

        if access_level == "EXPERT":
            return "EXPERT", identifier, 0
        elif access_level == "PREMIUM":
            return "PREMIUM", identifier, _premium_rpd()
        else:
            return "STANDARD", identifier, _standard_rpd()

    # Sans token : PUBLIC, identifie par IP
    ip = _get_client_ip(request)
    return "PUBLIC", f"ip:{ip}", _public_rph()


# ---------------------------------------------------------------------------
# Logique de comptage -- mg.api_rate_limit_counters
# ---------------------------------------------------------------------------
def _window_start_hourly() -> datetime:
    """Debut de l'heure courante UTC (fenetre glissante)."""
    now = datetime.now(tz=timezone.utc)
    return now.replace(minute=0, second=0, microsecond=0)


def _window_start_daily() -> datetime:
    """Debut du jour courant UTC (fenetre fixe)."""
    now = datetime.now(tz=timezone.utc)
    return now.replace(hour=0, minute=0, second=0, microsecond=0)


def _window_reset_ts(profile: str) -> int:
    """Timestamp Unix de reinitialisation de la fenetre."""
    if profile in ("PUBLIC", "OTP"):
        # Prochaine heure
        ws = _window_start_hourly()
        return int((ws + timedelta(hours=1)).timestamp())
    else:
        # Prochain minuit UTC
        ws = _window_start_daily()
        return int((ws + timedelta(days=1)).timestamp())


def _check_and_increment(
    identifier: str,
    profile: str,
    limit: int,
    access_class: str,
    db,
) -> tuple[bool, int, int]:
    """
    Verifie le compteur et l'incremente atomiquement via UPSERT.
    Retourne (allowed, current_count, reset_ts).

    Pattern UPSERT :
      - Si la ligne n'existe pas : INSERT avec counter=1
      - Si elle existe : UPDATE counter = counter + 1
      - Atomic via ON CONFLICT UPDATE
    """
    if profile in ("PUBLIC", "OTP"):
        window_type = "HOURLY"
        window_start = _window_start_hourly()
    else:
        window_type = "DAILY"
        window_start = _window_start_daily()

    reset_ts = _window_reset_ts(profile)

    # UPSERT atomique -- incrément systématique puis vérification
    result = db.execute(text("""
        INSERT INTO mg.api_rate_limit_counters
            (identifier, window_type, window_start, counter, access_class, updated_at)
        VALUES
            (:identifier, :window_type, :window_start, 1, :access_class, NOW())
        ON CONFLICT (identifier, window_type, window_start)
        DO UPDATE SET
            counter    = mg.api_rate_limit_counters.counter + 1,
            updated_at = NOW()
        RETURNING counter
    """), {
        "identifier":   identifier,
        "window_type":  window_type,
        "window_start": window_start,
        "access_class": access_class,
    }).fetchone()

    db.commit()
    current = result[0] if result else 1

    # Verifier APRES increment (si depasse : rembourser -- decrement)
    if current > limit:
        # Rembourser l'increment pour ne pas fausser les stats
        db.execute(text("""
            UPDATE mg.api_rate_limit_counters
            SET counter = counter - 1, updated_at = NOW()
            WHERE identifier = :identifier
              AND window_type = :window_type
              AND window_start = :window_start
        """), {
            "identifier":   identifier,
            "window_type":  window_type,
            "window_start": window_start,
        })
        db.commit()
        return False, current - 1, reset_ts

    return True, current, reset_ts


# ---------------------------------------------------------------------------
# Construction des headers RFC 6585
# ---------------------------------------------------------------------------
def _rl_headers(limit: int, remaining: int, reset_ts: int) -> dict:
    return {
        "X-RateLimit-Limit":     str(limit),
        "X-RateLimit-Remaining": str(max(0, remaining)),
        "X-RateLimit-Reset":     str(reset_ts),
    }


def _too_many_headers(limit: int, reset_ts: int) -> dict:
    retry_after = max(0, reset_ts - int(time.time()))
    return {
        "X-RateLimit-Limit":     str(limit),
        "X-RateLimit-Remaining": "0",
        "X-RateLimit-Reset":     str(reset_ts),
        "Retry-After":           str(retry_after),
    }


# ---------------------------------------------------------------------------
# Middleware principal -- @app.middleware("http")
# ---------------------------------------------------------------------------
async def rate_limit_middleware(request: Request, call_next):
    """
    Middleware de rate limiting OSA.
    A enregistrer dans main.py via @app.middleware("http")
    AVANT add_middleware(CORSMiddleware).
    """
    # Bypass global si desactive
    if not _rl_enabled():
        return await call_next(request)

    path = request.url.path

    # Bypass endpoints exempts
    if path in _EXEMPT_PATHS:
        return await call_next(request)

    # Determiner le profil
    profile, identifier, limit = _get_profile(request)

    # Bypass LEGACY (X-Api-Key) et EXPERT
    if profile in ("LEGACY", "EXPERT"):
        response = await call_next(request)
        return response

    # Quota OTP specifique sur /auth/otp/request
    if path == "/auth/otp/request":
        profile = "OTP"
        # Toujours par IP pour /auth/otp/request, meme si JWT present
        ip = _get_client_ip(request)
        identifier = f"ip:{ip}"
        limit = _otp_rph()

    db = SessionLocal()
    try:
        # Verifier et incrementer
        db.execute(text("SET LOCAL statement_timeout = '100ms'"))
        allowed, current, reset_ts = _check_and_increment(
            identifier, profile, limit, profile, db
        )
    except Exception as exc:
        # En cas d'erreur SQL (timeout, connexion) : fail open
        # Le rate limiting ne doit jamais bloquer l'API en cas de panne
        log.error("Rate limit check failed (fail open): %s", exc)
        db.rollback()
        return await call_next(request)
    finally:
        db.close()

    remaining = limit - current

    if not allowed:
        reset_ts_val = _window_reset_ts(profile)
        headers = _too_many_headers(limit, reset_ts_val)
        log.warning(
            "Rate limit exceeded -- profile=%s identifier=%s path=%s limit=%d",
            profile, identifier, path, limit,
        )
        # Enregistrer le 429 dans api_usage_registry pour audit complet
        # (telemetry.py n'est pas appelé car le router n'est jamais atteint)
        asyncio.create_task(asyncio.to_thread(
            _write_usage_sync,
            "RATE_LIMIT_EXCEEDED",
            path,
            request.method,
            profile,
            429,
            0.0,
            0,
        ))
        return JSONResponse(
            status_code=429,
            content={
                "detail": (
                    f"Rate limit depasse ({limit} req/"
                    f"{'heure' if profile in ('PUBLIC', 'OTP') else 'jour'}). "
                    f"Reessayer apres reinitialisation."
                ),
                "profile":    profile,
                "limit":      limit,
                "reset_at":   reset_ts_val,
            },
            headers=headers,
        )

    # Requete autorisee -- appeler le handler
    response = await call_next(request)

    # Ajouter les headers RFC 6585 sur la reponse
    response.headers["X-RateLimit-Limit"]     = str(limit)
    response.headers["X-RateLimit-Remaining"] = str(max(0, remaining))
    response.headers["X-RateLimit-Reset"]     = str(reset_ts)

    return response
