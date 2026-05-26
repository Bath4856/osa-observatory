"""
OSA Observatory -- Sprint 16
Router countries -- Scores ISA complets -- Couche 1
Reecrit depuis ma.v_isa_observed_scores_by_country_year
Authentification : validate_standard_access (Couche 1)
"""

import time
from fastapi import APIRouter, Depends, Query
from fastapi.responses import JSONResponse, Response
from sqlalchemy import text
from sqlalchemy.orm import Session
from typing import Optional
from api.db import get_db
from api.security import validate_standard_access
from api.middleware.release_guard import validate_release_status
from api.middleware.telemetry import register_api_usage
import json

router = APIRouter(prefix="/api/v2/countries", tags=["Countries -- Couche 1"])

def _json(data) -> Response:
    return Response(
        content=json.dumps(data, ensure_ascii=False, default=str),
        media_type="application/json; charset=utf-8"
    )

def _rows(db: Session, sql: str, params: dict = None) -> list:
    result = db.execute(text(sql), params or {})
    return [dict(r) for r in result.mappings().all()]


@router.get(
    "",
    summary="Latest ISA scores -- all countries -- Couche 1",
    description=(
        "Returns the latest ISA score for all 54 countries "
        "with P7J trajectory and AMAR alert. "
        "Requires Standard affiliation (Couche 1)."
    ),
)
async def get_latest_countries(
    db:     Session       = Depends(get_db),
    auth:   dict          = Depends(validate_standard_access),
    region: Optional[str] = Query(default=None),
    year:   Optional[int] = Query(default=None),
):
    t0 = time.time()
    validate_release_status()
    effective_year = year or 2024
    rows = _rows(db, """
        SELECT
            s.country_iso3, s.year, s.region_code, s.region_label,
            s.isa_observed_score, s.sovereignty_score,
            s.vulnerability_score, s.resilience_score,
            s.data_confidence, s.nb_pillars_observed, s.publication_status
        FROM pub.mv_isa_country_scores s
        WHERE s.year = :year
          AND s.publication_status = 'OFFICIAL_CONSOLIDATED'
          AND (:region IS NULL OR s.region_code = :region)
        ORDER BY s.isa_observed_score DESC NULLS LAST
    """, {
        "year":   effective_year,
        "region": region.upper() if region else None,
    })
    elapsed = round((time.time() - t0) * 1000, 2)
    await register_api_usage(
        "V2_COUNTRIES_LIST", "/api/v2/countries", "GET",
        "STANDARD", 200, elapsed, len(rows)
    )
    return _json({
        "year":       effective_year,
        "count":      len(rows),
        "elapsed_ms": elapsed,
        "access":     "Couche 1 -- Standard",
        "data":       rows,
    })


@router.get(
    "/{iso3}",
    summary="Country ISA profile -- Couche 1",
    description="Returns full ISA profile for a single country. Requires Standard affiliation.",
)
async def get_country_profile(
    iso3: str,
    db:   Session       = Depends(get_db),
    auth: dict          = Depends(validate_standard_access),
    year: Optional[int] = Query(default=None),
):
    t0 = time.time()
    validate_release_status()
    rows = _rows(db, """
        SELECT
            s.country_iso3,
            s.year,
            ca.region_code,
            rg.name_fr                                          AS region_label,
            ROUND(s.isa_observed_score::numeric, 4)             AS isa_observed_score,
            ROUND(s.sovereignty_observed_score::numeric, 4)     AS sovereignty_score,
            ROUND(s.vulnerability_observed_score::numeric, 4)   AS vulnerability_score,
            ROUND(s.resilience_observed_score::numeric, 4)      AS resilience_score,
            ROUND(s.avg_observation_confidence::numeric, 4)     AS data_confidence,
            s.nb_pillars_observed,
            s.publication_status
        FROM ma.v_isa_observed_scores_by_country_year s
        LEFT JOIN rf.v_country_aliases ca ON ca.iso3 = s.country_iso3
        LEFT JOIN rf.regions rg ON rg.code = ca.region_code
        WHERE s.country_iso3 = :iso3
          AND s.publication_status = 'OFFICIAL_CONSOLIDATED'
          AND (:year IS NULL OR s.year = :year)
        ORDER BY s.year DESC
    """, {"iso3": iso3.upper(), "year": year})
    elapsed = round((time.time() - t0) * 1000, 2)
    if not rows:
        return JSONResponse(status_code=404,
            content={"error": f"Country {iso3.upper()} not found"})
    await register_api_usage(
        "V2_COUNTRY_PROFILE", f"/api/v2/countries/{iso3}", "GET",
        "STANDARD", 200, elapsed, len(rows)
    )
    return _json({
        "country_iso3": iso3.upper(),
        "elapsed_ms":   elapsed,
        "access":       "Couche 1 -- Standard",
        "data":         rows,
    })


