import time
from fastapi import APIRouter, Depends, Query
from sqlalchemy import text
from sqlalchemy.orm import Session

from api.db import get_db
from api.middleware.release_guard import validate_release_status
from api.middleware.telemetry import register_api_usage

# =============================================================================
# OSA ISA — P8 V2 Countries Router — enrichi documentation institutionnelle
# =============================================================================

_COUNTRIES_DESCRIPTION = """
Returns the latest ISA (Indice de Souveraineté Africaine) score for all
54 African countries, enriched with P7J decision class and P7Z fragility signals.

---

## Définition de l'ISA

L'**Indice de Souveraineté Africaine (ISA)** est un indice composite mesurant
le niveau de souveraineté institutionnelle d'un pays africain sur 10 piliers :

| Pilier | Domaine |
|--------|---------|
| PRES | Ressources — Énergie et eau certifiée |
| PMON | Monnaie — Résilience financière |
| PHUM | Capital humain |
| PECO | Diversification économique |
| PENV | Résilience environnementale |
| PMIL | Résilience sécuritaire |
| PMIN | Chaîne de valeur minière |
| PGEO | Gouvernance et stabilité |
| PNUM | Souveraineté numérique |
| PTRA | Transport et logistique |

`isa_observed_score ∈ [0, 1]` — calculé sur données 2010–2024.

---

## Enrichissement P7J et P7Z

Ce endpoint agrège trois couches analytiques :
- **Scores ISA observés** (P7A–P7E) — dernière année disponible
- **Décision pays P7J v2** — `country_decision_class`
- **Fragilité souveraine P7Z Phase 2** — `sovereign_fragility_class`, `avg_exec_probability`

---

## Avertissements

> ⚠️ `latest_year` peut varier par pays selon la disponibilité des données.
> La majorité des pays a `latest_year = 2024`.

> ⚠️ `avg_exec_probability` est la moyenne P7Z Phase 2 sur les 4 piliers
> `P7Z_SIMULATION_READY`. Elle ne couvre pas encore les 10 piliers.

---

## Gouvernance

- **Release** : P8V2_2026_CANDIDATE
- **Données** : 2010–2024 — 54 pays africains
- **Freeze** : P7K V3 FROZEN — 2026-05-15
"""

_HISTORY_DESCRIPTION = """
Returns the full ISA score history (2010–2024) for a single country,
enriched with P7J decision class.

---

## Usage institutionnel

Ce endpoint est conçu pour :
- l'analyse des tendances souveraines sur 15 ans,
- la comparaison intersectorielle des dynamiques ISA,
- la préparation de rapports institutionnels pays.

---

## Avertissements

> ⚠️ Les données antérieures à 2015 peuvent avoir une couverture d'indicateurs
> plus limitée. Consulter `data_completeness` dans les métadonnées sources
> pour évaluer la fiabilité par année.
"""

_PILLARS_DESCRIPTION = """
Returns pillar-level ISA scores for a single country, enriched with
P7Z Phase 2 convergence signals.

---

## Définition des scores piliers

Chaque pilier expose :
- `isa_observed_score` — score ISA observé du pilier
- `sovereignty_observed_score` — composante souveraineté
- `vulnerability_observed_score` — composante vulnérabilité
- `resilience_observed_score` — composante résilience
- `avg_exec_probability` — probabilité d'exécution P7Z moyennée sur les interventions
- `convergence_class` — classe de convergence vers le seuil prédictif

---

## Gouvernance

- **Source piliers** : `ma.v_isa_observed_scores_by_pillar`
- **Enrichissement P7Z** : `ma.mv_isa_p7z_execution_probability` (agrégé)
- **Freeze** : P7K V3 — 2026-05-15
"""

router = APIRouter(prefix="/api/v2/countries", tags=["P8 Countries — ISA Scores"])
ENDPOINT_ACCESS = "PUBLIC"


