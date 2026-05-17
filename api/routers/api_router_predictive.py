import time
from fastapi import APIRouter, Depends, Query, Path
from sqlalchemy import text
from sqlalchemy.orm import Session

from api.db import get_db
from api.security import validate_expert_access
from api.middleware.telemetry import register_api_usage

# =============================================================================
# OSA ISA — P8 V2 Predictive Router
# Documentation institutionnelle, méthodologique et de gouvernance
# =============================================================================

_READINESS_DESCRIPTION = """
Returns P7Z Phase 2 predictive readiness aggregated by country and year.

---

## Définition institutionnelle

La **predictive readiness** ISA/P7Z mesure la capacité d'un pays à exécuter
des interventions souveraines dans un horizon temporel donné, selon les
paramètres du moteur probabiliste P7Z Phase 2.

**Ce n'est pas** un classement de performance nationale.
**C'est** un signal de convergence institutionnelle vers l'exécutabilité.

---

## Indicateurs clés

| Champ | Définition |
|-------|-----------|
| `avg_execution_probability` | Moyenne des probabilités d'exécution par pays/année |
| `nb_simulation_ready` | Interventions en classe `P7Z_SIMULATION_READY` (seuil strict) |
| `min_convergence_years` | Horizon minimum pour atteindre `EXEC_READY_CAUTION` |
| `sovereign_fragility_class` | Classe de fragilité nationale issue de `v_isa_p7z_fragility_engine` |
| `p7z_national_status` | Statut P7Z global du pays |

---

## Classes de convergence

| Classe | Horizon | Interprétation |
|--------|---------|----------------|
| `CONVERGENCE_IMMINENT` | < 2 ans | Conditions quasi-réunies — préparation à lancer |
| `CONVERGENCE_SHORT_TERM` | 2–5 ans | Planification active requise |
| `CONVERGENCE_MEDIUM_TERM` | 5–10 ans | Programme structurel à moyen terme |
| `CONVERGENCE_LONG_TERM` | > 10 ans | Réforme institutionnelle profonde nécessaire |

---

## Avertissements méthodologiques

> ⚠️ `avg_execution_probability` est agrégée sur toutes les interventions
> d'un pays, incluant les classes `P7Z_SIMULATION_PARTIAL`.
> Pour les signaux détaillés par intervention, utiliser `/predictive/signals` (EXPERT).

> ⚠️ `min_convergence_years` est calculé sur les interventions
> `P7Z_SIMULATION_READY` uniquement. Il ne reflète pas la situation
> des piliers en `P7Z_MONITORING_ONLY` (ex: PGEO — 18.8 ans).

---

## Gouvernance

Données gouvernées par :
- **P7K V3 FROZEN** — baseline du 2026-05-15
- **P7Z Phase 2 ACTIVE** — moteur probabiliste opérationnel
- **mg.isa_package_freeze_registry** — intégrité de la baseline garantie
- **mg.isa_view_lineage_registry** — 22 dépendances documentées

Release : **P8V2_2026_CANDIDATE** — Accès : **PUBLIC**
"""

_SIGNALS_DESCRIPTION = """
Returns detailed P7Z Phase 2 execution probability signals with all
probability components. **Expert access required** (X-API-Key header).

---

## Définition institutionnelle

Les **execution signals** exposent les quatre composantes du calcul de
probabilité d'exécution P7Z Phase 2, par pays × année × pilier × famille
d'intervention.

**Réservé aux analystes institutionnels et partenaires accrédités.**

---

## Composantes de probabilité

| Composante | Formule | Signal capturé |
|-----------|---------|----------------|
| `prob_base` | `base − gap×0.40 − uncertainty×penalty + maturity×0.15` | État fondamental de l'intervention |
| `prob_scenario` | `central_delta×0.50 + stress_delta×0.25 + confidence×0.05` | Signal scénario P7H |
| `prob_decision` | `CRITICAL+0.08 / HIGH+0.04 / STANDARD+0.01 / MONITOR−0.02` | Signal décision P7J |
| `prob_pressure_penalty` | `(pressure − 0.60) × (−0.15)` si pressure > 0.60 | Pénalité pression souveraine |

**Résultat** : `execution_probability = Σ(4 composantes)` — borné à `[0.0, 1.0]`

---

## Intervalle de confiance

`confidence_interval = calibration_uncertainty_score × 0.25`

Exemple : uncertainty = 0.20 → IC = ±0.050

---

## Politique d'accès expert

L'accès expert est requis car ces données exposent :
- les composantes internes du modèle probabiliste,
- les signaux de décision P7J non agrégés,
- les paramètres de calibration du cost model P7K.

Une mauvaise interprétation de ces données par un utilisateur non averti
pourrait conduire à des décisions institutionnelles incorrectes.

---

## Gouvernance

- **Authentification** : SHA-256 hash de la clé dans `mg.api_key_registry`
- **Telemetry** : chaque appel tracé dans `mg.api_usage_registry`
- **Audit** : `rf.isa_cost_model_audit_log` + `mg.isa_view_lineage_registry`

Release : **P8V2_2026_CANDIDATE** — Accès : **EXPERT** — Auth : X-API-Key
"""

