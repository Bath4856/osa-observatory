"""
OSA Observatory -- OIM, generation automatique des analyses de vision
api/routers/oim_analysis_gen.py

Chantier prioritaire du 4 aout 2026 : automatiser la generation des 9
analyses primaires (5W1H, SWOT, ZACHMAN, RISQUE, ECONOMIQUE, GOUVERNANCE,
MULTICRITERE, FAISABILITE, 5_POURQUOI) par pays+pilier, a partir des
vraies donnees ISA/POA (ma.mv_isa_observed_scores_by_pillar +
ma.mv_p7i_risk_source) -- condition prealable a tout lancement en masse
(540 visions/an). Cf. ADR-011 (roadmap V1-V6, registre de maturite des
briques scientifiques) -- ce fichier implemente OIM V1.

INTERDEPENDANCE (10eme methode) traitee separement, en 2 temps (Theo,
4 aout 2026, suite a l'echec reel du premier test) :
1. DETECTEUR DE CANDIDATS (deterministe, jamais le LLM) -- compare ce
   pilier aux 9 autres piliers du MEME pays+annee sur des donnees ISA
   REELLES (forecast_trend_class, strategic_risk_score partages) --
   heuristique de premiere generation, a affiner en V6 (cf. ADR-011,
   POA/GAP encore trop immatures pour une vraie correlation).
2. Le LLM REDIGE une synthese a partir de ces candidats REELS + du
   contenu des 9 analyses deja PROMOTED -- jamais a partir de rien.
Le schema ContentInterdependance est a 4 etats (analysis_status) :
l'absence de relation demontree est un resultat scientifique valide,
jamais force par le schema (cf. commit du 4 aout 2026 sur osoa.py).

Reutilise METHOD_MODELS (schema JSON automatique via model_json_schema(),
pas de prompt ecrit a la main par methode) et VALID_METHODS de osoa.py.

PROMPT DES 9 PRIMAIRES EN 5 ETAPES (structure proposee par Theo le 4 aout
2026) : donnees -> vocabulaire autorise (extrait automatiquement du
schema via scan des enum/$defs, jamais ecrit a la main) -> schema JSON ->
regles imperatives -> reponse JSON seule.
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

# MULTICRITERE -- ne jamais laisser le LLM inventer une transformation
# indicateur -> score. Seuls les champs deja bornes [0,1] par construction
# (des scores/taux reels, jamais une pente ou un delta) sont eligibles
# comme "score" d'un critere. Chantier futur note par Theo : une vraie
# couche de transformation normee OSA (indicateur -> transformation ->
# score) reste a construire -- ceci est un garde-fou minimal en attendant.
BOUNDED_SCORE_FIELDS = (
    "isa_observed_score", "sovereignty_observed_score",
    "vulnerability_observed_score", "resilience_observed_score",
    "strategic_risk_score", "strategic_upside_score", "data_completeness",
)

# Seuil documente (pas invente par le LLM) pour le detecteur de candidats
# d'interdependance -- a affiner en V6 quand POA/GAP seront matures.
INTERDEPENDANCE_RISK_THRESHOLD = 0.4

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

INTERDEPENDANCE_SYSTEM_PROMPT = """Tu evalues l'existence eventuelle d'une interdependance entre ce pilier et
un autre pilier du MEME pays -- tu ne "trouves" pas une relation, tu
"evalues" si une relation CAUSALE est demontrable a partir des preuves
disponibles. L'absence de relation ou de preuve suffisante est un
resultat scientifique parfaitement valide -- n'invente JAMAIS une
relation pour satisfaire le schema.

ETAPE 0 -- Contexte fige (a utiliser tel quel, jamais invente) :
country_iso3 = "{country_iso3}"
pillar_code (ce pilier) = "{pillar_code}"

ETAPE 1 -- Candidats identifies par OSA (donnees ISA reelles et
deterministes -- OSA identifie les candidats possibles, toi tu redige,
tu n'inventes jamais un candidat qui n'est pas dans cette liste) :
{candidates}

ETAPE 2 -- Contenu des 9 analyses primaires deja validees pour ce pilier
(utilise-les pour etayer ou nuancer les candidats de l'ETAPE 1) :
{analyses_content}

ETAPE 3 -- Vocabulaire controle autorise (OBLIGATOIRE) :
{vocabulary}

ETAPE 4 -- Schema JSON exact a respecter :
{schema}

ETAPE 5 -- Regles imperatives, DISTINCTION CORRELATION / CAUSALITE
(critique -- decision de Theo du 4 aout 2026, suite a un test reel ou le
moteur a conclu a tort une relation a partir d'une simple co-occurrence
de faiblesse) :
- Une CORRELATION D'ETAT (deux piliers presentant simultanement un
  risque eleve ou une tendance similaire) N'EST PAS une preuve de
  relation causale. Elle demontre seulement que deux piliers sont
  fragiles en meme temps -- jamais que l'un influence l'autre. Les
  candidats de l'ETAPE 1 sont des candidats a INVESTIGUER, jamais des
  relations demontrees.