@router.get(
    "",
    summary="Latest ISA scores — all 54 African countries",
    description=_COUNTRIES_DESCRIPTION,
    responses={
        200: {
            "description": "Latest ISA scores with P7J decision and P7Z fragility.",
            "content": {
                "application/json": {
                    "example": {
                        "count": 54,
                        "data": [
                            {
                                "country_iso3": "ZMB",
                                "latest_year": 2024,
                                "isa_observed_score": 0.694,
                                "sovereignty_observed_score": 0.715,
                                "vulnerability_observed_score": 0.731,
                                "resilience_observed_score": 0.621,
                                "country_decision_class": "COUNTRY_DECISION_STANDARD",
                                "country_decision_priority_score": 0.361,
                                "sovereign_fragility_class": "SOVEREIGN_RESILIENT",
                                "p7z_national_status": "P7Z_NATIONAL_STABLE",
                                "sovereign_fragility_index": 0.012,
                                "avg_exec_probability": 0.649,
                            }
                        ],
                        "release": "P8V2_2026_CANDIDATE",
                        "data_period": "2010–2024",
                        "disclaimer": (
                            "ISA scores are analytical indicators. "
                            "They do not constitute official national statistics."
                        ),
                    }
                }
            },
        },
        503: {"description": "Release not active."},
    },
    openapi_extra={
        "x-osa-governance": {
            "package": "P8V2",
            "source": "pub.v_isa_country_latest",
            "enrichment": ["P7J_v2", "P7Z_Phase2"],
            "freeze_baseline": "P7K V3 — 2026-05-15",
            "disclaimer": (
                "ISA scores are analytical indicators, "
                "not official national statistics."
            ),
        }
    },
)
async def get_latest_countries(db: Session = Depends(get_db)):
    t0 = time.time()
    validate_release_status()
    rows = db.execute(text("""
        SELECT * FROM pub.v_isa_country_latest
        ORDER BY isa_observed_score DESC NULLS LAST
    """)).mappings().all()
    elapsed = round((time.time() - t0) * 1000, 2)
    await register_api_usage(
        "V2_COUNTRIES_LIST", "/api/v2/countries", "GET",
        ENDPOINT_ACCESS, 200, elapsed, len(rows)
    )
    return {
        "count": len(rows),
        "data": [dict(r) for r in rows],
        "release": "P8V2_2026_CANDIDATE",
        "data_period": "2010–2024",
        "disclaimer": (
            "ISA scores are analytical indicators. "
            "They do not constitute official national statistics."
        ),
    }


@router.get(
    "/{iso3}",
    summary="Country profile — latest ISA score",
    description=_COUNTRIES_DESCRIPTION,
    openapi_extra={"x-osa-governance": {"source": "pub.v_isa_country_latest"}},
)
async def get_country_profile(iso3: str, db: Session = Depends(get_db)):
    t0 = time.time()
    validate_release_status()
    rows = db.execute(text("""
        SELECT * FROM pub.v_isa_country_latest
        WHERE country_iso3 = :iso3
    """), {"iso3": iso3.upper()}).mappings().all()
    elapsed = round((time.time() - t0) * 1000, 2)
    await register_api_usage(
        "V2_COUNTRY_PROFILE", f"/api/v2/countries/{iso3}", "GET",
        ENDPOINT_ACCESS, 200, elapsed, len(rows)
    )
    return {"count": len(rows), "data": [dict(r) for r in rows]}


@router.get(
    "/{iso3}/history",
    summary="Country ISA score history (2010–2024)",
    description=_HISTORY_DESCRIPTION,
    responses={
        200: {
            "description": "Full ISA score history for a single country.",
            "content": {
                "application/json": {
                    "example": {
                        "count": 15,
                        "data": [
                            {
                                "country_iso3": "MAR",
                                "year": 2024,
                                "isa_observed_score": 0.650,
                                "sovereignty_observed_score": 0.672,
                                "vulnerability_observed_score": 0.688,
                                "resilience_observed_score": 0.590,
                                "country_decision_class": "COUNTRY_DECISION_STANDARD",
                            }
                        ],
                    }
                }
            },
        }
    },
    openapi_extra={"x-osa-governance": {"source": "pub.v_isa_country_history"}},
)
async def get_country_history(iso3: str, db: Session = Depends(get_db)):
    t0 = time.time()
    validate_release_status()
    rows = db.execute(text("""
        SELECT * FROM pub.v_isa_country_history
        WHERE country_iso3 = :iso3
        ORDER BY year
    """), {"iso3": iso3.upper()}).mappings().all()
    elapsed = round((time.time() - t0) * 1000, 2)
    await register_api_usage(
        "V2_COUNTRY_HISTORY", f"/api/v2/countries/{iso3}/history", "GET",
        ENDPOINT_ACCESS, 200, elapsed, len(rows)
    )
    return {"count": len(rows), "data": [dict(r) for r in rows]}


@router.get(
    "/{iso3}/pillars",
    summary="Country pillar breakdown — ISA scores + P7Z convergence",
    description=_PILLARS_DESCRIPTION,
    openapi_extra={
        "x-osa-governance": {
            "source": "pub.v_isa_pillar_breakdown",
            "enrichment": "P7Z_Phase2",
        }
    },
)
async def get_country_pillars(
    iso3: str,
    year: int = Query(default=None, description="Filter by year (2010–2024)."),
    db: Session = Depends(get_db),
):
    t0 = time.time()
    validate_release_status()
    if year:
        rows = db.execute(text("""
            SELECT * FROM pub.v_isa_pillar_breakdown
            WHERE country_iso3 = :iso3 AND year = :year
            ORDER BY pillar_code
        """), {"iso3": iso3.upper(), "year": year}).mappings().all()
    else:
        rows = db.execute(text("""
            SELECT * FROM pub.v_isa_pillar_breakdown
            WHERE country_iso3 = :iso3
            ORDER BY year DESC, pillar_code
        """), {"iso3": iso3.upper()}).mappings().all()
    elapsed = round((time.time() - t0) * 1000, 2)
    await register_api_usage(
        "V2_COUNTRY_PILLARS", f"/api/v2/countries/{iso3}/pillars", "GET",
        ENDPOINT_ACCESS, 200, elapsed, len(rows)
    )
    return {"count": len(rows), "data": [dict(r) for r in rows]}
