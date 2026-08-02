"""
OSA Observatory -- OIM, vision stratégique annuelle
api/routers/oim_vision.py

Endpoints pour mg.pillar_strategic_vision : creer une vision
(pays+pilier+annee), y rattacher des analyses (les 10 memes methodes
que osoa.py) et generer les 3 livrables qui la composent :
ETUDE_OPPORTUNITE (reutilisee comme "Vision", decision de Theo du
28 juillet 2026), SCHEMA_DIRECTEUR, PLAN_ACTION.

Reutilise les modeles Pydantic et la logique de construction de
livrables deja definis dans osoa.py (METHOD_MODELS, VALID_METHODS,
DELIVERABLE_REQUIRED_METHODS, DELIVERABLE_BUILDERS) -- pas de
duplication des 9-10 methodes d'analyse.

Ajout du 28 juillet 2026 (nouvelle session) : explosion d'un
PLAN_ACTION en projets nommes (mg.plan_action_projects), meme patron
double fournisseur IA (AI_SUMMARY_PROVIDER) que le resume executif
Vision -- IA propose, humain valide, puis promotion en vrai projet
du catalogue (rf.sovereign_project_catalog, doctrinal_status=OIM_GENERATED).
"""
import json
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import text
from pydantic import BaseModel, Field

from api.db import get_db
from api.routers.auth_affiliates import get_current_affiliate
from api.routers.osoa import (
    METHOD_MODELS,
    VALID_METHODS,
    DELIVERABLE_REQUIRED_METHODS,
    DELIVERABLE_BUILDERS,
)

router = APIRouter(
    prefix="/api/v2/oim",
    tags=["OIM - Vision stratégique"],
)


def _validate_pillar_code(db: Session, pillar_code: str):
    row = db.execute(
        text("SELECT pillar_code FROM mg.working_groups WHERE pillar_code = :code"),
        {"code": pillar_code},
    ).mappings().first()
    if not row:
        raise HTTPException(status_code=422, detail={
            "fr": f"pillar_code '{pillar_code}' introuvable dans mg.working_groups.",
            "en": f"pillar_code '{pillar_code}' not found in mg.working_groups.",
        })


# ── Vision (mg.pillar_strategic_vision) ─────────────────────────────────────────

class VisionCreate(BaseModel):
    country_iso3: str = Field(..., min_length=3, max_length=3)
    pillar_code: str
    year: int
    status: str = Field("DRAFT", description="DRAFT, VALIDATED ou ARCHIVED")


@router.post(
    "/visions",
    summary="Créer une vision stratégique OIM (pays+pilier+année)",
    description="Une seule vision par (pays, pilier, année) -- contrainte d'unicité en base.",
)
def create_vision(
    data: VisionCreate,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    affiliate_id = int(payload["sub"])
    _validate_pillar_code(db, data.pillar_code)
    if data.status not in ("DRAFT", "VALIDATED", "ARCHIVED"):
        raise HTTPException(status_code=422, detail={
            "fr": "status doit être DRAFT, VALIDATED ou ARCHIVED.",
            "en": "status must be DRAFT, VALIDATED or ARCHIVED.",
        })
    try:
        row = db.execute(
            text("""
                INSERT INTO mg.pillar_strategic_vision (country_iso3, pillar_code, year, status, created_by)
                VALUES (:country_iso3, :pillar_code, :year, :status, :created_by)
                RETURNING id, country_iso3, pillar_code, year, status, created_at::text, updated_at::text
            """),
            {
                "country_iso3": data.country_iso3.upper(),
                "pillar_code": data.pillar_code,
                "year": data.year,
                "status": data.status,
                "created_by": affiliate_id,
            },
        ).mappings().first()
        db.commit()
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=409, detail={
            "fr": f"Erreur à la création (déjà existante pour ce pays/pilier/année ?) : {e}",
            "en": f"Creation error (already exists for this country/pillar/year?): {e}",
        })
    return dict(row)


