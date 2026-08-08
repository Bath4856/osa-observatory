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
from typing import Optional, List, Literal
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
        "Le Moteur de génie scientifique (OIM/OSOA) est un outil d'aide à la "
        "décision d'engagement -- il ne remplace pas l'évaluation finale des "
        "instances compétentes. Une recommandation d'intervention n'équivaut "
        "jamais à une amélioration actée : seule une donnée réellement "
        "collectée lors d'un cycle futur peut faire évoluer l'Indice de "
        "Souveraineté Africaine (ISA)."
    ),
    "en": (
        "The Scientific Engineering Engine (OIM/OSOA) is a decision-support "
        "tool for engagement assessment -- it does not replace the final "
        "evaluation of competent bodies. An intervention recommendation never "
        "equates to an enacted improvement: only data actually collected in a "
        "future cycle can move the African Sovereignty Index (ISA)."
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
    # Pilier/pays -- connus des la creation pour OIM, decouverts plus
    # tard pour OSOA (cf. endpoint dedie /opportunities/{id}/principal-pillar)
    principal_pillar_code: Optional[str] = Field(None, description="Code du pilier principal, si deja connu")
    country_iso3: Optional[str] = Field(None, min_length=3, max_length=3)
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
    principal_pillar_code: Optional[str] = None
    country_iso3: Optional[str] = None
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

    if data.principal_pillar_code:
        pillar = db.execute(
            text("SELECT pillar_code FROM mg.working_groups WHERE pillar_code = :code"),
            {"code": data.principal_pillar_code},
        ).mappings().first()
        if not pillar:
            raise HTTPException(status_code=422, detail={
                "fr": f"principal_pillar_code '{data.principal_pillar_code}' introuvable dans mg.working_groups.",
                "en": f"principal_pillar_code '{data.principal_pillar_code}' not found in mg.working_groups.",
            })

    try:
        row = db.execute(
            text("""
                INSERT INTO osoa.opportunities
                    (code, title_fr, title_en, origin_type, participation_mode,
                     origin_project_family_id, client_id, deliverable_id,
                     principal_pillar_code, country_iso3, created_by)
                VALUES
                    (:code, :title_fr, :title_en, :origin_type, :participation_mode,
                     :origin_project_family_id, :client_id, :deliverable_id,
                     :principal_pillar_code, :country_iso3, :created_by)
                RETURNING id, code, title_fr, title_en, origin_type, participation_mode,
                          current_phase, status, client_id, deliverable_id,
                          origin_project_family_id, principal_pillar_code, country_iso3,
                          created_at::text, updated_at::text
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
                "principal_pillar_code": data.principal_pillar_code,
                "country_iso3": data.country_iso3.upper() if data.country_iso3 else None,
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
                   origin_project_family_id, principal_pillar_code, country_iso3,
                   created_at::text, updated_at::text
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


class PrincipalPillarUpdate(BaseModel):
    principal_pillar_code: Optional[str] = None
    country_iso3: Optional[str] = Field(None, min_length=3, max_length=3)


@router.post(
    "/opportunities/{opportunity_id}/principal-pillar",
    summary="Déclarer le pilier principal et/ou le pays découverts pour une opportunité",
    description=(
        "Pour OSOA : ni le pilier ni le pays ne sont necessairement connus a la "
        "creation, decouverts apres analyse (5W1H/ZACHMAN). Pour OIM : generalement "
        "deja connus a la creation, cet endpoint permet neanmoins une correction. "
        "Chaque champ est independant -- fournir seulement l'un des deux ne modifie "
        "pas l'autre."
    ),
)
def set_principal_pillar(
    opportunity_id: int,
    data: PrincipalPillarUpdate,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    opp = db.execute(
        text("SELECT id FROM osoa.opportunities WHERE id = :id"),
        {"id": opportunity_id},
    ).mappings().first()
    if not opp:
        raise HTTPException(status_code=404, detail={"fr": "Opportunité introuvable.", "en": "Opportunity not found."})

    if data.principal_pillar_code is None and data.country_iso3 is None:
        raise HTTPException(status_code=422, detail={
            "fr": "Au moins un champ (principal_pillar_code ou country_iso3) doit être fourni.",
            "en": "At least one field (principal_pillar_code or country_iso3) must be provided.",
        })

    if data.principal_pillar_code is not None:
        pillar = db.execute(
            text("SELECT pillar_code FROM mg.working_groups WHERE pillar_code = :code"),
            {"code": data.principal_pillar_code},
        ).mappings().first()
        if not pillar:
            raise HTTPException(status_code=422, detail={
                "fr": f"principal_pillar_code '{data.principal_pillar_code}' introuvable dans mg.working_groups.",
                "en": f"principal_pillar_code '{data.principal_pillar_code}' not found in mg.working_groups.",
            })

    row = db.execute(
        text("""
            UPDATE osoa.opportunities
            SET principal_pillar_code = COALESCE(:pillar_code, principal_pillar_code),
                country_iso3 = COALESCE(:country_iso3, country_iso3),
                updated_at = NOW()
            WHERE id = :id
            RETURNING id, code, principal_pillar_code, country_iso3, updated_at::text
        """),
        {
            "pillar_code": data.principal_pillar_code,
            "country_iso3": data.country_iso3.upper() if data.country_iso3 else None,
            "id": opportunity_id,
        },
    ).mappings().first()
    db.commit()

    return dict(row)


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
    country_iso3: Optional[str] = Query(default=None, description="Code pays ISO3, ex. SEN"),
    principal_pillar_code: Optional[str] = Query(default=None, description="Code du pilier principal, ex. PMIN"),
    db: Session = Depends(get_db),
):
    sql = """
        SELECT id, code, title_fr, title_en, origin_type, participation_mode,
               current_phase, status, client_id, deliverable_id,
               origin_project_family_id, principal_pillar_code, country_iso3,
               created_at::text, updated_at::text
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
    if country_iso3:
        sql += " AND country_iso3 = :country_iso3"
        params["country_iso3"] = country_iso3.upper()
    if principal_pillar_code:
        sql += " AND principal_pillar_code = :principal_pillar_code"
        params["principal_pillar_code"] = principal_pillar_code
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
    "MULTICRITERE", "ECONOMIQUE", "GOUVERNANCE", "ZACHMAN", "INTERDEPENDANCE",
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
    probabilite: Literal["FAIBLE", "MOYEN", "ELEVE"]
    impact: Literal["FAIBLE", "MOYEN", "ELEVE"]
    mitigation: Optional[str] = None


class ContentRisque(BaseModel):
    risques: List[RisqueItem] = Field(..., min_length=1)


class ContentFaisabilite(BaseModel):
    faisabilite_technique: str
    faisabilite_financiere: str
    faisabilite_organisationnelle: str
    delai_estime_jours_min: int = Field(..., ge=0)
    delai_estime_jours_max: int = Field(..., ge=0)
    conclusion: Literal["FAVORABLE", "DEFAVORABLE", "CONDITIONNEL"]

    @model_validator(mode="after")
    def _check_delai_range(self):
        if self.delai_estime_jours_max < self.delai_estime_jours_min:
            raise ValueError("delai_estime_jours_max doit être >= delai_estime_jours_min")
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
    # Renommee "Analyse Economique Strategique" le 4 aout 2026 (decision de
    # Theo) : la Vision OIM ne vend pas un projet chiffre -- elle demontre
    # qu'un probleme est objectivable et qu'il est scientifiquement pertinent
    # d'engager les etapes suivantes. Les estimations financieres detaillees
    # viennent plus tard (Schema Directeur, puis le projet). AUCUN chiffre
    # ici -- uniquement des niveaux qualitatifs, jamais un cout invente.
    impact_attendu: Literal["FAIBLE", "MOYEN", "ELEVE"]
    potentiel_creation_valeur: Literal["FAIBLE", "MOYEN", "ELEVE"]
    potentiel_reduction_pertes: Literal["FAIBLE", "MOYEN", "ELEVE"]
    potentiel_recettes_publiques: Literal["FAIBLE", "MOYEN", "ELEVE"]
    ordre_de_grandeur_investissement: Literal["FAIBLE", "MOYEN", "ELEVE"]
    horizon_benefices: Literal["COURT_TERME", "MOYEN_TERME", "LONG_TERME"]
    benefices_attendus_fr: str
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
    perspective: Literal["EXECUTIVE", "BUSINESS_MGMT", "ARCHITECT", "ENGINEER", "TECHNICIAN", "ENTERPRISE"]
    quoi: Optional[str] = None
    comment: Optional[str] = None
    ou: Optional[str] = None
    qui: Optional[str] = None
    quand: Optional[str] = None
    pourquoi: Optional[str] = None


class ContentZachman(BaseModel):
    grille: List[ZachmanRow] = Field(..., min_length=6, max_length=6)

    @model_validator(mode="after")
    def _check_all_perspectives_present(self):
        found = {row.perspective for row in self.grille}
        missing = set(ZACHMAN_PERSPECTIVES) - found
        if missing:
            raise ValueError(f"perspectives manquantes dans la grille : {missing}")
        return self


PILLAR_CODES = ("PECO", "PENV", "PGEO", "PHUM", "PMIL", "PMIN", "PMON", "PNUM", "PRES", "PTRA")


class ContentStrategicLever(BaseModel):
    # Levier strategique -- PAS un projet nomme. Correctif du 5 aout 2026
    # (echec reel) : mg.strategic_levers est un CATALOGUE PARTAGE existant
    # (lever_code, Sprint OIM Lot 1/2, ADR004_strategic_chain_draft.md du
    # 14 juillet) -- l'IA doit REUTILISER un code existant si pertinent,
    # jamais l'ecrire directement (vocabulaire partage entre visions,
    # controle humain obligatoire avant tout ajout au catalogue).
    # lever_code TOUJOURS requis -- soit un code existant reutilise, soit
    # une proposition de nouveau code (majuscules_underscore, coherent
    # avec les codes existants comme DIGITALIZATION).
    lever_code: str
    reuses_existing_code: bool
    label_fr: str
    label_en: str
    description_fr: str
    description_en: Optional[str] = None
    relevance_weight: float = Field(..., ge=0, le=1)


class LeverEffect(BaseModel):
    target_pillar_code: Literal["PECO", "PENV", "PGEO", "PHUM", "PMIL", "PMIN", "PMON", "PNUM", "PRES", "PTRA"]
    expected_effect_fr: str
    confidence: Literal["LOW", "MODERATE", "HIGH", "VERY_HIGH"]


class ContentInterdependance(BaseModel):
    # 10eme methode -- NIVEAU VISION. Refonte du 5 aout 2026 (Theo) :
    # l'interdependance de la Vision n'est PLUS une relation scientifique
    # entre deux piliers (corr(A,B) -- releve de la recherche, pas d'OIM),
    # mais l'effet attendu d'un LEVIER STRATEGIQUE (pas encore un projet
    # nomme) sur d'autres piliers. Distinct du niveau Plan d'action
    # (ContentInterventionInterdependance ci-dessous, sur un vrai projet).
    primary_pillar_code: Literal["PECO", "PENV", "PGEO", "PHUM", "PMIL", "PMIN", "PMON", "PNUM", "PRES", "PTRA"]
    strategic_lever_code: str
    strategic_lever_label: str
    expected_effects: List[LeverEffect] = Field(default_factory=list)
    scientific_rationale: str

    @model_validator(mode="after")
    def _check_no_self_effect(self):
        for effect in self.expected_effects:
            if effect.target_pillar_code == self.primary_pillar_code:
                raise ValueError("target_pillar_code d'un effet ne peut pas être le pilier principal lui-même")
        return self


class InterventionEffect(BaseModel):
    target_pillar_code: Literal["PECO", "PENV", "PGEO", "PHUM", "PMIL", "PMIN", "PMON", "PNUM", "PRES", "PTRA"]
    effect_fr: str
    confidence: Literal["LOW", "MODERATE", "HIGH", "VERY_HIGH"]


class ContentInterventionInterdependance(BaseModel):
    # NIVEAU PLAN D'ACTION -- une fois qu'un projet REEL existe
    # (rf.sovereign_project_catalog), analyse ses effets attendus sur
    # d'autres piliers. Distinct du niveau Vision ci-dessus (base sur un
    # levier, avant tout projet nomme). N'appartient PAS aux 10 methodes
    # d'analyse (pas dans METHOD_MODELS) -- objet de niveau projet.
    primary_pillar_code: Literal["PECO", "PENV", "PGEO", "PHUM", "PMIL", "PMIN", "PMON", "PNUM", "PRES", "PTRA"]
    project_code: str
    project_name: str
    expected_effects: List[InterventionEffect] = Field(default_factory=list)
    scientific_rationale: str

    @model_validator(mode="after")
    def _check_no_self_effect(self):
        for effect in self.expected_effects:
            if effect.target_pillar_code == self.primary_pillar_code:
                raise ValueError("target_pillar_code d'un effet ne peut pas être le pilier principal lui-même")
        return self


class ReviewIssue(BaseModel):
    # Un probleme identifie par THEO -- structure imposee (Theo, 6 aout
    # 2026) : jamais un commentaire libre. rule_violated nomme la regle
    # precise (ex. "vocabulaire_controle", "affirmation_non_etayee"),
    # evidence cite le passage concerne ET la donnee reelle en jeu --
    # SANS jamais reinterpreter la donnee soi-meme (THEO verifie si une
    # affirmation est etayee, il ne juge jamais si un chiffre est
    # "significatif" ou pas selon son propre jugement).
    rule_violated: str
    evidence: str
    proposed_correction: str


class ContentAnalysisReview(BaseModel):
    # Verdict du reviseur IA THEO (6 aout 2026) -- role distinct du
    # redacteur SCRIBE : juge un brouillon deja genere contre les
    # vraies donnees et les regles doctrinales, ne re-redige JAMAIS
    # lui-meme, ne reinterprete JAMAIS les donnees.
    review_status: Literal["CONFORME", "A_REVOIR", "PROBLEME_DETECTE"]
    issues: List[ReviewIssue] = Field(default_factory=list)

    @model_validator(mode="after")
    def _check_issues_consistency(self):
        if self.review_status == "CONFORME" and self.issues:
            raise ValueError("issues doit être vide quand review_status == CONFORME")
        if self.review_status != "CONFORME" and not self.issues:
            raise ValueError("issues ne peut pas être vide quand review_status != CONFORME")
        return self






class ContentAllPrimaryAnalyses(BaseModel):
    # Modele combine (7 aout 2026, test d'optimisation) -- les 9 analyses
    # primaires en UN SEUL objet, pour un unique appel IA au lieu de 9.
    # Economie mesuree ~70% du prompt (snapshot + regles payes une seule
    # fois au lieu de 9) -- QUALITE A VALIDER EMPIRIQUEMENT avant
    # generalisation au pipeline batch. Les noms de champs different des
    # cles de METHOD_MODELS (identifiants Python valides) -- voir
    # COMBINED_FIELD_TO_METHOD dans oim_analysis_gen.py pour la
    # correspondance.
    analyse_5w1h: Content5W1H
    analyse_swot: ContentSWOT
    analyse_zachman: ContentZachman
    analyse_risque: ContentRisque
    analyse_economique: ContentEconomique
    analyse_gouvernance: ContentGouvernance
    analyse_multicritere: ContentMulticritere
    analyse_faisabilite: ContentFaisabilite
    analyse_5_pourquoi: Content5Pourquoi



class ContentSchemaDirecteur(BaseModel):
    # Refonte du 7 aout 2026 (Theo) : le Schema directeur n'est plus un
    # recyclage de fragments de l'etude d'opportunite -- c'est un vrai
    # travail analytique PROPRE, mene APRES validation de l'opportunite
    # et APRES qu'un levier soit choisi. Reutilise ContentZachman tel
    # quel (deja 6 perspectives completes -- legitime ICI, contrairement
    # au niveau opportunite ou seules 2 perspectives sont retenues).
    # Repond a "quelle architecture cible, gouvernee comment, priorisee
    # comment" -- jamais "y a-t-il un probleme" (deja etabli) ni "quelles
    # actions precises" (Plan d'action, en aval).
    zachman: ContentZachman
    gouvernance: ContentGouvernance
    multicritere: ContentMulticritere



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
    "INTERDEPENDANCE": ContentInterdependance,
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

    # INTERDEPENDANCE : pillar_code et indicator_codes valides contre les
    # referentiels reels (rf.pillars, rf.poa_catalog), pas une simple
    # supposition -- meme discipline que categorie_5m ci-dessus.
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
            else:  # POA
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
                    "fr": f"known_intervention_requirement_id {validated.known_intervention_requirement_id} introuvable dans mg.transformation_requirements.",
                    "en": f"known_intervention_requirement_id {validated.known_intervention_requirement_id} not found in mg.transformation_requirements.",
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
    "SCHEMA_DIRECTEUR": ["ZACHMAN", "GOUVERNANCE", "MULTICRITERE", "FAISABILITE", "RISQUE"],
    "PLAN_ACTION": ["5_POURQUOI", "GOUVERNANCE", "MULTICRITERE", "RISQUE"],
}


class DeliverableCreate(BaseModel):
    deliverable_type: str = Field(..., description="ETUDE_OPPORTUNITE, ETUDE_FAISABILITE, SCHEMA_DIRECTEUR ou PLAN_ACTION")


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


def _build_schema_directeur(analyses: dict) -> dict:
    return {
        "architecture_complete": analyses["ZACHMAN"]["content"].get("grille"),
        "gouvernance": analyses["GOUVERNANCE"]["content"],
        "priorisation": analyses["MULTICRITERE"]["content"],
        "contraintes": analyses["FAISABILITE"]["content"],
        "risques_structurels": analyses["RISQUE"]["content"].get("risques"),
    }


def _derive_actions_from_5why(content: dict) -> List[str]:
    niveaux = content.get("niveaux", [])
    cause = content.get("cause_racine", "")
    actions = []
    if cause:
        actions.append(f"Traiter la cause racine : {cause}")
    for i, n in enumerate(niveaux, start=1):
        actions.append(f"Action liée au niveau {i} : {n.get('reponse', '')}")
    return actions


def _build_plan_action(analyses: dict) -> dict:
    pourquoi_content = analyses["5_POURQUOI"]["content"]
    return {
        "cause_racine": pourquoi_content.get("cause_racine"),
        "actions_correctives": _derive_actions_from_5why(pourquoi_content),
        "responsables": analyses["GOUVERNANCE"]["content"].get("parties_prenantes"),
        "priorisation": analyses["MULTICRITERE"]["content"].get("criteres"),
        "mitigation": analyses["RISQUE"]["content"].get("risques"),
    }


DELIVERABLE_BUILDERS = {
    "ETUDE_OPPORTUNITE": _build_etude_opportunite,
    "ETUDE_FAISABILITE": _build_etude_faisabilite,
    "SCHEMA_DIRECTEUR": _build_schema_directeur,
    "PLAN_ACTION": _build_plan_action,
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


# ── Resume executif IA (livrable ETUDE_OPPORTUNITE = Vision uniquement) ──────────
# Ajoute le 28 juillet 2026 -- donnees ouvertes. SCHEMA_DIRECTEUR et PLAN_ACTION
# restent payants (Go-To-Market), aucun resume public prevu pour eux.
#
# Double fournisseur possible (AI_SUMMARY_PROVIDER=anthropic|openai, variable
# d'environnement) -- choix acte le 28 juillet 2026 pour ne pas dependre d'un
# seul fournisseur. Echec explicite si le fournisseur choisi n'a pas sa cle
# correspondante configuree, jamais de repli silencieux.

import os as _os_summary

try:
    import anthropic as _anthropic_sdk
except ImportError:
    _anthropic_sdk = None

try:
    import openai as _openai_sdk
except ImportError:
    _openai_sdk = None


SUMMARY_SYSTEM_PROMPT = (
    "Tu rediges le resume executif d'une ETUDE D'OPPORTUNITE de souverainete "
    "africaine, a partir d'un contenu JSON structure (5W1H, SWOT, architecture "
    "Zachman, risques, analyse economique). Ce texte n'est PAS une simple "
    "restitution scientifique d'un constat -- c'est une mini-etude d'opportunite "
    "orientee Go-To-Market, destinee a faire emerger une demande d'intervention. "
    "Il doit accomplir DEUX fonctions dans l'ordre : "
    "1) ETABLIR l'opportunite a partir des faits observes (forces/faiblesses/"
    "risques/potentiel economique) -- academique, scientifique, jamais de "
    "langage promotionnel ni d'affirmation non etayee par le contenu fourni. "
    "Ne JAMAIS utiliser d'adjectifs absolus ou promotionnels (ex. 'indeniable', "
    "'majeur', 'fort' au sens absolu) -- preferer un vocabulaire evidentiel "
    "mesure (ex. 'documente', 'observe', 'identifie'). "
    "2) TERMINER par une invitation EXPLICITE (pas implicite) a commander une "
    "intervention adaptee -- une etude de faisabilite ET/OU un schema directeur "
    "et plan d'actions -- qui permettrait de DEFINIR la reponse a cette "
    "opportunite. La faisabilite doit souvent etre validee avant que le plan "
    "d'actions ne puisse etre engage -- ne jamais presupposer que le plan "
    "d'actions peut etre commande directement sans cette etape possible, "
    "proposer les deux options. Ne JAMAIS presenter une strategie ou un plan "
    "d'actions comme deja existant ou deja mis en oeuvre -- a ce stade, ils "
    "n'existent pas encore, ils sont precisement ce que l'intervention "
    "proposee permettrait de produire. Ne JAMAIS parler de 'le projet' au "
    "singulier comme s'il etait deja identifie -- a ce stade aucun projet "
    "precis n'existe, seul un futur plan d'actions les definirait (et "
    "generalement plusieurs, pas un seul). Utiliser 'certains projets' ou "
    "'les projets qui pourraient en decouler' au pluriel et au conditionnel. "
    "Formuler la derniere phrase comme une invitation claire (ex. 'Cette "
    "analyse invite a la commande d'une etude de faisabilite et/ou d'un "
    "schema directeur et d'un plan d'actions pour...' plutot que 'La "
    "strategie consiste a...'). Le contenu fourni inclut un champ "
    "levier_strategique (label_fr, description_fr) -- ancre explicitement "
    "l'opportunite et l'invitation finale sur ce levier precis, jamais un "
    "discours generique deconnecte de lui. Longueur : 150-200 mots par "
    "langue maximum. Reponds UNIQUEMENT en JSON valide, sans aucun texte "
    "avant ou apres, au format exact : "
    '{"summary_fr": "...", "summary_en": "..."}'
)


def _generate_summary_anthropic(content_json: str, system_prompt: str = None) -> dict:
    system_prompt = system_prompt or SUMMARY_SYSTEM_PROMPT
    api_key = _os_summary.environ.get("ANTHROPIC_API_KEY")
    if not api_key or _anthropic_sdk is None:
        raise HTTPException(status_code=503, detail={
            "fr": "AI_SUMMARY_PROVIDER=anthropic mais ANTHROPIC_API_KEY n'est pas configurée sur ce serveur.",
            "en": "AI_SUMMARY_PROVIDER=anthropic but ANTHROPIC_API_KEY is not configured on this server.",
        })
    client = _anthropic_sdk.Anthropic(api_key=api_key)
    response = client.messages.create(
        model="claude-sonnet-5",
        max_tokens=1200,
        system=system_prompt,
        messages=[{"role": "user", "content": content_json}],
    )
    raw_text = "".join(block.text for block in response.content if block.type == "text")
    return json.loads(raw_text)


def _generate_summary_openai(content_json: str, system_prompt: str = None) -> dict:
    system_prompt = system_prompt or SUMMARY_SYSTEM_PROMPT
    api_key = _os_summary.environ.get("OPENAI_API_KEY")
    if not api_key or _openai_sdk is None:
        raise HTTPException(status_code=503, detail={
            "fr": "AI_SUMMARY_PROVIDER=openai mais OPENAI_API_KEY n'est pas configurée sur ce serveur.",
            "en": "AI_SUMMARY_PROVIDER=openai but OPENAI_API_KEY is not configured on this server.",
        })
    client = _openai_sdk.OpenAI(api_key=api_key)
    response = client.chat.completions.create(
        model="gpt-4o",
        response_format={"type": "json_object"},
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": content_json},
        ],
    )
    return json.loads(response.choices[0].message.content)


def _call_summary_ai(system_prompt: str, user_content: str) -> dict:
    """Helper partage pour review-summary/regenerate-summary -- meme
    selection de fournisseur (AI_SUMMARY_PROVIDER) que generate-summary,
    jamais dupliquee, juste parametree avec un prompt different."""
    provider = _os_summary.environ.get("AI_SUMMARY_PROVIDER", "anthropic").lower()
    if provider == "anthropic":
        return _generate_summary_anthropic(user_content, system_prompt)
    elif provider == "openai":
        return _generate_summary_openai(user_content, system_prompt)
    else:
        raise HTTPException(status_code=500, detail={
            "fr": f"AI_SUMMARY_PROVIDER='{provider}' invalide -- doit être 'anthropic' ou 'openai'.",
            "en": f"AI_SUMMARY_PROVIDER='{provider}' invalid -- must be 'anthropic' or 'openai'.",
        })


class SummaryValidateUpdate(BaseModel):
    public_summary_fr: Optional[str] = None
    public_summary_en: Optional[str] = None


@router.post(
    "/deliverables/{deliverable_id}/generate-summary",
    summary="Générer le résumé exécutif académique/scientifique bilingue (IA) -- ETUDE_OPPORTUNITE uniquement",
    description=(
        "Reservé au livrable ETUDE_OPPORTUNITE (= la Vision), destine aux donnees "
        "ouvertes. Fournisseur IA selectionne via AI_SUMMARY_PROVIDER "
        "(anthropic ou openai, defaut anthropic). Genere un brouillon -- DOIT "
        "etre valide par un humain (endpoint validate-summary) avant toute "
        "publication reelle. Echoue explicitement si la cle correspondante "
        "n'est pas configuree."
    ),
)
def generate_deliverable_summary(
    deliverable_id: int,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    deliverable = db.execute(
        text("SELECT id, vision_id, deliverable_type, content FROM osoa.strategic_deliverables WHERE id = :id"),
        {"id": deliverable_id},
    ).mappings().first()
    if not deliverable:
        raise HTTPException(status_code=404, detail={"fr": "Livrable introuvable.", "en": "Deliverable not found."})
    if deliverable["deliverable_type"] != "ETUDE_OPPORTUNITE":
        raise HTTPException(status_code=422, detail={
            "fr": "Le résumé exécutif public n'est disponible que pour ETUDE_OPPORTUNITE (= la Vision) -- SCHEMA_DIRECTEUR et PLAN_ACTION restent payants (Go-To-Market).",
            "en": "The public executive summary is only available for ETUDE_OPPORTUNITE (= the Vision) -- SCHEMA_DIRECTEUR and PLAN_ACTION remain paid (Go-To-Market).",
        })

    # Le levier strategique promu devient le point d'entree unique -- garde-fou
    # ajoute le 5 aout 2026 (Theo) : un seul pivot pour eviter les trous
    # techniques et incoherences entre les differents generateurs IA.
    pourquoi_analysis = db.execute(
        text("""
            SELECT id FROM osoa.strategic_analyses
            WHERE vision_id = :vision_id AND method = '5_POURQUOI'
            ORDER BY created_at DESC LIMIT 1
        """),
        {"vision_id": deliverable["vision_id"]},
    ).mappings().first()
    lever = None
    if pourquoi_analysis:
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
            "fr": "Aucun levier stratégique promu pour cette vision -- générez et promouvez un levier avant de générer le résumé.",
            "en": "No promoted strategic lever for this vision -- generate and promote a lever before generating the summary.",
        })

    evidence = _build_opportunity_evidence(db, deliverable["vision_id"])
    evidence["levier_strategique"] = {
        "lever_code": lever["lever_code"],
        "label_fr": lever["label_fr"],
        "description_fr": lever["description_fr"],
    }
    content_json = json.dumps(evidence, ensure_ascii=False, default=str)
    provider = _os_summary.environ.get("AI_SUMMARY_PROVIDER", "anthropic").lower()

    try:
        parsed = _call_summary_ai(SUMMARY_SYSTEM_PROMPT, content_json)
        summary_fr = parsed["summary_fr"]
        summary_en = parsed["summary_en"]
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=502, detail={
            "fr": f"Échec de la génération IA ({provider}) : {e}",
            "en": f"AI generation failed ({provider}): {e}",
        })

    row = db.execute(
        text("""
            UPDATE osoa.strategic_deliverables
            SET public_summary_fr = :summary_fr, public_summary_en = :summary_en, summary_status = 'AI_DRAFTED'
            WHERE id = :id
            RETURNING id, deliverable_type, public_summary_fr, public_summary_en, summary_status
        """),
        {"summary_fr": summary_fr, "summary_en": summary_en, "id": deliverable_id},
    ).mappings().first()
    db.commit()

    return dict(row)