_FRAGILITY_DESCRIPTION = """
Returns the P7Z Phase 2 sovereign fragility index by country and year.

---

## Définition institutionnelle

L'**indice de fragilité souveraine** (`sovereign_fragility_index`) mesure
la vulnérabilité systémique d'un pays face aux défaillances d'exécution
dans ses piliers souverains.

**Ce n'est pas** un indicateur de fragilité étatique au sens politique.
**C'est** un score de propagation des risques d'exécution institutionnelle.

---

## Formule

```
sovereign_fragility_index =
  Σ(cascade_impact_score × systemic_fragility_weight) /
  Σ(systemic_fragility_weight)
```

où :
```
cascade_impact_score =
  failure_probability × cascade_failure_probability × fragility_weight
```

---

## Classes de fragilité

| Classe | Seuil | Signification institutionnelle |
|--------|-------|-------------------------------|
| `SOVEREIGN_FRAGILE` | ≥ 0.12 | Intervention systémique nationale urgente |
| `SOVEREIGN_VULNERABLE` | ≥ 0.07 | Surveillance nationale renforcée |
| `SOVEREIGN_MODERATE` | ≥ 0.03 | Risque modéré — programmes ciblés |
| `SOVEREIGN_RESILIENT` | < 0.03 | Système souverain absorbant |

---

## Avertissements méthodologiques

> ⚠️ En P7Z Phase 2, `sovereign_fragility_index` est calculé uniquement
> sur les 4 piliers `P7Z_SIMULATION_READY` (PRES, PMON, PNUM, PTRA).
> Les piliers `MONITORING_ONLY` (PGEO, PMIL, etc.) ne sont pas encore
> intégrés dans le calcul de fragilité nationale. Ce périmètre s'élargira
> en P7Z Phase 3.

> ⚠️ `SOVEREIGN_RESILIENT` pour tous les pays en Phase 2 est un résultat
> structurel — seuls les piliers à forte probabilité d'exécution entrent
> dans le calcul cascade. Ce n'est pas une certification de stabilité nationale.

---

## Gouvernance

- **Source** : `ma.v_isa_p7z_fragility_engine` → `pub.v_isa_sovereign_fragility`
- **Dépendances** : P7Z Phase 2 — `mv_isa_p7z_execution_probability`
- **Lineage** : refresh_order 80 dans `mg.isa_view_lineage_registry`
- **Freeze** : P7K V3 FROZEN — 2026-05-15

Release : **P8V2_2026_CANDIDATE** — Accès : **PUBLIC**
"""

router = APIRouter(prefix="/api/v2/predictive", tags=["P8 Predictive — P7Z Phase 2"])


@router.get(
    "/readiness",
    summary="P7Z country predictive readiness — aggregated by country/year",
    description=_READINESS_DESCRIPTION,
    responses={
        200: {
            "description": "P7Z predictive readiness aggregated by country and year.",
            "content": {
                "application/json": {
                    "example": {
                        "count": 54,
                        "data": [
                            {
                                "country_iso3": "MDG",
                                "year": 2024,
                                "nb_pillars_assessed": 4,
                                "nb_interventions": 40,
                                "nb_high_probability": 12,
                                "nb_simulation_ready": 4,
                                "avg_execution_probability": 0.539,
                                "max_execution_probability": 0.707,
                                "avg_convergence_years": 1.8,
                                "min_convergence_years": 0.7,
                                "sovereign_fragility_class": "SOVEREIGN_RESILIENT",
                                "p7z_national_status": "P7Z_NATIONAL_STABLE",
                                "sovereign_fragility_index": 0.011,
                                "most_fragile_pillar": "PMON",
                                "most_resilient_pillar": "PNUM",
                            }
                        ],
                        "disclaimer": (
                            "Predictive readiness reflects institutional execution convergence, "
                            "not national performance or political stability."
                        ),
                    }
                }
            },
        },
        503: {"description": "Release not active."},
    },
    openapi_extra={
        "x-osa-governance": {
            "package": "P7Z_Phase2",
            "source": "pub.v_isa_p7z_country_readiness",
            "freeze_baseline": "P7K V3 — 2026-05-15",
            "calibration_status": "PROVISIONAL",
            "disclaimer": "Not a national performance ranking.",
        }
    },
)
async def get_readiness(
    year: int = Query(
        default=None,
        description="Filter by year (2010–2024). If omitted, returns all years.",
    ),
    db: Session = Depends(get_db),
):
    t0 = time.time()
    if year:
        rows = db.execute(text("""
            SELECT * FROM pub.v_isa_p7z_country_readiness
            WHERE year = :year
            ORDER BY avg_execution_probability DESC NULLS LAST
        """), {"year": year}).mappings().all()
    else:
        rows = db.execute(text("""
            SELECT * FROM pub.v_isa_p7z_country_readiness
            ORDER BY year DESC, avg_execution_probability DESC NULLS LAST
        """)).mappings().all()

    elapsed = round((time.time() - t0) * 1000, 2)
    await register_api_usage(
        "V2_P7Z_READINESS", "/api/v2/predictive/readiness", "GET",
        "PUBLIC", 200, elapsed, len(rows)
    )
    return {
        "count": len(rows),
        "data": [dict(r) for r in rows],
        "disclaimer": (
            "Predictive readiness reflects institutional execution convergence, "
            "not national performance or political stability. "
            "Governed by P7K V3 FROZEN baseline (2026-05-15)."
        ),
    }


