"""
OSA Observatory -- Sprint 14
Router rankings -- Classement ISA par pays
Reecrit proprement depuis pub.mv_isa_country_rankings
"""

import time
from fastapi import APIRouter, Depends, Query
from fastapi.responses import Response
from sqlalchemy import text
from sqlalchemy.orm import Session
from typing import Optional
from api.db import get_db
import json

router = APIRouter(prefix="/api/v2/rankings", tags=["Rankings"])

_DISCLAIMER = (
    "OSA Observatory -- Observatoire de la Souverainete Africaine. "
    "ISA scores are computed from official international data sources. "
    "Rankings are informational and do not constitute a political qualification."
)

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
    summary="ISA rankings -- all countries",
    description=(
        "Returns ISA rankings for all 54 African countries. "
        "Includes global rank, regional rank, ISA scores and P7J trajectory. "
        "Defaults to latest available year."
    ),
)
async def get_rankings(
    db:     Session       = Depends(get_db),
    year:   Optional[int] = Query(default=None, description="Year (2020-2024). Defaults to latest."),
    region: Optional[str] = Query(default=None, description="Region code (AFW, AFE, AFN, AFC, AFS)"),
):
    t0 = time.time()
    effective_year = year or 2024
    data = _rows(db, """
        SELECT
            country_iso3, year, region_code, region_label,
            isa_observed_score, sovereignty_score, vulnerability_score,
            resilience_score, data_confidence,
            nb_pillars_observed, isa_rank, regional_rank,
            avg_priority_score, nb_pillars_accelerating, nb_pillars_critical,
            sovereign_momentum, publication_status
        FROM pub.mv_isa_country_rankings
        WHERE year = :year
          AND (:region IS NULL OR region_code = :region)
        ORDER BY isa_rank
    """, {
        "year":   effective_year,
        "region": region.upper() if region else None,
    })
    elapsed = round((time.time() - t0) * 1000, 2)
    return _json({
        "year":        effective_year,
        "count":       len(data),
        "elapsed_ms":  elapsed,
        "disclaimer":  _DISCLAIMER,
        "rankings":    data,
    })


@router.get(
    "/{iso3}",
    summary="ISA rankings history -- one country",
    description="Returns ISA rankings history for a specific country (2020-2024).",
)
async def get_country_rankings(
    iso3: str,
    db:   Session = Depends(get_db),
):
    data = _rows(db, """
        SELECT
            country_iso3, year, region_code, region_label,
            isa_observed_score, sovereignty_score, vulnerability_score,
            resilience_score, data_confidence,
            isa_rank, regional_rank, sovereign_momentum,
            nb_pillars_accelerating, nb_pillars_critical
        FROM pub.mv_isa_country_rankings
        WHERE country_iso3 = :iso3
        ORDER BY year DESC
    """, {"iso3": iso3.upper()})
    if not data:
        from fastapi.responses import JSONResponse
        return JSONResponse(status_code=404,
            content={"error": f"Country {iso3.upper()} not found"})
    return _json({
        "country_iso3": iso3.upper(),
        "disclaimer":   _DISCLAIMER,
        "history":      data,
    })


@router.get(
    "/region/{region_code}",
    summary="ISA rankings by region",
)
async def get_region_rankings(
    region_code: str,
    db:          Session       = Depends(get_db),
    year:        Optional[int] = Query(default=None),
):
    effective_year = year or 2024
    data = _rows(db, """
        SELECT
            country_iso3, year, region_code, region_label,
            isa_observed_score, isa_rank, regional_rank,
            sovereign_momentum, nb_pillars_accelerating, nb_pillars_critical
        FROM pub.mv_isa_country_rankings
        WHERE region_code = :region
          AND year = :year
        ORDER BY regional_rank
    """, {"region": region_code.upper(), "year": effective_year})
    return _json({
        "region_code":  region_code.upper(),
        "year":         effective_year,
        "count":        len(data),
        "disclaimer":   _DISCLAIMER,
        "rankings":     data,
    })
