"""
OSA Observatory -- OIM, generation automatique des analyses de vision
api/routers/oim_analysis_gen.py

Chantier prioritaire du 4 aout 2026 : automatiser la generation des 9
analyses primaires (5W1H, SWOT, ZACHMAN, RISQUE, ECONOMIQUE, GOUVERNANCE,
MULTICRITERE, FAISABILITE, 5_POURQUOI) par pays+pilier, a partir des
vraies donnees ISA/POA (ma.mv_isa_observed_scores_by_pillar +
ma.mv_p7i_risk_source) -- condition prealable a tout lancement en masse
(540 visions/an).

INTERDEPENDANCE (10eme methode) traitee separement : jamais generee a
partir des donnees brutes comme les 9 primaires, mais comme une SYNTHESE
deduite du contenu des 9 autres, une fois PROMUES (validees) -- decision
de Theo pour eviter d'inventer une relation inter-pilier a partir de
chiffres seuls.

Reutilise METHOD_MODELS (schema JSON automatique via model_json_schema(),
pas de prompt ecrit a la main par methode) et VALID_METHODS de osoa.py.
"""
import json
import os
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import text
from pydantic import BaseModel

from api.db import get_db
from api.routers.auth_affiliates import get_current_affiliate
from api.routers.osoa import METHOD_MODELS

try:
    import anthropic as _anthropic_sdk_gen
except ImportError:
    _anthropic_sdk_gen = None

try:
    import openai as _openai_sdk_gen
except ImportError:
    _openai_sdk_gen = None

router = APIRouter(
    prefix="/api/v2/oim",
    tags=["OIM - Génération automatique des analyses"],
)

PRIMARY_METHODS = [
    "5W1H", "SWOT", "ZACHMAN", "RISQUE", "ECONOMIQUE",
    "GOUVERNANCE", "MULTICRITERE", "FAISABILITE", "5_POURQUOI",
]

PRIMARY_ANALYSIS_SYSTEM_PROMPT = """Tu rediges une analyse strategique de type {method} pour un pilier de
souverainete africaine, a partir de donnees ISA reelles et observees
(jamais inventees). Utilise EXCLUSIVEMENT les donnees fournies -- si une
donnee manque, reste generique plutot que d'inventer un chiffre precis.

Regles imperatives :
- Vocabulaire mesure : jamais d'adjectif absolu ou promotionnel
  (indeniable, majeur, enorme) -- preferer documente/observe/identifie.
- Tout champ numerique de cout ou de delai DOIT etre une fourchette
  (min/max), jamais un chiffre unique presente comme certain.
- Reponds UNIQUEMENT en JSON valide conforme au schema exact fourni,
  sans aucun texte avant ou apres.

Schema JSON attendu :
{schema}

Donnees reelles du pilier (pays+pilier+annee) :
{data_snapshot}
"""

INTERDEPENDANCE_SYSTEM_PROMPT = """Tu identifies une eventuelle interdependance entre ce pilier et un autre
pilier ou indicateur POA, en SYNTHESE des 9 analyses deja validees
fournies ci-dessous -- jamais a partir de donnees brutes. Cherche une
relation reelle qui ressort de leur contenu (ex. une cause racine du
5 Pourquoi qui pointe vers un autre secteur, un risque du RISQUE qui
depend d'un autre pilier). Si aucune interdependance claire ne ressort,
reponds avec basis_type="AUCUNE_IDENTIFIEE" et une methodology_note_fr
expliquant pourquoi.

Reponds UNIQUEMENT en JSON valide conforme au schema exact fourni, sans
aucun texte avant ou apres.

Schema JSON attendu :
{schema}

Contenu des 9 analyses deja validees :
{analyses_content}
"""


def _ai_client_and_provider():
    provider = os.environ.get("AI_SUMMARY_PROVIDER", "anthropic").lower()
    return provider


