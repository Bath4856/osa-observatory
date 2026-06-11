"""
OSA Observatory -- Sprint 19
Router Open Data -- Couche 0 publique
CC-BY-NC-4.0 -- open.osa-observatory.org
"""

import time
import json
from decimal import Decimal
from fastapi import APIRouter, Depends, Query
from fastapi.responses import JSONResponse, Response
from sqlalchemy import text
from sqlalchemy.orm import Session
from typing import Optional
from api.db import get_db

router = APIRouter(
    prefix="/opendata",
    tags=["Open Data -- Couche 0 -- CC-BY-NC-4.0"],
)

_DISCLAIMER = (
    "OSA Observatory -- Observatoire de la Souverainete Africaine. "
    "Published under CC-BY-NC-4.0. "
    "Early-warning analytical tool -- not a legal or diplomatic qualification. "
    "Request institutional access at open.osa-observatory.org for full scores and analytics."
)

class _OSAEncoder(json.JSONEncoder):
    def default(self, o):
        if isinstance(o, Decimal):
            return float(o)
        return super().default(o)

def _wrap(data: list, dataset_code: str) -> Response:
    payload = {
        "dataset":    dataset_code,
        "license":    "CC-BY-NC-4.0",
        "access":     "Couche 0 -- Open Data -- CC-BY-NC-4.0",
        "disclaimer": _DISCLAIMER,
        "count":      len(data),
        "data":       data,
    }
    return Response(
        content=json.dumps(payload, ensure_ascii=False, cls=_OSAEncoder),
        media_type="application/json; charset=utf-8"
    )

def _rows(db: Session, sql: str, params: dict = None) -> list:
    result = db.execute(text(sql), params or {})
    return [dict(r) for r in result.mappings().all()]


# ── 1. Catalogue ──────────────────────────────────────────────
@router.get("/", summary="Catalogue datasets Open Data OSA")
async def get_catalog(db: Session = Depends(get_db)):
    """
    Catalogue complet des datasets Open Data OSA Observatory.

    Retourne la liste de tous les datasets disponibles en acces libre (CC-BY-NC-4.0),
    avec leur description, couverture geographique et temporelle.
    Licence : CC-BY-NC-4.0 — usage non commercial avec attribution obligatoire.
    """
    data = _rows(db, "SELECT * FROM pub.v_isa_open_data_catalog ORDER BY access_layer, dataset_code")
    return {"platform": "OSA Observatory Open Data", "license": "CC-BY-NC-4.0",
            "disclaimer": _DISCLAIMER, "datasets": data}


# ── 2. Etat souverain le plus recent ─────────────────────────
@router.get("/countries/latest", summary="Etat souverain le plus recent -- 54 pays")
async def get_countries_latest(
    db:       Session       = Depends(get_db),
    region:   Optional[str] = Query(default=None),
    momentum: Optional[str] = Query(default=None),
    amar_band: Optional[str] = Query(default=None),
):
    """
    Etat souverain le plus recent — 54 pays africains.

    Momentum souverain, alertes AMAR, piliers critiques/accelerants/progressants.
    Filtres optionnels :
    - region : AFC, AFS, AFE, AFN, AFW
    - momentum : POSITIVE_MOMENTUM, NEGATIVE_MOMENTUM, STABLE_MOMENTUM
    - amar_band : BLACK, RED, ORANGE, YELLOW, GREEN
    Licence : CC-BY-NC-4.0
    """
    data = _rows(db, """
        SELECT * FROM pub.mv_isa_country_latest
        WHERE (:region   IS NULL OR region_code          = :region)
          AND (:momentum IS NULL OR sovereign_momentum = :momentum)
          AND (:amar     IS NULL OR amar_risk_band        = :amar)
        ORDER BY nb_pillars_critical DESC, country_iso3
    """, {
        "region":   region.upper()   if region   else None,
        "momentum": momentum.upper() if momentum else None,
        "amar":     amar_band.upper() if amar_band else None,
    })
    return _wrap(data, "ISA_COUNTRY_LATEST")