@router.post(
    "/deliverables/{deliverable_id}/validate-summary",
    summary="Valider (et éventuellement corriger) le résumé exécutif avant publication",
    description="Passage obligatoire par un humain -- jamais de publication directe d'un résumé AI_DRAFTED.",
)
def validate_deliverable_summary(
    deliverable_id: int,
    data: SummaryValidateUpdate,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    deliverable = db.execute(
        text("SELECT id, summary_status FROM osoa.strategic_deliverables WHERE id = :id"),
        {"id": deliverable_id},
    ).mappings().first()
    if not deliverable:
        raise HTTPException(status_code=404, detail={"fr": "Livrable introuvable.", "en": "Deliverable not found."})

    if deliverable["summary_status"] == "PENDING":
        raise HTTPException(status_code=422, detail={
            "fr": "Aucun résumé n'a encore été généré -- utiliser generate-summary d'abord.",
            "en": "No summary has been generated yet -- use generate-summary first.",
        })

    row = db.execute(
        text("""
            UPDATE osoa.strategic_deliverables
            SET public_summary_fr = COALESCE(:summary_fr, public_summary_fr),
                public_summary_en = COALESCE(:summary_en, public_summary_en),
                summary_status = 'HUMAN_VALIDATED'
            WHERE id = :id
            RETURNING id, deliverable_type, public_summary_fr, public_summary_en, summary_status
        """),
        {"summary_fr": data.public_summary_fr, "summary_en": data.public_summary_en, "id": deliverable_id},
    ).mappings().first()
    db.commit()

    return dict(row)

def _build_opportunity_evidence(db: Session, vision_id: int) -> dict:
    """Assemble le VRAI paquet de preuves OpportunityEvidence pour le
    resume executif (7 aout 2026, conception actee avec Theo) --
    5W1H+SWOT+5_POURQUOI+RISQUE+ECONOMIQUE+MULTICRITERE (analyses
    promues reelles, interrogees directement -- pas seulement le
    sous-ensemble de DELIVERABLE_REQUIRED_METHODS["ETUDE_OPPORTUNITE"])
    + ZACHMAN FILTRE aux 2 premieres perspectives (EXECUTIVE,
    BUSINESS_MGMT) -- jamais les 6, reservees au Schema directeur.
    Ne genere rien -- lit uniquement des analyses deja promues."""
    methods_needed = ["5W1H", "SWOT", "5_POURQUOI", "RISQUE", "ECONOMIQUE", "MULTICRITERE", "ZACHMAN"]
    rows = db.execute(
        text("""
            SELECT method, content FROM osoa.strategic_analyses
            WHERE vision_id = :vision_id AND method = ANY(:methods)
        """),
        {"vision_id": vision_id, "methods": methods_needed},
    ).mappings().all()
    by_method = {r["method"]: r["content"] for r in rows}

    missing = [m for m in methods_needed if m not in by_method]
    if missing:
        raise HTTPException(status_code=422, detail={
            "fr": f"Analyses manquantes pour le paquet de preuves OpportunityEvidence : {', '.join(missing)}.",
            "en": f"Missing analyses for the OpportunityEvidence package: {', '.join(missing)}.",
        })

    zachman_complet = by_method["ZACHMAN"]
    zachman_reduit = {
        "grille": [
            row for row in zachman_complet.get("grille", [])
            if row.get("perspective") in ("EXECUTIVE", "BUSINESS_MGMT")
        ]
    }

    return {
        "analysis_5w1h": by_method["5W1H"],
        "swot": by_method["SWOT"],
        "root_causes": by_method["5_POURQUOI"],
        "risk_analysis": by_method["RISQUE"],
        "economic_analysis": by_method["ECONOMIQUE"],
        "multicriteria": by_method["MULTICRITERE"],
        "zachman": zachman_reduit,
    }




# ── Boucle SCRIBE/THEO pour le resume executif (Niveau 0), 7 aout 2026 ───────
# Demande explicite de Theo : "nous finissons le Niveau 0" avant la refonte
# complete OpportunityStudy (Niveau 1). Reutilise ContentAnalysisReview
# (deja generique : review_status + issues structurees) et _call_summary_ai
# (deja parametree ci-dessus) -- aucune duplication.

SUMMARY_REVIEWER_SYSTEM_PROMPT = """Tu es THEO, un REVISEUR SCIENTIFIQUE independant -- tu ne rediges JAMAIS
toi-meme, tu juges un resume executif deja redige par SCRIBE, contre le
paquet de preuves fourni ci-dessous et les regles imperatives qui
encadraient sa redaction.

Paquet de preuves (le contenu reel du livrable ETUDE_OPPORTUNITE, source
de verite -- jamais a contredire) :
{evidence_json}

Resume executif produit par SCRIBE, a evaluer (FR) :
{summary_fr}

Resume executif produit par SCRIBE, a evaluer (EN) :
{summary_en}

Regles imperatives qui encadraient SCRIBE (verifie leur respect exact) :
- Le resume doit accomplir DEUX fonctions dans l'ordre : (1) ETABLIR
  l'opportunite a partir des faits du paquet de preuves, academique,
  jamais de langage promotionnel ; (2) TERMINER par une invitation
  EXPLICITE a commander une intervention (etude de faisabilite et/ou
  schema directeur et plan d'actions).
- Vocabulaire mesure : jamais d'adjectifs absolus ou promotionnels
  (indeniable, majeur, enorme) -- preferer documente/observe/identifie.
- Chaque affirmation du resume doit etre etayee par le paquet de preuves
  -- signale toute affirmation qui semble inventee ou non reliee.
- Jamais presenter une strategie/un plan comme deja existant.
- Jamais parler de "le projet" au singulier comme deja identifie --
  seulement "certains projets" au pluriel et au conditionnel.
- Longueur 150-200 mots par langue maximum -- signale si trop long ou
  trop court.

Pour chaque probleme trouve, structure ta reponse en 3 parties :
rule_violated, evidence, proposed_correction -- meme discipline que pour
les 9 analyses primaires.

Verdicts possibles : CONFORME (issues vide) / A_REVOIR / PROBLEME_DETECTE
(au moins un item dans issues).

Reponds UNIQUEMENT en JSON valide, sans aucun texte avant ou apres, au
format exact :
{{"review_status": "...", "issues": [{{"rule_violated": "...", "evidence": "...", "proposed_correction": "..."}}]}}
"""


@router.post(
    "/deliverables/{deliverable_id}/review-summary",
    summary="Faire évaluer le résumé exécutif par THEO (juge, ne rédige jamais)",
    description="Réservé aux livrables ETUDE_OPPORTUNITE ayant un résumé AI_DRAFTED. Vérifie la fidélité au paquet de preuves et le respect des règles imposées à SCRIBE.",
)
def review_deliverable_summary(
    deliverable_id: int,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    deliverable = db.execute(
        text("SELECT id, vision_id, deliverable_type, content, public_summary_fr, public_summary_en FROM osoa.strategic_deliverables WHERE id = :id"),
        {"id": deliverable_id},
    ).mappings().first()
    if not deliverable:
        raise HTTPException(status_code=404, detail={"fr": "Livrable introuvable.", "en": "Deliverable not found."})
    if deliverable["deliverable_type"] != "ETUDE_OPPORTUNITE":
        raise HTTPException(status_code=422, detail={
            "fr": "La revue du résumé n'est disponible que pour ETUDE_OPPORTUNITE.",
            "en": "Summary review is only available for ETUDE_OPPORTUNITE.",
        })
    if not deliverable["public_summary_fr"]:
        raise HTTPException(status_code=422, detail={
            "fr": "Aucun résumé à évaluer -- générez-le d'abord (POST .../generate-summary).",
            "en": "No summary to evaluate -- generate it first (POST .../generate-summary).",
        })

    evidence = _build_opportunity_evidence(db, deliverable["vision_id"])
    evidence_json = json.dumps(evidence, ensure_ascii=False, default=str)
    system_prompt = SUMMARY_REVIEWER_SYSTEM_PROMPT.format(
        evidence_json=evidence_json,
        summary_fr=deliverable["public_summary_fr"],
        summary_en=deliverable["public_summary_en"] or "",
    )

    try:
        parsed = _call_summary_ai(system_prompt, "Évalue ce résumé maintenant, selon les règles fournies ci-dessus.")
        validated = ContentAnalysisReview(**parsed)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=502, detail={
            "fr": f"Échec de la révision IA : {e}",
            "en": f"AI review failed: {e}",
        })

    issues_json = json.dumps([i.model_dump() for i in validated.issues], ensure_ascii=False)
    row = db.execute(
        text("""
            INSERT INTO mg.summary_review (deliverable_id, review_status, issues)
            VALUES (:deliverable_id, :status, CAST(:issues AS jsonb))
            RETURNING id, deliverable_id, review_status, issues, created_at::text
        """),
        {"deliverable_id": deliverable_id, "status": validated.review_status, "issues": issues_json},
    ).mappings().first()
    db.commit()

    return dict(row)


@router.post(
    "/deliverables/{deliverable_id}/regenerate-summary",
    summary="Régénérer le résumé exécutif en intégrant la dernière critique de THEO",
    description="Réservé aux livrables ayant au moins une revue enregistrée (POST .../review-summary).",
)
def regenerate_deliverable_summary(
    deliverable_id: int,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    deliverable = db.execute(
        text("SELECT id, vision_id, deliverable_type, content FROM osoa.strategic_deliverables WHERE id = :id"),
        {"id": deliverable_id},
    ).mappings().first()
    if not deliverable:
        raise HTTPException(status_code=404, detail={"fr": "Livrable introuvable.", "en": "Deliverable not found."})

    latest_review = db.execute(
        text("""
            SELECT review_status, issues FROM mg.summary_review
            WHERE deliverable_id = :deliverable_id ORDER BY created_at DESC LIMIT 1
        """),
        {"deliverable_id": deliverable_id},
    ).mappings().first()
    if not latest_review:
        raise HTTPException(status_code=422, detail={
            "fr": "Aucune revue disponible -- faites évaluer le résumé d'abord (POST .../review-summary).",
            "en": "No review available -- have the summary evaluated first (POST .../review-summary).",
        })

    pourquoi_analysis = db.execute(
        text("""
            SELECT id FROM osoa.strategic_analyses
            WHERE vision_id = :vision_id AND method = '5_POURQUOI'
            ORDER BY created_at DESC LIMIT 1
        """),
        {"vision_id": deliverable["vision_id"]},
    ).mappings().first()
    lever = None
    if pourquoi_analysis:
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
            "fr": "Aucun levier stratégique promu pour cette vision.",
            "en": "No promoted strategic lever for this vision.",
        })

    evidence = _build_opportunity_evidence(db, deliverable["vision_id"])
    evidence["levier_strategique"] = {
        "lever_code": lever["lever_code"],
        "label_fr": lever["label_fr"],
        "description_fr": lever["description_fr"],
    }
    content_json = json.dumps(evidence, ensure_ascii=False, default=str)

    issues_lines = [
        "- Regle violee: " + issue["rule_violated"] + " | Preuve: " + issue["evidence"] + " | Correction proposee: " + issue["proposed_correction"]
        for issue in latest_review["issues"]
    ]
    issues_text = "\n".join(issues_lines)
    feedback_note = (
        "\n\nCORRECTION REQUISE -- THEO (le reviseur scientifique) a identifie "
        "les problemes suivants dans une version precedente :\n"
        + issues_text +
        "\nCorrige precisement ces points dans cette nouvelle version, sans "
        "repeter les memes defauts."
    )
    system_prompt = SUMMARY_SYSTEM_PROMPT + feedback_note

    try:
        parsed = _call_summary_ai(system_prompt, content_json)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=502, detail={
            "fr": f"Échec de la régénération IA : {e}",
            "en": f"AI regeneration failed: {e}",
        })

    row = db.execute(
        text("""
            UPDATE osoa.strategic_deliverables
            SET public_summary_fr = :summary_fr, public_summary_en = :summary_en, summary_status = 'AI_DRAFTED'
            WHERE id = :id
            RETURNING id, deliverable_type, public_summary_fr, public_summary_en, summary_status
        """),
        {"summary_fr": parsed["summary_fr"], "summary_en": parsed["summary_en"], "id": deliverable_id},
    ).mappings().first()
    db.commit()

    return dict(row)


