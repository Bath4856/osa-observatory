"""
OSA ISA Public API — Early Warning Sprint 7 router
Sprint 7 — Mai 2026

Endpoints :
  GET /api/v2/early-warning/escalation          — escalation tous pays
  GET /api/v2/early-warning/escalation/{iso3}   — escalation pays unique
  GET /api/v2/early-warning/priority-queue       — file de priorité

Views :
  ma.v_isa_risk_escalation_engine
  ma.v_isa_national_escalation_queue

Access class : PUBLIC
Methodology note : OBLIGATOIRE (Early Warning)
"""
from typing import Optional, List
from fastapi import APIRouter, Depends, Query, Path
from sqlalchemy.orm import Session
from sqlalchemy import text
from pydantic import BaseModel, Field
from api.db import get_db

router = APIRouter(
    prefix="/api/v2/early-warning",
    tags=["Early Warning & Conflict Risk"],
)

METHODOLOGY_NOTE = (
    "This indicator provides an early-warning signal for prevention purposes. "
    "It does not constitute a legal qualification of atrocity, conflict, "
    "genocide, or criminal responsibility. "
    "OSA/ISA scores are analytical instruments based on observed sovereign indicators."
)


# ── Schémas ───────────────────────────────────────────────────────────────────

class EscalationItem(BaseModel):
    country_iso3:           str             = Field(..., description="Code ISO3 pays OSA")
    year:                   int             = Field(..., description="Année de référence")
    pillar_code:            str             = Field(..., description="Code pilier ISA")
    sovereign_alert_level:  Optional[str]   = Field(None, description="Niveau d'alerte souveraine actuel")
    previous_alert_level:   Optional[str]   = Field(None, description="Niveau d'alerte année précédente")
    alert_rank:             Optional[int]   = Field(None, description="Rang d'alerte actuel")
    previous_alert_rank:    Optional[int]   = Field(None, description="Rang d'alerte année précédente")
    early_warning_score:    Optional[float] = Field(None, description="Score d'alerte précoce actuel (0–1)")
    previous_warning_score: Optional[float] = Field(None, description="Score d'alerte précoce année précédente (0–1)")
    risk_delta:             Optional[float] = Field(None, description="Variation du score (+ = aggravation)")
    alert_rank_delta:       Optional[int]   = Field(None, description="Variation du rang (+ = dégradation)")
    risk_escalation_class:  Optional[str]   = Field(None, description="ESCALATING / STABLE / RECOVERING / INSUFFICIENT_DATA")
    risk_escalation_label:  Optional[str]   = Field(None, description="Libellé d'escalation")
    risk_escalation_action: Optional[str]   = Field(None, description="Action recommandée")
    escalation_reason:      Optional[str]   = Field(None, description="Motif analytique")
    methodology_note:       str             = Field(default=METHODOLOGY_NOTE)


class PriorityQueueItem(BaseModel):
    country_iso3:               str             = Field(..., description="Code ISO3 pays OSA")
    year:                       int             = Field(..., description="Année de référence")
    pillar_code:                str             = Field(..., description="Code pilier ISA")
    intervention_family_code:   Optional[str]   = Field(None, description="Code famille d'intervention")
    intervention_family_label:  Optional[str]   = Field(None, description="Libellé famille d'intervention")
    executive_decision_class:   Optional[str]   = Field(None, description="Classe de décision exécutive")
    executive_priority_score:   Optional[float] = Field(None, description="Score de priorité exécutive (0–1)")
    budget_pressure_score:      Optional[float] = Field(None, description="Score de pression budgétaire (0–1)")
    governance_risk_score:      Optional[float] = Field(None, description="Score de risque de gouvernance (0–1)")
    national_escalation_score:  Optional[float] = Field(None, description="Score d'escalation nationale (0–1)")
    escalation_level_code:      Optional[str]   = Field(None, description="Code niveau d'escalation")
    escalation_target:          Optional[str]   = Field(None, description="Cible d'escalation identifiée")
    escalation_action:          Optional[str]   = Field(None, description="Action recommandée")
    national_escalation_status: Optional[str]   = Field(None, description="Statut d'escalation nationale")
    methodology_note:           str             = Field(default=METHODOLOGY_NOTE)


# ── Endpoints escalation ──────────────────────────────────────────────────────

