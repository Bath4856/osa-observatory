"""
OSA ISA Public API — Decision & Scenarios routers
Sprint 7 — API Phase 2

Endpoints :
  GET /api/v2/decision/priorities           — priorités décision tous pays
  GET /api/v2/decision/priorities/{iso3}    — priorités décision pays unique
  GET /api/v2/sovereignty/readiness         — readiness souveraine agrégée (pas de filtre pays/année)
  GET /api/v2/early-warning/fragility       — fragilité structurelle tous pays
  GET /api/v2/early-warning/fragility/{iso3}— fragilité structurelle pays unique
  GET /api/v2/scenarios/country             — scénarios P7H tous pays
  GET /api/v2/scenarios/country/{iso3}      — scénarios P7H pays unique
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

# ── Routers ───────────────────────────────────────────────────────────────────

decision_router = APIRouter(prefix="/api/v2/decision",    tags=["Decision Support"])
sovereignty_router = APIRouter(prefix="/api/v2/sovereignty", tags=["Sovereignty"])
ew_router       = APIRouter(prefix="/api/v2/early-warning", tags=["Early Warning & Conflict Risk"])
scenario_router = APIRouter(prefix="/api/v2/scenarios",   tags=["Scenarios"])


# ── Schémas ───────────────────────────────────────────────────────────────────

class DecisionPriorityItem(BaseModel):
    country_iso3:                        str             = Field(..., description="Code ISO3 pays OSA")
    year:                                int             = Field(..., description="Année de référence")
    pillar_code:                         str             = Field(..., description="Code pilier ISA")
    intervention_family_code:            Optional[str]   = Field(None)
    intervention_family_label:           Optional[str]   = Field(None)
    strategic_objective:                 Optional[str]   = Field(None)
    recommended_action:                  Optional[str]   = Field(None)
    candidate_intervention_status:       Optional[str]   = Field(None)
    sovereign_alert_level:               Optional[str]   = Field(None)
    early_warning_class:                 Optional[str]   = Field(None)
    early_warning_score:                 Optional[float] = Field(None, description="Score d'alerte précoce (0–1)")
    intervention_alert_priority_score:   Optional[float] = Field(None, description="Score de priorité d'intervention (0–1)")
    intervention_priority_class:         Optional[str]   = Field(None)
    decision_priority_score:             Optional[float] = Field(None, description="Score de priorité décision (0–1)")
    decision_priority_class:             Optional[str]   = Field(None)
    decision_rank:                       Optional[int]   = Field(None, description="Rang de priorité décision")
    decision_label:                      Optional[str]   = Field(None)
    decision_action:                     Optional[str]   = Field(None)
    decision_timing_label:               Optional[str]   = Field(None)
    early_warning_confidence:            Optional[float] = Field(None)
    intervention_priority_label:         Optional[str]   = Field(None)
    priority_intervention_action:        Optional[str]   = Field(None)
    priority_intervention_alert_status:  Optional[str]   = Field(None)
    central_isa_delta:                   Optional[float] = Field(None)
    ambitious_isa_delta:                 Optional[float] = Field(None)
    stress_isa_delta:                    Optional[float] = Field(None)
    central_simulation_decision:         Optional[str]   = Field(None)
    stress_simulation_decision:          Optional[str]   = Field(None)
    decision_confidence_score:           Optional[float] = Field(None)
    governance_track:                    Optional[str]   = Field(None)
    public_decision_scope:               Optional[str]   = Field(None)
    decision_timing_code:                Optional[str]   = Field(None)
    decision_max_months:                 Optional[int]   = Field(None)
    decision_support_status:             Optional[str]   = Field(None)
    methodology_note:                    str             = Field(default=METHODOLOGY_NOTE)


class SovereigntyReadinessItem(BaseModel):
    pillar_code:                  str             = Field(..., description="Code pilier ISA")
    semantic_code:                Optional[str]   = Field(None, description="Code sémantique")
    nb_indicators:                Optional[int]   = Field(None, description="Nombre d'indicateurs")
    avg_sovereignty_score:        Optional[float] = Field(None, description="Score souveraineté moyen (0–1)")
    avg_sovereignty_vulnerability:Optional[float] = Field(None, description="Vulnérabilité souveraine moyenne (0–1)")
    avg_dynamic_confidence:       Optional[float] = Field(None, description="Confiance dynamique moyenne (0–1)")
    avg_operational_score:        Optional[float] = Field(None, description="Score opérationnel moyen (0–1)")
    avg_forecastability_score:    Optional[float] = Field(None, description="Score de prévisibilité moyen (0–1)")
    nb_sovereignty_strong:        Optional[int]   = Field(None, description="Nb indicateurs souveraineté forte")
    nb_sovereignty_controlled:    Optional[int]   = Field(None, description="Nb indicateurs souveraineté contrôlée")
    nb_sovereignty_fragile:       Optional[int]   = Field(None, description="Nb indicateurs souveraineté fragile")
    nb_sovereignty_gap_locked:    Optional[int]   = Field(None, description="Nb indicateurs souveraineté gap-locked")
    nb_sovereignty_weak:          Optional[int]   = Field(None, description="Nb indicateurs souveraineté faible")
    isa_sovereignty_readiness_score: Optional[float] = Field(None, description="Score de readiness souveraine ISA (0–1)")
    sovereignty_readiness_status: Optional[str]   = Field(None, description="Statut de readiness souveraine")


class FragilityWarningItem(BaseModel):
    country_iso3:                 str             = Field(..., description="Code ISO3 pays OSA")
    year:                         int             = Field(..., description="Année de référence")
    pillar_code:                  str             = Field(..., description="Code pilier ISA")
    sovereign_alert_level:        Optional[str]   = Field(None)
    early_warning_class:          Optional[str]   = Field(None)
    forecast_blocking_reason:     Optional[str]   = Field(None)
    strategic_diagnostic_role:    Optional[str]   = Field(None)
    fragility_warning_score:      Optional[float] = Field(None, description="Score de fragilité (0–1)")
    stress_propagation_score:     Optional[float] = Field(None, description="Score de propagation du stress (0–1)")
    early_warning_score:          Optional[float] = Field(None, description="Score d'alerte précoce (0–1)")
    early_warning_confidence:     Optional[float] = Field(None, description="Confiance alerte précoce (0–1)")
    fragility_warning_class:      Optional[str]   = Field(None, description="Classe de fragilité")
    fragility_recommended_action: Optional[str]   = Field(None)
    methodology_note:             str             = Field(default=METHODOLOGY_NOTE)


class ScenarioItem(BaseModel):
    country_iso3:                         str             = Field(..., description="Code ISO3 pays OSA")
    year:                                 int             = Field(..., description="Année de référence")
    scenario_code:                        Optional[str]   = Field(None, description="Code scénario P7H")
    scenario_label:                       Optional[str]   = Field(None, description="Libellé scénario")
    scenario_family:                      Optional[str]   = Field(None, description="Famille de scénario")
    nb_pillars_simulated:                 Optional[int]   = Field(None, description="Nb piliers simulés")
    country_simulation_confidence:        Optional[float] = Field(None, description="Confiance simulation (0–1)")
    country_simulated_isa_delta:          Optional[float] = Field(None, description="Delta ISA simulé")
    country_simulated_sovereignty_delta:  Optional[float] = Field(None, description="Delta souveraineté simulé")
    country_simulated_isa_score:          Optional[float] = Field(None, description="Score ISA simulé (0–1)")
    nb_policy_usable_pillars:             Optional[int]   = Field(None, description="Nb piliers actionnables")
    country_simulated_vulnerability_delta:Optional[float] = Field(None)
    country_simulated_resilience_delta:   Optional[float] = Field(None)
    nb_volatility_warning_pillars:        Optional[int]   = Field(None)
    nb_low_confidence_pillars:            Optional[int]   = Field(None)
    nb_stress_pillars:                    Optional[int]   = Field(None)
    country_scenario_status:              Optional[str]   = Field(None)


# ── Decision priorities ───────────────────────────────────────────────────────

@decision_router.get("/priorities",
    summary="Priorités de décision souveraine ISA — tous pays",
    description=(
        "Priorisation dynamique des interventions souveraines par pays et pilier. "
        "Complète /opportunities avec une logique de criticité alignée sur P7J. "
        "Source : ma.v_isa_decision_priority_engine."
    ),
    response_model=List[DecisionPriorityItem])
def list_decision_priorities(
    year:   Optional[int] = Query(None, description="Filtrer par année (ex: 2024)"),
    pillar: Optional[str] = Query(None, description="Filtrer par pilier"),
    limit:  int           = Query(100, ge=1, le=5000),
    db:     Session       = Depends(get_db),
):
    sql = "SELECT * FROM ma.v_isa_decision_priority_engine WHERE 1=1"
    params = {}
    if year is not None:
        sql += " AND year = :year"
        params["year"] = year
    if pillar is not None:
        sql += " AND pillar_code = :pillar"
        params["pillar"] = pillar.upper()
    sql += " ORDER BY decision_rank ASC NULLS LAST, year DESC LIMIT :limit"
    params["limit"] = limit
    rows = db.execute(text(sql), params).mappings().all()
    return [dict(r, methodology_note=METHODOLOGY_NOTE) for r in rows]


@decision_router.get("/priorities/{iso3}",
    summary="Priorités de décision souveraine ISA — pays unique",
    description="Priorités d'intervention pour un pays donné. Source : ma.v_isa_decision_priority_engine.",
    response_model=List[DecisionPriorityItem])
def get_decision_priorities_country(
    iso3:   str           = Path(..., min_length=3, max_length=3),
    year:   Optional[int] = Query(None),
    pillar: Optional[str] = Query(None),
    limit:  int           = Query(50, ge=1, le=1000),
    db:     Session       = Depends(get_db),
):
    sql = "SELECT * FROM ma.v_isa_decision_priority_engine WHERE country_iso3 = :iso3"
    params = {"iso3": iso3.upper()}
    if year is not None:
        sql += " AND year = :year"
        params["year"] = year
    if pillar is not None:
        sql += " AND pillar_code = :pillar"
        params["pillar"] = pillar.upper()
    sql += " ORDER BY decision_rank ASC NULLS LAST, year DESC LIMIT :limit"
    params["limit"] = limit
    rows = db.execute(text(sql), params).mappings().all()
    return [dict(r, methodology_note=METHODOLOGY_NOTE) for r in rows]


# ── Sovereignty readiness ─────────────────────────────────────────────────────

@sovereignty_router.get("/readiness",
    summary="Readiness souveraine ISA — agrégat par pilier",
    description=(
        "Mesure la capacité souveraine observée par pilier. "
        "Distinct de P7Z (prédictive) — vue de la readiness actuelle, pas projetée. "
        "Vue agrégée sans dimension pays/année. "
        "Source : ma.v_isa_sovereignty_readiness."
    ),
    response_model=List[SovereigntyReadinessItem])
def get_sovereignty_readiness(
    pillar: Optional[str] = Query(None, description="Filtrer par pilier (ex: PGEO)"),
    limit:  int           = Query(67, ge=1, le=200),
    db:     Session       = Depends(get_db),
):
    sql = "SELECT * FROM ma.v_isa_sovereignty_readiness WHERE 1=1"
    params = {}
    if pillar is not None:
        sql += " AND pillar_code = :pillar"
        params["pillar"] = pillar.upper()
    sql += " ORDER BY isa_sovereignty_readiness_score DESC NULLS LAST LIMIT :limit"
    params["limit"] = limit
    return [dict(r) for r in db.execute(text(sql), params).mappings().all()]


# ── Fragility warning ─────────────────────────────────────────────────────────

@ew_router.get("/fragility",
    summary="Signal de fragilité structurelle ISA — tous pays",
    description=(
        "Signal de fragilité structurelle souveraine agrégé par pays et pilier. "
        "Complément d'AMAR : AMAR mesure le précurseur d'atrocités, "
        "la fragilité mesure les gaps structurels sous-jacents. "
        "Source : ma.v_isa_fragility_warning_engine. " + METHODOLOGY_NOTE
    ),
    response_model=List[FragilityWarningItem])
def list_fragility(
    year:             Optional[int] = Query(None, description="Filtrer par année (ex: 2024)"),
    pillar:           Optional[str] = Query(None, description="Filtrer par pilier"),
    fragility_class:  Optional[str] = Query(None, description="Filtrer par classe de fragilité"),
    limit:            int           = Query(540, ge=1, le=5000),
    db:               Session       = Depends(get_db),
):
    sql = "SELECT * FROM ma.v_isa_fragility_warning_engine WHERE 1=1"
    params = {}
    if year is not None:
        sql += " AND year = :year"
        params["year"] = year
    if pillar is not None:
        sql += " AND pillar_code = :pillar"
        params["pillar"] = pillar.upper()
    if fragility_class is not None:
        sql += " AND fragility_warning_class = :fragility_class"
        params["fragility_class"] = fragility_class.upper()
    sql += " ORDER BY fragility_warning_score DESC NULLS LAST, year DESC LIMIT :limit"
    params["limit"] = limit
    rows = db.execute(text(sql), params).mappings().all()
    return [dict(r, methodology_note=METHODOLOGY_NOTE) for r in rows]


@ew_router.get("/fragility/{iso3}",
    summary="Signal de fragilité structurelle ISA — pays unique",
    description=(
        "Signal de fragilité structurelle pour un pays donné. "
        "Source : ma.v_isa_fragility_warning_engine. " + METHODOLOGY_NOTE
    ),
    response_model=List[FragilityWarningItem])
def get_fragility_country(
    iso3:            str           = Path(..., min_length=3, max_length=3),
    year:            Optional[int] = Query(None),
    pillar:          Optional[str] = Query(None),
    fragility_class: Optional[str] = Query(None),
    limit:           int           = Query(100, ge=1, le=1000),
    db:              Session       = Depends(get_db),
):
    sql = "SELECT * FROM ma.v_isa_fragility_warning_engine WHERE country_iso3 = :iso3"
    params = {"iso3": iso3.upper()}
    if year is not None:
        sql += " AND year = :year"
        params["year"] = year
    if pillar is not None:
        sql += " AND pillar_code = :pillar"
        params["pillar"] = pillar.upper()
    if fragility_class is not None:
        sql += " AND fragility_warning_class = :fragility_class"
        params["fragility_class"] = fragility_class.upper()
    sql += " ORDER BY fragility_warning_score DESC NULLS LAST, year DESC LIMIT :limit"
    params["limit"] = limit
    rows = db.execute(text(sql), params).mappings().all()
    return [dict(r, methodology_note=METHODOLOGY_NOTE) for r in rows]


# ── Scenarios ─────────────────────────────────────────────────────────────────

@scenario_router.get("/country",
    summary="Scénarios P7H par pays — tous pays",
    description=(
        "Résultats des simulations de scénarios souverains P7H par pays et année. "
        "Cohérent avec P7Z déjà exposé — les deux forment la couche prédictive OSA. "
        "Source : ma.v_isa_scenario_country_year."
    ),
    response_model=List[ScenarioItem])
def list_scenarios(
    year:            Optional[int] = Query(None, description="Filtrer par année (ex: 2024)"),
    scenario_code:   Optional[str] = Query(None, description="Filtrer par code scénario"),
    scenario_family: Optional[str] = Query(None, description="Filtrer par famille de scénario"),
    limit:           int           = Query(100, ge=1, le=5000),
    db:              Session       = Depends(get_db),
):
    sql = "SELECT * FROM ma.v_isa_scenario_country_year WHERE 1=1"
    params = {}
    if year is not None:
        sql += " AND year = :year"
        params["year"] = year
    if scenario_code is not None:
        sql += " AND scenario_code = :scenario_code"
        params["scenario_code"] = scenario_code.upper()
    if scenario_family is not None:
        sql += " AND scenario_family = :scenario_family"
        params["scenario_family"] = scenario_family.upper()
    sql += " ORDER BY year DESC, country_iso3, scenario_code LIMIT :limit"
    params["limit"] = limit
    return [dict(r) for r in db.execute(text(sql), params).mappings().all()]


@scenario_router.get("/country/{iso3}",
    summary="Scénarios P7H par pays — pays unique",
    description="Scénarios souverains P7H pour un pays donné. Source : ma.v_isa_scenario_country_year.",
    response_model=List[ScenarioItem])
def get_scenarios_country(
    iso3:            str           = Path(..., min_length=3, max_length=3),
    year:            Optional[int] = Query(None),
    scenario_code:   Optional[str] = Query(None),
    scenario_family: Optional[str] = Query(None),
    limit:           int           = Query(50, ge=1, le=1000),
    db:              Session       = Depends(get_db),
):
    sql = "SELECT * FROM ma.v_isa_scenario_country_year WHERE country_iso3 = :iso3"
    params = {"iso3": iso3.upper()}
    if year is not None:
        sql += " AND year = :year"
        params["year"] = year
    if scenario_code is not None:
        sql += " AND scenario_code = :scenario_code"
        params["scenario_code"] = scenario_code.upper()
    if scenario_family is not None:
        sql += " AND scenario_family = :scenario_family"
        params["scenario_family"] = scenario_family.upper()
    sql += " ORDER BY year DESC, scenario_code LIMIT :limit"
    params["limit"] = limit
    return [dict(r) for r in db.execute(text(sql), params).mappings().all()]
