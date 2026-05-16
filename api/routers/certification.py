from fastapi import APIRouter, Query
from api.db import fetch_all

router = APIRouter(prefix="/api/v1/certification", tags=["ISA Certification"])

@router.get("")
def get_certification_status(country_iso3: str | None = Query(default=None), year: int | None = Query(default=None)):
    sql = """
        SELECT *
        FROM ma.v_isa_certification_engine
        WHERE (%s IS NULL OR country_iso3 = %s)
          AND (%s IS NULL OR year = %s)
        ORDER BY year DESC, country_iso3
    """
    iso = country_iso3.upper() if country_iso3 else None
    return fetch_all(sql, (iso, iso, year, year))

@router.get("/snapshots")
def get_snapshot_registry(country_iso3: str | None = Query(default=None), year: int | None = Query(default=None)):
    sql = """
        SELECT *
        FROM ma.v_isa_snapshot_registry
        WHERE (%s IS NULL OR country_iso3 = %s)
          AND (%s IS NULL OR year = %s)
        ORDER BY year DESC, country_iso3
    """
    iso = country_iso3.upper() if country_iso3 else None
    return fetch_all(sql, (iso, iso, year, year))
