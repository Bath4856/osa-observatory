from fastapi import APIRouter, Query
from api.db import fetch_all

router = APIRouter(prefix="/api/v1/premium", tags=["OSA Premium"])

@router.get("/feasibility")
def get_feasibility_triggers(country_iso3: str | None = Query(default=None), year: int | None = Query(default=None)):
    sql = """
        SELECT *
        FROM ma.v_isa_premium_feasibility_triggers
        WHERE (%s IS NULL OR country_iso3 = %s)
          AND (%s IS NULL OR year = %s)
        ORDER BY premium_priority_class, country_iso3, year DESC
    """
    return fetch_all(sql, (country_iso3.upper() if country_iso3 else None, country_iso3.upper() if country_iso3 else None, year, year))

@router.get("/catalog")
def get_premium_catalog():
    return fetch_all("SELECT * FROM ma.v_isa_premium_catalog ORDER BY product_code")