@router.get(
    "/{iso3}/pillars",
    summary="Country pillar breakdown -- Couche 1",
    description="Returns ISA scores by pillar for a single country. Requires Standard affiliation.",
)
async def get_country_pillars(
    iso3: str,
    db:   Session       = Depends(get_db),
    auth: dict          = Depends(validate_standard_access),
    year: Optional[int] = Query(default=None),
):
    t0 = time.time()
    validate_release_status()
    effective_year = year or 2024
    rows = _rows(db, """
        SELECT
            p.country_iso3,
            p.year,
            p.pillar_code,
            ROUND(p.isa_observed_score::numeric, 4)           AS pillar_isa_score,
            ROUND(p.sovereignty_observed_score::numeric, 4)   AS sovereignty_score,
            ROUND(p.vulnerability_observed_score::numeric, 4) AS vulnerability_score,
            ROUND(p.avg_observation_confidence::numeric, 4)   AS data_confidence,
            p.nb_indicators_observed,
            -- Trajectoire P7J Couche 1
            r.trajectory_class,
            ROUND(r.trend_slope::numeric, 5)                  AS trend_slope,
            r.recommended_action,
            r.intervention_family_label,
            r.intervention_priority_class,
            ROUND(r.intervention_priority_score::numeric, 4)  AS intervention_priority_score
        FROM ma.v_isa_observed_scores_by_pillar p
        LEFT JOIN ma.v_p7j_recommendation_engine r
            ON  r.country_iso3 = p.country_iso3
            AND r.year         = p.year
            AND r.pillar_code  = p.pillar_code
        WHERE p.country_iso3       = :iso3
          AND p.year               = :year
          AND p.publication_status = 'OFFICIAL_CONSOLIDATED'
        ORDER BY p.pillar_code
    """, {"iso3": iso3.upper(), "year": effective_year})
    elapsed = round((time.time() - t0) * 1000, 2)
    if not rows:
        return JSONResponse(status_code=404,
            content={"error": f"Country {iso3.upper()} not found for year {effective_year}"})
    await register_api_usage(
        "V2_COUNTRY_PILLARS", f"/api/v2/countries/{iso3}/pillars", "GET",
        "STANDARD", 200, elapsed, len(rows)
    )
    return _json({
        "country_iso3": iso3.upper(),
        "year":         effective_year,
        "elapsed_ms":   elapsed,
        "access":       "Couche 1 -- Standard",
        "data":         rows,
    })


@router.get(
    "/{iso3}/history",
    summary="Country ISA history 2020-2024 -- Couche 1",
    description="Returns ISA history for a single country. Requires Standard affiliation.",
)
async def get_country_history(
    iso3: str,
    db:   Session = Depends(get_db),
    auth: dict    = Depends(validate_standard_access),
):
    t0 = time.time()
    validate_release_status()
    rows = _rows(db, """
        SELECT
            s.country_iso3,
            s.year,
            ROUND(s.isa_observed_score::numeric, 4)           AS isa_observed_score,
            ROUND(s.sovereignty_observed_score::numeric, 4)   AS sovereignty_score,
            ROUND(s.vulnerability_observed_score::numeric, 4) AS vulnerability_score,
            ROUND(s.resilience_observed_score::numeric, 4)    AS resilience_score,
            ROUND(s.avg_observation_confidence::numeric, 4)   AS data_confidence,
            s.nb_pillars_observed,
            -- Delta annuel
            ROUND((s.isa_observed_score - LAG(s.isa_observed_score)
                OVER (PARTITION BY s.country_iso3 ORDER BY s.year))::numeric, 4)
                AS isa_annual_delta
        FROM ma.v_isa_observed_scores_by_country_year s
        WHERE s.country_iso3       = :iso3
          AND s.publication_status = 'OFFICIAL_CONSOLIDATED'
        ORDER BY s.year DESC
    """, {"iso3": iso3.upper()})
    elapsed = round((time.time() - t0) * 1000, 2)
    if not rows:
        return JSONResponse(status_code=404,
            content={"error": f"Country {iso3.upper()} not found"})
    await register_api_usage(
        "V2_COUNTRY_HISTORY", f"/api/v2/countries/{iso3}/history", "GET",
        "STANDARD", 200, elapsed, len(rows)
    )
    return _json({
        "country_iso3": iso3.upper(),
        "elapsed_ms":   elapsed,
        "access":       "Couche 1 -- Standard",
        "data":         rows,
    })
