"""
OSA ISA Public API — Sovereignty router
Sprint 7 — Mai 2026 | Sprint 28 — Juin 2026
"""
from typing import Optional, List
from fastapi import APIRouter, Depends, Query, Path
from sqlalchemy.orm import Session
from sqlalchemy import text
from pydantic import BaseModel, Field
from api.db import get_db

router = APIRouter(
    prefix="/api/v2/sovereignty",
    tags=["Sovereignty"],
)

class SWOTSignalItem(BaseModel):
    country_iso3:              str             = Field(..., description="Code ISO3 pays OSA (3 lettres)")
    year:                      int             = Field(..., description="Annee de reference")
    pillar_code:               str             = Field(..., description="Code pilier ISA")
    strength_score:            Optional[float] = Field(None, description="Score Force (0-1)")
    opportunity_score:         Optional[float] = Field(None, description="Score Opportunite (0-1)")
    weakness_score:            Optional[float] = Field(None, description="Score Faiblesse (0-1)")
    threat_score:              Optional[float] = Field(None, description="Score Menace (0-1)")
    strategic_risk_score:      Optional[float] = Field(None, description="Score de risque strategique (0-1)")
    strategic_upside_score:    Optional[float] = Field(None, description="Score de potentiel strategique (0-1)")
    observation_confidence:    Optional[float] = Field(None, description="Indice de confiance (0-1)")
    strategic_attention_class: Optional[str]   = Field(None, description="Classe attention strategique OSA")
    swot_strategic_role:       Optional[str]   = Field(None, description="Role strategique SWOT du pilier")
    publication_status:        Optional[str]   = Field(None, description="Statut de publication OSA")

@router.get("/swot",
    summary="Signaux SWOT souverains ISA — tous pays",
    description="Force/Opportunite/Faiblesse/Menace par pilier et par pays.",
    response_model=List[SWOTSignalItem])
def list_swot(
    year:   Optional[int] = Query(None, description="Filtrer par annee (ex: 2024)"),
    pillar: Optional[str] = Query(None, description="Filtrer par pilier (ex: PGEO)"),
    limit:  int           = Query(540, ge=1, le=5000),
    db:     Session       = Depends(get_db),
):
    sql = "SELECT * FROM pub.mv_swot_signal WHERE 1=1"
    params = {}
    if year is not None:
        sql += " AND year = :year"
        params["year"] = year
    if pillar is not None:
        sql += " AND pillar_code = :pillar"
        params["pillar"] = pillar.upper()
    sql += " ORDER BY year DESC, country_iso3, pillar_code LIMIT :limit"
    params["limit"] = limit
    return [dict(r) for r in db.execute(text(sql), params).mappings().all()]

@router.get("/swot/{iso3}",
    summary="Signaux SWOT souverains ISA — pays unique",
    description="Signaux SWOT pour un pays donne, tous piliers.",
    response_model=List[SWOTSignalItem])
def get_swot_country(
    iso3:   str           = Path(..., min_length=3, max_length=3, description="Code ISO3 du pays"),
    year:   Optional[int] = Query(None),
    pillar: Optional[str] = Query(None),
    limit:  int           = Query(100, ge=1, le=1000),
    db:     Session       = Depends(get_db),
):
    sql = "SELECT * FROM pub.mv_swot_signal WHERE country_iso3 = :iso3"
    params = {"iso3": iso3.upper()}
    if year is not None:
        sql += " AND year = :year"
        params["year"] = year
    if pillar is not None:
        sql += " AND pillar_code = :pillar"
        params["pillar"] = pillar.upper()
    sql += " ORDER BY year DESC, pillar_code LIMIT :limit"
    params["limit"] = limit
    return [dict(r) for r in db.execute(text(sql), params).mappings().all()]

class StructuralObsItem(BaseModel):
    country_iso3:       str             = Field(...,  description="Code ISO3 pays (3 lettres)")
    year:               int             = Field(...,  description="Annee de reference")
    indicator_code:     str             = Field(...,  description="Code indicateur OSA")
    indicator_label:    Optional[str]   = Field(None, description="Libelle de l indicateur")
    pillar_code:        str             = Field(...,  description="Code pilier souverain")
    observed_value:     Optional[float] = Field(None, description="Valeur observee normalisee (0-1) ou valeur brute source directe")
    raw_value:          Optional[float] = Field(None, description="Valeur brute source avant normalisation")
    confidence_score:   Optional[float] = Field(None, description="Indice de confiance (0-1)")
    is_estimated:       bool            = Field(...,  description="Toujours faux pour les observations souveraines autonomes")
    value_status:       Optional[str]   = Field(None, description="Statut : OBSERVED, COLLECTING, PARTIAL")
    publication_status: Optional[str]   = Field(None, description="Statut de publication OSA pour cette annee")