def _call_ai(system_prompt: str, user_content: str) -> dict:
    provider = _ai_client_and_provider()
    if provider == "anthropic":
        api_key = os.environ.get("ANTHROPIC_API_KEY")
        if not api_key or _anthropic_sdk_gen is None:
            raise HTTPException(status_code=503, detail={
                "fr": "AI_SUMMARY_PROVIDER=anthropic mais ANTHROPIC_API_KEY n'est pas configurée.",
                "en": "AI_SUMMARY_PROVIDER=anthropic but ANTHROPIC_API_KEY is not configured.",
            })
        client = _anthropic_sdk_gen.Anthropic(api_key=api_key)
        response = client.messages.create(
            model="claude-sonnet-5",
            max_tokens=2000,
            system=system_prompt,
            messages=[{"role": "user", "content": user_content}],
        )
        raw_text = "".join(block.text for block in response.content if block.type == "text")
        return json.loads(raw_text)
    elif provider == "openai":
        api_key = os.environ.get("OPENAI_API_KEY")
        if not api_key or _openai_sdk_gen is None:
            raise HTTPException(status_code=503, detail={
                "fr": "AI_SUMMARY_PROVIDER=openai mais OPENAI_API_KEY n'est pas configurée.",
                "en": "AI_SUMMARY_PROVIDER=openai but OPENAI_API_KEY is not configured.",
            })
        client = _openai_sdk_gen.OpenAI(api_key=api_key)
        response = client.chat.completions.create(
            model="gpt-4o",
            response_format={"type": "json_object"},
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_content},
            ],
        )
        return json.loads(response.choices[0].message.content)
    else:
        raise HTTPException(status_code=500, detail={
            "fr": f"AI_SUMMARY_PROVIDER='{provider}' invalide.",
            "en": f"AI_SUMMARY_PROVIDER='{provider}' invalid.",
        })


def _get_pillar_data_snapshot(db: Session, country_iso3: str, pillar_code: str, year: int) -> dict:
    row = db.execute(
        text("""
            SELECT s.isa_observed_score, s.sovereignty_observed_score, s.vulnerability_observed_score,
                   s.resilience_observed_score, s.data_completeness, s.certification_status,
                   r.isa_trend_slope, r.isa_volatility, r.strategic_risk_score, r.strategic_upside_score,
                   r.forecast_trend_class, r.swot_data_status,
                   r.central_isa_delta, r.ambitious_isa_delta, r.stress_isa_delta
            FROM ma.mv_isa_observed_scores_by_pillar s
            LEFT JOIN ma.mv_p7i_risk_source r
                ON r.country_iso3 = s.country_iso3 AND r.pillar_code = s.pillar_code AND r.year = s.year
            WHERE s.country_iso3 = :country_iso3 AND s.pillar_code = :pillar_code AND s.year = :year
        """),
        {"country_iso3": country_iso3, "pillar_code": pillar_code, "year": year},
    ).mappings().first()
    return dict(row) if row else {}


# ── Etape 1 : generation des 9 analyses primaires ────────────────────────────

