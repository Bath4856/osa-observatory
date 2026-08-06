"""
OSA Observatory -- OIM, generation automatique des analyses de vision
api/routers/oim_analysis_gen.py

Chantier du 4-5 aout 2026, en 2 sessions :
(A) Automatisation des 9 analyses primaires par pays+pilier (OIM V1,
    valide sur NAM/PTRA/2024 et CMR/PMIN/2024) + snapshot enrichi des
    vraies observations POA (rf.poa_catalog).
(B) REFONTE DE L'INTERDEPENDANCE EN 2 NIVEAUX (5 aout, matin) -- Theo a
    demontre que l'interdependance N'EST PAS une relation scientifique
    entre deux piliers (corr(A,B) -- releve de la recherche, pas d'OIM).
    OIM repond a une question operationnelle : "si on agit sur ce levier
    / ce projet, quels autres piliers en beneficient ?"
    Chaine complete : POA -> GAP -> 5 Pourquoi -> Cause racine ->
    LEVIER STRATEGIQUE -> Interdependance des leviers (niveau VISION,
    avant tout projet) -> PROJET -> Interdependance des interventions
    (niveau PLAN D'ACTION, sur un projet reel).
    L'ancien detecteur de candidats par correlation de risque partage
    (base sur ma.mv_p7i_risk_source) est retire -- obsolete sous cette
    doctrine.

Reutilise METHOD_MODELS (schema JSON automatique via model_json_schema())
et VALID_METHODS de osoa.py pour les 9 methodes primaires + le levier.
Le niveau Plan d'action (ContentInterventionInterdependance) n'appartient
PAS aux 10 methodes -- objet de niveau projet, hors METHOD_MODELS.

PROMPT DES 9 PRIMAIRES EN 5 ETAPES (structure de Theo, 4 aout 2026) :
donnees -> vocabulaire autorise (extrait automatiquement du schema) ->
schema JSON -> regles imperatives -> reponse JSON seule.
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
from api.routers.osoa import (
    METHOD_MODELS, ContentStrategicLever, ContentInterventionInterdependance,
    ContentAnalysisReview,
)

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

BOUNDED_SCORE_FIELDS = (
    "isa_observed_score", "sovereignty_observed_score",
    "vulnerability_observed_score", "resilience_observed_score",
    "strategic_risk_score", "strategic_upside_score", "data_completeness",
)

PRIMARY_ANALYSIS_SYSTEM_PROMPT = """Tu rediges une analyse strategique de type {method} pour un pilier de
souverainete africaine.

ETAPE 1 -- Donnees reelles du pilier (pays+pilier+annee, jamais inventees) :
{data_snapshot}

ETAPE 2 -- Vocabulaire controle autorise (OBLIGATOIRE -- tu n'as PAS le
droit d'utiliser une autre valeur que celles listees ici pour les champs
concernes, aucune exception) :
{vocabulary}

ETAPE 3 -- Schema JSON exact a respecter :
{schema}

ETAPE 4 -- Regles imperatives :
- Vocabulaire mesure : jamais d'adjectif absolu ou promotionnel
  (indeniable, majeur, enorme) -- preferer documente/observe/identifie.
- Pour tout champ liste en ETAPE 2, utilise EXCLUSIVEMENT l'une des
  valeurs autorisees, jamais une autre formulation ni une traduction.
- Utilise EXCLUSIVEMENT les donnees fournies en ETAPE 1 -- si une donnee
  manque, reste generique plutot que d'inventer un chiffre precis.
- Si poa_observations est present dans l'ETAPE 1, CE SONT DE VRAIS
  PHENOMENES OBSERVES independants du score ISA (ex. fuite de valeur
  miniere, signal de contrebande) -- prends-les serieusement en compte,
  surtout pour les forces/faiblesses/risques/causes racines, ne les
  ignore jamais s'ils sont presents.
{method_specific_rules}
ETAPE 5 -- Reponds UNIQUEMENT en JSON valide conforme au schema, sans
aucun texte avant ou apres.
"""

MULTICRITERE_SPECIFIC_RULE = """- Pour le champ "score" de chaque critere, utilise EXCLUSIVEMENT l'une
  des donnees suivantes de l'ETAPE 1, deja bornees [0,1] par construction :
  {bounded_fields}. Ne JAMAIS utiliser isa_trend_slope, isa_volatility, ni
  les champs central/ambitious/stress_isa_delta comme "score" -- ce sont
  des pentes/deltas, pas des scores.
"""

LEVER_SYSTEM_PROMPT = """Tu identifies un LEVIER STRATEGIQUE pour ce pilier, a partir des 9
analyses primaires deja validees ci-dessous -- surtout la cause racine du
5 Pourquoi et les risques identifies. Un levier n'est PAS un projet nomme
concret (ex. "SNCTM") -- c'est un domaine d'intervention (ex.
"Renforcement de la tracabilite miniere") qui repond a la cause racine
identifiee, avant qu'aucun projet precis n'existe.

