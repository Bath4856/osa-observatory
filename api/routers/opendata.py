"""
OSA Observatory -- Sprint 13
Router Open Data -- Couche 0 publique
CC-BY-4.0 -- open.osa-observatory.org
"""

import time
import json
from fastapi import APIRouter, Depends, Query
from fastapi.responses import JSONResponse, Response
from sqlalchemy import text
from sqlalchemy.orm import Session
from typing import Optional
from api.db import get_db

router = APIRouter(
    prefix="/opendata",
    tags=["Open Data -- Couche 0 -- CC-BY-4.0"],
)

_DISCLAIMER = (
    "OSA Observatory -- Observatoire de la Souverainete Africaine. "
    "Published under CC-BY-4.0. "
    "Early-warning analytical tool -- not a legal or diplomatic qualification. "
    "Subscribe at open.osa-observatory.org for full scores and analytics."
)

def _wrap(data: list, dataset_code: str) -> Response:
    payload = {
        "dataset":    dataset_code,
        "license":    "CC-BY-4.0",
        "access":     "Couche 0 -- Open Data",
        "disclaimer": _DISCLAIMER,
        "count":      len(data),
        "data":       data,
    }
    return Response(
        content=json.dumps(payload, ensure_ascii=False),
        media_type="application/json; charset=utf-8"
    )

def _rows(db: Session, sql: str, params: dict = None) -> list:
    result = db.execute(text(sql), params or {})
    return [dict(r) for r in result.mappings().all()]


# ── 1. Catalogue ──────────────────────────────────────────────
@router.get("/", summary="Catalogue datasets Open Data OSA")
async def get_catalog(db: Session = Depends(get_db)):
    data = _rows(db, "SELECT * FROM pub.v_isa_open_data_catalog ORDER BY access_layer, dataset_code")
    return {"platform": "OSA Observatory Open Data", "license": "CC-BY-4.0",
            "disclaimer": _DISCLAIMER, "datasets": data}


# ── 2. Etat souverain le plus recent ─────────────────────────
@router.get("/countries/latest", summary="Etat souverain le plus recent -- 54 pays")
async def get_countries_latest(
    db:       Session       = Depends(get_db),
    region:   Optional[str] = Query(default=None),
    momentum: Optional[str] = Query(default=None),
    amar_band: Optional[str] = Query(default=None),
):
    data = _rows(db, """
        SELECT * FROM pub.mv_isa_country_latest
        WHERE (:region   IS NULL OR region_code       = :region)
          AND (:momentum IS NULL OR sovereign_momentum = :momentum)
          AND (:amar     IS NULL OR amar_risk_band     = :amar)
        ORDER BY nb_pillars_critical DESC, country_iso3
    """, {
        "region":   region.upper()   if region   else None,
        "momentum": momentum.upper() if momentum else None,
        "amar":     amar_band.upper() if amar_band else None,
    })
    return _wrap(data, "ISA_COUNTRY_LATEST")


@router.get("/countries/latest/{iso3}", summary="Etat souverain le plus recent -- un pays")
async def get_country_latest(iso3: str, db: Session = Depends(get_db)):
    data = _rows(db,
        "SELECT * FROM pub.mv_isa_country_latest WHERE country_iso3 = :iso3",
        {"iso3": iso3.upper()})
    if not data:
        return JSONResponse(status_code=404, content={"error": f"Country {iso3.upper()} not found"})
    return _wrap(data, "ISA_COUNTRY_LATEST")


# ── 3. Historique directionnel ────────────────────────────────
@router.get("/countries/history", summary="Historique directionnel souverain 2020-2024")
async def get_countries_history(
    db:        Session       = Depends(get_db),
    direction: Optional[str] = Query(default=None),
    year:      Optional[int] = Query(default=None),
):
    data = _rows(db, """
        SELECT * FROM pub.v_isa_country_history
        WHERE (:direction IS NULL OR annual_direction = :direction)
          AND (:year      IS NULL OR year             = :year)
        ORDER BY country_iso3, year
    """, {
        "direction": direction.upper() if direction else None,
        "year":      year,
    })
    return _wrap(data, "ISA_COUNTRY_HISTORY")


