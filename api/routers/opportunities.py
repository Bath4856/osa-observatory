import time
from fastapi import APIRouter, Depends, Query
from sqlalchemy import text
from sqlalchemy.orm import Session

from api.db import get_db
from api.middleware.telemetry import register_api_usage

# ── Opportunities ─────────────────────────────────────────────────────────────
opportunities_router = APIRouter(
    prefix="/api/v2/opportunities",
    tags=["Opportunities"]
)


@opportunities_router.get(
    "",
    summary="Opportunity catalog (PUBLIC_LIMITED)",
    description="Returns sovereign intervention opportunities enriched with P7Z execution probability. "
                "Filtered to HIGH_PROBABILITY and MEDIUM_PROBABILITY by default.",
)
async def get_opportunities(
    iso3: str = Query(default=None, description="Filter by ISO3 country code"),
    pillar: str = Query(default=None, description="Filter by pillar code"),
    db: Session = Depends(get_db),
):
    t0 = time.time()

    base = """
        SELECT country_iso3, year, pillar_code,
               intervention_family_code, intervention_family_label,
               strategic_objective, consultation_theme,
               opportunity_class, delta_potential_label,
               trajectory_class, intervention_priority_class,
               intervention_priority_score, region_code, region_label,
               feasibility_call, source
        FROM pub.mv_isa_opportunity_catalog
        WHERE 1=1
    """
    params: dict = {}

    if iso3:
        base += " AND country_iso3 = :iso3"
        params["iso3"] = iso3.upper()
    if pillar:
        base += " AND pillar_code = :pillar"
        params["pillar"] = pillar.upper()

    base += " ORDER BY intervention_priority_score DESC NULLS LAST LIMIT 500"

    rows = db.execute(text(base), params).mappings().all()

    elapsed = round((time.time() - t0) * 1000, 2)
    await register_api_usage(
        "V2_OPPORTUNITIES", "/api/v2/opportunities", "GET",
        "PUBLIC_LIMITED", 200, elapsed, len(rows)
    )
    return {"count": len(rows), "data": [dict(r) for r in rows]}


# ── Methodology ───────────────────────────────────────────────────────────────
methodology_router = APIRouter(
    prefix="/api/v2/methodology",
    tags=["Methodology"]
)


