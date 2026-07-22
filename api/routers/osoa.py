"""
OSA Observatory -- OSOA (OSA Strategic Opportunity Assessment)
api/routers/osoa.py

Premier lot d'endpoints exposant osoa.opportunities (ADR-008, modele de
donnees deploye le 17-18 juillet 2026, jamais expose via API jusqu'ici --
tout teste uniquement en SQL direct via psql). Prefixe /api/v2/osoa,
distinct de /api/v2/opportunities (deja pris par api/routers/opportunities.py,
concept different : pub.mv_isa_opportunity_catalog, catalogue P7Z
d'opportunites d'intervention souveraine, sans rapport avec OSOA).

Doctrine ADR-010 (20 juillet 2026) appliquee, revisee le 20 juillet au soir :
  - Une opportunite EXTERNAL peut naitre avec un client au KYC encore
    PENDING -- la negociation doit pouvoir commencer avant verification
    complete, toujours mediee par un affilie (aucun acces direct client,
    "pas de boite noire"). Le passage PENDING -> VERIFIED intervient a la
    signature/acceptation du contrat (osoa.contracts), endpoint a
    construire -- pas de blocage a la creation de l'opportunite elle-meme.
  - Disclaimer standard requis sur toute sortie publique OIM/OSOA (recommandation
    d'intervention, jamais une amelioration actee) -- inclus dans les
    reponses de lecture (GET).

Authentification : reutilise get_current_affiliate (auth_affiliates.py) --
toute personne affiliee authentifiee peut creer/consulter une opportunite,
pas reserve aux seuls ADMIN (les membres du Collège/Comité Technique portent
couramment les AMI/AO/AOI).
"""
from typing import Optional, List
import json
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import text
from pydantic import BaseModel, Field, model_validator

from api.db import get_db
from api.routers.auth_affiliates import get_current_affiliate

router = APIRouter(
    prefix="/api/v2/osoa",
    tags=["OSOA"],
)

# ── Disclaimer standard OIM/OSOA (ADR-010, symetrique a celui d'AMAR) ─────────
OSOA_DISCLAIMER = {
    "fr": (
        "OSOA est un outil d'aide a la decision d'engagement -- il ne remplace "
        "pas l'evaluation finale des instances competentes. Une recommandation "
        "d'intervention n'equivaut jamais a une amelioration actee : seule une "
        "donnee reellement collectee lors d'un cycle futur peut faire evoluer "
        "l'Indice de Souverainete Africaine (ISA)."
    ),
    "en": (
        "OSOA is a decision-support tool for engagement assessment -- it does "
        "not replace the final evaluation of competent bodies. An intervention "
        "recommendation never equates to an enacted improvement: only data "
        "actually collected in a future cycle can move the African Sovereignty "
        "Index (ISA)."
    ),
}


# ── Schemas ───────────────────────────────────────────────────────────────────

class OpportunityCreate(BaseModel):
    code: str = Field(..., min_length=1, max_length=100, description="Code unique de l'opportunite")
    title_fr: str = Field(..., min_length=1)
    title_en: Optional[str] = None
    origin_type: str = Field(..., description="INTERNAL ou EXTERNAL")
    # Chemin interne (OIM)
    origin_project_family_id: Optional[int] = None
    # Chemin externe (OSOA)
    client_id: Optional[int] = None
    deliverable_id: Optional[int] = None
    participation_mode: Optional[str] = Field(
        None,
        description="Obligatoire si EXTERNAL : PROVIDER (OSA prestataire, cas DP), "
                     "CONSORTIUM_PARTNER (OSA partenaire technique d'un tiers porteur, "
                     "cas AMI/AO/AOI depose par un externe), ou WATCH_ONLY (veille, aucun engagement).",
    )


class OpportunityItem(BaseModel):
    id: int
    code: str
    title_fr: str
    title_en: Optional[str] = None
    origin_type: str
    participation_mode: Optional[str] = None
    current_phase: int
    status: str
    client_id: Optional[int] = None
    deliverable_id: Optional[int] = None
    origin_project_family_id: Optional[int] = None
    created_at: str
    updated_at: str


