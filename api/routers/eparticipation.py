from fastapi import APIRouter, Query
from api.db import fetch_all

router = APIRouter(prefix="/api/v1/eparticipation", tags=["E-participation"])

@router.get("/queue")
def get_eparticipation_queue(country_iso3: str | None = Query(default=None), year: int | None = Query(default=None)):
    sql = """
        SELECT *
        FROM ma.v_isa_eparticipation_queue
        WHERE (%s IS NULL OR country_iso3 = %s)
          AND (%s IS NULL OR year = %s)
        ORDER BY queue_priority NULLS LAST, country_iso3, year DESC
    """
    iso = country_iso3.upper() if country_iso3 else None
    return fetch_all(sql, (iso, iso, year, year))