@router.get(
    "/readiness/{iso3}",
    summary="P7Z predictive readiness — single country (all years)",
    description=_READINESS_DESCRIPTION,
    openapi_extra={
        "x-osa-governance": {
            "package": "P7Z_Phase2",
            "source": "pub.v_isa_p7z_country_readiness",
            "freeze_baseline": "P7K V3 — 2026-05-15",
        }
    },
)
async def get_readiness_by_country(
    iso3: str = Path(description="ISO3 country code (e.g. MAR, KEN, ZMB)."),
    db: Session = Depends(get_db),
):
    t0 = time.time()
    rows = db.execute(text("""
        SELECT * FROM pub.v_isa_p7z_country_readiness
        WHERE country_iso3 = :iso3
        ORDER BY year DESC
    """), {"iso3": iso3.upper()}).mappings().all()

    elapsed = round((time.time() - t0) * 1000, 2)
    await register_api_usage(
        "V2_P7Z_READINESS_ISO3", f"/api/v2/predictive/readiness/{iso3}", "GET",
        "PUBLIC", 200, elapsed, len(rows)
    )
    return {
        "count": len(rows),
        "data": [dict(r) for r in rows],
        "disclaimer": (
            "Predictive readiness reflects institutional execution convergence. "
            "Not a national performance ranking."
        ),
    }


@router.get(
    "/signals",
    summary="P7Z execution probability signals — EXPERT ACCESS ONLY",
    description=_SIGNALS_DESCRIPTION,
    responses={
        200: {
            "description": "Detailed P7Z execution probability signals with probability components.",
            "content": {
                "application/json": {
                    "example": {
                        "count": 1,
                        "data": [
                            {
                                "country_iso3": "MAR",
                                "year": 2024,
                                "pillar_code": "PRES",
                                "intervention_family_code": "ENERGY_WATER_CERTIFICATION",
                                "execution_probability": 0.689,
                                "confidence_interval": 0.038,
                                "execution_probability_class": "HIGH_PROBABILITY",
                                "p7z_eligibility_class": "P7Z_SIMULATION_READY",
                                "estimated_convergence_years": 1.3,
                                "predictive_gap_score": 0.061,
                                "prob_base": 0.571,
                                "prob_scenario": 0.089,
                                "prob_decision": 0.040,
                                "prob_pressure_penalty": -0.011,
                                "central_isa_delta": 0.178,
                                "central_decision": "SIMULATION_USABLE_FOR_POLICY_DISCUSSION",
                                "decision_priority_class": "DECISION_HIGH",
                                "executive_master_status": "EXECUTIVE_PRIORITY",
                            }
                        ],
                        "access_class": "EXPERT",
                        "disclaimer": (
                            "Expert data. Probability components are model internals. "
                            "Not for public distribution without institutional authorization."
                        ),
                    }
                }
            },
        },
        401: {"description": "Missing X-API-Key header."},
        403: {"description": "Invalid or expired API key."},
    },
    openapi_extra={
        "x-osa-governance": {
            "package": "P7Z_Phase2",
            "source": "pub.v_isa_p7z_execution_signals",
            "access_class": "EXPERT",
            "auth": "X-API-Key — SHA-256 hash in mg.api_key_registry",
            "freeze_baseline": "P7K V3 — 2026-05-15",
            "audit_trail": "mg.api_usage_registry + rf.isa_cost_model_audit_log",
            "disclaimer": (
                "Expert data. Not for public distribution "
                "without institutional authorization."
            ),
        }
    },
)
async def get_predictive_signals(
    iso3: str = Query(default=None, description="Filter by ISO3 country code."),
    year: int = Query(default=None, description="Filter by year (2010–2024)."),
    pillar: str = Query(
        default=None,
        description="Filter by pillar code (PRES, PMON, PNUM, PTRA, PHUM, PECO, PENV, PMIL, PMIN, PGEO).",
    ),
    db: Session = Depends(get_db),
    auth=Depends(validate_expert_access),
):
    t0 = time.time()
    base = "SELECT * FROM pub.v_isa_p7z_execution_signals"
    params: dict = {}
    filters = []

    if iso3:
        filters.append("country_iso3 = :iso3")
        params["iso3"] = iso3.upper()
    if year:
        filters.append("year = :year")
        params["year"] = year
    if pillar:
        filters.append("pillar_code = :pillar")
        params["pillar"] = pillar.upper()

    if filters:
        base += " WHERE " + " AND ".join(filters)
    base += " ORDER BY execution_probability DESC NULLS LAST"

    rows = db.execute(text(base), params).mappings().all()

    elapsed = round((time.time() - t0) * 1000, 2)
    await register_api_usage(
        "V2_P7Z_SIGNALS", "/api/v2/predictive/signals", "GET",
        "EXPERT", 200, elapsed, len(rows)
    )
    return {
        "count": len(rows),
        "data": [dict(r) for r in rows],
        "access_class": "EXPERT",
        "disclaimer": (
            "Expert data. Probability components are model internals. "
            "Not for public distribution without institutional authorization. "
            "Governed by P7K V3 FROZEN baseline (2026-05-15)."
        ),
    }