class OpportunityListResponse(BaseModel):
    disclaimer: dict
    count: int
    items: List[OpportunityItem]


class OpportunityDetailResponse(BaseModel):
    disclaimer: dict
    opportunity: OpportunityItem


# ── Endpoint 1 : creation d'une opportunite ────────────────────────────────────

@router.post(
    "/opportunities",
    summary="Créer une opportunité OSOA (interne OIM ou externe)",
    description=(
        "Crée une opportunité INTERNAL (rattachée à une famille de projets "
        "mg.project_families, chemin OIM) ou EXTERNAL (rattachée à un client "
        "osoa.clients + un livrable gtm.deliverables, chemin OSOA). "
        "Une opportunité EXTERNAL exige un client au KYC déjà VERIFIED -- "
        "création bloquée sinon (ADR-010)."
    ),
)
def create_opportunity(
    data: OpportunityCreate,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    affiliate_id = int(payload["sub"])

    if data.origin_type not in ("INTERNAL", "EXTERNAL"):
        raise HTTPException(status_code=422, detail={
            "fr": "origin_type doit être INTERNAL ou EXTERNAL.",
            "en": "origin_type must be INTERNAL or EXTERNAL.",
        })

    if data.origin_type == "INTERNAL":
        if not data.origin_project_family_id or data.client_id or data.deliverable_id or data.participation_mode:
            raise HTTPException(status_code=422, detail={
                "fr": "Une opportunité INTERNAL exige origin_project_family_id et exclut client_id/deliverable_id/participation_mode.",
                "en": "An INTERNAL opportunity requires origin_project_family_id and excludes client_id/deliverable_id/participation_mode.",
            })
    else:  # EXTERNAL
        if not data.client_id or data.origin_project_family_id:
            raise HTTPException(status_code=422, detail={
                "fr": "Une opportunité EXTERNAL exige client_id, et exclut origin_project_family_id.",
                "en": "An EXTERNAL opportunity requires client_id, and excludes origin_project_family_id.",
            })
        if data.participation_mode not in ("PROVIDER", "CONSORTIUM_PARTNER", "WATCH_ONLY"):
            raise HTTPException(status_code=422, detail={
                "fr": "participation_mode obligatoire pour EXTERNAL : PROVIDER, CONSORTIUM_PARTNER ou WATCH_ONLY.",
                "en": "participation_mode required for EXTERNAL: PROVIDER, CONSORTIUM_PARTNER or WATCH_ONLY.",
            })
        if data.participation_mode == "PROVIDER" and not data.deliverable_id:
            raise HTTPException(status_code=422, detail={
                "fr": "participation_mode=PROVIDER exige deliverable_id (livrable porté par OSA).",
                "en": "participation_mode=PROVIDER requires deliverable_id (deliverable owned by OSA).",
            })
        if data.participation_mode in ("CONSORTIUM_PARTNER", "WATCH_ONLY") and data.deliverable_id:
            raise HTTPException(status_code=422, detail={
                "fr": "deliverable_id doit être vide si OSA n'est pas prestataire principal (CONSORTIUM_PARTNER/WATCH_ONLY).",
                "en": "deliverable_id must be empty if OSA is not the lead provider (CONSORTIUM_PARTNER/WATCH_ONLY).",
            })
        # Pas de blocage KYC a la creation -- une opportunite EXTERNAL peut
        # naitre avec un client encore PENDING, la negociation devant
        # pouvoir commencer avant verification complete. Le passage
        # PENDING -> VERIFIED intervient a la signature/acceptation du
        # contrat (osoa.contracts), endpoint non encore construit a ce
        # jour (decision du 20 juillet 2026, revise le blocage initial a
        # la creation qui etait trop strict).
        client = db.execute(
            text("SELECT id FROM osoa.clients WHERE id = :id"),
            {"id": data.client_id},
        ).mappings().first()
        if not client:
            raise HTTPException(status_code=404, detail={
                "fr": "Client introuvable.",
                "en": "Client not found.",
            })

    try:
        row = db.execute(
            text("""
                INSERT INTO osoa.opportunities
                    (code, title_fr, title_en, origin_type, participation_mode,
                     origin_project_family_id, client_id, deliverable_id, created_by)
                VALUES
                    (:code, :title_fr, :title_en, :origin_type, :participation_mode,
                     :origin_project_family_id, :client_id, :deliverable_id, :created_by)
                RETURNING id, code, title_fr, title_en, origin_type, participation_mode,
                          current_phase, status, client_id, deliverable_id,
                          origin_project_family_id, created_at::text, updated_at::text
            """),
            {
                "code": data.code,
                "title_fr": data.title_fr,
                "title_en": data.title_en,
                "origin_type": data.origin_type,
                "participation_mode": data.participation_mode,
                "origin_project_family_id": data.origin_project_family_id,
                "client_id": data.client_id,
                "deliverable_id": data.deliverable_id,
                "created_by": affiliate_id,
            },
        ).mappings().first()
        db.commit()
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=409, detail={
            "fr": f"Erreur à la création (code déjà utilisé ou référence invalide ?) : {e}",
            "en": f"Creation error (code already used or invalid reference?): {e}",
        })

    return {"disclaimer": OSOA_DISCLAIMER, "opportunity": dict(row)}


