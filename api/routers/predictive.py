import time
from fastapi import APIRouter, Depends, Query, Path
from sqlalchemy import text
from sqlalchemy.orm import Session

from api.db import get_db
from api.security import validate_expert_access
from api.middleware.telemetry import register_api_usage

router = APIRouter(prefix="/api/v2/predictive", tags=["Predictive"])


@router.get(
    "/readiness",
    summary="P7Z country predictive readiness — all countries",
    description="Returns P7Z Phase 2 predictive readiness aggregated by country/year. "
                "Includes nb_simulation_ready, avg_execution_probability, convergence years, "
                "and sovereign fragility class.",
)
async def get_readiness(
    year: int = Query(default=None, description="Filter by year (optional)"),
    db: Session = Depends(get_db),
):
    t0 = time.time()

    if year:
        rows = db.execute(text("""
            SELECT *
            FROM pub.v_isa_p7z_country_readiness
            WHERE year = :year
            ORDER BY avg_execution_probability DESC NULLS LAST
        """), {"year": year}).mappings().all()
    else:
        rows = db.execute(text("""
            SELECT *
            FROM pub.v_isa_p7z_country_readiness
            ORDER BY year DESC, avg_execution_probability DESC NULLS LAST
        """)).mappings().all()

    elapsed = round((time.time() - t0) * 1000, 2)
    await register_api_usage(
        "V2_P7Z_READINESS", "/api/v2/predictive/readiness", "GET",
        "PUBLIC", 200, elapsed, len(rows)
    )
    return {"count": len(rows), "data": [dict(r) for r in rows]}


@router.get(
    "/readiness/{iso3}",
    summary="P7Z predictive readiness — single country",
    description="Returns P7Z readiness for a single country across all years.",
)
async def get_readiness_by_country(
    iso3: str = Path(description="ISO3 country code"),
    db: Session = Depends(get_db),
):
    t0 = time.time()

    rows = db.execute(text("""
        SELECT *
        FROM pub.v_isa_p7z_country_readiness
        WHERE country_iso3 = :iso3
        ORDER BY year DESC
    """), {"iso3": iso3.upper()}).mappings().all()

    elapsed = round((time.time() - t0) * 1000, 2)
    await register_api_usage(
        "V2_P7Z_READINESS_ISO3", f"/api/v2/predictive/readiness/{iso3}", "GET",
        "PUBLIC", 200, elapsed, len(rows)
    )
    return {"count": len(rows), "data": [dict(r) for r in rows]}


@router.get(
    "/signals",
    summary="P7Z execution probability signals — EXPERT",
    description="Returns detailed P7Z Phase 2 execution probability signals with all "
                "probability components. Requires X-API-Key header. Expert access only.",
)
async def get_predictive_signals(
    iso3: str = Query(default=None, description="Filter by ISO3 country code"),
    year: int = Query(default=None, description="Filter by year"),
    db: Session = Depends(get_db),
    auth=Depends(validate_expert_access),
):
    t0 = time.time()

    base_query = "SELECT * FROM pub.v_isa_p7z_execution_signals"
    params = {}
    filters = []

    if iso3:
        filters.append("country_iso3 = :iso3")
        params["iso3"] = iso3.upper()
    if year:
        filters.append("year = :year")
        params["year"] = year

    if filters:
        base_query += " WHERE " + " AND ".join(filters)
    base_query += " ORDER BY execution_probability DESC NULLS LAST"

    rows = db.execute(text(base_query), params).mappings().all()

    elapsed = round((time.time() - t0) * 1000, 2)
    await register_api_usage(
        "V2_P7Z_SIGNALS", "/api/v2/predictive/signals", "GET",
        "EXPERT", 200, elapsed, len(rows)
    )
    return {"count": len(rows), "data": [dict(r) for r in rows]}


@router.get(
    "/fragility",
    summary="Sovereign fragility index — P7Z Phase 2",
    description="Returns the sovereign fragility index by country/year. "
                "Includes most_fragile_pillar, most_resilient_pillar, p7z_national_status.",
)
async def get_sovereign_fragility(
    year: int = Query(default=None, description="Filter by year"),
    db: Session = Depends(get_db),
):
    t0 = time.time()

    if year:
        rows = db.execute(text("""
            SELECT *
            FROM pub.v_isa_sovereign_fragility
            WHERE year = :year
            ORDER BY sovereign_fragility_index DESC NULLS LAST
        """), {"year": year}).mappings().all()
    else:
        rows = db.execute(text("""
            SELECT *
            FROM pub.v_isa_sovereign_fragility
            ORDER BY year DESC, sovereign_fragility_index DESC NULLS LAST
        """)).mappings().all()

    elapsed = round((time.time() - t0) * 1000, 2)
    await register_api_usage(
        "V2_SOVEREIGN_FRAGILITY", "/api/v2/predictive/fragility", "GET",
        "PUBLIC", 200, elapsed, len(rows)
    )
    return {"count": len(rows), "data": [dict(r) for r in rows]}