@router.post(
    "/deliverables/bulk-validate-summaries-conforme",
    summary="Valider en masse tous les résumés exécutifs jugés CONFORME par THEO",
    description="Acte humain explicite -- chantier 540, cloture la boucle SCRIBE/THEO/validation a l'echelle.",
)
def bulk_validate_summaries_conforme(
    dry_run: bool = Query(default=False, description="Si true, execute tout mais annule (rollback) -- previsualise sans rien changer."),
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    rows = db.execute(
        text("""
            SELECT DISTINCT ON (sr.deliverable_id) sr.deliverable_id, sr.review_status, sd.summary_status
            FROM mg.summary_review sr
            JOIN osoa.strategic_deliverables sd ON sd.id = sr.deliverable_id
            WHERE sd.summary_status = 'AI_DRAFTED'
            ORDER BY sr.deliverable_id, sr.created_at DESC
        """),
    ).mappings().all()

    validated_ids = []
    for row in rows:
        if row["review_status"] != "CONFORME":
            continue
        db.execute(
            text("UPDATE osoa.strategic_deliverables SET summary_status = 'HUMAN_VALIDATED' WHERE id = :id"),
            {"id": row["deliverable_id"]},
        )
        validated_ids.append(row["deliverable_id"])

    if dry_run:
        db.rollback()
    else:
        db.commit()
    return {"dry_run": dry_run, "validated_count": len(validated_ids), "validated_deliverable_ids": validated_ids}
