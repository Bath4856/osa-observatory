"""
OSA ISA Public API — Sovereignty router
Sprint 7 — Mai 2026

Endpoints :
  GET /api/v2/sovereignty/swot          — signaux SWOT tous pays
  GET /api/v2/sovereignty/swot/{iso3}   — signaux SWOT pays unique

View : pub.mv_swot_signal
Access class : PUBLIC
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
    year:                      int             = Field(..., description="Année de référence")
    pillar_code:               str             = Field(..., description="Code pilier ISA")
    strength_score:            Optional[float] = Field(None, description="Score Force — capacité souveraine observée (0–1)")
    opportunity_score:         Optional[float] = Field(None, description="Score Opportunité — potentiel souverain mobilisable (0–1)")
    weakness_score:            Optional[float] = Field(None, description="Score Faiblesse — fragilité structurelle observée (0–1)")
    threat_score:              Optional[float] = Field(None, description="Score Menace — pression externe ou interne (0–1)")
    strategic_risk_score:      Optional[float] = Field(None, description="Score de risque stratégique agrégé (0–1)")
    strategic_upside_score:    Optional[float] = Field(None, description="Score de potentiel stratégique agrégé (0–1)")
    observation_confidence:    Optional[float] = Field(None, description="Indice de confiance (0–1)")
    strategic_attention_class: Optional[str]   = Field(None, description="Classe d'attention stratégique OSA")
    swot_strategic_role:       Optional[str]   = Field(None, description="Rôle stratégique SWOT du pilier")
    publication_status:        Optional[str]   = Field(None, description="Statut de publication OSA")


@router.get("/swot",
    summary="Signaux SWOT souverains ISA — tous pays",
    description="Force/Opportunité/Faiblesse/Menace par pilier et par pays. Source : pub.mv_swot_signal.",
    response_model=List[SWOTSignalItem])
def list_swot(
    year:   Optional[int] = Query(None, description="Filtrer par année (ex: 2024)"),
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
    description="Signaux SWOT F/O/F/M pour un pays donné, tous piliers. Source : pub.mv_swot_signal.",
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