@router.get("/visions", summary="Lister les visions stratégiques")
def list_visions(
    country_iso3: Optional[str] = Query(default=None),
    pillar_code: Optional[str] = Query(default=None),
    year: Optional[int] = Query(default=None),
    status: Optional[str] = Query(default=None),
    db: Session = Depends(get_db),
):
    sql = """
        SELECT id, country_iso3, pillar_code, year, status, created_by, created_at::text, updated_at::text
        FROM mg.pillar_strategic_vision WHERE 1=1
    """
    params: dict = {}
    if country_iso3:
        sql += " AND country_iso3 = :country_iso3"
        params["country_iso3"] = country_iso3.upper()
    if pillar_code:
        sql += " AND pillar_code = :pillar_code"
        params["pillar_code"] = pillar_code
    if year:
        sql += " AND year = :year"
        params["year"] = year
    if status:
        sql += " AND status = :status"
        params["status"] = status
    sql += " ORDER BY year DESC, country_iso3, pillar_code"
    rows = db.execute(text(sql), params).mappings().all()
    return {"count": len(rows), "items": [dict(r) for r in rows]}


@router.get("/visions/{vision_id}", summary="Consulter une vision stratégique")
def get_vision(vision_id: int, db: Session = Depends(get_db)):
    row = db.execute(
        text("""
            SELECT id, country_iso3, pillar_code, year, status, created_by, created_at::text, updated_at::text
            FROM mg.pillar_strategic_vision WHERE id = :id
        """),
        {"id": vision_id},
    ).mappings().first()
    if not row:
        raise HTTPException(status_code=404, detail={"fr": "Vision introuvable.", "en": "Vision not found."})
    return dict(row)


# ── Analyses rattachées a une vision ─────────────────────────────────────────────

class VisionAnalysisCreate(BaseModel):
    method: str = Field(..., description=f"Une de : {', '.join(VALID_METHODS)}")
    content: dict