@router.get("/countries/latest/{iso3}", summary="Etat souverain le plus recent -- un pays")
async def get_country_latest(iso3: str, db: Session = Depends(get_db)):
    """
    Etat souverain le plus recent pour un pays africain.

    Retourne le momentum souverain, les alertes AMAR, le nombre de piliers
    critiques/accelerants/progressants pour le pays specifie.

    Parametre : iso3 — code ISO 3166-1 alpha-3 (ex: GHA, SEN, ZAF)
    Licence : CC-BY-NC-4.0
    """
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
    """
    Historique directionnel souverain 2020-2024 — 54 pays africains.

    Direction annuelle, statut AMAR et statut de publication par pays et annee.
    Filtres optionnels :
    - direction : IMPROVING, DECLINING, STABLE, ACCELERATING, CRITICAL
    - year : 2020, 2021, 2022, 2023, 2024
    Statuts publication : OFFICIAL / CONSOLIDATED / PRELIMINARY / COLLECTING.
    Licence : CC-BY-NC-4.0
    """
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
    """
    Historique directionnel souverain 2020-2024 pour un pays.

    Retourne la direction annuelle (IMPROVING/DECLINING/STABLE), le statut AMAR
    et le statut de publication pour chaque annee disponible.

    Parametre : iso3 — code ISO 3166-1 alpha-3 (ex: GHA, SEN, ZAF)
    Licence : CC-BY-NC-4.0
    """
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
    """
    Trajectoires souveraines par pilier — 54 pays africains.

    Classe de trajectoire pour chacun des 10 piliers ISA par pays et annee.
    Filtres optionnels :
    - pillar : PECO, PENV, PGEO, PHUM, PMIL, PMIN, PMON, PNUM, PRES, PTRA
    - trajectory : CRITICAL, DECLINING, STABLE, PROGRESSING, ACCELERATING
    - year : 2020-2024
    Licence : CC-BY-NC-4.0
    """
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
    """
    Trajectoires souveraines par pilier pour un pays africain.

    Classe de trajectoire pour chacun des 10 piliers ISA du pays specifie.
    Parametre : iso3 — code ISO 3166-1 alpha-3 (ex: GHA, SEN, ZAF)
    Filtre optionnel par annee (2020-2024).
    Licence : CC-BY-NC-4.0
    """
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
    """
    Catalogue projets souverains structurants — 54 pays africains.

    Pour chaque pilier en deficit souverain, projets a fort impact souverain.
    Filtres optionnels :
    - opportunity_class : HIGH_IMPACT_OPPORTUNITY, SIGNIFICANT_OPPORTUNITY
    - pillar : PECO, PENV, PGEO, PHUM, PMIL, PMIN, PMON, PNUM, PRES, PTRA
    Note d'opportunite accessible librement. Faisabilite sur demande institutionnelle.
    Licence : CC-BY-NC-4.0
    """
    data = _rows(db, """
        SELECT * FROM pub.mv_isa_opportunity_catalog
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
    """
    Projets souverains structurants prioritaires pour un pays.

    Identifie les projets a fort impact pour chaque pilier en deficit souverain.
    Note d'opportunite accessible librement. Etude de faisabilite complete
    disponible sur demande institutionnelle.

    Parametre : iso3 — code ISO 3166-1 alpha-3 (ex: GHA, SEN, ZAF)
    Licence : CC-BY-NC-4.0
    """
    data = _rows(db, """
        SELECT * FROM pub.mv_isa_opportunity_catalog
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
    """
    Alertes AMAR (Africa Mass Atrocity Risk) — 54 pays, 2020-2024.

    Precurseurs comportementaux de risque d'atrocites de masse.
    Sources : ACLED, SIPRI, indicateurs de gouvernance ISA.
    Bandes : BLACK (critique) > RED > ORANGE > YELLOW > GREEN.
    Filtres optionnels :
    - risk_band : BLACK, RED, ORANGE, YELLOW, GREEN
    - year : 2020-2024
    Doctrine : observation pure — jamais une qualification diplomatique.
    Licence : CC-BY-NC-4.0
    """
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
    """
    Alertes AMAR pour un pays africain.

    Le moteur AMAR mesure les precurseurs comportementaux de risque d'atrocites
    de masse. Bandes : BLACK > RED > ORANGE > YELLOW > GREEN.
    Doctrine : observation comportementale pure — jamais une qualification diplomatique.

    Parametre : iso3 — code ISO 3166-1 alpha-3 (ex: GHA, SEN, ZAF)
    Licence : CC-BY-NC-4.0
    """
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
    """
    Trajectoires souveraines P7J et recommandations d'intervention — 54 pays.

    Classe de trajectoire, signal associe et famille d'intervention par pilier.
    Source : pub.mv_trajectories (vue materialisee — performance optimisee).
    Filtres optionnels :
    - trajectory_class : CRITICAL, DECLINING, STABLE, PROGRESSING, ACCELERATING
    - year : 2020-2024
    Licence : CC-BY-NC-4.0
    """
    data = _rows(db, """
        SELECT country_iso3, year, pillar_code,
               trajectory_class, trajectory_signal,
               intervention_family_label,
               country_sovereign_alert_level
        FROM pub.mv_trajectories
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
    """
    Trajectoires souveraines P7J pour un pays africain.

    Classe de trajectoire, signal et recommandation d'intervention pour
    chacun des 10 piliers ISA du pays specifie.
    Parametre : iso3 — code ISO 3166-1 alpha-3 (ex: GHA, SEN, ZAF)
    Filtre optionnel par annee (2020-2024).
    Licence : CC-BY-NC-4.0
    """
    data = _rows(db, """
        SELECT country_iso3, year, pillar_code,
               trajectory_class, trajectory_signal,
               intervention_family_label,
               country_sovereign_alert_level
        FROM pub.mv_trajectories
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
    """
    Documentation methodologique complete ISA v2.

    Retourne la description des 10 piliers, des indicateurs, des sources,
    de la methode d'imputation MICE et des regles de normalisation.
    Chaque indicateur ISA est une donnee primaire observable — jamais un sondage,
    jamais une estimation d'expert.
    Licence : CC-BY-NC-4.0
    """
    data = _rows(db, "SELECT * FROM pub.v_isa_public_methodology LIMIT 1")
    return {"dataset": "ISA_METHODOLOGY", "license": "CC-BY-NC-4.0",
            "access": "Couche 0 -- Open Data -- CC-BY-NC-4.0", "disclaimer": _DISCLAIMER, "data": data}


# ── Politique de publication ──────────────────────────────────────────────────
@router.get("/publication-policy", summary="Politique de publication OSA — cycle Y/Y-1")
async def get_publication_policy(db: Session = Depends(get_db)):
    """
    Cycle officiel de publication ISA OSA Observatory.

    Statuts :
    - COLLECTING   : collecte en cours — données non soumises au Comité Scientifique
    - PRELIMINARY  : collecte terminée — soumis au Comité Scientifique
    - CONSOLIDATED : validé Comité Scientifique — publié officiellement
    - OFFICIAL     : archivé — période de contestation close

    Calendrier (Y = année de publication) :
    - 2e semaine avril Y    : ouverture revue Comité Scientifique
    - 3e semaine juillet Y  : validation Comité Scientifique
    - 4e semaine août Y     : PV de validation disponible (déclencheur officiel)
    - 2e semaine septembre Y: publication officielle ISA Y-1

    Première publication institutionnelle OSA : septembre 2027
    Couvre Y-1=2026 + validation historique 2020-2025.
    """
    data = _rows(db, """
        SELECT year, publication_year, status,
               validated_at::text,
               published_at::text,
               committee_review_open::text,
               committee_validation::text,
               publication_target::text,
               pv_reference, notes
        FROM rf.publication_policy
        ORDER BY year DESC
    """)
    return _wrap(data, "OSA_PUBLICATION_POLICY")
