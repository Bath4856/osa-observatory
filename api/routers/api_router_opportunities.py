import time
from fastapi import APIRouter, Depends, Query
from sqlalchemy import text
from sqlalchemy.orm import Session

from api.db import get_db
from api.middleware.telemetry import register_api_usage

# =============================================================================
# OSA ISA — P8 V2 Opportunities Router
# Enrichi avec documentation institutionnelle, méthodologique et de gouvernance
# =============================================================================

_OPPORTUNITY_DESCRIPTION = """
Returns sovereign intervention opportunities enriched with P7Z Phase 2
execution probability scores.

---

## Définition institutionnelle

Une **"opportunity" ISA/P7Z** n'est **pas** :
- une recommandation politique automatique,
- une décision d'investissement,
- une prévision certaine ou une garantie d'exécution.

C'est un **signal probabiliste souverain**, issu de la convergence entre :
- les scores ISA observés (P7A–P7E),
- la dynamique sectorielle par pilier,
- la faisabilité d'exécution institutionnelle (P7K V3 FROZEN),
- la convergence prédictive P7Z Phase 2,
- la fragilité souveraine nationale,
- la pression décisionnelle P7J.

---

## execution_probability — définition scientifique

`execution_probability` est un **score composite calibré** dans l'intervalle `[0, 1]`.

**Ce n'est pas une probabilité statistique classique.**
C'est une mesure de convergence souveraine multi-facteurs pondérée par
`calibration_uncertainty_score` issu du cost model P7K V3.

| Classe | Signification institutionnelle |
|--------|-------------------------------|
| `HIGH_PROBABILITY` (≥ 0.60) | Forte convergence systémique — conditions d'exécution favorables |
| `MEDIUM_PROBABILITY` (≥ 0.40) | Faisabilité plausible — conditions partiellement réunies |
| `LOW_PROBABILITY` (≥ 0.20) | Blocages structurels identifiés — support institutionnel requis |
| `VERY_LOW_PROBABILITY` (< 0.20) | Risque élevé d'échec d'exécution — révision requise |

---

## Politique de filtrage par défaut

Par défaut (`min_prob = 0.40`), seules les classes `HIGH_PROBABILITY` et
`MEDIUM_PROBABILITY` sont exposées publiquement.

Les classes `LOW_PROBABILITY` et `VERY_LOW_PROBABILITY` sont exclues par défaut
afin d'**éviter la surinterprétation d'interventions structurellement instables**
ou insuffisamment calibrées dans le cost model P7K.

Ce seuil est configurable via le paramètre `min_prob`.

---

## Dépendances méthodologiques

| Package | Version | Rôle |
|---------|---------|------|
| P7J | v2 ACTIVE | Matrice décisionnelle — decision_priority_class |
| P7K | V3 FROZEN | Gouvernance exécutive — cost model calibré |
| P7Z | Phase 2 ACTIVE | Simulation et convergence probabiliste |
| MG | V1 ACTIVE | Calibration, freeze, lineage, audit |
| P8 | V2 CANDIDATE | Publication et gouvernance API |

---

## Gouvernance scientifique

Tous les scores exposés par ce endpoint sont gouvernés par :
- **freeze baseline** : `mg.isa_package_freeze_registry` (P7K V3 FROZEN)
- **lineage** : `mg.isa_view_lineage_registry` (22 dépendances documentées)
- **calibration_status** : PROVISIONAL / VALIDATED / REVIEW_REQUIRED
- **calibration_uncertainty_score** : [0.15 – 0.25] selon la source proxy
- **calibration_review_due_date** : révision obligatoire avant 2027-05-15

Toute révision du cost model P7K est tracée dans `rf.isa_cost_model_audit_log`
via le trigger `trg_cost_model_audit`.

---

## Avertissements méthodologiques

> ⚠️ Les scores `execution_probability` reflètent l'état de la calibration
> au moment du freeze P7K V3 (2026-05-15). Ils ne tiennent pas compte
> d'événements postérieurs à cette date.

> ⚠️ `p7z_eligibility_class = P7Z_SIMULATION_PARTIAL` indique que seuls
> les modules de convergence et de fragilité ont été activés.
> La projection ISA complète n'est disponible qu'en `P7Z_SIMULATION_READY`.

> ⚠️ `confidence_interval` = `calibration_uncertainty_score × 0.25`.
> Une valeur avec `uncertainty = 0.25` implique un intervalle de confiance
> de ±0.0625 autour du score affiché.

---

## Statut de publication

Release : **P8V2_2026_CANDIDATE** — version 2.0.0-candidate  
Accès : **PUBLIC_LIMITED**  
Données : 2010–2024 — 54 pays africains — 10 piliers ISA
"""