@router.get("/countries/history/{iso3}", summary="Historique directionnel -- un pays")
async def get_country_history(iso3: str, db: Session = Depends(get_db)):
    data = _rows(db,
        "SELECT * FROM pub.v_isa_country_history WHERE country_iso3 = :iso3 ORDER BY year",
        {"iso3": iso3.upper()})
    if not data:
        return JSONResponse(status_code=404, content={"error": f"Country {iso3.upper()} not found"})
    return _wrap(data, "ISA_COUNTRY_HISTORY")


# ── 4. Trajectoires par pilier ────────────────────────────────
@router.get("/pillars", summary="Trajectoires souveraines par pilier 2020-2024")
async def get_pillars(
    db:         Session       = Depends(get_db),
    pillar:     Optional[str] = Query(default=None),
    trajectory: Optional[str] = Query(default=None),
    year:       Optional[int] = Query(default=None),
):
    data = _rows(db, """
        SELECT * FROM pub.mv_isa_pillar_breakdown
        WHERE (:pillar     IS NULL OR pillar_code      = :pillar)
          AND (:trajectory IS NULL OR trajectory_class = :trajectory)
          AND (:year       IS NULL OR year             = :year)
        ORDER BY country_iso3, year, pillar_code
    """, {
        "pillar":     pillar.upper()     if pillar     else None,
        "trajectory": trajectory.upper() if trajectory else None,
        "year":       year,
    })
    return _wrap(data, "ISA_PILLAR_BREAKDOWN")


@router.get("/pillars/{iso3}", summary="Trajectoires par pilier -- un pays")
async def get_country_pillars(
    iso3: str,
    db:   Session       = Depends(get_db),
    year: Optional[int] = Query(default=None),
):
    data = _rows(db, """
        SELECT * FROM pub.mv_isa_pillar_breakdown
        WHERE country_iso3 = :iso3
          AND (:year IS NULL OR year = :year)
        ORDER BY year, pillar_code
    """, {"iso3": iso3.upper(), "year": year})
    if not data:
        return JSONResponse(status_code=404, content={"error": f"Country {iso3.upper()} not found"})
    return _wrap(data, "ISA_PILLAR_BREAKDOWN")


# ── 5. Opportunites projets structurants ─────────────────────
@router.get("/opportunities", summary="Catalogue opportunites projets structurants")
async def get_opportunities(
    db:                Session       = Depends(get_db),
    opportunity_class: Optional[str] = Query(default=None),
    pillar:            Optional[str] = Query(default=None),
):
    data = _rows(db, """
        SELECT * FROM pub.v_isa_opportunity_catalog
        WHERE (:opp    IS NULL OR opportunity_class = :opp)
          AND (:pillar IS NULL OR pillar_code       = :pillar)
        ORDER BY
            CASE opportunity_class
                WHEN 'HIGH_IMPACT_OPPORTUNITY'  THEN 1
                WHEN 'SIGNIFICANT_OPPORTUNITY'  THEN 2
                WHEN 'UNLOCK_OPPORTUNITY'       THEN 3
                ELSE 4
            END, country_iso3
    """, {
        "opp":    opportunity_class.upper() if opportunity_class else None,
        "pillar": pillar.upper()            if pillar            else None,
    })
    return _wrap(data, "ISA_OPPORTUNITY_CATALOG")


@router.get("/opportunities/{iso3}", summary="Opportunites projets structurants -- un pays")
async def get_country_opportunities(iso3: str, db: Session = Depends(get_db)):
    data = _rows(db, """
        SELECT * FROM pub.v_isa_opportunity_catalog
        WHERE country_iso3 = :iso3
        ORDER BY
            CASE opportunity_class
                WHEN 'HIGH_IMPACT_OPPORTUNITY'  THEN 1
                WHEN 'SIGNIFICANT_OPPORTUNITY'  THEN 2
                WHEN 'UNLOCK_OPPORTUNITY'       THEN 3
                ELSE 4
            END, pillar_code
    """, {"iso3": iso3.upper()})
    if not data:
        return JSONResponse(status_code=404, content={"error": f"Country {iso3.upper()} not found"})
    return _wrap(data, "ISA_OPPORTUNITY_CATALOG")


