from fastapi import APIRouter, Query
from api.db import fetch_all

router = APIRouter(prefix="/api/v1/isa", tags=["ISA Open Data"])

@router.get("/country/{iso3}")
def get_country_isa(iso3: str, year: int | None = Query(default=None)):
    sql = """
        SELECT *
        FROM ma.v_isa_observed_scores_by_country_year
        WHERE country_iso3 = %s
          AND (%s IS NULL OR year = %s)
        ORDER BY year DESC
    """
    return fetch_all(sql, (iso3.upper(), year, year))

@router.get("/pillar/{pillar}")
def get_pillar_isa(pillar: str, year: int | None = Query(default=None)):
    sql = """
        SELECT *
        FROM ma.v_isa_observed_scores_by_pillar
        WHERE pillar_code = %s
          AND (%s IS NULL OR year = %s)
        ORDER BY year DESC, country_iso3
    """
    return fetch_all(sql, (pillar.upper(), year, year))

@router.get("/region/{region}")
def get_region_isa(region: str, year: int | None = Query(default=None)):
    sql = """
        SELECT *
        FROM ma.v_isa_observed_scores_by_region_year
        WHERE region_code = %s OR region_name = %s
          AND (%s IS NULL OR year = %s)
        ORDER BY year DESC
    """
    return fetch_all(sql, (region.upper(), region, year, year))

@router.get("/swot/{country}")
def get_country_swot(country: str, year: int | None = Query(default=None)):
    sql = """
        SELECT *
        FROM ma.v_isa_swot_signal_engine
        WHERE country_iso3 = %s
          AND (%s IS NULL OR year = %s)
        ORDER BY year DESC, pillar_code
    """
    return fetch_all(sql, (country.upper(), year, year))