# ── Endpoint 2 : consultation d'une opportunite ────────────────────────────────

@router.get(
    "/opportunities/{opportunity_id}",
    summary="Consulter une opportunité OSOA",
    response_model=OpportunityDetailResponse,
)
def get_opportunity(opportunity_id: int, db: Session = Depends(get_db)):
    row = db.execute(
        text("""
            SELECT id, code, title_fr, title_en, origin_type, participation_mode,
                   current_phase, status, client_id, deliverable_id,
                   origin_project_family_id, created_at::text, updated_at::text
            FROM osoa.opportunities
            WHERE id = :id
        """),
        {"id": opportunity_id},
    ).mappings().first()
    if not row:
        raise HTTPException(status_code=404, detail={
            "fr": "Opportunité introuvable.",
            "en": "Opportunity not found.",
        })
    return {"disclaimer": OSOA_DISCLAIMER, "opportunity": dict(row)}


# ── Endpoint 3 : liste des opportunites ────────────────────────────────────────

@router.get(
    "/opportunities",
    summary="Lister les opportunités OSOA",
    response_model=OpportunityListResponse,
    description="Filtrable par statut (ACTIVE/CLOSED/ABANDONED) et/ou origine (INTERNAL/EXTERNAL).",
)
def list_opportunities(
    status: Optional[str] = Query(default=None, description="ACTIVE, CLOSED ou ABANDONED"),
    origin_type: Optional[str] = Query(default=None, description="INTERNAL ou EXTERNAL"),
    participation_mode: Optional[str] = Query(default=None, description="PROVIDER, CONSORTIUM_PARTNER ou WATCH_ONLY"),
    db: Session = Depends(get_db),
):
    sql = """
        SELECT id, code, title_fr, title_en, origin_type, participation_mode,
               current_phase, status, client_id, deliverable_id,
               origin_project_family_id, created_at::text, updated_at::text
        FROM osoa.opportunities
        WHERE 1=1
    """
    params: dict = {}
    if status:
        sql += " AND status = :status"
        params["status"] = status
    if origin_type:
        sql += " AND origin_type = :origin_type"
        params["origin_type"] = origin_type
    if participation_mode:
        sql += " AND participation_mode = :participation_mode"
        params["participation_mode"] = participation_mode
    sql += " ORDER BY created_at DESC"

    rows = db.execute(text(sql), params).mappings().all()
    return {"disclaimer": OSOA_DISCLAIMER, "count": len(rows), "items": [dict(r) for r in rows]}


# ── Devis (osoa.quotes) ────────────────────────────────────────────────────────
# Positionnement dans le tunnel : depot -> etude de faisabilite ->
# DEVIS (ici) -> negociation -> accord -> contrat. N'affecte jamais
# osoa.clients.kyc_status -- ce passage reste reserve a la signature
# du contrat (decision du 20 juillet 2026).

