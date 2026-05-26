"""
OSA Observatory -- Sprint 14
Router predictive -- Intelligence predictive P7Z
Reecrit proprement depuis pub.v_isa_p7z_country_readiness
et pub.v_isa_p7z_execution_signals
Acces Couche 2 -- Affilie premium requis
"""

import time
from fastapi import APIRouter, Depends, Query
from fastapi.responses import JSONResponse, Response
from sqlalchemy import text
from sqlalchemy.orm import Session
from typing import Optional
from api.db import get_db
from api.security import validate_premium_access
import json

router = APIRouter(prefix="/api/v2/predictive", tags=["Predictive -- Couche 2"])

def _json(data) -> Response:
    return Response(
        content=json.dumps(data, ensure_ascii=False, default=str),
        media_type="application/json; charset=utf-8"
    )

def _rows(db: Session, sql: str, params: dict = None) -> list:
    result = db.execute(text(sql), params or {})
    return [dict(r) for r in result.mappings().all()]


@router.get(
    "/readiness",
    summary="P7Z country predictive readiness -- all countries",
    description=(
        "Returns P7Z predictive readiness aggregated by country/year. "
        "Includes nb_simulation_ready, execution maturity class, "
        "and sovereign execution pressure. "
        "Requires Premium affiliation (Couche 2)."
    ),
)
async def get_readiness(
    db:     Session       = Depends(get_db),
    auth:   dict          = Depends(validate_premium_access),
    year:   Optional[int] = Query(default=None),
    region: Optional[str] = Query(default=None),
    readiness_class: Optional[str] = Query(
        default=None,
        description="HIGH_READINESS | PARTIAL_READINESS | LOW_READINESS"
    ),
):
    t0 = time.time()
    data = _rows(db, """
        SELECT *
        FROM pub.v_isa_p7z_country_readiness
        WHERE (:year    IS NULL OR year = :year)
          AND (:region  IS NULL OR region_code = :region)
          AND (:rclass  IS NULL OR predictive_readiness_class = :rclass)
        ORDER BY year DESC, avg_execution_maturity DESC NULLS LAST
    """, {
        "year":   year,
        "region": region.upper()         if region         else None,
        "rclass": readiness_class.upper() if readiness_class else None,
    })
    elapsed = round((time.time() - t0) * 1000, 2)
    return _json({
        "count":      len(data),
        "elapsed_ms": elapsed,
        "access":     "Couche 2 -- Affilie Premium",
        "data":       data,
    })


@router.get(
    "/readiness/{iso3}",
    summary="P7Z predictive readiness -- one country",
)
async def get_country_readiness(
    iso3: str,
    db:   Session = Depends(get_db),
    auth: dict    = Depends(validate_premium_access),
):
    data = _rows(db, """
        SELECT * FROM pub.v_isa_p7z_country_readiness
        WHERE country_iso3 = :iso3
        ORDER BY year DESC
    """, {"iso3": iso3.upper()})
    if not data:
        return JSONResponse(status_code=404,
            content={"error": f"Country {iso3.upper()} not found"})
    return _json({"country_iso3": iso3.upper(), "access": "Couche 2 -- Affilie Premium", "data": data})


@router.get(
    "/signals",
    summary="P7Z execution signals -- all countries",
    description=(
        "Returns sovereign execution signals (HIGH_PROBABILITY, CONVERGENCE_IMMINENT). "
        "Requires Premium affiliation (Couche 2)."
    ),
)
async def get_signals(
    db:     Session       = Depends(get_db),
    auth:   dict          = Depends(validate_premium_access),
    year:   Optional[int] = Query(default=None),
    status: Optional[str] = Query(
        default=None,
        description="CONVERGENCE_IMMINENT | HIGH_PROBABILITY | MODERATE_PROBABILITY"
    ),
    pillar: Optional[str] = Query(default=None),
):
    t0 = time.time()
    data = _rows(db, """
        SELECT *
        FROM pub.v_isa_p7z_execution_signals
        WHERE (:year   IS NULL OR year = :year)
          AND (:status IS NULL OR predictive_execution_status = :status)
          AND (:pillar IS NULL OR pillar_code = :pillar)
        ORDER BY year DESC,
            CASE predictive_execution_status
                WHEN 'CONVERGENCE_IMMINENT' THEN 1
                WHEN 'HIGH_PROBABILITY'     THEN 2
                ELSE 3
            END,
            country_iso3
    """, {
        "year":   year,
        "status": status.upper() if status else None,
        "pillar": pillar.upper() if pillar else None,
    })
    elapsed = round((time.time() - t0) * 1000, 2)
    return _json({
        "count":      len(data),
        "elapsed_ms": elapsed,
        "access":     "Couche 2 -- Affilie Premium",
        "data":       data,
    })


@router.get(
    "/signals/{iso3}",
    summary="P7Z execution signals -- one country",
)
async def get_country_signals(
    iso3: str,
    db:   Session = Depends(get_db),
    auth: dict    = Depends(validate_premium_access),
):
    data = _rows(db, """
        SELECT * FROM pub.v_isa_p7z_execution_signals
        WHERE country_iso3 = :iso3
        ORDER BY year DESC, execution_signal_class
    """, {"iso3": iso3.upper()})
    if not data:
        return JSONResponse(status_code=404,
            content={"error": f"Country {iso3.upper()} not found"})
    return _json({"country_iso3": iso3.upper(), "access": "Couche 2 -- Affilie Premium", "data": data})


@router.get(
    "/fragility",
    summary="Sovereign fragility -- all countries",
    description="Returns sovereign fragility scores and classes. Couche 2.",
)
async def get_fragility(
    db:     Session       = Depends(get_db),
    auth:   dict          = Depends(validate_premium_access),
    year:   Optional[int] = Query(default=None),
    region: Optional[str] = Query(default=None),
):
    t0 = time.time()
    data = _rows(db, """
        SELECT *
        FROM pub.v_isa_sovereign_fragility
        WHERE (:year   IS NULL OR year = :year)
          AND (:region IS NULL OR region_code = :region)
        ORDER BY year DESC, sovereign_fragility_score DESC NULLS LAST
    """, {
        "year":   year,
        "region": region.upper() if region else None,
    })
    elapsed = round((time.time() - t0) * 1000, 2)
    return _json({
        "count":      len(data),
        "elapsed_ms": elapsed,
        "access":     "Couche 2 -- Affilie Premium",
        "data":       data,
    })


@router.get(
    "/fragility/{iso3}",
    summary="Sovereign fragility -- one country",
)
async def get_country_fragility(
    iso3: str,
    db:   Session = Depends(get_db),
    auth: dict    = Depends(validate_premium_access),
):
    data = _rows(db, """
        SELECT * FROM pub.v_isa_sovereign_fragility
        WHERE country_iso3 = :iso3
        ORDER BY year DESC
    """, {"iso3": iso3.upper()})
    if not data:
        return JSONResponse(status_code=404,
            content={"error": f"Country {iso3.upper()} not found"})
    return _json({"country_iso3": iso3.upper(), "access": "Couche 2 -- Affilie Premium", "data": data})
