import time
from fastapi import APIRouter, Depends, Query
from sqlalchemy import text
from sqlalchemy.orm import Session

from api.db import get_db
from api.middleware.telemetry import register_api_usage

# ── Opportunities ─────────────────────────────────────────────────────────────
opportunities_router = APIRouter(
    prefix="/api/v2/opportunities",
    tags=["Opportunities"]
)


@opportunities_router.get(
    "",
    summary="Opportunity catalog (PUBLIC_LIMITED)",
    description="Returns sovereign intervention opportunities enriched with P7Z execution probability. "
                "Filtered to HIGH_PROBABILITY and MEDIUM_PROBABILITY by default.",
)
async def get_opportunities(
    iso3: str = Query(default=None, description="Filter by ISO3 country code"),
    pillar: str = Query(default=None, description="Filter by pillar code"),
    min_prob: float = Query(default=0.40, description="Minimum execution probability [0–1]"),
    db: Session = Depends(get_db),
):
    t0 = time.time()

    base = """
        SELECT *
        FROM pub.v_isa_opportunity_catalog
        WHERE (execution_probability >= :min_prob OR execution_probability IS NULL)
    """
    params: dict = {"min_prob": min_prob}

    if iso3:
        base += " AND country_iso3 = :iso3"
        params["iso3"] = iso3.upper()
    if pillar:
        base += " AND pillar_code = :pillar"
        params["pillar"] = pillar.upper()

    base += " ORDER BY execution_probability DESC NULLS LAST LIMIT 500"

    rows = db.execute(text(base), params).mappings().all()

    elapsed = round((time.time() - t0) * 1000, 2)
    await register_api_usage(
        "V2_OPPORTUNITIES", "/api/v2/opportunities", "GET",
        "PUBLIC_LIMITED", 200, elapsed, len(rows)
    )
    return {"count": len(rows), "data": [dict(r) for r in rows]}


# ── Methodology ───────────────────────────────────────────────────────────────
methodology_router = APIRouter(
    prefix="/api/v2/methodology",
    tags=["Methodology"]
)


@methodology_router.get(
    "",
    summary="Public methodology",
    description="Returns public methodology metadata and active packages.",
)
async def get_methodology(db: Session = Depends(get_db)):
    t0 = time.time()

    rows = db.execute(text("""
        SELECT * FROM pub.v_isa_public_methodology
        ORDER BY package_code
    """)).mappings().all()

    elapsed = round((time.time() - t0) * 1000, 2)
    await register_api_usage(
        "V2_METHODOLOGY", "/api/v2/methodology", "GET",
        "PUBLIC", 200, elapsed, len(rows)
    )
    return {"count": len(rows), "data": [dict(r) for r in rows]}
