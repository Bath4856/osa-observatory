from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from api.config import settings
from api.db import check_db_connection
from api.routers import countries, rankings, predictive, release
from fastapi.responses import RedirectResponse
from api.routers.opportunities import opportunities_router, methodology_router, sovereign_router
from api.routers.early_warning import router as early_warning_router
from api.routers.amar_triggers import router as amar_triggers_router  # SPRINT25
from api.routers.sovereignty import router as sovereignty_router
# SPRINT14 DEPRECATED -- from api.routers.early_warning_sprint7 import router as early_warning_sprint7_router
# SPRINT14 DEPRECATED -- from api.routers.decision_scenarios_sprint7 import (
# SPRINT14 DEPRECATED --     decision_router, sovereignty_router as sovereignty_readiness_router,
# SPRINT14 DEPRECATED --     ew_router as ew_sprint7_phase2_router, scenario_router
# SPRINT14 DEPRECATED -- )
# SPRINT14 DEPRECATED -- from api.routers.api_phase3_sprint8 import decision_phase3_router, ew_phase3_router
from api.routers.sovereignty_fiscal_margin import router as fiscal_margin_router
from api.routers.opendata import router as opendata_router
from api.routers.eparticipation import router as eparticipation_router
from api.routers.tokens import router as tokens_router, public_router as tokens_public_router
from api.routers.tickets import public_router as tickets_public_router, admin_router as tickets_admin_router
from api.routers.affiliation import router as affiliation_router
# SPRINT17 -- Authentification JWT
from api.routers.auth import router as auth_router
# SPRINT17 -- Rate limiting
from api.middleware.rate_limiter import rate_limit_middleware
# SPRINT17 -- Metriques Prometheus
from api.middleware.metrics import metrics_middleware
from api.metrics_server import start_internal_metrics_server

from contextlib import asynccontextmanager

@asynccontextmanager
async def lifespan(app):
    start_internal_metrics_server(host="0.0.0.0", port=9091)
    yield

app = FastAPI(
    lifespan=lifespan,
    title="OSA Observatory -- African Sovereignty Observatory",
    version=settings.APP_VERSION,
    description=(
        "OSA Observatory measures the sovereignty of 54 African states across 10 behavioural pillars. "
        "Fact-based, not perception-based. "
        "Provides ISA scores, sovereign trajectories, early warning signals and sovereign opportunity catalogue. "
        "Data: 2021-2024. Licence: CC-BY-NC-4.0. "
        "Portal: https://open.osa-observatory.africa"
    ),
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
    contact={
        "name": "OSA Observatory",
        "url": "https://osa-observatory.africa",
    },
    license_info={
        "name": "OSA Institutional Data License",
    },
)

# ── Middlewares -- ordre FIFO : premier declare = premier execute ─────────────
# Ordre : metrics (mesure tout) -> rate_limit (bloque) -> CORS

# 1. Metriques Prometheus -- DOIT etre avant rate_limit pour mesurer les 429
@app.middleware("http")
async def _metrics(request: Request, call_next):
    return await metrics_middleware(request, call_next)

# 2. Rate limiting -- DOIT etre avant CORS
@app.middleware("http")
async def _rate_limit(request: Request, call_next):
    return await rate_limit_middleware(request, call_next)

# 3. CORS
origins = (
    settings.CORS_ORIGINS.split(",")
    if settings.CORS_ORIGINS != "*"
    else ["*"]
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)

# ── /metrics -- sous-application ASGI Prometheus ─────────────────────────────
# Protege par le middleware : acces EXPERT uniquement via rate_limiter
# (exempt du rate limit mais pas de l'auth JWT)
import sys
sys.path.insert(0, "G:/python-packages")
from prometheus_client import make_asgi_app as _make_metrics_app
from api.routers.auth import require_expert
from fastapi import Depends

metrics_app = _make_metrics_app()

@app.get("/metrics", tags=["Monitoring"], include_in_schema=False)
async def metrics_endpoint(claims: dict = Depends(require_expert)):
    """Endpoint Prometheus -- acces EXPERT uniquement."""
    from starlette.responses import Response
    from prometheus_client import generate_latest, CONTENT_TYPE_LATEST
    return Response(
        content=generate_latest(),
        media_type=CONTENT_TYPE_LATEST,
    )

# ── Routers ───────────────────────────────────────────────────────────────────
app.include_router(countries.router)
app.include_router(rankings.router)
app.include_router(predictive.router)
app.include_router(release.router)
app.include_router(opportunities_router)
app.include_router(methodology_router)
app.include_router(sovereign_router)
app.include_router(early_warning_router)
app.include_router(amar_triggers_router)  # SPRINT25
app.include_router(sovereignty_router)
# SPRINT14 DEPRECATED -- app.include_router(early_warning_sprint7_router)
# SPRINT14 DEPRECATED -- app.include_router(decision_router)
# SPRINT14 DEPRECATED -- app.include_router(sovereignty_readiness_router)
# SPRINT14 DEPRECATED -- app.include_router(ew_sprint7_phase2_router)
# SPRINT14 DEPRECATED -- app.include_router(scenario_router)
# SPRINT14 DEPRECATED -- app.include_router(decision_phase3_router)
# SPRINT14 DEPRECATED -- app.include_router(ew_phase3_router)
app.include_router(fiscal_margin_router)
app.include_router(opendata_router)
app.include_router(eparticipation_router)
app.include_router(tokens_router)
app.include_router(tokens_public_router)
app.include_router(tickets_public_router)
app.include_router(affiliation_router)
app.include_router(tickets_admin_router)
app.include_router(auth_router)          # SPRINT17 -- JWT /auth/*

# ── Redirection 301 -- compatibilite endpoint rankings (Sprint 19 -- suppression Sprint 21)
@app.get("/api/v2/rankings", include_in_schema=False)
@app.get("/api/v2/rankings/{path:path}", include_in_schema=False)
async def redirect_rankings(path: str = ""):
    target = "/api/v2/scores" + (f"/{path}" if path else "")
    return RedirectResponse(url=target, status_code=301)

# ── Health + Root ─────────────────────────────────────────────────────────────
@app.get("/", tags=["Health"])
def root():
    return {
        "platform":  "OSA ISA Public API",
        "version":   settings.APP_VERSION,
        "status":    "ACTIVE_CANDIDATE",
        "docs":      "/docs",
        "openapi":   "/openapi.json",
    }


@app.get("/health", tags=["Health"])
def health():
    db_ok = check_db_connection()
    return JSONResponse(
        status_code=200 if db_ok else 503,
        content={
            "status":    "ok" if db_ok else "degraded",
            "database":  "connected" if db_ok else "unreachable",
            "version":   settings.APP_VERSION,
        }
    )