# ── 6. Alertes AMAR ──────────────────────────────────────────
@router.get("/alerts/amar", summary="Alertes precurseurs atrocites AMAR 2020-2024")
async def get_amar_alerts(
    db:        Session       = Depends(get_db),
    risk_band: Optional[str] = Query(default=None),
    year:      Optional[int] = Query(default=None),
):
    data = _rows(db, """
        SELECT country_iso3, year, risk_code, risk_band, source_engine, public_narrative
        FROM mg.v_public_p7i_amar_alerts
        WHERE (:band IS NULL OR risk_band = :band)
          AND (:year IS NULL OR year      = :year)
          AND year >= 2020
        ORDER BY year DESC, risk_band, country_iso3
    """, {
        "band": risk_band.upper() if risk_band else None,
        "year": year,
    })
    return _wrap(data, "ISA_AMAR_ALERTS")


@router.get("/alerts/amar/{iso3}", summary="Alertes AMAR -- un pays")
async def get_country_amar(iso3: str, db: Session = Depends(get_db)):
    data = _rows(db, """
        SELECT country_iso3, year, risk_code, risk_band, source_engine, public_narrative
        FROM mg.v_public_p7i_amar_alerts
        WHERE country_iso3 = :iso3 AND year >= 2020
        ORDER BY year
    """, {"iso3": iso3.upper()})
    if not data:
        return JSONResponse(status_code=404, content={"error": f"Country {iso3.upper()} not found"})
    return _wrap(data, "ISA_AMAR_ALERTS")


# ── 7. Trajectoires P7J ──────────────────────────────────────
@router.get("/trajectories", summary="Trajectoires souveraines P7J 2020-2024")
async def get_trajectories(
    db:               Session       = Depends(get_db),
    trajectory_class: Optional[str] = Query(default=None),
    year:             Optional[int] = Query(default=None),
):
    data = _rows(db, """
        SELECT country_iso3, year, pillar_code,
               trajectory_class, trajectory_signal,
               intervention_family_label,
               country_sovereign_alert_level
        FROM mg.v_public_p7j_recommendations
        WHERE (:traj IS NULL OR trajectory_class = :traj)
          AND (:year IS NULL OR year             = :year)
        ORDER BY year DESC, country_iso3, pillar_code
    """, {
        "traj": trajectory_class.upper() if trajectory_class else None,
        "year": year,
    })
    return _wrap(data, "ISA_P7J_TRAJECTORIES")


@router.get("/trajectories/{iso3}", summary="Trajectoires P7J -- un pays")
async def get_country_trajectories(
    iso3: str,
    db:   Session       = Depends(get_db),
    year: Optional[int] = Query(default=None),
):
    data = _rows(db, """
        SELECT country_iso3, year, pillar_code,
               trajectory_class, trajectory_signal,
               intervention_family_label,
               country_sovereign_alert_level
        FROM mg.v_public_p7j_recommendations
        WHERE country_iso3 = :iso3
          AND (:year IS NULL OR year = :year)
        ORDER BY year, pillar_code
    """, {"iso3": iso3.upper(), "year": year})
    if not data:
        return JSONResponse(status_code=404, content={"error": f"Country {iso3.upper()} not found"})
    return _wrap(data, "ISA_P7J_TRAJECTORIES")


# ── 8. Methodologie ──────────────────────────────────────────
@router.get("/methodology", summary="Documentation methodologique ISA v2")
async def get_methodology(db: Session = Depends(get_db)):
    data = _rows(db, "SELECT * FROM pub.v_isa_public_methodology LIMIT 1")
    return {"dataset": "ISA_METHODOLOGY", "license": "CC-BY-4.0",
            "access": "Couche 0 -- Open Data", "disclaimer": _DISCLAIMER, "data": data}