@router.get(
    "/fragility",
    summary="Sovereign fragility index — P7Z Phase 2",
    description=_FRAGILITY_DESCRIPTION,
    responses={
        200: {
            "description": "Sovereign fragility index by country and year.",
            "content": {
                "application/json": {
                    "example": {
                        "count": 270,
                        "data": [
                            {
                                "country_iso3": "SDN",
                                "year": 2024,
                                "sovereign_fragility_index": 0.019,
                                "sovereign_resilience_index": 0.981,
                                "sovereign_fragility_class": "SOVEREIGN_RESILIENT",
                                "p7z_national_status": "P7Z_NATIONAL_STABLE",
                                "avg_exec_probability": 0.534,
                                "most_fragile_pillar": "PMON",
                                "most_resilient_pillar": "PNUM",
                                "nb_high_cascade_pillars": 0,
                                "total_ready_interventions": 4,
                                "nb_pillars_assessed": 4,
                            }
                        ],
                        "methodology_note": (
                            "In P7Z Phase 2, sovereign_fragility_index is computed "
                            "on P7Z_SIMULATION_READY pillars only (PRES, PMON, PNUM, PTRA). "
                            "Full national fragility coverage planned for P7Z Phase 3."
                        ),
                        "disclaimer": (
                            "Not a political stability index. "
                            "Reflects institutional execution risk propagation only."
                        ),
                    }
                }
            },
        },
        503: {"description": "Release not active."},
    },
    openapi_extra={
        "x-osa-governance": {
            "package": "P7Z_Phase2",
            "source": "pub.v_isa_sovereign_fragility",
            "coverage": "P7Z_SIMULATION_READY pillars only (Phase 2)",
            "full_coverage": "Planned for P7Z Phase 3",
            "freeze_baseline": "P7K V3 — 2026-05-15",
            "disclaimer": (
                "Not a political stability index. "
                "Reflects institutional execution risk propagation."
            ),
        }
    },
)
async def get_sovereign_fragility(
    year: int = Query(default=None, description="Filter by year (2010–2024)."),
    db: Session = Depends(get_db),
):
    t0 = time.time()
    if year:
        rows = db.execute(text("""
            SELECT * FROM pub.v_isa_sovereign_fragility
            WHERE year = :year
            ORDER BY sovereign_fragility_index DESC NULLS LAST
        """), {"year": year}).mappings().all()
    else:
        rows = db.execute(text("""
            SELECT * FROM pub.v_isa_sovereign_fragility
            ORDER BY year DESC, sovereign_fragility_index DESC NULLS LAST
        """)).mappings().all()

    elapsed = round((time.time() - t0) * 1000, 2)
    await register_api_usage(
        "V2_SOVEREIGN_FRAGILITY", "/api/v2/predictive/fragility", "GET",
        "PUBLIC", 200, elapsed, len(rows)
    )
    return {
        "count": len(rows),
        "data": [dict(r) for r in rows],
        "methodology_note": (
            "In P7Z Phase 2, sovereign_fragility_index is computed on "
            "P7Z_SIMULATION_READY pillars only (PRES, PMON, PNUM, PTRA). "
            "Full national fragility coverage planned for P7Z Phase 3."
        ),
        "disclaimer": (
            "Not a political stability index. "
            "Reflects institutional execution risk propagation only. "
            "Governed by P7K V3 FROZEN baseline (2026-05-15)."
        ),
    }