@methodology_router.get(
    "",
    summary="Public methodology",
    description="Returns public methodology metadata and active packages.",
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

# ── Sovereign Projects ────────────────────────────────────────────────────────
from fastapi.responses import Response
import json

sovereign_router = APIRouter(
    prefix="/api/v2/sovereign-projects",
    tags=["Sovereign Projects"]
)

def _json(data) -> Response:
    return Response(
        content=json.dumps(data, ensure_ascii=False, default=str),
        media_type="application/json; charset=utf-8"
    )

@sovereign_router.get(
    "",
    summary="Catalogue projets souverains -- PUBLIC",
    description="Catalogue des projets structurants souverains par pilier. "
                "Filtrable par pilier, pays ou classe d opportunite. "
                "Croise avec les opportunites ISA P7J."
)
async def get_sovereign_projects(
    pillar:  str = Query(default=None, description="Code pilier (ex: PMIN, PECO)"),
    iso3:    str = Query(default=None, description="ISO3 pays (projets specifiques ou generiques)"),
    status:  str = Query(default=None, description="Statut projet (CONCEPT/FEASIBILITY/ACTIVE)"),
    lang:    str = Query(default="en", description="Langue des contenus : en (defaut) ou fr"),
    db: Session = Depends(get_db),
):
    t0 = time.time()
    rows = db.execute(text("""
        SELECT
            sp.project_code, sp.project_acronym,
            COALESCE(
                CASE WHEN :lang = 'fr' THEN sp.project_name_fr ELSE sp.project_name_en END,
                sp.project_name
            ) AS project_name,
            sp.pillar_code, sp.country_iso3,
            COALESCE(
                CASE WHEN :lang = 'fr' THEN sp.project_description_fr ELSE sp.project_description_en END,
                sp.project_description
            ) AS project_description,
            COALESCE(
                CASE WHEN :lang = 'fr' THEN sp.strategic_objective_fr ELSE sp.strategic_objective_en END,
                sp.strategic_objective
            ) AS strategic_objective,
            COALESCE(
                CASE WHEN :lang = 'fr' THEN sp.deliverable_public_fr ELSE sp.deliverable_public_en END,
                sp.deliverable_public
            ) AS deliverable_public,
            sp.opportunity_class,
            sp.priority_score, sp.status, sp.tags,
            COALESCE(CASE WHEN :lang = 'fr' THEN spc.project_family_label_fr ELSE spc.project_family_label_en END, spc.project_family_label) AS project_family_label,
            spc.strategic_objective AS family_objective,
            -- Enrichissement ISA : score opportunité du pays/pilier
            opp.trajectory_class, opp.intervention_priority_class,
            opp.intervention_priority_score, opp.delta_potential_label,
            opp.region_code, opp.region_label
        FROM rf.sovereign_project_catalog sp
        JOIN rf.structuring_project_catalog spc
            ON spc.project_family_code = sp.project_family_code
        LEFT JOIN pub.mv_isa_opportunity_catalog opp
            ON opp.pillar_code = sp.pillar_code
            AND (sp.country_iso3 IS NULL OR opp.country_iso3 = sp.country_iso3)
            AND opp.opportunity_class IN ('HIGH_IMPACT_OPPORTUNITY','SIGNIFICANT_OPPORTUNITY')
        WHERE sp.is_active = true
          AND (:pillar IS NULL OR sp.pillar_code = :pillar)
          AND (:iso3   IS NULL OR sp.country_iso3 = :iso3 OR sp.country_iso3 IS NULL)
          AND (:status IS NULL OR sp.status = :status)
        ORDER BY sp.priority_score DESC, sp.pillar_code
        LIMIT 200
    """), {
        "pillar": pillar.upper() if pillar else None,
        "iso3":   iso3.upper()   if iso3   else None,
        "status": status.upper() if status else None,
        "lang":   lang.lower()   if lang   else "en",
    }).mappings().all()

    elapsed = round((time.time() - t0) * 1000, 2)
    await register_api_usage(
        "V2_SOVEREIGN_PROJECTS", "/api/v2/sovereign-projects", "GET",
        "PUBLIC", 200, elapsed, len(rows)
    )
    return _json({"count": len(rows), "elapsed_ms": elapsed, "data": [dict(r) for r in rows]})


@sovereign_router.get(
    "/country/{iso3}",
    summary="Projets souverains prioritaires par pays -- PUBLIC",
    description="Retourne les projets souverains prioritaires pour un pays donné, "
                "croisés avec les scores ISA réels du pays."
)
async def get_country_sovereign_projects(
    iso3: str,
    lang: str = Query(default="en", description="Langue des contenus : en (defaut) ou fr"),
    db: Session = Depends(get_db),
):
    t0 = time.time()
    rows = db.execute(text("""
        SELECT
            sp.project_code, sp.project_acronym,
            COALESCE(
                CASE WHEN :lang = 'fr' THEN sp.project_name_fr ELSE sp.project_name_en END,
                sp.project_name
            ) AS project_name,
            sp.pillar_code,
            COALESCE(
                CASE WHEN :lang = 'fr' THEN sp.project_description_fr ELSE sp.project_description_en END,
                sp.project_description
            ) AS project_description,
            COALESCE(
                CASE WHEN :lang = 'fr' THEN sp.strategic_objective_fr ELSE sp.strategic_objective_en END,
                sp.strategic_objective
            ) AS strategic_objective,
            sp.deliverable_public, sp.opportunity_class,
            sp.priority_score, sp.status, sp.tags,
            COALESCE(CASE WHEN :lang = 'fr' THEN spc.project_family_label_fr ELSE spc.project_family_label_en END, spc.project_family_label) AS project_family_label,
            opp.trajectory_class, opp.intervention_priority_class,
            opp.intervention_priority_score, opp.delta_potential_label,
            opp.region_code, opp.region_label,
            cs.isa_observed_score, cs.data_confidence
        FROM rf.sovereign_project_catalog sp
        JOIN rf.structuring_project_catalog spc
            ON spc.project_family_code = sp.project_family_code
        LEFT JOIN pub.mv_isa_opportunity_catalog opp
            ON opp.pillar_code    = sp.pillar_code
            AND opp.country_iso3  = :iso3
        LEFT JOIN pub.mv_isa_country_scores cs
            ON cs.country_iso3    = :iso3
            AND cs.year           = opp.year
        WHERE sp.is_active = true
          AND (sp.country_iso3 = :iso3 OR sp.country_iso3 IS NULL)
        ORDER BY sp.priority_score DESC, opp.intervention_priority_score DESC NULLS LAST
    """), {"iso3": iso3.upper(), "lang": lang.lower() if lang else "en"}).mappings().all()

    elapsed = round((time.time() - t0) * 1000, 2)
    await register_api_usage(
        "V2_SOVEREIGN_PROJECTS_COUNTRY", f"/api/v2/sovereign-projects/country/{iso3}", "GET",
        "PUBLIC", 200, elapsed, len(rows)
    )
    return _json({
        "country_iso3": iso3.upper(),
        "count": len(rows),
        "elapsed_ms": elapsed,
        "data": [dict(r) for r in rows]
    })


@sovereign_router.get(
    "/recommendation/{iso3}/{pillar}",
    summary="Recommandation stratégique pilier -- PUBLIC",
    description="Diagnostic stratégique (rôle SWOT) et projet structurant recommandé pour un pays "
                "et un pilier donnés. Doctrine : aucun score numérique n'est exposé au public -- "
                "les scores servent uniquement au tri interne (ORDER BY), jamais à l'affichage. "
                "Le projet recommandé n'a pas d'impact ISA calculé ; il est propose parce que "
                "l'analyse stratégique identifie une pertinence sur ce pilier (swot_strategic_role)."
)
async def get_pillar_recommendation(
    iso3: str,
    pillar: str,
    lang: str = Query(default="en", description="Langue des contenus : en (defaut) ou fr"),
    db: Session = Depends(get_db),
):
    t0 = time.time()
    lang_norm = lang.lower() if lang else "en"

    diagnosis = db.execute(text("""
        SELECT
            country_iso3, year, pillar_code,
            swot_strategic_role, strategic_recommendation_action,
            project_orientation, strategic_objective,
            open_data_deliverable, recommendation_evidence_status
        FROM ma.mv_isa_project_opportunity_catalog
        WHERE country_iso3 = :iso3 AND pillar_code = :pillar
        ORDER BY year DESC
        LIMIT 1
    """), {"iso3": iso3.upper(), "pillar": pillar.upper()}).mappings().first()

    project = db.execute(text("""
        SELECT
            sp.project_code, sp.project_acronym,
            COALESCE(
                CASE WHEN :lang = 'fr' THEN sp.project_name_fr ELSE sp.project_name_en END,
                sp.project_name
            ) AS project_name,
            COALESCE(
                CASE WHEN :lang = 'fr' THEN sp.project_description_fr ELSE sp.project_description_en END,
                sp.project_description
            ) AS project_description,
            COALESCE(
                CASE WHEN :lang = 'fr' THEN sp.deliverable_public_fr ELSE sp.deliverable_public_en END,
                sp.deliverable_public
            ) AS deliverable_public,
            sp.status
        FROM rf.sovereign_project_catalog sp
        WHERE sp.is_active = true
          AND sp.pillar_code = :pillar
          AND (sp.country_iso3 = :iso3 OR sp.country_iso3 IS NULL)
        ORDER BY sp.priority_score DESC
        LIMIT 1
    """), {"pillar": pillar.upper(), "iso3": iso3.upper(), "lang": lang_norm}).mappings().first()

    elapsed = round((time.time() - t0) * 1000, 2)
    await register_api_usage(
        "V2_PILLAR_RECOMMENDATION", f"/api/v2/sovereign-projects/recommendation/{iso3}/{pillar}", "GET",
        "PUBLIC", 200, elapsed, 1 if project else 0
    )
    return _json({
        "country_iso3": iso3.upper(),
        "pillar_code": pillar.upper(),
        "diagnosis": dict(diagnosis) if diagnosis else None,
        "recommended_project": dict(project) if project else None,
        "elapsed_ms": elapsed,
    })