@router.get("/escalation",
    summary="Signal d'escalation souveraine ISA — tous pays",
    description=(
        "Détecte les pays dont la situation se dégrade (ESCALATING), "
        "se stabilise (STABLE) ou s'améliore (RECOVERING). "
        "Complémentaire d'AMAR : AMAR mesure le niveau, l'escalation mesure la tendance. "
        "Source : ma.v_isa_risk_escalation_engine. " + METHODOLOGY_NOTE
    ),
    response_model=List[EscalationItem])
def list_escalation(
    year:             Optional[int] = Query(None, description="Filtrer par année (ex: 2024)"),
    pillar:           Optional[str] = Query(None, description="Filtrer par pilier (ex: PGEO)"),
    escalation_class: Optional[str] = Query(None, description="ESCALATING / STABLE / RECOVERING"),
    limit:            int           = Query(540, ge=1, le=5000),
    db:               Session       = Depends(get_db),
):
    sql = "SELECT * FROM ma.v_isa_risk_escalation_engine WHERE 1=1"
    params = {}
    if year is not None:
        sql += " AND year = :year"
        params["year"] = year
    if pillar is not None:
        sql += " AND pillar_code = :pillar"
        params["pillar"] = pillar.upper()
    if escalation_class is not None:
        sql += " AND risk_escalation_class = :escalation_class"
        params["escalation_class"] = escalation_class.upper()
    sql += " ORDER BY year DESC, country_iso3, pillar_code LIMIT :limit"
    params["limit"] = limit
    rows = db.execute(text(sql), params).mappings().all()
    return [dict(r, methodology_note=METHODOLOGY_NOTE) for r in rows]


@router.get("/escalation/{iso3}",
    summary="Signal d'escalation souveraine ISA — pays unique",
    description=(
        "Signal ESCALATING/STABLE/RECOVERING pour un pays donné, tous piliers. "
        "Source : ma.v_isa_risk_escalation_engine. " + METHODOLOGY_NOTE
    ),
    response_model=List[EscalationItem])
def get_escalation_country(
    iso3:             str           = Path(..., min_length=3, max_length=3, description="Code ISO3 du pays"),
    year:             Optional[int] = Query(None),
    pillar:           Optional[str] = Query(None),
    escalation_class: Optional[str] = Query(None, description="ESCALATING / STABLE / RECOVERING"),
    limit:            int           = Query(100, ge=1, le=1000),
    db:               Session       = Depends(get_db),
):
    sql = "SELECT * FROM ma.v_isa_risk_escalation_engine WHERE country_iso3 = :iso3"
    params = {"iso3": iso3.upper()}
    if year is not None:
        sql += " AND year = :year"
        params["year"] = year
    if pillar is not None:
        sql += " AND pillar_code = :pillar"
        params["pillar"] = pillar.upper()
    if escalation_class is not None:
        sql += " AND risk_escalation_class = :escalation_class"
        params["escalation_class"] = escalation_class.upper()
    sql += " ORDER BY year DESC, pillar_code LIMIT :limit"
    params["limit"] = limit
    rows = db.execute(text(sql), params).mappings().all()
    return [dict(r, methodology_note=METHODOLOGY_NOTE) for r in rows]


# ── Endpoint priority-queue ───────────────────────────────────────────────────

@router.get("/priority-queue",
    summary="File de priorité d'intervention souveraine ISA",
    description=(
        "File ordonnée des pays et piliers par urgence d'intervention, "
        "classée par score de priorité exécutive décroissant. "
        "Directement actionnable par un décideur institutionnel. "
        "Source : ma.v_isa_national_escalation_queue. " + METHODOLOGY_NOTE
    ),
    response_model=List[PriorityQueueItem])
def get_priority_queue(
    year:   Optional[int] = Query(None, description="Filtrer par année (ex: 2024)"),
    pillar: Optional[str] = Query(None, description="Filtrer par pilier"),
    limit:  int           = Query(20, ge=1, le=540, description="Taille de la file (défaut: 20)"),
    db:     Session       = Depends(get_db),
):
    sql = "SELECT * FROM ma.v_isa_national_escalation_queue WHERE 1=1"
    params = {}
    if year is not None:
        sql += " AND year = :year"
        params["year"] = year
    if pillar is not None:
        sql += " AND pillar_code = :pillar"
        params["pillar"] = pillar.upper()
    sql += " ORDER BY executive_priority_score DESC NULLS LAST LIMIT :limit"
    params["limit"] = limit
    rows = db.execute(text(sql), params).mappings().all()
    return [dict(r, methodology_note=METHODOLOGY_NOTE) for r in rows]