Catalogue existant de leviers (REUTILISE un de ces codes si pertinent,
plutot que d'en proposer un nouveau -- vocabulaire partage entre visions,
jamais duplique) :
{existing_catalog}

Contenu des 9 analyses deja validees :
{analyses_content}

Schema JSON attendu :
{schema}

Regles imperatives :
- Le levier doit repondre directement a la cause_racine du 5 Pourquoi
  fourni ci-dessus -- jamais un levier deconnecte de cette analyse.
- Verifie d'abord le catalogue existant -- reuses_existing_code=true et
  lever_code = un code EXACT du catalogue si un levier convient deja.
- Si aucun levier existant ne convient, propose un nouveau lever_code
  (MAJUSCULES_UNDERSCORE, ex. TRACEABILITY_ENHANCEMENT), avec
  reuses_existing_code=false.
- Vocabulaire mesure, jamais promotionnel.
- Reponds UNIQUEMENT en JSON valide conforme au schema, sans aucun texte
  avant ou apres.
"""

VISION_INTERDEPENDANCE_SYSTEM_PROMPT = """Tu evalues les effets attendus d'un LEVIER STRATEGIQUE sur d'autres
piliers du MEME pays -- jamais une relation causale directe entre deux
piliers (ca releve de la recherche scientifique, pas d'OIM). Le levier
n'est pas encore un projet nomme -- tu evalues des effets POSSIBLES,
jamais garantis.

Contexte fige (a utiliser tel quel, jamais invente) :
primary_pillar_code = "{primary_pillar_code}"
strategic_lever_code = "{strategic_lever_code}"
strategic_lever_label = "{strategic_lever_label}"
strategic_lever_description = "{strategic_lever_description}"

Contenu des 9 analyses deja validees (pour etayer les effets attendus,
jamais les inventer) :
{analyses_content}

Vocabulaire controle autorise (OBLIGATOIRE) :
{vocabulary}

Schema JSON attendu :
{schema}

Regles imperatives :
- expected_effects PEUT etre une liste VIDE -- c'est un resultat
  legitime (ce levier ne beneficie qu'a son pilier principal), jamais
  une erreur a corriger en inventant un effet.
- N'invente JAMAIS un effet non etaye par le contenu des 9 analyses.
- target_pillar_code d'un effet ne peut jamais etre primary_pillar_code
  lui-meme.
- Reponds UNIQUEMENT en JSON valide conforme au schema, sans aucun texte
  avant ou apres.
"""

PROJECT_INTERDEPENDANCE_SYSTEM_PROMPT = """Tu evalues les effets attendus d'un PROJET REEL et nomme sur d'autres
piliers du MEME pays -- ce projet existe deja concretement (architecture,
objectifs), tu ne l'inventes pas.

Contexte fige (a utiliser tel quel, jamais invente) :
primary_pillar_code = "{primary_pillar_code}"
project_code = "{project_code}"
project_name = "{project_name}"
project_description = "{project_description}"
strategic_objective = "{strategic_objective}"

Vocabulaire controle autorise (OBLIGATOIRE) :
{vocabulary}

Schema JSON attendu :
{schema}

Regles imperatives :
- expected_effects PEUT etre une liste VIDE -- resultat legitime.
- Base chaque effet sur un besoin technique ou organisationnel REEL
  qu'implique ce projet (ex. tracabilite numerique -> identite
  numerique -> PNUM), jamais une supposition vague.
- target_pillar_code d'un effet ne peut jamais etre primary_pillar_code
  lui-meme.
- Reponds UNIQUEMENT en JSON valide conforme au schema, sans aucun texte
  avant ou apres.
"""


def _extract_controlled_vocabulary(schema: dict) -> str:
    """Parcourt le schema JSON (properties + $defs pour les sous-modeles
    imbriques) et liste tout champ "enum" trouve -- une seule source de
    verite (le modele Pydantic lui-meme), jamais une liste ecrite a la
    main a synchroniser separement."""
    defs = schema.get("$defs", {})
    lines = []

    def scan(properties: dict, prefix: str = ""):
        for field_name, field_schema in properties.items():
            enum_values = field_schema.get("enum")
            if enum_values:
                lines.append(f"- {prefix}{field_name} : UNIQUEMENT l'une de {enum_values}, aucune autre valeur.")
            ref = field_schema.get("$ref") or (field_schema.get("items") or {}).get("$ref")
            if ref:
                def_name = ref.split("/")[-1]
                nested = defs.get(def_name, {})
                scan(nested.get("properties", {}), prefix=f"{field_name}[].")

    scan(schema.get("properties", {}))
    return "\n".join(lines) if lines else "(aucun vocabulaire controle specifique pour cette methode)"


def _get_poa_observations(db: Session, country_iso3: str, pillar_code: str, year: int) -> list:
    """Recupere les vraies observations POA (Phenomenes Observables
    Autonomes) pour ce pilier -- donnees REELLES et independantes du
    score ISA (systeme herite rf.poa_catalog, Sprint 31 -- distinct de
    la nouvelle taxonomie rf.poa_phenomenon_domain/type)."""
    poa_indicators = db.execute(
        text("""
            SELECT p.indicator_code, p.delta_desc_fr, p.metric_label_fr
            FROM rf.poa_catalog p
            JOIN rf.indicators i ON i.code = p.indicator_code
            WHERE i.pillar_code = :pillar_code
        """),
        {"pillar_code": pillar_code},
    ).mappings().all()

    observations = []
    for ind in poa_indicators:
        code = ind["indicator_code"]
        row = db.execute(
            text("""
                SELECT processed_value AS value
                FROM ma.indicator_values
                WHERE indicator_code = :code AND country_iso3 = :country_iso3 AND year = :year AND layer_id = 3
                ORDER BY id DESC LIMIT 1
            """),
            {"code": code, "country_iso3": country_iso3, "year": year},
        ).mappings().first()
        source = "ma.indicator_values"
        if not row or row["value"] is None:
            row = db.execute(
                text("""
                    SELECT value_raw AS value
                    FROM collect.raw_data
                    WHERE indicator_code = :code AND country_iso3 = :country_iso3 AND year = :year
                    ORDER BY id_raw DESC LIMIT 1
                """),
                {"code": code, "country_iso3": country_iso3, "year": year},
            ).mappings().first()
            source = "collect.raw_data"
        if row and row["value"] is not None:
            observations.append({
                "indicator_code": code,
                "description": ind["delta_desc_fr"],
                "metric_label": ind["metric_label_fr"],
                "value": float(row["value"]),
                "source": source,
            })
    return observations


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
    snapshot = dict(row) if row else {}
    if snapshot:
        poa_observations = _get_poa_observations(db, country_iso3, pillar_code, year)
        if poa_observations:
            snapshot["poa_observations"] = poa_observations
    return snapshot


# ── Etape 1 : generation des 9 analyses primaires ────────────────────────────

@router.post(
    "/visions/{vision_id}/generate-analysis-drafts",
    summary="Générer les 9 analyses primaires (IA) à partir des vraies données ISA+POA du pilier",
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
        schema = model_cls.model_json_schema()
        schema_json = json.dumps(schema, ensure_ascii=False)
        vocabulary = _extract_controlled_vocabulary(schema)

        method_specific_rules = ""
        if method == "MULTICRITERE":
            method_specific_rules = MULTICRITERE_SPECIFIC_RULE.format(bounded_fields=", ".join(BOUNDED_SCORE_FIELDS))

        system_prompt = PRIMARY_ANALYSIS_SYSTEM_PROMPT.format(
            method=method,
            data_snapshot=snapshot_json,
            vocabulary=vocabulary,
            schema=schema_json,
            method_specific_rules=method_specific_rules,
        )

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


# ── Etape 2a : levier strategique (catalogue partage mg.strategic_levers) ────
# Correctif du 5 aout 2026 (echec reel) : mg.strategic_levers est le
# CATALOGUE PARTAGE existant (Sprint OIM Lot 1/2) -- l'IA ne genere
# jamais de contenu libre par vision dans cette table, seulement une
# PROPOSITION (mg.strategic_lever_proposals), qui a la promotion cree le
# lever_code au catalogue s'il est nouveau, puis lie l'analyse 5_POURQUOI
# via mg.root_cause_levers.

@router.post(
    "/visions/{vision_id}/generate-strategic-lever-draft",
    summary="Générer une proposition de levier stratégique (IA) à partir des 9 analyses déjà promues",
    description="Réutilise le catalogue partagé (mg.strategic_levers) si pertinent, propose un nouveau code sinon. Réservé aux visions dont les 9 méthodes primaires sont déjà PROMOTED.",
)
def generate_strategic_lever_draft(
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
            SELECT id, method, content FROM osoa.strategic_analyses
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

    pourquoi_analysis = next(r for r in promoted if r["method"] == "5_POURQUOI")

    analyses_content = {r["method"]: r["content"] for r in promoted}
    analyses_json = json.dumps(analyses_content, ensure_ascii=False, default=str)

    catalog_rows = db.execute(
        text("SELECT lever_code, label_fr, description_fr FROM rf.strategic_levers WHERE is_active = true"),
    ).mappings().all()
    catalog_json = json.dumps([dict(r) for r in catalog_rows], ensure_ascii=False)

    schema = ContentStrategicLever.model_json_schema()
    schema_json = json.dumps(schema, ensure_ascii=False)
    system_prompt = LEVER_SYSTEM_PROMPT.format(existing_catalog=catalog_json, analyses_content=analyses_json, schema=schema_json)

    try:
        parsed = _call_ai(system_prompt, analyses_json)
        validated = ContentStrategicLever(**parsed)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=502, detail={
            "fr": f"Échec de la génération IA (levier stratégique) : {e}",
            "en": f"AI generation failed (strategic lever): {e}",
        })

    row = db.execute(
        text("""
            INSERT INTO mg.strategic_lever_proposals
                (vision_id, source_analysis_id, proposed_lever_code, reuses_existing_code,
                 label_fr, label_en, description_fr, description_en, relevance_weight, created_by)
            VALUES
                (:vision_id, :source_analysis_id, :proposed_lever_code, :reuses_existing_code,
                 :label_fr, :label_en, :description_fr, :description_en, :relevance_weight, :created_by)
            RETURNING id, vision_id, source_analysis_id, proposed_lever_code, reuses_existing_code,
                      label_fr, label_en, description_fr, description_en, relevance_weight, status, created_at::text
        """),
        {
            "vision_id": vision_id,
            "source_analysis_id": pourquoi_analysis["id"],
            "proposed_lever_code": validated.lever_code,
            "reuses_existing_code": validated.reuses_existing_code,
            "label_fr": validated.label_fr,
            "label_en": validated.label_en,
            "description_fr": validated.description_fr,
            "description_en": validated.description_en,
            "relevance_weight": validated.relevance_weight,
            "created_by": affiliate_id,
        },
    ).mappings().first()
    db.commit()

    return dict(row)


@router.get("/visions/{vision_id}/strategic-levers", summary="Lister les propositions de levier d'une vision")
def list_strategic_levers(vision_id: int, db: Session = Depends(get_db)):
    rows = db.execute(
        text("""
            SELECT id, vision_id, source_analysis_id, proposed_lever_code, reuses_existing_code,
                   label_fr, label_en, description_fr, description_en, relevance_weight, status, created_at::text
            FROM mg.strategic_lever_proposals WHERE vision_id = :vision_id ORDER BY created_at
        """),
        {"vision_id": vision_id},
    ).mappings().all()
    return {"count": len(rows), "items": [dict(r) for r in rows]}


class StrategicLeverValidate(BaseModel):
    label_fr: Optional[str] = None
    label_en: Optional[str] = None
    description_fr: Optional[str] = None
    description_en: Optional[str] = None
    proposed_lever_code: Optional[str] = None
    relevance_weight: Optional[float] = None


@router.post("/strategic-lever-proposals/{proposal_id}/validate", summary="Valider (et éventuellement corriger) une proposition de levier")
def validate_strategic_lever(
    proposal_id: int,
    data: StrategicLeverValidate,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    proposal = db.execute(
        text("SELECT id, status FROM mg.strategic_lever_proposals WHERE id = :id"),
        {"id": proposal_id},
    ).mappings().first()
    if not proposal:
        raise HTTPException(status_code=404, detail={"fr": "Proposition introuvable.", "en": "Proposal not found."})
    if proposal["status"] == "PROMOTED":
        raise HTTPException(status_code=409, detail={
            "fr": "Cette proposition a déjà été promue.",
            "en": "This proposal has already been promoted.",
        })

    updates = {"id": proposal_id}
    set_clauses = ["status = 'HUMAN_VALIDATED'", "updated_at = NOW()"]
    for field in ("label_fr", "label_en", "description_fr", "description_en", "proposed_lever_code", "relevance_weight"):
        value = getattr(data, field)
        if value is not None:
            set_clauses.append(f"{field} = :{field}")
            updates[field] = value

    row = db.execute(
        text(f"""
            UPDATE mg.strategic_lever_proposals SET {', '.join(set_clauses)}
            WHERE id = :id
            RETURNING id, proposed_lever_code, reuses_existing_code, label_fr, label_en,
                      description_fr, description_en, relevance_weight, status
        """),
        updates,
    ).mappings().first()
    db.commit()
    return dict(row)


@router.post(
    "/strategic-lever-proposals/{proposal_id}/promote",
    summary="Promouvoir une proposition de levier validée -- crée le lever_code au catalogue si nouveau, lie l'analyse via mg.root_cause_levers",
)
def promote_strategic_lever_proposal(
    proposal_id: int,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    proposal = db.execute(
        text("""
            SELECT id, source_analysis_id, proposed_lever_code, reuses_existing_code,
                   label_fr, label_en, description_fr, description_en, relevance_weight, status
            FROM mg.strategic_lever_proposals WHERE id = :id
        """),
        {"id": proposal_id},
    ).mappings().first()
    if not proposal:
        raise HTTPException(status_code=404, detail={"fr": "Proposition introuvable.", "en": "Proposal not found."})
    if proposal["status"] != "HUMAN_VALIDATED":
        raise HTTPException(status_code=422, detail={
            "fr": "Seule une proposition HUMAN_VALIDATED peut être promue.",
            "en": "Only a HUMAN_VALIDATED proposal can be promoted.",
        })

    lever_code = proposal["proposed_lever_code"]
    existing = db.execute(
        text("SELECT lever_code FROM rf.strategic_levers WHERE lever_code = :code"),
        {"code": lever_code},
    ).mappings().first()

    if proposal["reuses_existing_code"]:
        if not existing:
            raise HTTPException(status_code=422, detail={
                "fr": f"lever_code '{lever_code}' marqué comme réutilisé mais introuvable dans le catalogue.",
                "en": f"lever_code '{lever_code}' marked as reused but not found in catalog.",
            })
    else:
        if not existing:
            db.execute(
                text("""
                    INSERT INTO rf.strategic_levers (lever_code, label_fr, label_en, description_fr, description_en)
                    VALUES (:lever_code, :label_fr, :label_en, :description_fr, :description_en)
                """),
                {
                    "lever_code": lever_code,
                    "label_fr": proposal["label_fr"],
                    "label_en": proposal["label_en"],
                    "description_fr": proposal["description_fr"],
                    "description_en": proposal["description_en"],
                },
            )

    analysis = db.execute(
        text("SELECT method FROM osoa.strategic_analyses WHERE id = :id"),
        {"id": proposal["source_analysis_id"]},
    ).mappings().first()
    evidence_type = analysis["method"] if analysis else "5_POURQUOI"

    try:
        db.execute(
            text("""
                INSERT INTO mg.lever_evidence (lever_code, analysis_id, evidence_type, relevance_weight)
                VALUES (:lever_code, :analysis_id, :evidence_type, :relevance_weight)
            """),
            {
                "lever_code": lever_code,
                "analysis_id": proposal["source_analysis_id"],
                "evidence_type": evidence_type,
                "relevance_weight": proposal["relevance_weight"],
            },
        )
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=409, detail={
            "fr": f"Erreur à la liaison cause racine <-> levier : {e}",
            "en": f"Error linking root cause to lever: {e}",
        })

    row = db.execute(
        text("""
            UPDATE mg.strategic_lever_proposals SET status = 'PROMOTED', updated_at = NOW()
            WHERE id = :id
            RETURNING id, proposed_lever_code, status
        """),
        {"id": proposal_id},
    ).mappings().first()
    db.commit()

    return dict(row)


# ── Etape 2b : interdependance niveau VISION, basee sur le levier promu ──────

@router.post(
    "/visions/{vision_id}/generate-interdependance-draft",
    summary="Générer le brouillon INTERDEPENDANCE niveau Vision (IA), à partir du levier stratégique promu",
    description="Réservé aux visions dont un levier stratégique est déjà PROMOTED (lié via mg.root_cause_levers). Évalue les effets possibles du levier sur d'autres piliers -- jamais une relation directe entre deux piliers.",
)
def generate_interdependance_draft(
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

    pourquoi_analysis = db.execute(
        text("""
            SELECT id FROM osoa.strategic_analyses
            WHERE vision_id = :vision_id AND method = '5_POURQUOI'
            ORDER BY created_at DESC LIMIT 1
        """),
        {"vision_id": vision_id},
    ).mappings().first()
    if not pourquoi_analysis:
        raise HTTPException(status_code=422, detail={
            "fr": "Aucune analyse 5_POURQUOI promue pour cette vision.",
            "en": "No promoted 5_POURQUOI analysis for this vision.",
        })

    lever = db.execute(
        text("""
            SELECT sl.lever_code, sl.label_fr, sl.description_fr
            FROM mg.lever_evidence le
            JOIN rf.strategic_levers sl ON sl.lever_code = le.lever_code
            WHERE le.analysis_id = :analysis_id
            ORDER BY le.relevance_weight DESC LIMIT 1
        """),
        {"analysis_id": pourquoi_analysis["id"]},
    ).mappings().first()
    if not lever:
        raise HTTPException(status_code=422, detail={
            "fr": "Aucun levier stratégique promu (mg.lever_evidence) pour cette vision -- générez et promouvez un levier d'abord.",
            "en": "No promoted strategic lever (mg.lever_evidence) for this vision -- generate and promote a lever first.",
        })

    promoted = db.execute(
        text("""
            SELECT method, content FROM osoa.strategic_analyses
            WHERE vision_id = :vision_id AND method = ANY(:methods)
        """),
        {"vision_id": vision_id, "methods": PRIMARY_METHODS},
    ).mappings().all()
    analyses_content = {r["method"]: r["content"] for r in promoted}
    analyses_json = json.dumps(analyses_content, ensure_ascii=False, default=str)

    model_cls = METHOD_MODELS["INTERDEPENDANCE"]
    schema = model_cls.model_json_schema()
    schema_json = json.dumps(schema, ensure_ascii=False)
    vocabulary = _extract_controlled_vocabulary(schema)
    system_prompt = VISION_INTERDEPENDANCE_SYSTEM_PROMPT.format(
        primary_pillar_code=vision["pillar_code"],
        strategic_lever_code=lever["lever_code"],
        strategic_lever_label=lever["label_fr"],
        strategic_lever_description=lever["description_fr"],
        analyses_content=analyses_json,
        vocabulary=vocabulary,
        schema=schema_json,
    )

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


# ── Etape 3 : interdependance niveau PLAN D'ACTION, sur un projet reel ───────

@router.post(
    "/projects/{project_code}/generate-interdependance-draft",
    summary="Générer le brouillon d'interdépendance des interventions (IA), sur un projet réel promu",
    description="Réservé aux projets existants dans rf.sovereign_project_catalog. Évalue les effets attendus de CE projet réel sur d'autres piliers.",
)
def generate_project_interdependance_draft(
    project_code: str,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    affiliate_id = int(payload["sub"])

    project = db.execute(
        text("""
            SELECT project_code, pillar_code, project_name, project_description, strategic_objective
            FROM rf.sovereign_project_catalog WHERE project_code = :project_code
        """),
        {"project_code": project_code},
    ).mappings().first()
    if not project:
        raise HTTPException(status_code=404, detail={"fr": "Projet introuvable.", "en": "Project not found."})

    schema = ContentInterventionInterdependance.model_json_schema()
    schema_json = json.dumps(schema, ensure_ascii=False)
    vocabulary = _extract_controlled_vocabulary(schema)
    system_prompt = PROJECT_INTERDEPENDANCE_SYSTEM_PROMPT.format(
        primary_pillar_code=project["pillar_code"],
        project_code=project["project_code"],
        project_name=project["project_name"],
        project_description=project["project_description"],
        strategic_objective=project["strategic_objective"],
        vocabulary=vocabulary,
        schema=schema_json,
    )

    project_context = json.dumps(dict(project), ensure_ascii=False, default=str)

    try:
        parsed = _call_ai(system_prompt, project_context)
        validated = ContentInterventionInterdependance(**parsed)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=502, detail={
            "fr": f"Échec de la génération IA (interdépendance des interventions) : {e}",
            "en": f"AI generation failed (intervention interdependence): {e}",
        })

    row = db.execute(
        text("""
            INSERT INTO mg.project_interdependence_drafts (project_code, content, created_by)
            VALUES (:project_code, CAST(:content AS jsonb), :created_by)
            RETURNING id, project_code, content, status, created_at::text
        """),
        {
            "project_code": project_code,
            "content": validated.model_dump_json(),
            "created_by": affiliate_id,
        },
    ).mappings().first()
    db.commit()

    return dict(row)


@router.get("/projects/{project_code}/interdependence-drafts", summary="Lister les brouillons d'interdépendance d'un projet")
def list_project_interdependence_drafts(project_code: str, db: Session = Depends(get_db)):
    rows = db.execute(
        text("""
            SELECT id, project_code, content, status, created_at::text
            FROM mg.project_interdependence_drafts WHERE project_code = :project_code ORDER BY created_at
        """),
        {"project_code": project_code},
    ).mappings().all()
    return {"count": len(rows), "items": [dict(r) for r in rows]}


class ProjectInterdependenceValidate(BaseModel):
    content: Optional[dict] = None


@router.post("/project-interdependence-drafts/{draft_id}/validate", summary="Valider (et éventuellement corriger) un brouillon d'interdépendance de projet")
def validate_project_interdependence_draft(
    draft_id: int,
    data: ProjectInterdependenceValidate,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    draft = db.execute(
        text("SELECT id FROM mg.project_interdependence_drafts WHERE id = :id"),
        {"id": draft_id},
    ).mappings().first()
    if not draft:
        raise HTTPException(status_code=404, detail={"fr": "Brouillon introuvable.", "en": "Draft not found."})

    if data.content is not None:
        try:
            validated = ContentInterventionInterdependance(**data.content)
        except Exception as e:
            raise HTTPException(status_code=422, detail={
                "fr": f"Contenu corrigé invalide : {e}",
                "en": f"Corrected content invalid: {e}",
            })
        row = db.execute(
            text("""
                UPDATE mg.project_interdependence_drafts
                SET content = CAST(:content AS jsonb), status = 'HUMAN_VALIDATED', updated_at = NOW()
                WHERE id = :id
                RETURNING id, project_code, content, status
            """),
            {"content": validated.model_dump_json(), "id": draft_id},
        ).mappings().first()
    else:
        row = db.execute(
            text("""
                UPDATE mg.project_interdependence_drafts
                SET status = 'HUMAN_VALIDATED', updated_at = NOW()
                WHERE id = :id
                RETURNING id, project_code, content, status
            """),
            {"id": draft_id},
        ).mappings().first()

    db.commit()
    return dict(row)


# ── Les deux agents IA d'OIM, nommes le 6 aout 2026 (Theo) ──────────────────
# SCRIBE (redacteur) : genere les 9 analyses primaires, le levier, les
#   interdependances, les resumes, les actions -- transcrit fidelement les
#   vraies donnees, n'invente jamais (PRIMARY_ANALYSIS_SYSTEM_PROMPT et les
#   autres prompts de generation deja construits jouent ce role).
# THEO (reviseur) : juge un brouillon deja produit par SCRIBE contre les
#   vraies donnees et la doctrine -- ne rediges JAMAIS lui-meme, critique
#   seulement, avec la meme rigueur que Theo appliquerait lui-meme.

REVIEWER_SYSTEM_PROMPT = """Tu es THEO, un REVISEUR SCIENTIFIQUE independant -- tu ne rediges JAMAIS
toi-meme, tu juges une analyse deja produite par SCRIBE (l'agent
redacteur d'OIM), contre les vraies donnees et EXACTEMENT les memes
contraintes que SCRIBE a recues -- jamais des regles approximatives,
les memes que celles imposees au redacteur.

Donnees reelles du pilier (source de verite, jamais a contredire) :
{data_snapshot}

Vocabulaire controle qui etait IMPOSE a SCRIBE (verifie que chaque champ
concerne respecte EXACTEMENT l'une de ces valeurs, aucune autre) :
{vocabulary}

Schema JSON qui etait IMPOSE a SCRIBE :
{schema}
{method_specific_rules}
Analyse produite par SCRIBE, a evaluer (methode {method}) :
{analysis_content}

Regles imperatives a verifier :
- Chaque champ a vocabulaire controle (liste ci-dessus) respecte-t-il
  EXACTEMENT l'une des valeurs autorisees ? Signale toute deviation.
- Vocabulaire mesure : signale tout adjectif absolu ou promotionnel
  (indeniable, majeur, enorme).
- Chaque affirmation doit etre etayee par les donnees reelles fournies
  ci-dessus -- signale toute affirmation qui semble inventee ou non
  reliee aux donnees.
- Coherence interne (l'analyse ne se contredit pas elle-meme).
- Si poa_observations est present dans les donnees, verifie qu'il est
  bien pris en compte si pertinent pour cette methode.

Verdicts possibles :
- CONFORME : respecte toutes les regles et le vocabulaire controle,
  peut etre valide tel quel par un humain sans correction.
- A_REVOIR : probleme mineur, une relecture humaine rapide suffit.
- PROBLEME_DETECTE : probleme serieux (invention non etayee, incoherence
  majeure, vocabulaire absolu, deviation du vocabulaire controle) --
  regeneration recommandee.

Reponds UNIQUEMENT en JSON valide, sans aucun texte avant ou apres, au
format exact : {{"review_status": "...", "review_comment_fr": "..."}}
"""


# ── Reviseur : juge un brouillon sans jamais le re-rediger ───────────────────

@router.post(
    "/analysis-drafts/{draft_id}/review",
    summary="Faire évaluer un brouillon par le réviseur IA (juge, ne rédige jamais)",
)
def review_analysis_draft(
    draft_id: int,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    draft = db.execute(
        text("SELECT id, vision_id, method, content FROM mg.pillar_analysis_drafts WHERE id = :id"),
        {"id": draft_id},
    ).mappings().first()
    if not draft:
        raise HTTPException(status_code=404, detail={"fr": "Brouillon introuvable.", "en": "Draft not found."})

    vision = db.execute(
        text("SELECT country_iso3, pillar_code, year FROM mg.pillar_strategic_vision WHERE id = :id"),
        {"id": draft["vision_id"]},
    ).mappings().first()
    snapshot = _get_pillar_data_snapshot(db, vision["country_iso3"], vision["pillar_code"], vision["year"])
    snapshot_json = json.dumps(snapshot, ensure_ascii=False, default=str)
    content_json = json.dumps(draft["content"], ensure_ascii=False, default=str)

    method = draft["method"]
    model_cls = METHOD_MODELS[method]
    schema = model_cls.model_json_schema()
    schema_json = json.dumps(schema, ensure_ascii=False)
    vocabulary = _extract_controlled_vocabulary(schema)
    method_specific_rules = ""
    if method == "MULTICRITERE":
        method_specific_rules = "\nRegle specifique MULTICRITERE qui etait imposee a SCRIBE :\n" + MULTICRITERE_SPECIFIC_RULE.format(bounded_fields=", ".join(BOUNDED_SCORE_FIELDS))

    system_prompt = REVIEWER_SYSTEM_PROMPT.format(
        data_snapshot=snapshot_json, method=method, analysis_content=content_json,
        schema=schema_json, vocabulary=vocabulary, method_specific_rules=method_specific_rules,
    )

    try:
        parsed = _call_ai(system_prompt, content_json)
        validated = ContentAnalysisReview(**parsed)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=502, detail={
            "fr": f"Échec de la révision IA : {e}",
            "en": f"AI review failed: {e}",
        })

    row = db.execute(
        text("""
            INSERT INTO mg.analysis_review (draft_id, review_status, review_comment_fr)
            VALUES (:draft_id, :status, :comment)
            RETURNING id, draft_id, review_status, review_comment_fr, created_at::text
        """),
        {"draft_id": draft_id, "status": validated.review_status, "comment": validated.review_comment_fr},
    ).mappings().first()
    db.commit()

    return dict(row)


@router.post(
    "/visions/{vision_id}/review-all-drafts",
    summary="Faire évaluer par le réviseur IA tous les brouillons AI_DRAFTED d'une vision",
)
def review_all_drafts(
    vision_id: int,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    drafts = db.execute(
        text("SELECT id FROM mg.pillar_analysis_drafts WHERE vision_id = :vision_id AND status = 'AI_DRAFTED'"),
        {"vision_id": vision_id},
    ).mappings().all()

    results = []
    for d in drafts:
        try:
            result = review_analysis_draft(d["id"], payload, db)
            results.append(result)
        except HTTPException as e:
            results.append({"draft_id": d["id"], "error": e.detail})

    return {"count": len(results), "items": results}


# ── Regeneration corrective a partir de la critique du reviseur ──────────────

@router.post(
    "/analysis-drafts/{draft_id}/regenerate",
    summary="Régénérer un brouillon en intégrant la dernière critique du réviseur",
    description="Réservé aux brouillons ayant au moins une revue (review_status != CONFORME idéalement). La critique est injectée explicitement dans le prompt.",
)
def regenerate_analysis_draft(
    draft_id: int,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    affiliate_id = int(payload["sub"])

    draft = db.execute(
        text("SELECT id, vision_id, method FROM mg.pillar_analysis_drafts WHERE id = :id"),
        {"id": draft_id},
    ).mappings().first()
    if not draft:
        raise HTTPException(status_code=404, detail={"fr": "Brouillon introuvable.", "en": "Draft not found."})

    latest_review = db.execute(
        text("""
            SELECT review_status, review_comment_fr FROM mg.analysis_review
            WHERE draft_id = :draft_id ORDER BY created_at DESC LIMIT 1
        """),
        {"draft_id": draft_id},
    ).mappings().first()
    if not latest_review:
        raise HTTPException(status_code=422, detail={
            "fr": "Aucune revue disponible pour ce brouillon -- faites-le évaluer d'abord (POST .../review).",
            "en": "No review available for this draft -- have it evaluated first (POST .../review).",
        })

    vision = db.execute(
        text("SELECT country_iso3, pillar_code, year FROM mg.pillar_strategic_vision WHERE id = :id"),
        {"id": draft["vision_id"]},
    ).mappings().first()
    snapshot = _get_pillar_data_snapshot(db, vision["country_iso3"], vision["pillar_code"], vision["year"])
    if not snapshot:
        raise HTTPException(status_code=422, detail={
            "fr": "Aucune donnée ISA observée -- régénération impossible sans donnée réelle.",
            "en": "No observed ISA data -- regeneration impossible without real data.",
        })
    snapshot_json = json.dumps(snapshot, ensure_ascii=False, default=str)

    method = draft["method"]
    model_cls = METHOD_MODELS[method]
    schema = model_cls.model_json_schema()
    schema_json = json.dumps(schema, ensure_ascii=False)
    vocabulary = _extract_controlled_vocabulary(schema)
    method_specific_rules = ""
    if method == "MULTICRITERE":
        method_specific_rules = MULTICRITERE_SPECIFIC_RULE.format(bounded_fields=", ".join(BOUNDED_SCORE_FIELDS))

    base_prompt = PRIMARY_ANALYSIS_SYSTEM_PROMPT.format(
        method=method, data_snapshot=snapshot_json, vocabulary=vocabulary,
        schema=schema_json, method_specific_rules=method_specific_rules,
    )
    feedback_note = (
        "\n\nCORRECTION REQUISE -- THEO (le reviseur scientifique) a "
        "evalue une version precedente et signale : "
        f"\"{latest_review['review_comment_fr']}\". Corrige precisement "
        "ce point dans cette nouvelle version, sans repeter les memes "
        "defauts."
    )
    system_prompt = base_prompt + feedback_note

    try:
        parsed = _call_ai(system_prompt, snapshot_json)
        validated = model_cls(**parsed)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=502, detail={
            "fr": f"Échec de la régénération IA : {e}",
            "en": f"AI regeneration failed: {e}",
        })

    row = db.execute(
        text("""
            UPDATE mg.pillar_analysis_drafts
            SET content = CAST(:content AS jsonb), status = 'AI_DRAFTED', updated_at = NOW()
            WHERE id = :id
            RETURNING id, vision_id, method, content, status, created_at::text
        """),
        {"content": validated.model_dump_json(), "id": draft_id},
    ).mappings().first()
    db.commit()

    return dict(row)


# ── Validation groupee du CONFORME -- acte humain deliberer, jamais cache ────

@router.post(
    "/visions/{vision_id}/bulk-validate-conforme",
    summary="Valider en masse tous les brouillons jugés CONFORME par le réviseur",
    description="Acte humain explicite (appeler cet endpoint = décision consciente de faire confiance au réviseur pour les brouillons CONFORME) -- jamais un automatisme caché.",
)
def bulk_validate_conforme(
    vision_id: int,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    rows = db.execute(
        text("""
            SELECT DISTINCT ON (ar.draft_id) ar.draft_id, ar.review_status, pad.status AS draft_status
            FROM mg.analysis_review ar
            JOIN mg.pillar_analysis_drafts pad ON pad.id = ar.draft_id
            WHERE pad.vision_id = :vision_id AND pad.status = 'AI_DRAFTED'
            ORDER BY ar.draft_id, ar.created_at DESC
        """),
        {"vision_id": vision_id},
    ).mappings().all()

    validated_ids = []
    for row in rows:
        if row["review_status"] != "CONFORME":
            continue
        db.execute(
            text("UPDATE mg.pillar_analysis_drafts SET status = 'HUMAN_VALIDATED', updated_at = NOW() WHERE id = :id"),
            {"id": row["draft_id"]},
        )
        validated_ids.append(row["draft_id"])

    db.commit()
    return {"validated_count": len(validated_ids), "validated_draft_ids": validated_ids}