- basis_type=AI_PREDICTIVE_ESTIMATE signale PAR CONSTRUCTION une preuve
  faible (aucune correlation statistique reelle calculee, aucun POA/GAP
  commun disponible, aucune decision du Comite Scientifique). Dans ce
  cas, analysis_status DOIT presque toujours etre DONNEES_INSUFFISANTES,
  JAMAIS RELATION_IDENTIFIEE -- sauf si le contenu des 9 analyses
  (ETAPE 2) revele un vrai MECANISME causal explicite et argumente
  (ex. "la rupture de tracabilite du pilier X oblige le recours au
  systeme numerique du pilier Y"), jamais une simple co-occurrence de
  faiblesse ou de risque.
- Aujourd'hui, les referentiels POA et GAP ne sont pas encore peuples
  (cf. doctrine OSA, roadmap de maturation des briques scientifiques).
  DONNEES_INSUFFISANTES est donc le resultat ATTENDU et scientifiquement
  le plus honnete dans la grande majorite des cas -- ce n'est jamais un
  echec de l'analyse, c'est une conclusion scientifique valide en soi.
- Si analysis_status = RELATION_IDENTIFIEE malgre tout, source_pillar_code
  ou target_pillar_code DOIT correspondre a un candidat reel de l'ETAPE 1,
  jamais un pilier absent de cette liste.
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


def _find_interdependance_candidates(db: Session, country_iso3: str, pillar_code: str, year: int) -> list:
    """Detecteur heuristique de candidats d'interdependance -- DETERMINISTE,
    jamais le LLM (doctrine actee le 4 aout 2026 : OSA identifie les
    candidats a partir de donnees reelles, le LLM redige seulement).
    Compare ce pilier aux 9 AUTRES piliers du MEME pays+annee, sur des
    donnees ISA REELLES deja existantes (contrairement a POA/GAP, encore
    vides -- cf. ADR-011, brique Interdependance classee EXPERIMENTATION).
    Un pilier est candidat s'il partage la meme classe de tendance
    (forecast_trend_class) OU s'il a lui aussi un risque strategique eleve
    (>= INTERDEPENDANCE_RISK_THRESHOLD, seuil documente, pas invente par
    le LLM). Heuristique de premiere generation -- a affiner en V6."""
    this_pillar = db.execute(
        text("""
            SELECT forecast_trend_class, strategic_risk_score
            FROM ma.mv_p7i_risk_source
            WHERE country_iso3 = :country_iso3 AND pillar_code = :pillar_code AND year = :year
        """),
        {"country_iso3": country_iso3, "pillar_code": pillar_code, "year": year},
    ).mappings().first()
    if not this_pillar:
        return []

    others = db.execute(
        text("""
            SELECT r.pillar_code, r.forecast_trend_class, r.strategic_risk_score, s.isa_observed_score
            FROM ma.mv_p7i_risk_source r
            JOIN ma.mv_isa_observed_scores_by_pillar s
                ON s.country_iso3 = r.country_iso3 AND s.pillar_code = r.pillar_code AND s.year = r.year
            WHERE r.country_iso3 = :country_iso3 AND r.year = :year AND r.pillar_code != :pillar_code
        """),
        {"country_iso3": country_iso3, "year": year, "pillar_code": pillar_code},
    ).mappings().all()

    candidates = []
    for other in others:
        reasons = []
        if this_pillar["forecast_trend_class"] and other["forecast_trend_class"] == this_pillar["forecast_trend_class"]:
            reasons.append(f"même classe de tendance ({other['forecast_trend_class']})")
        this_risk = this_pillar["strategic_risk_score"]
        other_risk = other["strategic_risk_score"]
        if this_risk is not None and other_risk is not None and this_risk >= INTERDEPENDANCE_RISK_THRESHOLD and other_risk >= INTERDEPENDANCE_RISK_THRESHOLD:
            reasons.append(f"risque stratégique élevé partagé (seuil {INTERDEPENDANCE_RISK_THRESHOLD})")
        if reasons:
            candidates.append({
                "pillar_code": other["pillar_code"],
                "isa_observed_score": float(other["isa_observed_score"]) if other["isa_observed_score"] is not None else None,
                "forecast_trend_class": other["forecast_trend_class"],
                "strategic_risk_score": float(other["strategic_risk_score"]) if other["strategic_risk_score"] is not None else None,
                "reasons": reasons,
            })
    return candidates


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


# ── Etape 2 : synthese INTERDEPENDANCE, a partir des 9 promues + candidats reels ─

@router.post(
    "/visions/{vision_id}/generate-interdependance-draft",
    summary="Générer le brouillon INTERDEPENDANCE (IA) en synthèse des 9 analyses déjà promues + candidats réels",
    description=(
        "Réservé aux visions dont les 9 méthodes primaires sont déjà PROMOTED. "
        "Les candidats sont d'abord identifiés par un détecteur déterministe "
        "(données ISA réelles, jamais le LLM) -- le LLM ne fait que rédiger "
        "la synthèse à partir de ces candidats réels."
    ),
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

    candidates = _find_interdependance_candidates(db, vision["country_iso3"], vision["pillar_code"], vision["year"])
    candidates_json = json.dumps(candidates, ensure_ascii=False, default=str)

    analyses_content = {r["method"]: r["content"] for r in promoted}
    analyses_json = json.dumps(analyses_content, ensure_ascii=False, default=str)

    model_cls = METHOD_MODELS["INTERDEPENDANCE"]
    schema = model_cls.model_json_schema()
    schema_json = json.dumps(schema, ensure_ascii=False)
    vocabulary = _extract_controlled_vocabulary(schema)
    system_prompt = INTERDEPENDANCE_SYSTEM_PROMPT.format(
        country_iso3=vision["country_iso3"],
        pillar_code=vision["pillar_code"],
        candidates=candidates_json,
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
