"""
OSA Observatory -- Middleware Prometheus
Sprint 17 -- api/middleware/metrics.py

7 categories de metriques :
  1. osa_request_duration_seconds  -- Histogram latence
  2. osa_requests_total            -- Counter volume
  3. osa_errors_total              -- Counter erreurs
  4. osa_rate_limit_rejections_total -- Counter 429
  5. osa_auth_failures_total       -- Counter echecs auth
  6. osa_materialized_view_refresh_seconds -- Gauge duree refresh vues
  7. osa_quota_usage_ratio         -- Gauge usage quotas

Integration main.py :
  Monter AVANT rate_limiter pour mesurer les 429.
  /metrics protege EXPERT via sub-application ASGI.
"""

import os
import sys
import time
import logging
from typing import Optional

sys.path.insert(0, "G:/python-packages")

from prometheus_client import (
    Counter, Histogram, Gauge, CollectorRegistry,
    make_asgi_app, REGISTRY
)
from starlette.requests import Request

log = logging.getLogger("osa_metrics")

# ---------------------------------------------------------------------------
# Definition des metriques
# ---------------------------------------------------------------------------

# 1. Latence des requetes
REQUEST_DURATION = Histogram(
    "osa_request_duration_seconds",
    "Duree des requetes HTTP OSA en secondes",
    ["endpoint", "method", "status_code"],
    buckets=[0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.0, 5.0, 10.0],
)

# 2. Volume des requetes
REQUESTS_TOTAL = Counter(
    "osa_requests_total",
    "Nombre total de requetes HTTP OSA",
    ["endpoint", "method", "status_code", "access_level"],
)

# 3. Erreurs HTTP (4xx/5xx)
ERRORS_TOTAL = Counter(
    "osa_errors_total",
    "Nombre total d'erreurs HTTP OSA",
    ["endpoint", "error_type"],
)

# 4. Rejets rate limiting
RATE_LIMIT_REJECTIONS = Counter(
    "osa_rate_limit_rejections_total",
    "Nombre de requetes rejetees par le rate limiter",
    ["profile", "endpoint"],
)

# 5. Echecs d'authentification
AUTH_FAILURES = Counter(
    "osa_auth_failures_total",
    "Nombre d'echecs d'authentification",
    ["reason"],
)

# 6. Duree refresh vues materialisees
MATVIEW_REFRESH_DURATION = Gauge(
    "osa_materialized_view_refresh_seconds",
    "Duree du dernier refresh de vue materialisee",
    ["view_name"],
)

# 7. Ratio usage quotas
QUOTA_USAGE_RATIO = Gauge(
    "osa_quota_usage_ratio",
    "Ratio d'utilisation du quota (0.0 - 1.0)",
    ["affiliation_id", "access_level"],
)

# ---------------------------------------------------------------------------
# Helpers pour normaliser les labels
# ---------------------------------------------------------------------------
def _endpoint_label(path: str) -> str:
    """
    Normalise le chemin pour le label Prometheus.
    Remplace les parametres variables par des placeholders
    pour eviter l'explosion de cardinalite.
    Ex: /api/v2/countries/SEN -> /api/v2/countries/{iso3}
    """
    import re
    # Remplacer les codes ISO3 (3 lettres majuscules)
    path = re.sub(r"/[A-Z]{3}(?=/|$)", "/{iso3}", path)
    # Remplacer les IDs numeriques
    path = re.sub(r"/\d+(?=/|$)", "/{id}", path)
    # Tronquer si trop long
    return path[:80]


def _access_level_from_request(request: Request) -> str:
    """Extrait le niveau d'acces depuis les headers de la requete."""
    auth = request.headers.get("Authorization", "")
    if auth.startswith("Bearer "):
        try:
            import jwt as pyjwt
            claims = pyjwt.decode(
                auth[7:],
                options={"verify_signature": False, "verify_exp": False},
                algorithms=["HS256"],
            )
            return claims.get("access_level", "UNKNOWN")
        except Exception:
            return "INVALID"
    elif request.headers.get("X-Api-Key"):
        return "LEGACY"
    return "PUBLIC"


# ---------------------------------------------------------------------------
# Middleware principal
# ---------------------------------------------------------------------------
async def metrics_middleware(request: Request, call_next):
    """
    Middleware de collecte des metriques Prometheus.
    A enregistrer AVANT rate_limiter dans main.py.
    """
    start = time.perf_counter()
    path = request.url.path
    method = request.method
    endpoint = _endpoint_label(path)
    access_level = _access_level_from_request(request)

    try:
        response = await call_next(request)
    except Exception as exc:
        # Erreur non geree
        ERRORS_TOTAL.labels(
            endpoint=endpoint,
            error_type="UNHANDLED_EXCEPTION",
        ).inc()
        raise

    status_code = str(response.status_code)
    duration = time.perf_counter() - start

    # Enregistrer la latence
    REQUEST_DURATION.labels(
        endpoint=endpoint,
        method=method,
        status_code=status_code,
    ).observe(duration)

    # Enregistrer le volume
    REQUESTS_TOTAL.labels(
        endpoint=endpoint,
        method=method,
        status_code=status_code,
        access_level=access_level,
    ).inc()

    # Erreurs 4xx/5xx
    if response.status_code >= 400:
        if response.status_code == 401:
            error_type = "UNAUTHORIZED"
            AUTH_FAILURES.labels(reason="401").inc()
        elif response.status_code == 403:
            error_type = "FORBIDDEN"
            AUTH_FAILURES.labels(reason="403").inc()
        elif response.status_code == 429:
            error_type = "RATE_LIMITED"
            # Recuperer le profil depuis le header de reponse si present
            profile = response.headers.get("X-RateLimit-Profile", "UNKNOWN")
            RATE_LIMIT_REJECTIONS.labels(
                profile=profile,
                endpoint=endpoint,
            ).inc()
        elif response.status_code >= 500:
            error_type = "SERVER_ERROR"
        else:
            error_type = f"HTTP_{status_code}"

        ERRORS_TOTAL.labels(
            endpoint=endpoint,
            error_type=error_type,
        ).inc()

    return response


# ---------------------------------------------------------------------------
# Fonction utilitaire pour mettre a jour les metriques vues materialisees
# Appelee depuis run_full_pipeline.ps1 option [8] ou directement
# ---------------------------------------------------------------------------
def record_matview_refresh(view_name: str, duration_seconds: float) -> None:
    """Enregistre la duree d'un refresh de vue materialisee."""
    MATVIEW_REFRESH_DURATION.labels(view_name=view_name).set(duration_seconds)
    log.info("Matview refresh enregistre : %s = %.2fs", view_name, duration_seconds)


def record_quota_usage(affiliation_id: str, access_level: str,
                       used: int, limit: int) -> None:
    """Met a jour le ratio d'utilisation du quota d'un affilie."""
    if limit > 0:
        ratio = min(used / limit, 1.0)
        QUOTA_USAGE_RATIO.labels(
            affiliation_id=str(affiliation_id),
            access_level=access_level,
        ).set(ratio)