_METHODOLOGY_DESCRIPTION = """
Returns the public methodology metadata and active packages for the current
P8 V2 release.

---

## Contenu

Ce endpoint expose :
- les métadonnées de la release courante (`mg.release_registry`)
- les packages analytiques actifs dans la chaîne OSA/ISA
- la version méthodologique et la période de données couverte

---

## Chaîne analytique OSA/ISA

| Package | Statut | Rôle |
|---------|--------|------|
| P7G | ACTIVE | Forecast Trend Intelligence |
| P7I | ACTIVE | Early Warning Risk Engine |
| P7J | ACTIVE | Decision Intelligence |
| P7K | FROZEN | Executive Governance — baseline calibrée |
| P7Z | ACTIVE | Predictive Sovereign Intelligence (Phase 1 + 2) |
| P8 | ACTIVE_CANDIDATE | Institutional Public Observatory |

---

## Gouvernance des releases

Les releases sont versionnées sémantiquement (SemVer).
La release `ACTIVE_CANDIDATE` est en validation parallèle avec `P8OPS` (LEGACY_ACTIVE).
La promotion vers `ACTIVE_RELEASE` interviendra après validation complète
des 14 endpoints et du dry run institutionnel.
"""


opportunities_router = APIRouter(
    prefix="/api/v2/opportunities",
    tags=["P8 Opportunities"]
)

methodology_router = APIRouter(
    prefix="/api/v2/methodology",
    tags=["P8 Methodology"]
)


