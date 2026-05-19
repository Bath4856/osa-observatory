"""
OSA ISA Public API — Phase 3 routers (cartographie API complète)
Sprint 8 — Mai 2026

Endpoints :
  GET /api/v2/decision/intervention-matrix          — matrice décision EXPERT
  GET /api/v2/decision/intervention-matrix/{iso3}   — pays unique EXPERT
  GET /api/v2/early-warning/annual-summary           — agrégat alertes annuel
  GET /api/v2/early-warning/annual-summary/{iso3}    — pays unique

Views :
  ma.v_isa_intervention_decision_matrix  — 8100 lignes
  ma.v_isa_early_warning_country_year    — 810 lignes
"""
from typing import Optional, List
from fastapi import APIRouter, Depends, Query, Path
from sqlalchemy.orm import Session
from sqlalchemy import text
from pydantic import BaseModel, Field
from api.db import get_db

METHODOLOGY_NOTE = (
    "This indicator provides an early-warning signal for prevention purposes. "
    "It does not constitute a legal qualification of atrocity, conflict, "
    "genocide, or criminal responsibility. "
    "OSA/ISA scores are analytical instruments based on observed sovereign indicators."
)

decision_phase3_router = APIRouter(prefix="/api/v2/decision",      tags=["Decision Support"])
ew_phase3_router       = APIRouter(prefix="/api/v2/early-warning", tags=["Early Warning & Conflict Risk"])


# ── Schémas ───────────────────────────────────────────────────────────────────

class InterventionMatrixItem(BaseModel):
    country_iso3:              str             = Field(..., description="Code ISO3 pays OSA")
    year:                      int             = Field(..., description="Année de référence")
    pillar_code:               str             = Field(..., description="Code pilier ISA")
    intervention_family_code:  Optional[str]   = Field(None, description="Code famille d'intervention")
    intervention_family_label: Optional[str]   = Field(None, description="Libellé famille d'intervention")
    strategic_objective:       Optional[str]   = Field(None, description="Objectif stratégique")
    recommended_action:        Optional[str]   = Field(None, description="Action recommandée")
    sovereign_alert_level:     Optional[str]   = Field(None, description="Niveau d'alerte souveraine")
    decision_priority_class:   Optional[str]   = Field(None, description="Classe de priorité décision")
    decision_label:            Optional[str]   = Field(None, description="Libellé décision")
    decision_priority_score:   Optional[float] = Field(None, description="Score de priorité (0–1)")
    decision_confidence_score: Optional[float] = Field(None, description="Confiance décision (0–1)")
    governance_track:          Optional[str]   = Field(None, description="Track de gouvernance")
    public_decision_scope:     Optional[str]   = Field(None, description="Périmètre décision public")
    decision_timing_code:      Optional[str]   = Field(None, description="Code timing")
    decision_timing_label:     Optional[str]   = Field(None, description="Libellé timing")
    decision_max_months:       Optional[int]   = Field(None, description="Délai maximum (mois)")
    central_isa_delta:         Optional[float] = Field(None, description="Delta ISA scénario central")
    ambitious_isa_delta:       Optional[float] = Field(None, description="Delta ISA scénario ambitieux")
    stress_isa_delta:          Optional[float] = Field(None, description="Delta ISA scénario stress")
    decision_matrix_action:    Optional[str]   = Field(None, description="Action matrice décision")
    decision_readiness_class:  Optional[str]   = Field(None, description="Classe de readiness décision")
    decision_support_status:   Optional[str]   = Field(None, description="Statut support décision")


class AnnualSummaryItem(BaseModel):
    country_iso3:                     str             = Field(..., description="Code ISO3 pays OSA")
    year:                             int             = Field(..., description="Année de référence")
    nb_pillars_monitored:             Optional[int]   = Field(None, description="Nb piliers monitorés")
    country_early_warning_score:      Optional[float] = Field(None, description="Score alerte précoce pays (0–1)")
    country_early_warning_confidence: Optional[float] = Field(None, description="Confiance alerte précoce (0–1)")
    nb_red_alerts:                    Optional[int]   = Field(None, description="Nb alertes RED")
    nb_orange_alerts:                 Optional[int]   = Field(None, description="Nb alertes ORANGE")
    nb_yellow_alerts:                 Optional[int]   = Field(None, description="Nb alertes YELLOW")
    nb_green_alerts:                  Optional[int]   = Field(None, description="Nb alertes GREEN")
    avg_fragility_warning_score:      Optional[float] = Field(None, description="Score fragilité moyen (0–1)")
    avg_stress_propagation_score:     Optional[float] = Field(None, description="Score propagation stress moyen (0–1)")
    country_sovereign_alert_level:    Optional[str]   = Field(None, description="Niveau d'alerte souveraine pays")
    country_early_warning_status:     Optional[str]   = Field(None, description="Statut alerte précoce pays")
    methodology_note:                 str             = Field(default=METHODOLOGY_NOTE)


# ── Intervention matrix (EXPERT) ─────────────────────────────────────────────