class QuoteCreate(BaseModel):
    strategic_analysis_id: Optional[int] = None
    strategic_deliverable_id: Optional[int] = None
    amount: float = Field(..., ge=0)
    currency: str = Field(..., min_length=3, max_length=3, description="Code devise ISO 4217, ex. XOF, USD, EUR")
    description_fr: Optional[str] = None
    valid_until: Optional[str] = Field(None, description="Date limite de validite, format YYYY-MM-DD")


class QuoteRespond(BaseModel):
    status: str = Field(..., description="ACCEPTED ou REJECTED")


class QuoteItem(BaseModel):
    id: int
    opportunity_id: int
    strategic_analysis_id: Optional[int] = None
    strategic_deliverable_id: Optional[int] = None
    amount: float
    currency: str
    status: str
    description_fr: Optional[str] = None
    valid_until: Optional[str] = None
    proposed_by: Optional[int] = None
    proposed_at: str
    responded_by: Optional[int] = None
    responded_at: Optional[str] = None


@router.post(
    "/opportunities/{opportunity_id}/quotes",
    summary="Proposer un devis pour une opportunité OSOA",
    description=(
        "Crée une proposition chiffrée (étude d'opportunité et/ou de faisabilité "
        "monnayable) rattachée à une opportunité. Statut initial PROPOSED."
    ),
)
def create_quote(
    opportunity_id: int,
    data: QuoteCreate,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    affiliate_id = int(payload["sub"])

    opp = db.execute(
        text("SELECT id FROM osoa.opportunities WHERE id = :id"),
        {"id": opportunity_id},
    ).mappings().first()
    if not opp:
        raise HTTPException(status_code=404, detail={
            "fr": "Opportunité introuvable.",
            "en": "Opportunity not found.",
        })

    if data.strategic_deliverable_id:
        deliverable = db.execute(
            text("SELECT id FROM osoa.strategic_deliverables WHERE id = :id AND opportunity_id = :opp_id"),
            {"id": data.strategic_deliverable_id, "opp_id": opportunity_id},
        ).mappings().first()
        if not deliverable:
            raise HTTPException(status_code=404, detail={
                "fr": "Livrable synthétique introuvable pour cette opportunité.",
                "en": "Strategic deliverable not found for this opportunity.",
            })

    try:
        row = db.execute(
            text("""
                INSERT INTO osoa.quotes
                    (opportunity_id, strategic_analysis_id, strategic_deliverable_id,
                     amount, currency, description_fr, valid_until, proposed_by)
                VALUES
                    (:opportunity_id, :strategic_analysis_id, :strategic_deliverable_id,
                     :amount, :currency, :description_fr, :valid_until, :proposed_by)
                RETURNING id, opportunity_id, strategic_analysis_id, strategic_deliverable_id,
                          amount, currency, status, description_fr, valid_until::text,
                          proposed_by, proposed_at::text, responded_by, responded_at::text
            """),
            {
                "opportunity_id": opportunity_id,
                "strategic_analysis_id": data.strategic_analysis_id,
                "strategic_deliverable_id": data.strategic_deliverable_id,
                "amount": data.amount,
                "currency": data.currency.upper(),
                "description_fr": data.description_fr,
                "valid_until": data.valid_until,
                "proposed_by": affiliate_id,
            },
        ).mappings().first()
        db.commit()
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=409, detail={
            "fr": f"Erreur à la création du devis : {e}",
            "en": f"Error creating quote: {e}",
        })

    return {"disclaimer": OSOA_DISCLAIMER, "quote": dict(row)}


@router.get(
    "/opportunities/{opportunity_id}/quotes",
    summary="Lister les devis d'une opportunité OSOA",
)
def list_quotes(opportunity_id: int, db: Session = Depends(get_db)):
    rows = db.execute(
        text("""
            SELECT id, opportunity_id, strategic_analysis_id, strategic_deliverable_id,
                   amount, currency, status, description_fr, valid_until::text,
                   proposed_by, proposed_at::text, responded_by, responded_at::text
            FROM osoa.quotes
            WHERE opportunity_id = :opportunity_id
            ORDER BY proposed_at DESC
        """),
        {"opportunity_id": opportunity_id},
    ).mappings().all()
    return {"disclaimer": OSOA_DISCLAIMER, "count": len(rows), "items": [dict(r) for r in rows]}


