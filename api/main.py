from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from api.config import settings
from api.db import check_db_connection
from api.routers import countries, rankings, predictive, release
from api.routers.opportunities import opportunities_router, methodology_router
from api.routers.early_warning import router as early_warning_router
from api.routers.sovereignty import router as sovereignty_router
from api.routers.early_warning_sprint7 import router as early_warning_sprint7_router

app = FastAPI(
    title="OSA ISA Public API",
    version=settings.APP_VERSION,
    description=(
        "Observatoire de la Souveraineté Africaine — Institutional Sovereign Intelligence API. "
        "Provides ISA scores, country rankings, predictive execution signals (P7Z Phase 2), "
        "sovereign fragility indices, civilian protection risk (P7I-AMAR), "
        "and conflict-economy exposure (P7I-AMAR-GENECO) for 54 African countries (2010–2024)."
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

# ── CORS ─────────────────────────────────────────────────────────────────────
origins = (
    settings.CORS_ORIGINS.split(",")
    if settings.CORS_ORIGINS != "*"
    else ["*"]
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["GET"],
    allow_headers=["*"],
)

# ── Routers ───────────────────────────────────────────────────────────────────
app.include_router(countries.router)
app.include_router(rankings.router)
app.include_router(predictive.router)
app.include_router(release.router)
app.include_router(opportunities_router)
app.include_router(methodology_router)
app.include_router(early_warning_router)
app.include_router(sovereignty_router)
app.include_router(early_warning_sprint7_router)

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