@decision_phase3_router.get("/intervention-matrix",
    summary="Matrice d'intervention décision ISA — tous pays (EXPERT)",
    description=(
        "Matrice complète des décisions d'intervention souveraine par pays et pilier. "
        "Croise opportunités, coûts, faisabilité et timing. "
        "Niveau expert — réservé aux partenaires institutionnels. "
        "Source : ma.v_isa_intervention_decision_matrix."
    ),
    response_model=List[InterventionMatrixItem])
def list_intervention_matrix(
    year:   Optional[int] = Query(None, description="Filtrer par année (ex: 2024)"),
    pillar: Optional[str] = Query(None, description="Filtrer par pilier"),
    limit:  int           = Query(100, ge=1, le=5000),
    db:     Session       = Depends(get_db),
):
    sql = "SELECT * FROM ma.v_isa_intervention_decision_matrix WHERE 1=1"
    params = {}
    if year is not None:
        sql += " AND year = :year"
        params["year"] = year
    if pillar is not None:
        sql += " AND pillar_code = :pillar"
        params["pillar"] = pillar.upper()
    sql += " ORDER BY decision_priority_score DESC NULLS LAST, year DESC LIMIT :limit"
    params["limit"] = limit
    return [dict(r) for r in db.execute(text(sql), params).mappings().all()]


@decision_phase3_router.get("/intervention-matrix/{iso3}",
    summary="Matrice d'intervention décision ISA — pays unique (EXPERT)",
    description=(
        "Matrice d'intervention pour un pays donné. "
        "Source : ma.v_isa_intervention_decision_matrix."
    ),
    response_model=List[InterventionMatrixItem])
def get_intervention_matrix_country(
    iso3:   str           = Path(..., min_length=3, max_length=3),
    year:   Optional[int] = Query(None),
    pillar: Optional[str] = Query(None),
    limit:  int           = Query(50, ge=1, le=1000),
    db:     Session       = Depends(get_db),
):
    sql = "SELECT * FROM ma.v_isa_intervention_decision_matrix WHERE country_iso3 = :iso3"
    params = {"iso3": iso3.upper()}
    if year is not None:
        sql += " AND year = :year"
        params["year"] = year
    if pillar is not None:
        sql += " AND pillar_code = :pillar"
        params["pillar"] = pillar.upper()
    sql += " ORDER BY decision_priority_score DESC NULLS LAST, year DESC LIMIT :limit"
    params["limit"] = limit
    return [dict(r) for r in db.execute(text(sql), params).mappings().all()]


# ── Annual summary (PUBLIC) ───────────────────────────────────────────────────

@ew_phase3_router.get("/annual-summary",
    summary="Synthèse annuelle des alertes souveraines ISA — tous pays",
    description=(
        "Agrégat annuel des alertes early warning par pays — "
        "score composite, distribution des alertes par bande, "
        "fragilité et propagation du stress. "
        "Utile pour les tableaux de bord de synthèse et comparaisons historiques. "
        "Source : ma.v_isa_early_warning_country_year. " + METHODOLOGY_NOTE
    ),
    response_model=List[AnnualSummaryItem])
def list_annual_summary(
    year:   Optional[int] = Query(None, description="Filtrer par année (ex: 2024)"),
    level:  Optional[str] = Query(None, description="Filtrer par niveau d'alerte (RED/ORANGE/YELLOW/GREEN)"),
    limit:  int           = Query(54, ge=1, le=1000),
    db:     Session       = Depends(get_db),
):
    sql = "SELECT * FROM ma.v_isa_early_warning_country_year WHERE 1=1"
    params = {}
    if year is not None:
        sql += " AND year = :year"
        params["year"] = year
    if level is not None:
        sql += " AND country_sovereign_alert_level = :level"
        params["level"] = level.upper()
    sql += " ORDER BY country_early_warning_score DESC NULLS LAST, year DESC LIMIT :limit"
    params["limit"] = limit
    rows = db.execute(text(sql), params).mappings().all()
    return [dict(r, methodology_note=METHODOLOGY_NOTE) for r in rows]


@ew_phase3_router.get("/annual-summary/{iso3}",
    summary="Synthèse annuelle des alertes souveraines ISA — pays unique",
    description=(
        "Historique des synthèses annuelles d'alertes pour un pays donné. "
        "Source : ma.v_isa_early_warning_country_year. " + METHODOLOGY_NOTE
    ),
    response_model=List[AnnualSummaryItem])
def get_annual_summary_country(
    iso3:  str           = Path(..., min_length=3, max_length=3),
    year:  Optional[int] = Query(None),
    limit: int           = Query(15, ge=1, le=100),
    db:    Session       = Depends(get_db),
):
    sql = "SELECT * FROM ma.v_isa_early_warning_country_year WHERE country_iso3 = :iso3"
    params = {"iso3": iso3.upper()}
    if year is not None:
        sql += " AND year = :year"
        params["year"] = year
    sql += " ORDER BY year DESC LIMIT :limit"
    params["limit"] = limit
    rows = db.execute(text(sql), params).mappings().all()
    return [dict(r, methodology_note=METHODOLOGY_NOTE) for r in rows]