@router.post(
    "/quotes/{quote_id}/respond",
    summary="Répondre à un devis (accepter ou rejeter)",
    description=(
        "Transition de statut PROPOSED -> ACCEPTED ou REJECTED. N'affecte pas "
        "osoa.clients.kyc_status -- ce passage reste reserve a la signature du "
        "contrat, endpoint distinct non encore construit."
    ),
)
def respond_to_quote(
    quote_id: int,
    data: QuoteRespond,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    affiliate_id = int(payload["sub"])

    if data.status not in ("ACCEPTED", "REJECTED"):
        raise HTTPException(status_code=422, detail={
            "fr": "status doit être ACCEPTED ou REJECTED.",
            "en": "status must be ACCEPTED or REJECTED.",
        })

    quote = db.execute(
        text("SELECT id, status FROM osoa.quotes WHERE id = :id"),
        {"id": quote_id},
    ).mappings().first()
    if not quote:
        raise HTTPException(status_code=404, detail={
            "fr": "Devis introuvable.",
            "en": "Quote not found.",
        })
    if quote["status"] != "PROPOSED":
        raise HTTPException(status_code=409, detail={
            "fr": f"Ce devis n'est plus en attente de réponse (statut actuel : {quote['status']}).",
            "en": f"This quote is no longer awaiting a response (current status: {quote['status']}).",
        })

    row = db.execute(
        text("""
            UPDATE osoa.quotes
            SET status = :status, responded_by = :responded_by, responded_at = NOW()
            WHERE id = :id
            RETURNING id, opportunity_id, strategic_analysis_id, strategic_deliverable_id,
                      amount, currency, status, description_fr, valid_until::text,
                      proposed_by, proposed_at::text, responded_by, responded_at::text
        """),
        {"status": data.status, "responded_by": affiliate_id, "id": quote_id},
    ).mappings().first()
    db.commit()

    return {"disclaimer": OSOA_DISCLAIMER, "quote": dict(row)}


# ── Analyses strategiques (osoa.strategic_analyses) ────────────────────────────
# 9 methodes, chacune avec une structure de contenu (content, JSONB) validee
# strictement plutot que libre -- decision du 22 juillet 2026. Le vocabulaire
# de 5_POURQUOI reprend rf.cause_category_5m (deja utilise par ADR-006,
# mg.pillar_5whys_analysis) plutot que d'en inventer un nouveau. ZACHMAN
# reprend la grille 6x6 deja utilisee ailleurs dans le projet (Sprint 8
# validation des sources, Sprint 19 architecture de publication ISA) --
# 6 colonnes (quoi/comment/ou/qui/quand/pourquoi) x 6 perspectives.


VALID_METHODS = (
    "5W1H", "SWOT", "5_POURQUOI", "RISQUE", "FAISABILITE",
    "MULTICRITERE", "ECONOMIQUE", "GOUVERNANCE", "ZACHMAN",
)


class Content5W1H(BaseModel):
    quoi: str
    qui: str
    ou: str
    quand: str
    comment: str
    pourquoi: str


class ContentSWOT(BaseModel):
    forces: List[str] = Field(default_factory=list)
    faiblesses: List[str] = Field(default_factory=list)
    opportunites: List[str] = Field(default_factory=list)
    menaces: List[str] = Field(default_factory=list)


class Niveau5Pourquoi(BaseModel):
    pourquoi: str
    reponse: str


class Content5Pourquoi(BaseModel):
    constat_initial: str
    niveaux: List[Niveau5Pourquoi] = Field(..., min_length=1, max_length=5)
    cause_racine: str
    categorie_5m: str  # validee contre rf.cause_category_5m dans l'endpoint


class RisqueItem(BaseModel):
    description: str
    probabilite: str  # FAIBLE, MOYENNE, ELEVEE
    impact: str  # FAIBLE, MOYEN, ELEVE
    mitigation: Optional[str] = None

    @model_validator(mode="after")
    def _check_values(self):
        if self.probabilite not in ("FAIBLE", "MOYENNE", "ELEVEE"):
            raise ValueError("probabilite doit être FAIBLE, MOYENNE ou ELEVEE")
        if self.impact not in ("FAIBLE", "MOYEN", "ELEVE"):
            raise ValueError("impact doit être FAIBLE, MOYEN ou ELEVE")
        return self


class ContentRisque(BaseModel):
    risques: List[RisqueItem] = Field(..., min_length=1)


class ContentFaisabilite(BaseModel):
    faisabilite_technique: str
    faisabilite_financiere: str
    faisabilite_organisationnelle: str
    delai_estime_jours: int = Field(..., ge=0)
    conclusion: str  # FAVORABLE, DEFAVORABLE, CONDITIONNEL

    @model_validator(mode="after")
    def _check_conclusion(self):
        if self.conclusion not in ("FAVORABLE", "DEFAVORABLE", "CONDITIONNEL"):
            raise ValueError("conclusion doit être FAVORABLE, DEFAVORABLE ou CONDITIONNEL")
        return self


class CritereItem(BaseModel):
    nom: str
    poids: float = Field(..., ge=0, le=1)
    score: float = Field(..., ge=0)
    commentaire: Optional[str] = None


class ContentMulticritere(BaseModel):
    criteres: List[CritereItem] = Field(..., min_length=1)
    score_global: float


class ContentEconomique(BaseModel):
    cout_estime: float = Field(..., ge=0)
    devise: str = Field(..., min_length=3, max_length=3)
    benefices_attendus_fr: str
    retour_sur_investissement_estime: Optional[str] = None
    hypotheses_fr: Optional[str] = None


class ContentGouvernance(BaseModel):
    parties_prenantes: List[str] = Field(..., min_length=1)
    structure_decisionnelle_fr: str
    risques_gouvernance_fr: Optional[str] = None
    mecanisme_supervision_fr: Optional[str] = None


ZACHMAN_PERSPECTIVES = (
    "EXECUTIVE", "BUSINESS_MGMT", "ARCHITECT", "ENGINEER", "TECHNICIAN", "ENTERPRISE",
)


class ZachmanRow(BaseModel):
    perspective: str
    quoi: Optional[str] = None
    comment: Optional[str] = None
    ou: Optional[str] = None
    qui: Optional[str] = None
    quand: Optional[str] = None
    pourquoi: Optional[str] = None

    @model_validator(mode="after")
    def _check_perspective(self):
        if self.perspective not in ZACHMAN_PERSPECTIVES:
            raise ValueError(f"perspective doit être l'une de {ZACHMAN_PERSPECTIVES}")
        return self


class ContentZachman(BaseModel):
    grille: List[ZachmanRow] = Field(..., min_length=6, max_length=6)

    @model_validator(mode="after")
    def _check_all_perspectives_present(self):
        found = {row.perspective for row in self.grille}
        missing = set(ZACHMAN_PERSPECTIVES) - found
        if missing:
            raise ValueError(f"perspectives manquantes dans la grille : {missing}")
        return self


METHOD_MODELS = {
    "5W1H": Content5W1H,
    "SWOT": ContentSWOT,
    "5_POURQUOI": Content5Pourquoi,
    "RISQUE": ContentRisque,
    "FAISABILITE": ContentFaisabilite,
    "MULTICRITERE": ContentMulticritere,
    "ECONOMIQUE": ContentEconomique,
    "GOUVERNANCE": ContentGouvernance,
    "ZACHMAN": ContentZachman,
}


class AnalysisCreate(BaseModel):
    method: str = Field(..., description=f"Une de : {', '.join(VALID_METHODS)}")
    content: dict


@router.post(
    "/opportunities/{opportunity_id}/analyses",
    summary="Créer une analyse stratégique pour une opportunité OSOA",
    description=(
        "Crée une analyse (5W1H, SWOT, 5_POURQUOI, RISQUE, FAISABILITE, "
        "MULTICRITERE, ECONOMIQUE, GOUVERNANCE ou ZACHMAN). Le contenu est "
        "validé strictement selon la méthode choisie, jamais un JSON libre."
    ),
)
def create_analysis(
    opportunity_id: int,
    data: AnalysisCreate,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    affiliate_id = int(payload["sub"])

    if data.method not in VALID_METHODS:
        raise HTTPException(status_code=422, detail={
            "fr": f"method doit être l'une de : {', '.join(VALID_METHODS)}.",
            "en": f"method must be one of: {', '.join(VALID_METHODS)}.",
        })

    opp = db.execute(
        text("SELECT id FROM osoa.opportunities WHERE id = :id"),
        {"id": opportunity_id},
    ).mappings().first()
    if not opp:
        raise HTTPException(status_code=404, detail={
            "fr": "Opportunité introuvable.",
            "en": "Opportunity not found.",
        })

    model_cls = METHOD_MODELS[data.method]
    try:
        validated = model_cls(**data.content)
    except Exception as e:
        raise HTTPException(status_code=422, detail={
            "fr": f"Contenu invalide pour la méthode {data.method} : {e}",
            "en": f"Invalid content for method {data.method}: {e}",
        })

    # 5_POURQUOI : categorie_5m validee contre le referentiel reel, pas une
    # simple liste figee cote code (coherent avec ADR-006 / mg.pillar_5whys_analysis).
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

    content_json = validated.model_dump_json()

    row = db.execute(
        text("""
            INSERT INTO osoa.strategic_analyses (opportunity_id, method, content, created_by)
            VALUES (:opportunity_id, :method, CAST(:content AS jsonb), :created_by)
            RETURNING id, opportunity_id, method, content, created_by, created_at::text
        """),
        {
            "opportunity_id": opportunity_id,
            "method": data.method,
            "content": content_json,
            "created_by": affiliate_id,
        },
    ).mappings().first()
    db.commit()

    return {"disclaimer": OSOA_DISCLAIMER, "analysis": dict(row)}


@router.get(
    "/opportunities/{opportunity_id}/analyses",
    summary="Lister les analyses stratégiques d'une opportunité OSOA",
)
def list_analyses(
    opportunity_id: int,
    method: Optional[str] = Query(default=None, description="Filtrer par méthode"),
    db: Session = Depends(get_db),
):
    sql = """
        SELECT id, opportunity_id, method, content, created_by, created_at::text
        FROM osoa.strategic_analyses
        WHERE opportunity_id = :opportunity_id
    """
    params: dict = {"opportunity_id": opportunity_id}
    if method:
        sql += " AND method = :method"
        params["method"] = method
    sql += " ORDER BY created_at DESC"

    rows = db.execute(text(sql), params).mappings().all()
    return {"disclaimer": OSOA_DISCLAIMER, "count": len(rows), "items": [dict(r) for r in rows]}


# ── Livrables synthetiques (osoa.strategic_deliverables) ───────────────────────
# Combine plusieurs osoa.strategic_analyses en un document coherent,
# monnayable -- ce que Théo appelle "étude d'opportunité et/ou de
# faisabilité". Snapshot fige a la generation, jamais recalcule
# automatiquement. Decision du 22 juillet 2026 : le devis (osoa.quotes)
# justifie desormais son prix par un de ces livrables plutot que par
# une simple analyse isolee (meme si strategic_analysis_id reste
# disponible en coexistence).


DELIVERABLE_REQUIRED_METHODS = {
    "ETUDE_OPPORTUNITE": ["5W1H", "SWOT", "ZACHMAN", "RISQUE", "ECONOMIQUE"],
    "ETUDE_FAISABILITE": ["FAISABILITE", "MULTICRITERE", "ECONOMIQUE", "RISQUE"],
}


class DeliverableCreate(BaseModel):
    deliverable_type: str = Field(..., description="ETUDE_OPPORTUNITE ou ETUDE_FAISABILITE")


def _latest_analysis_by_method(db: Session, opportunity_id: int, method: str):
    return db.execute(
        text("""
            SELECT id, content FROM osoa.strategic_analyses
            WHERE opportunity_id = :opportunity_id AND method = :method
            ORDER BY created_at DESC LIMIT 1
        """),
        {"opportunity_id": opportunity_id, "method": method},
    ).mappings().first()


def _build_etude_opportunite(analyses: dict) -> dict:
    econ = analyses["ECONOMIQUE"]["content"]
    zach = analyses["ZACHMAN"]["content"]
    executive_row = next(
        (row for row in zach.get("grille", []) if row.get("perspective") == "EXECUTIVE"), None
    )
    return {
        "cadrage": analyses["5W1H"]["content"],
        "swot": analyses["SWOT"]["content"],
        "architecture_perspective_executive": executive_row,
        "risques": analyses["RISQUE"]["content"].get("risques"),
        "benefices": econ.get("benefices_attendus_fr"),
        "roi_preliminaire": econ.get("retour_sur_investissement_estime"),
    }


def _build_etude_faisabilite(analyses: dict) -> dict:
    econ = analyses["ECONOMIQUE"]["content"]
    return {
        "faisabilite": analyses["FAISABILITE"]["content"],
        "score_multicritere": analyses["MULTICRITERE"]["content"].get("score_global"),
        "couts": econ.get("cout_estime"),
        "devise": econ.get("devise"),
        "hypotheses": econ.get("hypotheses_fr"),
        "risques": analyses["RISQUE"]["content"].get("risques"),
    }


DELIVERABLE_BUILDERS = {
    "ETUDE_OPPORTUNITE": _build_etude_opportunite,
    "ETUDE_FAISABILITE": _build_etude_faisabilite,
}


@router.post(
    "/opportunities/{opportunity_id}/deliverables",
    summary="Générer un livrable synthétique (étude d'opportunité ou de faisabilité)",
    description=(
        "Combine les dernières analyses stratégiques disponibles de l'opportunité "
        "en un document synthétique et figé (snapshot), monnayable via un devis. "
        "Échoue explicitement si une méthode requise n'a pas encore d'analyse."
    ),
)
def create_deliverable(
    opportunity_id: int,
    data: DeliverableCreate,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    affiliate_id = int(payload["sub"])

    if data.deliverable_type not in DELIVERABLE_REQUIRED_METHODS:
        raise HTTPException(status_code=422, detail={
            "fr": f"deliverable_type doit être l'une de : {', '.join(DELIVERABLE_REQUIRED_METHODS)}.",
            "en": f"deliverable_type must be one of: {', '.join(DELIVERABLE_REQUIRED_METHODS)}.",
        })

    opp = db.execute(
        text("SELECT id FROM osoa.opportunities WHERE id = :id"),
        {"id": opportunity_id},
    ).mappings().first()
    if not opp:
        raise HTTPException(status_code=404, detail={
            "fr": "Opportunité introuvable.",
            "en": "Opportunity not found.",
        })

    required = DELIVERABLE_REQUIRED_METHODS[data.deliverable_type]
    analyses = {}
    missing = []
    for method in required:
        row = _latest_analysis_by_method(db, opportunity_id, method)
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
            INSERT INTO osoa.strategic_deliverables
                (opportunity_id, deliverable_type, content, source_analysis_ids, generated_by)
            VALUES
                (:opportunity_id, :deliverable_type, CAST(:content AS jsonb), :source_ids, :generated_by)
            RETURNING id, opportunity_id, deliverable_type, content, source_analysis_ids,
                      generated_by, generated_at::text
        """),
        {
            "opportunity_id": opportunity_id,
            "deliverable_type": data.deliverable_type,
            "content": json.dumps(content),
            "source_ids": source_ids,
            "generated_by": affiliate_id,
        },
    ).mappings().first()
    db.commit()

    return {"disclaimer": OSOA_DISCLAIMER, "deliverable": dict(row)}


@router.get(
    "/opportunities/{opportunity_id}/deliverables",
    summary="Lister les livrables synthétiques d'une opportunité OSOA",
)
def list_deliverables(opportunity_id: int, db: Session = Depends(get_db)):
    rows = db.execute(
        text("""
            SELECT id, opportunity_id, deliverable_type, content, source_analysis_ids,
                   generated_by, generated_at::text
            FROM osoa.strategic_deliverables
            WHERE opportunity_id = :opportunity_id
            ORDER BY generated_at DESC
        """),
        {"opportunity_id": opportunity_id},
    ).mappings().all()
    return {"disclaimer": OSOA_DISCLAIMER, "count": len(rows), "items": [dict(r) for r in rows]}