_STRUCTURAL_OBS_BASE = """
WITH pub_policy AS (
    SELECT year, status AS publication_status
    FROM rf.publication_policy
),
normalized AS (
    SELECT
        iv.country_iso3,
        iv.year,
        iv.indicator_code,
        i.name_fr           AS indicator_label,
        i.pillar_code,
        iv.processed_value AS observed_value,
        iv.raw_value,
        iv.confidence_score,
        iv.is_estimated,
        iv.value_status
    FROM ma.indicator_values iv
    JOIN rf.indicators i ON i.code = iv.indicator_code
    WHERE iv.indicator_code IN ('PHUM_VALUE_CAPTURE', 'PMIN_VALUE_LEAKAGE')
      AND iv.layer_id = 3
),
raw_obs AS (
    SELECT
        rd.country_iso3,
        rd.year,
        rd.indicator_code,
        i.name_fr       AS indicator_label,
        i.pillar_code,
        rd.value_raw   AS observed_value,
        rd.value_raw   AS raw_value,
        NULL::numeric  AS confidence_score,
        false          AS is_estimated,
        'OBSERVED'     AS value_status
    FROM collect.raw_data rd
    JOIN rf.indicators i ON i.code = rd.indicator_code
    WHERE rd.indicator_code = 'PMIN_SMUGGLING_SIGNAL_RANK'
),
combined AS (
    SELECT * FROM normalized
    UNION ALL
    SELECT * FROM raw_obs
)
SELECT
    c.country_iso3,
    c.year,
    c.indicator_code,
    c.indicator_label,
    c.pillar_code,
    c.observed_value,
    c.raw_value,
    c.confidence_score,
    c.is_estimated,
    c.value_status,
    p.publication_status
FROM combined c
LEFT JOIN pub_policy p ON p.year = c.year
"""

@router.get("/structural-obs",
    summary="Observations Souveraines — tous pays",
    description=(
        "Observations de phenomenes souverains a materialite mesurable : "
        "retention du capital humain, fuite de valeur minerale, signal de "
        "contrebande miniere. Non comparatives inter-pays."
    ),
    response_model=List[StructuralObsItem])
def list_structural_obs(
    year:      Optional[int] = Query(None, description="Filtrer par annee (ex: 2023)"),
    indicator: Optional[str] = Query(None, description="Filtrer par indicateur"),
    limit:     int           = Query(1000, ge=1, le=5000),
    db:        Session       = Depends(get_db),
):
    sql = _STRUCTURAL_OBS_BASE + " WHERE 1=1"
    params: dict = {"limit": limit}
    if year is not None:
        sql += " AND c.year = :year"
        params["year"] = year
    if indicator is not None:
        sql += " AND c.indicator_code = :indicator"
        params["indicator"] = indicator.upper()
    sql += " ORDER BY c.year DESC, c.country_iso3, c.indicator_code LIMIT :limit"
    return [dict(r) for r in db.execute(text(sql), params).mappings().all()]

@router.get("/structural-obs/{iso3}",
    summary="Observations Souveraines — pays unique",
    description=(
        "Observations de phenomenes souverains a materialite mesurable pour "
        "un Etat donne. Chaque observation est autonome et documentee sur sa "
        "propre trajectoire historique, sans reference comparative a d autres Etats."
    ),
    response_model=List[StructuralObsItem])
def get_structural_obs_country(
    iso3:      str           = Path(..., min_length=3, max_length=3, description="Code ISO3 du pays (ex: SEN)"),
    year:      Optional[int] = Query(None, description="Filtrer par annee"),
    indicator: Optional[str] = Query(None, description="Filtrer par indicateur"),
    limit:     int           = Query(200, ge=1, le=1000),
    db:        Session       = Depends(get_db),
):
    sql = _STRUCTURAL_OBS_BASE + " WHERE c.country_iso3 = :iso3"
    params: dict = {"iso3": iso3.upper(), "limit": limit}
    if year is not None:
        sql += " AND c.year = :year"
        params["year"] = year
    if indicator is not None:
        sql += " AND c.indicator_code = :indicator"
        params["indicator"] = indicator.upper()
    sql += " ORDER BY c.year DESC, c.indicator_code LIMIT :limit"
    return [dict(r) for r in db.execute(text(sql), params).mappings().all()]
