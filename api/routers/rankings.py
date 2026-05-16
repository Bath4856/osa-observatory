import time
from fastapi import APIRouter, Depends, Path
from sqlalchemy import text
from sqlalchemy.orm import Session

from api.db import get_db
from api.middleware.telemetry import register_api_usage

router = APIRouter(prefix="/api/v2/rankings", tags=["Rankings"])

ENDPOINT_ACCESS = "PUBLIC"


@router.get(
    "/latest",
    summary="Latest ISA country rankings",
    description="Returns country rankings for the most recent year available.",
)
async def get_latest_rankings(db: Session = Depends(get_db)):
    t0 = time.time()

    rows = db.execute(text("""
        SELECT *
        FROM pub.v_isa_country_rankings
        WHERE year = (SELECT MAX(year) FROM pub.v_isa_country_rankings)
        ORDER BY isa_rank
    """)).mappings().all()

    elapsed = round((time.time() - t0) * 1000, 2)
    await register_api_usage(
        "V2_RANKINGS_LATEST", "/api/v2/rankings/latest", "GET",
        ENDPOINT_ACCESS, 200, elapsed, len(rows)
    )
    return {"count": len(rows), "data": [dict(r) for r in rows]}


@router.get(
    "/year/{year}",
    summary="ISA country rankings for a given year",
    description="Returns country rankings for a specific year (2010–2024).",
)
async def get_rankings_by_year(
    year: int = Path(description="Year between 2010 and 2024"),
    db: Session = Depends(get_db),
):
    t0 = time.time()

    rows = db.execute(text("""
        SELECT *
        FROM pub.v_isa_country_rankings
        WHERE year = :year
        ORDER BY isa_rank
    """), {"year": year}).mappings().all()

    elapsed = round((time.time() - t0) * 1000, 2)
    await register_api_usage(
        "V2_RANKINGS_YEAR", f"/api/v2/rankings/year/{year}", "GET",
        ENDPOINT_ACCESS, 200, elapsed, len(rows)
    )
    return {"count": len(rows), "data": [dict(r) for r in rows]}