@router.post(
    "/visions/{vision_id}/analyses",
    summary="Ajouter une analyse stratégique à une vision",
    description="Mêmes 10 méthodes que pour les opportunités OSOA (osoa.py), validation identique.",
)
def create_vision_analysis(
    vision_id: int,
    data: VisionAnalysisCreate,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    affiliate_id = int(payload["sub"])

    if data.method not in VALID_METHODS:
        raise HTTPException(status_code=422, detail={
            "fr": f"method doit être l'une de : {', '.join(VALID_METHODS)}.",
            "en": f"method must be one of: {', '.join(VALID_METHODS)}.",
        })

    vision = db.execute(
        text("SELECT id FROM mg.pillar_strategic_vision WHERE id = :id"),
        {"id": vision_id},
    ).mappings().first()
    if not vision:
        raise HTTPException(status_code=404, detail={"fr": "Vision introuvable.", "en": "Vision not found."})

    model_cls = METHOD_MODELS[data.method]
    try:
        validated = model_cls(**data.content)
    except Exception as e:
        raise HTTPException(status_code=422, detail={
            "fr": f"Contenu invalide pour la méthode {data.method} : {e}",
            "en": f"Invalid content for method {data.method}: {e}",
        })

    # 5_POURQUOI : categorie_5m validee contre le referentiel reel
    if data.method == "5_POURQUOI":
        cat = db.execute(
            text("SELECT code FROM rf.cause_category_5m WHERE code = :code"),
            {"code": validated.categorie_5m},
        ).mappings().first()
        if not cat:
            raise HTTPException(status_code=422, detail={
                "fr": f"categorie_5m '{validated.categorie_5m}' introuvable dans rf.cause_category_5m.",
                "en": f"categorie_5m '{validated.categorie_5m}' not found in rf.cause_category_5m.",
            })

    # INTERDEPENDANCE : pillar_code/indicator_codes valides contre les referentiels reels
    if data.method == "INTERDEPENDANCE":
        for side, side_type, pillar, codes in (
            ("source", validated.source_type, validated.source_pillar_code, validated.source_indicator_codes),
            ("target", validated.target_type, validated.target_pillar_code, validated.target_indicator_codes),
        ):
            if side_type == "PILLAR":
                row_p = db.execute(
                    text("SELECT code FROM rf.pillars WHERE code = :code"),
                    {"code": pillar},
                ).mappings().first()
                if not row_p:
                    raise HTTPException(status_code=422, detail={
                        "fr": f"{side}_pillar_code '{pillar}' introuvable dans rf.pillars.",
                        "en": f"{side}_pillar_code '{pillar}' not found in rf.pillars.",
                    })
            else:
                for code in codes:
                    row_i = db.execute(
                        text("SELECT indicator_code FROM rf.poa_catalog WHERE indicator_code = :code"),
                        {"code": code},
                    ).mappings().first()
                    if not row_i:
                        raise HTTPException(status_code=422, detail={
                            "fr": f"{side}_indicator_codes contient '{code}', introuvable dans rf.poa_catalog.",
                            "en": f"{side}_indicator_codes contains '{code}', not found in rf.poa_catalog.",
                        })
        if validated.known_intervention_requirement_id:
            row_req = db.execute(
                text("SELECT id FROM mg.transformation_requirements WHERE id = :id"),
                {"id": validated.known_intervention_requirement_id},
            ).mappings().first()
            if not row_req:
                raise HTTPException(status_code=422, detail={
                    "fr": f"known_intervention_requirement_id {validated.known_intervention_requirement_id} introuvable.",
                    "en": f"known_intervention_requirement_id {validated.known_intervention_requirement_id} not found.",
                })

    content_json = validated.model_dump_json()

    row = db.execute(
        text("""
            INSERT INTO osoa.strategic_analyses (vision_id, method, content, created_by)
            VALUES (:vision_id, :method, CAST(:content AS jsonb), :created_by)
            RETURNING id, vision_id, method, content, created_by, created_at::text
        """),
        {"vision_id": vision_id, "method": data.method, "content": content_json, "created_by": affiliate_id},
    ).mappings().first()
    db.commit()

    return dict(row)


@router.get("/visions/{vision_id}/analyses", summary="Lister les analyses d'une vision")
def list_vision_analyses(
    vision_id: int,
    method: Optional[str] = Query(default=None),
    db: Session = Depends(get_db),
):
    sql = """
        SELECT id, vision_id, method, content, created_by, created_at::text
        FROM osoa.strategic_analyses WHERE vision_id = :vision_id
    """
    params: dict = {"vision_id": vision_id}
    if method:
        sql += " AND method = :method"
        params["method"] = method
    sql += " ORDER BY created_at DESC"
    rows = db.execute(text(sql), params).mappings().all()
    return {"count": len(rows), "items": [dict(r) for r in rows]}


# ── Livrables d'une vision (Vision=ETUDE_OPPORTUNITE, Schema directeur, Plan action) ─

def _latest_vision_analysis_by_method(db: Session, vision_id: int, method: str):
    return db.execute(
        text("""
            SELECT id, content FROM osoa.strategic_analyses
            WHERE vision_id = :vision_id AND method = :method
            ORDER BY created_at DESC LIMIT 1
        """),
        {"vision_id": vision_id, "method": method},
    ).mappings().first()


class VisionDeliverableCreate(BaseModel):
    deliverable_type: str = Field(
        ...,
        description="ETUDE_OPPORTUNITE (= Vision), SCHEMA_DIRECTEUR ou PLAN_ACTION",
    )


@router.post(
    "/visions/{vision_id}/deliverables",
    summary="Générer un livrable pour une vision (Vision/Schéma directeur/Plan d'action)",
    description=(
        "ETUDE_OPPORTUNITE réutilisée telle quelle pour porter la Vision (décision "
        "actée le 28 juillet 2026, pas de nouveau type de livrable). Échoue "
        "explicitement si une méthode requise n'a pas encore d'analyse."
    ),
)
def create_vision_deliverable(
    vision_id: int,
    data: VisionDeliverableCreate,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    affiliate_id = int(payload["sub"])

    if data.deliverable_type not in DELIVERABLE_REQUIRED_METHODS:
        raise HTTPException(status_code=422, detail={
            "fr": f"deliverable_type doit être l'une de : {', '.join(DELIVERABLE_REQUIRED_METHODS)}.",
            "en": f"deliverable_type must be one of: {', '.join(DELIVERABLE_REQUIRED_METHODS)}.",
        })

    vision = db.execute(
        text("SELECT id FROM mg.pillar_strategic_vision WHERE id = :id"),
        {"id": vision_id},
    ).mappings().first()
    if not vision:
        raise HTTPException(status_code=404, detail={"fr": "Vision introuvable.", "en": "Vision not found."})

    required = DELIVERABLE_REQUIRED_METHODS[data.deliverable_type]
    analyses = {}
    missing = []
    for method in required:
        row = _latest_vision_analysis_by_method(db, vision_id, method)
        if not row:
            missing.append(method)
        else:
            analyses[method] = {"id": row["id"], "content": row["content"]}

    if missing:
        raise HTTPException(status_code=422, detail={
            "fr": f"Analyses manquantes pour générer {data.deliverable_type} : {', '.join(missing)}.",
            "en": f"Missing analyses to generate {data.deliverable_type}: {', '.join(missing)}.",
        })

    content = DELIVERABLE_BUILDERS[data.deliverable_type](analyses)
    source_ids = [a["id"] for a in analyses.values()]

    row = db.execute(
        text("""
            INSERT INTO osoa.strategic_deliverables (vision_id, deliverable_type, content, source_analysis_ids, generated_by)
            VALUES (:vision_id, :deliverable_type, CAST(:content AS jsonb), :source_ids, :generated_by)
            RETURNING id, vision_id, deliverable_type, content, source_analysis_ids, generated_by, generated_at::text
        """),
        {
            "vision_id": vision_id,
            "deliverable_type": data.deliverable_type,
            "content": json.dumps(content),
            "source_ids": source_ids,
            "generated_by": affiliate_id,
        },
    ).mappings().first()
    db.commit()

    return dict(row)


@router.get("/visions/{vision_id}/deliverables", summary="Lister les livrables d'une vision")
def list_vision_deliverables(vision_id: int, db: Session = Depends(get_db)):
    rows = db.execute(
        text("""
            SELECT id, vision_id, deliverable_type, content, source_analysis_ids, generated_by, generated_at::text,
                   public_summary_fr, public_summary_en, summary_status
            FROM osoa.strategic_deliverables WHERE vision_id = :vision_id
            ORDER BY generated_at DESC
        """),
        {"vision_id": vision_id},
    ).mappings().all()
    return {"count": len(rows), "items": [dict(r) for r in rows]}


# ── Explosion d'un PLAN_ACTION en projets nommes ──────────────────────────────
# Ajoute le 28 juillet 2026. Exemple de Theo : PMIN fuite de minerais (POA) ->
# plan d'actions -> actions concretes nommees ("Systeme numerique de
# tracabilite", "Systeme de certification", "Fonds souverain tokenise").
# Chaque action DEVIENT un projet reel dans rf.sovereign_project_catalog,
# jamais construit a la main (doctrine LEGACY_MANUAL rejetee la veille).
#
# Meme patron double fournisseur (AI_SUMMARY_PROVIDER=anthropic|openai) que
# le resume executif Vision -- IA propose, humain valide, PUIS SEULEMENT
# promotion en catalogue reel.

import os as _os_actions

try:
    import anthropic as _anthropic_sdk_actions
except ImportError:
    _anthropic_sdk_actions = None

try:
    import openai as _openai_sdk_actions
except ImportError:
    _openai_sdk_actions = None


ACTIONS_SYSTEM_PROMPT = (
    "Tu proposes des actions-projets concretes et nommees a partir du contenu "
    "JSON d'un plan d'actions de souverainete africaine (cause racine, actions "
    "correctives generiques, parties prenantes, criteres de priorisation). "
    "Propose entre 3 et 6 actions CONCRETES, chacune formulee comme un vrai nom "
    "de projet (exemple : 'Systeme numerique de tracabilite', pas 'ameliorer la "
    "tracabilite'). Chaque action doit etre directement justifiee par le contenu "
    "fourni, jamais inventee sans lien. Reponds UNIQUEMENT en JSON valide, sans "
    "aucun texte avant ou apres, au format exact : "
    '{"actions": [{"name_fr": "...", "name_en": "...", "description_fr": "...", "description_en": "..."}]}'
)


def _generate_actions_anthropic(content_json: str) -> dict:
    api_key = _os_actions.environ.get("ANTHROPIC_API_KEY")
    if not api_key or _anthropic_sdk_actions is None:
        raise HTTPException(status_code=503, detail={
            "fr": "AI_SUMMARY_PROVIDER=anthropic mais ANTHROPIC_API_KEY n'est pas configurée sur ce serveur.",
            "en": "AI_SUMMARY_PROVIDER=anthropic but ANTHROPIC_API_KEY is not configured on this server.",
        })
    client = _anthropic_sdk_actions.Anthropic(api_key=api_key)
    response = client.messages.create(
        model="claude-sonnet-5",
        max_tokens=1800,
        system=ACTIONS_SYSTEM_PROMPT,
        messages=[{"role": "user", "content": content_json}],
    )
    raw_text = "".join(block.text for block in response.content if block.type == "text")
    return json.loads(raw_text)


def _generate_actions_openai(content_json: str) -> dict:
    api_key = _os_actions.environ.get("OPENAI_API_KEY")
    if not api_key or _openai_sdk_actions is None:
        raise HTTPException(status_code=503, detail={
            "fr": "AI_SUMMARY_PROVIDER=openai mais OPENAI_API_KEY n'est pas configurée sur ce serveur.",
            "en": "AI_SUMMARY_PROVIDER=openai but OPENAI_API_KEY is not configured on this server.",
        })
    client = _openai_sdk_actions.OpenAI(api_key=api_key)
    response = client.chat.completions.create(
        model="gpt-4o",
        response_format={"type": "json_object"},
        messages=[
            {"role": "system", "content": ACTIONS_SYSTEM_PROMPT},
            {"role": "user", "content": content_json},
        ],
    )
    return json.loads(response.choices[0].message.content)


@router.post(
    "/deliverables/{deliverable_id}/generate-actions",
    summary="Générer des propositions d'actions-projets (IA) à partir d'un PLAN_ACTION",
    description="Réservé au livrable PLAN_ACTION. Brouillon IA -- DOIT être validé avant promotion en catalogue.",
)
def generate_plan_action_projects(
    deliverable_id: int,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    affiliate_id = int(payload["sub"])

    deliverable = db.execute(
        text("SELECT id, deliverable_type, content FROM osoa.strategic_deliverables WHERE id = :id"),
        {"id": deliverable_id},
    ).mappings().first()
    if not deliverable:
        raise HTTPException(status_code=404, detail={"fr": "Livrable introuvable.", "en": "Deliverable not found."})

    if deliverable["deliverable_type"] != "PLAN_ACTION":
        raise HTTPException(status_code=422, detail={
            "fr": "L'explosion en projets n'est disponible que pour PLAN_ACTION.",
            "en": "Project explosion is only available for PLAN_ACTION.",
        })

    provider = _os_actions.environ.get("AI_SUMMARY_PROVIDER", "anthropic").lower()
    content_json = json.dumps(deliverable["content"], ensure_ascii=False)

    try:
        if provider == "anthropic":
            parsed = _generate_actions_anthropic(content_json)
        elif provider == "openai":
            parsed = _generate_actions_openai(content_json)
        else:
            raise HTTPException(status_code=500, detail={
                "fr": f"AI_SUMMARY_PROVIDER='{provider}' invalide.",
                "en": f"AI_SUMMARY_PROVIDER='{provider}' invalid.",
            })
        actions = parsed["actions"]
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=502, detail={
            "fr": f"Échec de la génération IA ({provider}) : {e}",
            "en": f"AI generation failed ({provider}): {e}",
        })

    created = []
    for action in actions:
        row = db.execute(
            text("""
                INSERT INTO mg.plan_action_projects
                    (deliverable_id, action_name_fr, action_name_en, action_description_fr, action_description_en, created_by)
                VALUES (:deliverable_id, :name_fr, :name_en, :desc_fr, :desc_en, :created_by)
                RETURNING id, deliverable_id, action_name_fr, action_name_en, action_description_fr, action_description_en, status, created_at::text
            """),
            {
                "deliverable_id": deliverable_id,
                "name_fr": action["name_fr"],
                "name_en": action.get("name_en"),
                "desc_fr": action["description_fr"],
                "desc_en": action.get("description_en"),
                "created_by": affiliate_id,
            },
        ).mappings().first()
        created.append(dict(row))
    db.commit()

    return {"count": len(created), "items": created}


@router.get("/deliverables/{deliverable_id}/plan-action-projects", summary="Lister les actions proposées d'un PLAN_ACTION")
def list_plan_action_projects(deliverable_id: int, db: Session = Depends(get_db)):
    rows = db.execute(
        text("""
            SELECT id, deliverable_id, action_name_fr, action_name_en, action_description_fr,
                   action_description_en, status, promoted_project_code, created_at::text
            FROM mg.plan_action_projects WHERE deliverable_id = :deliverable_id
            ORDER BY created_at
        """),
        {"deliverable_id": deliverable_id},
    ).mappings().all()
    return {"count": len(rows), "items": [dict(r) for r in rows]}


class ActionProjectValidate(BaseModel):
    action_name_fr: Optional[str] = None
    action_name_en: Optional[str] = None
    action_description_fr: Optional[str] = None
    action_description_en: Optional[str] = None


@router.post(
    "/plan-action-projects/{action_id}/validate",
    summary="Valider (et éventuellement corriger) une action proposée",
)
def validate_plan_action_project(
    action_id: int,
    data: ActionProjectValidate,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    action = db.execute(
        text("SELECT id, status FROM mg.plan_action_projects WHERE id = :id"),
        {"id": action_id},
    ).mappings().first()
    if not action:
        raise HTTPException(status_code=404, detail={"fr": "Action introuvable.", "en": "Action not found."})
    if action["status"] == "PROMOTED":
        raise HTTPException(status_code=409, detail={
            "fr": "Cette action a déjà été promue en projet réel.",
            "en": "This action has already been promoted to a real project.",
        })

    row = db.execute(
        text("""
            UPDATE mg.plan_action_projects
            SET action_name_fr = COALESCE(:name_fr, action_name_fr),
                action_name_en = COALESCE(:name_en, action_name_en),
                action_description_fr = COALESCE(:desc_fr, action_description_fr),
                action_description_en = COALESCE(:desc_en, action_description_en),
                status = 'HUMAN_VALIDATED',
                updated_at = NOW()
            WHERE id = :id
            RETURNING id, action_name_fr, action_name_en, action_description_fr, action_description_en, status
        """),
        {
            "name_fr": data.action_name_fr, "name_en": data.action_name_en,
            "desc_fr": data.action_description_fr, "desc_en": data.action_description_en,
            "id": action_id,
        },
    ).mappings().first()
    db.commit()
    return dict(row)


@router.post(
    "/plan-action-projects/{action_id}/promote",
    summary="Promouvoir une action validée en vrai projet du catalogue (rf.sovereign_project_catalog)",
    description="Réservé aux actions HUMAN_VALIDATED. Crée une ligne doctrinal_status=OIM_GENERATED, tracée vers son plan d'actions source.",
)
def promote_plan_action_project(
    action_id: int,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    action = db.execute(
        text("""
            SELECT pap.id, pap.status, pap.action_name_fr, pap.action_name_en,
                   pap.action_description_fr, pap.action_description_en, pap.deliverable_id,
                   sd.vision_id
            FROM mg.plan_action_projects pap
            JOIN osoa.strategic_deliverables sd ON sd.id = pap.deliverable_id
            WHERE pap.id = :id
        """),
        {"id": action_id},
    ).mappings().first()
    if not action:
        raise HTTPException(status_code=404, detail={"fr": "Action introuvable.", "en": "Action not found."})
    if action["status"] != "HUMAN_VALIDATED":
        raise HTTPException(status_code=422, detail={
            "fr": "Seule une action HUMAN_VALIDATED peut être promue.",
            "en": "Only a HUMAN_VALIDATED action can be promoted.",
        })
    if not action["vision_id"]:
        raise HTTPException(status_code=422, detail={
            "fr": "Ce livrable n'est pas rattaché à une vision -- promotion impossible.",
            "en": "This deliverable is not attached to a vision -- promotion not possible.",
        })

    vision = db.execute(
        text("SELECT country_iso3, pillar_code FROM mg.pillar_strategic_vision WHERE id = :id"),
        {"id": action["vision_id"]},
    ).mappings().first()

    family = db.execute(
        text("SELECT project_family_code FROM rf.structuring_project_catalog WHERE pillar_code = :pillar_code LIMIT 1"),
        {"pillar_code": vision["pillar_code"]},
    ).mappings().first()
    if not family:
        raise HTTPException(status_code=422, detail={
            "fr": f"Aucune famille de projets trouvée pour le pilier {vision['pillar_code']}.",
            "en": f"No project family found for pillar {vision['pillar_code']}.",
        })

    project_code = f"OIM_{vision['country_iso3']}_{vision['pillar_code']}_{action_id}"

    try:
        project_row = db.execute(
            text("""
                INSERT INTO rf.sovereign_project_catalog
                    (project_code, project_family_code, pillar_code, country_iso3, project_name,
                     project_description, strategic_objective, deliverable_public, deliverable_premium,
                     doctrinal_status, project_name_fr, project_name_en, project_description_fr, project_description_en)
                VALUES
                    (:project_code, :family_code, :pillar_code, :country_iso3, :name,
                     :description, :objective, :deliverable_public, :deliverable_premium,
                     'OIM_GENERATED', :name_fr, :name_en, :desc_fr, :desc_en)
                RETURNING project_code
            """),
            {
                "project_code": project_code,
                "family_code": family["project_family_code"],
                "pillar_code": vision["pillar_code"],
                "country_iso3": vision["country_iso3"],
                "name": action["action_name_fr"],
                "description": action["action_description_fr"],
                "objective": action["action_description_fr"],
                "deliverable_public": "Note d'opportunité disponible sur demande institutionnelle.",
                "deliverable_premium": "Étude de faisabilité complète disponible sur demande institutionnelle.",
                "name_fr": action["action_name_fr"],
                "name_en": action["action_name_en"],
                "desc_fr": action["action_description_fr"],
                "desc_en": action["action_description_en"],
            },
        ).mappings().first()
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=409, detail={
            "fr": f"Erreur lors de la création du projet : {e}",
            "en": f"Error creating the project: {e}",
        })

    row = db.execute(
        text("""
            UPDATE mg.plan_action_projects
            SET status = 'PROMOTED', promoted_project_code = :project_code, updated_at = NOW()
            WHERE id = :id
            RETURNING id, status, promoted_project_code
        """),
        {"project_code": project_row["project_code"], "id": action_id},
    ).mappings().first()
    db.commit()

    return dict(row)
