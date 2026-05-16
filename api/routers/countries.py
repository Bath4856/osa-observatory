import time
from fastapi import APIRouter, Depends, Query
from sqlalchemy import text
from sqlalchemy.orm import Session

from api.db import get_db
from api.middleware.release_guard import validate_release_status
from api.middleware.telemetry import register_api_usage

router = APIRouter(prefix="/api/v2/countries", tags=["Countries"])

ENDPOINT_ACCESS = "PUBLIC"


@router.get(
    "",
    summary="Latest ISA scores — all countries",
    description="Returns the latest ISA score for all 54 countries, enriched with P7J decision class and P7Z fragility.",
)
async def get_latest_countries(db: Session = Depends(get_db)):
    t0 = time.time()
    validate_release_status()

    rows = db.execute(text("""
        SELECT *
        FROM pub.v_isa_country_latest
        ORDER BY isa_observed_score DESC NULLS LAST
    """)).mappings().all()

    elapsed = round((time.time() - t0) * 1000, 2)
    await register_api_usage(
        "V2_COUNTRIES_LIST", "/api/v2/countries", "GET",
        ENDPOINT_ACCESS, 200, elapsed, len(rows)
    )
    return {"count": len(rows), "data": [dict(r) for r in rows]}


@router.get(
    "/{iso3}",
    summary="Country profile — latest year",
    description="Returns the latest ISA profile for a single country.",
)
async def get_country_profile(iso3: str, db: Session = Depends(get_db)):
    t0 = time.time()
    validate_release_status()

    rows = db.execute(text("""
        SELECT *
        FROM pub.v_isa_country_latest
        WHERE country_iso3 = :iso3
    """), {"iso3": iso3.upper()}).mappings().all()

    elapsed = round((time.time() - t0) * 1000, 2)
    await register_api_usage(
        "V2_COUNTRY_PROFILE", f"/api/v2/countries/{iso3}", "GET",
        ENDPOINT_ACCESS, 200, elapsed, len(rows)
    )
    return {"count": len(rows), "data": [dict(r) for r in rows]}


@router.get(
    "/{iso3}/history",
    summary="Country ISA score history",
    description="Returns full ISA score history (2010–2024) for a single country.",
)
async def get_country_history(iso3: str, db: Session = Depends(get_db)):
    t0 = time.time()
    validate_release_status()

    rows = db.execute(text("""
        SELECT *
        FROM pub.v_isa_country_history
        WHERE country_iso3 = :iso3
        ORDER BY year
    """), {"iso3": iso3.upper()}).mappings().all()

    elapsed = round((time.time() - t0) * 1000, 2)
    await register_api_usage(
        "V2_COUNTRY_HISTORY", f"/api/v2/countries/{iso3}/history", "GET",
        ENDPOINT_ACCESS, 200, elapsed, len(rows)
    )
    return {"count": len(rows), "data": [dict(r) for r in rows]}


@router.get(
    "/{iso3}/pillars",
    summary="Country pillar breakdown",
    description="Returns pillar-level ISA scores enriched with P7Z convergence signals.",
)
async def get_country_pillars(
    iso3: str,
    year: int = Query(default=None, description="Filter by year (optional)"),
    db: Session = Depends(get_db),
):
    t0 = time.time()
    validate_release_status()

    if year:
        rows = db.execute(text("""
            SELECT *
            FROM pub.v_isa_pillar_breakdown
            WHERE country_iso3 = :iso3 AND year = :year
            ORDER BY pillar_code
        """), {"iso3": iso3.upper(), "year": year}).mappings().all()
    else:
        rows = db.execute(text("""
            SELECT *
            FROM pub.v_isa_pillar_breakdown
            WHERE country_iso3 = :iso3
            ORDER BY year DESC, pillar_code
        """), {"iso3": iso3.upper()}).mappings().all()

    elapsed = round((time.time() - t0) * 1000, 2)
    await register_api_usage(
        "V2_COUNTRY_PILLARS", f"/api/v2/countries/{iso3}/pillars", "GET",
        ENDPOINT_ACCESS, 200, elapsed, len(rows)
    )
    return {"count": len(rows), "data": [dict(r) for r in rows]}