@router.post(
    "/visions/{vision_id}/generate-analysis-drafts",
    summary="Générer les 9 analyses primaires (IA) à partir des vraies données ISA du pilier",
    description="Une donnée réelle par pays+pilier+année. Échoue explicitement si aucune donnée n'est disponible.",
)
def generate_analysis_drafts(
    vision_id: int,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    affiliate_id = int(payload["sub"])

    vision = db.execute(
        text("SELECT id, country_iso3, pillar_code, year FROM mg.pillar_strategic_vision WHERE id = :id"),
        {"id": vision_id},
    ).mappings().first()
    if not vision:
        raise HTTPException(status_code=404, detail={"fr": "Vision introuvable.", "en": "Vision not found."})

    snapshot = _get_pillar_data_snapshot(db, vision["country_iso3"], vision["pillar_code"], vision["year"])
    if not snapshot:
        raise HTTPException(status_code=422, detail={
            "fr": f"Aucune donnée ISA observée pour {vision['country_iso3']}/{vision['pillar_code']}/{vision['year']} -- génération impossible sans donnée réelle.",
            "en": f"No observed ISA data for {vision['country_iso3']}/{vision['pillar_code']}/{vision['year']} -- generation impossible without real data.",
        })
    snapshot_json = json.dumps(snapshot, ensure_ascii=False, default=str)

    created = []
    errors = []
    for method in PRIMARY_METHODS:
        model_cls = METHOD_MODELS[method]
        schema_json = json.dumps(model_cls.model_json_schema(), ensure_ascii=False)
        system_prompt = PRIMARY_ANALYSIS_SYSTEM_PROMPT.format(method=method, schema=schema_json, data_snapshot=snapshot_json)

        try:
            parsed = _call_ai(system_prompt, snapshot_json)
            validated = model_cls(**parsed)
        except HTTPException:
            raise
        except Exception as e:
            errors.append({"method": method, "error": str(e)})
            continue

        row = db.execute(
            text("""
                INSERT INTO mg.pillar_analysis_drafts (vision_id, method, content, created_by)
                VALUES (:vision_id, :method, CAST(:content AS jsonb), :created_by)
                RETURNING id, vision_id, method, content, status, created_at::text
            """),
            {
                "vision_id": vision_id,
                "method": method,
                "content": validated.model_dump_json(),
                "created_by": affiliate_id,
            },
        ).mappings().first()
        created.append(dict(row))

    db.commit()
    return {"count": len(created), "items": created, "errors": errors}


@router.get("/visions/{vision_id}/analysis-drafts", summary="Lister les brouillons d'analyses d'une vision")
def list_analysis_drafts(
    vision_id: int,
    status: Optional[str] = Query(default=None),
    db: Session = Depends(get_db),
):
    sql = """
        SELECT id, vision_id, method, content, status, promoted_analysis_id, created_at::text
        FROM mg.pillar_analysis_drafts WHERE vision_id = :vision_id
    """
    params: dict = {"vision_id": vision_id}
    if status:
        sql += " AND status = :status"
        params["status"] = status
    sql += " ORDER BY created_at"
    rows = db.execute(text(sql), params).mappings().all()
    return {"count": len(rows), "items": [dict(r) for r in rows]}


class AnalysisDraftValidate(BaseModel):
    content: Optional[dict] = None


@router.post("/analysis-drafts/{draft_id}/validate", summary="Valider (et éventuellement corriger) un brouillon d'analyse")
def validate_analysis_draft(
    draft_id: int,
    data: AnalysisDraftValidate,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    draft = db.execute(
        text("SELECT id, method, status FROM mg.pillar_analysis_drafts WHERE id = :id"),
        {"id": draft_id},
    ).mappings().first()
    if not draft:
        raise HTTPException(status_code=404, detail={"fr": "Brouillon introuvable.", "en": "Draft not found."})
    if draft["status"] == "PROMOTED":
        raise HTTPException(status_code=409, detail={
            "fr": "Ce brouillon a déjà été promu.",
            "en": "This draft has already been promoted.",
        })

    if data.content is not None:
        model_cls = METHOD_MODELS[draft["method"]]
        try:
            validated = model_cls(**data.content)
        except Exception as e:
            raise HTTPException(status_code=422, detail={
                "fr": f"Contenu corrigé invalide pour la méthode {draft['method']} : {e}",
                "en": f"Corrected content invalid for method {draft['method']}: {e}",
            })
        content_json = validated.model_dump_json()
        row = db.execute(
            text("""
                UPDATE mg.pillar_analysis_drafts
                SET content = CAST(:content AS jsonb), status = 'HUMAN_VALIDATED', updated_at = NOW()
                WHERE id = :id
                RETURNING id, method, content, status
            """),
            {"content": content_json, "id": draft_id},
        ).mappings().first()
    else:
        row = db.execute(
            text("""
                UPDATE mg.pillar_analysis_drafts
                SET status = 'HUMAN_VALIDATED', updated_at = NOW()
                WHERE id = :id
                RETURNING id, method, content, status
            """),
            {"id": draft_id},
        ).mappings().first()

    db.commit()
    return dict(row)


@router.post(
    "/analysis-drafts/{draft_id}/promote",
    summary="Promouvoir un brouillon validé en vraie analyse (osoa.strategic_analyses)",
)
def promote_analysis_draft(
    draft_id: int,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    affiliate_id = int(payload["sub"])

    draft = db.execute(
        text("SELECT id, vision_id, method, content, status FROM mg.pillar_analysis_drafts WHERE id = :id"),
        {"id": draft_id},
    ).mappings().first()
    if not draft:
        raise HTTPException(status_code=404, detail={"fr": "Brouillon introuvable.", "en": "Draft not found."})
    if draft["status"] != "HUMAN_VALIDATED":
        raise HTTPException(status_code=422, detail={
            "fr": "Seul un brouillon HUMAN_VALIDATED peut être promu.",
            "en": "Only a HUMAN_VALIDATED draft can be promoted.",
        })

    model_cls = METHOD_MODELS[draft["method"]]
    try:
        model_cls(**draft["content"])
    except Exception as e:
        raise HTTPException(status_code=422, detail={
            "fr": f"Contenu invalide au moment de la promotion : {e}",
            "en": f"Invalid content at promotion time: {e}",
        })

    analysis_row = db.execute(
        text("""
            INSERT INTO osoa.strategic_analyses (vision_id, method, content, created_by)
            VALUES (:vision_id, :method, CAST(:content AS jsonb), :created_by)
            RETURNING id
        """),
        {
            "vision_id": draft["vision_id"],
            "method": draft["method"],
            "content": json.dumps(draft["content"]),
            "created_by": affiliate_id,
        },
    ).mappings().first()

    row = db.execute(
        text("""
            UPDATE mg.pillar_analysis_drafts
            SET status = 'PROMOTED', promoted_analysis_id = :analysis_id, updated_at = NOW()
            WHERE id = :id
            RETURNING id, status, promoted_analysis_id
        """),
        {"analysis_id": analysis_row["id"], "id": draft_id},
    ).mappings().first()
    db.commit()

    return dict(row)


# ── Etape 2 : synthese INTERDEPENDANCE, a partir des 9 promues ────────────────

@router.post(
    "/visions/{vision_id}/generate-interdependance-draft",
    summary="Générer le brouillon INTERDEPENDANCE (IA) en synthèse des 9 analyses déjà promues",
    description="Réservé aux visions dont les 9 méthodes primaires sont déjà PROMOTED -- jamais généré à partir de données brutes.",
)
def generate_interdependance_draft(
    vision_id: int,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    affiliate_id = int(payload["sub"])

    vision = db.execute(
        text("SELECT id FROM mg.pillar_strategic_vision WHERE id = :id"),
        {"id": vision_id},
    ).mappings().first()
    if not vision:
        raise HTTPException(status_code=404, detail={"fr": "Vision introuvable.", "en": "Vision not found."})

    promoted = db.execute(
        text("""
            SELECT method, content FROM osoa.strategic_analyses
            WHERE vision_id = :vision_id AND method = ANY(:methods)
            ORDER BY created_at DESC
        """),
        {"vision_id": vision_id, "methods": PRIMARY_METHODS},
    ).mappings().all()

    found_methods = {r["method"] for r in promoted}
    missing = [m for m in PRIMARY_METHODS if m not in found_methods]
    if missing:
        raise HTTPException(status_code=422, detail={
            "fr": f"Méthodes primaires manquantes (doivent être promues) : {', '.join(missing)}.",
            "en": f"Missing primary methods (must be promoted): {', '.join(missing)}.",
        })

    analyses_content = {r["method"]: r["content"] for r in promoted}
    analyses_json = json.dumps(analyses_content, ensure_ascii=False, default=str)

    model_cls = METHOD_MODELS["INTERDEPENDANCE"]
    schema_json = json.dumps(model_cls.model_json_schema(), ensure_ascii=False)
    system_prompt = INTERDEPENDANCE_SYSTEM_PROMPT.format(schema=schema_json, analyses_content=analyses_json)

    try:
        parsed = _call_ai(system_prompt, analyses_json)
        validated = model_cls(**parsed)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=502, detail={
            "fr": f"Échec de la génération IA (INTERDEPENDANCE) : {e}",
            "en": f"AI generation failed (INTERDEPENDANCE): {e}",
        })

    row = db.execute(
        text("""
            INSERT INTO mg.pillar_analysis_drafts (vision_id, method, content, created_by)
            VALUES (:vision_id, 'INTERDEPENDANCE', CAST(:content AS jsonb), :created_by)
            RETURNING id, vision_id, method, content, status, created_at::text
        """),
        {
            "vision_id": vision_id,
            "content": validated.model_dump_json(),
            "created_by": affiliate_id,
        },
    ).mappings().first()
    db.commit()

    return dict(row)