@opportunities_router.get(
    "",
    summary="Sovereign intervention opportunities — P7Z enriched",
    description=_OPPORTUNITY_DESCRIPTION,
    responses={
        200: {
            "description": "List of sovereign intervention opportunities with P7Z execution signals.",
            "content": {
                "application/json": {
                    "example": {
                        "count": 3,
                        "data": [
                            {
                                "country_iso3": "MAR",
                                "year": 2024,
                                "pillar_code": "PRES",
                                "intervention_family_code": "ENERGY_WATER_CERTIFICATION",
                                "intervention_family_label": "Energy and Water Certification",
                                "strategic_objective": "Strengthen energy sovereignty",
                                "recommended_action": "Accelerate certified energy access",
                                "candidate_intervention_status": "PRIORITY_CANDIDATE",
                                "execution_probability": 0.689,
                                "execution_probability_class": "HIGH_PROBABILITY",
                                "p7z_eligibility_class": "P7Z_SIMULATION_READY",
                                "estimated_convergence_years": 1.3,
                                "probability_confidence_interval": 0.038,
                            }
                        ],
                        "methodology_note": (
                            "execution_probability is a calibrated sovereign convergence score, "
                            "not a classical statistical probability. "
                            "Governed by P7K V3 FROZEN cost model and P7Z Phase 2 engine. "
                            "Default filter: HIGH_PROBABILITY and MEDIUM_PROBABILITY only."
                        ),
                        "release": "P8V2_2026_CANDIDATE",
                        "disclaimer": (
                            "This data is provided for analytical and institutional purposes only. "
                            "It does not constitute a policy recommendation or investment decision."
                        ),
                    }
                }
            },
        },
        422: {"description": "Validation error — invalid query parameters."},
        503: {"description": "Release not active — API temporarily unavailable."},
    },
    openapi_extra={
        "x-osa-governance": {
            "package": "P8V2",
            "release": "P8V2_2026_CANDIDATE",
            "methodology_version": "ISA_DEV_P8V2",
            "data_period": "2010–2024",
            "source_packages": ["P7J_v2", "P7K_V3_FROZEN", "P7Z_Phase2"],
            "calibration_status": "PROVISIONAL",
            "uncertainty_policy": "uncertainty_score × 0.25 = confidence_interval",
            "freeze_baseline": "P7K V3 — 2026-05-15",
            "audit_trail": "rf.isa_cost_model_audit_log + mg.api_usage_registry",
            "disclaimer": "Not a policy recommendation. Not a statistical certainty.",
        }
    },
)
async def get_opportunities(
    iso3: str = Query(
        default=None,
        description="ISO3 country code (e.g. MAR, KEN, ZMB). Optional filter.",
    ),
    pillar: str = Query(
        default=None,
        description=(
            "Pillar code filter. One of: PRES, PMON, PNUM, PTRA, PHUM, "
            "PECO, PENV, PMIL, PMIN, PGEO."
        ),
    ),
    min_prob: float = Query(
        default=0.40,
        ge=0.0,
        le=1.0,
        description=(
            "Minimum execution_probability threshold [0–1]. Default: 0.40. "
            "Values below 0.40 (LOW_PROBABILITY and VERY_LOW_PROBABILITY) are hidden "
            "by default to prevent misinterpretation of structurally unstable interventions."
        ),
    ),
    db: Session = Depends(get_db),
):
    t0 = time.time()

    base = """
        SELECT *
        FROM pub.v_isa_opportunity_catalog
        WHERE (execution_probability >= :min_prob OR execution_probability IS NULL)
    """
    params: dict = {"min_prob": min_prob}

    if iso3:
        base += " AND country_iso3 = :iso3"
        params["iso3"] = iso3.upper()
    if pillar:
        base += " AND pillar_code = :pillar"
        params["pillar"] = pillar.upper()

    base += " ORDER BY execution_probability DESC NULLS LAST LIMIT 500"

    rows = db.execute(text(base), params).mappings().all()

    elapsed = round((time.time() - t0) * 1000, 2)
    await register_api_usage(
        "V2_OPPORTUNITIES", "/api/v2/opportunities", "GET",
        "PUBLIC_LIMITED", 200, elapsed, len(rows)
    )

    return {
        "count": len(rows),
        "data": [dict(r) for r in rows],
        "methodology_note": (
            "execution_probability is a calibrated sovereign convergence score, "
            "not a classical statistical probability. "
            "Governed by P7K V3 FROZEN cost model and P7Z Phase 2 engine. "
            f"Current filter: min_prob={min_prob} "
            "(LOW_PROBABILITY and VERY_LOW_PROBABILITY excluded by default)."
        ),
        "release": "P8V2_2026_CANDIDATE",
        "disclaimer": (
            "This data is provided for analytical and institutional purposes only. "
            "It does not constitute a policy recommendation or investment decision. "
            "Scores reflect the state of P7K V3 calibration at freeze date 2026-05-15."
        ),
    }


@methodology_router.get(
    "",
    summary="Public methodology — OSA/ISA analytical chain",
    description=_METHODOLOGY_DESCRIPTION,
    responses={
        200: {
            "description": "Public methodology metadata and active packages.",
            "content": {
                "application/json": {
                    "example": {
                        "count": 6,
                        "data": [
                            {
                                "release_code": "P8V2_2026_CANDIDATE",
                                "semantic_version": "2.0.0-candidate",
                                "methodology_version": "ISA_DEV_P8V2",
                                "data_period_start": 2010,
                                "data_period_end": 2024,
                                "package_code": "P7K",
                                "package_label": "Executive Governance Layer V3",
                                "package_status": "FROZEN",
                            }
                        ],
                    }
                }
            },
        },
        503: {"description": "Release not active."},
    },
    openapi_extra={
        "x-osa-governance": {
            "package": "P8V2",
            "release": "P8V2_2026_CANDIDATE",
            "access_class": "PUBLIC",
            "audit_trail": "mg.api_usage_registry",
        }
    },
)
async def get_methodology(db: Session = Depends(get_db)):
    t0 = time.time()

    rows = db.execute(text("""
        SELECT * FROM pub.v_isa_public_methodology
        ORDER BY package_code
    """)).mappings().all()

    elapsed = round((time.time() - t0) * 1000, 2)
    await register_api_usage(
        "V2_METHODOLOGY", "/api/v2/methodology", "GET",
        "PUBLIC", 200, elapsed, len(rows)
    )
    return {"count": len(rows), "data": [dict(r) for r in rows]}
