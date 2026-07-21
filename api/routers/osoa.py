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
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import text
from pydantic import BaseModel, Field

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

    try:
        row = db.execute(
            text("""
                INSERT INTO osoa.quotes
                    (opportunity_id, strategic_analysis_id, amount, currency,
                     description_fr, valid_until, proposed_by)
                VALUES
                    (:opportunity_id, :strategic_analysis_id, :amount, :currency,
                     :description_fr, :valid_until, :proposed_by)
                RETURNING id, opportunity_id, strategic_analysis_id, amount, currency,
                          status, description_fr, valid_until::text, proposed_by,
                          proposed_at::text, responded_by, responded_at::text
            """),
            {
                "opportunity_id": opportunity_id,
                "strategic_analysis_id": data.strategic_analysis_id,
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
            SELECT id, opportunity_id, strategic_analysis_id, amount, currency,
                   status, description_fr, valid_until::text, proposed_by,
                   proposed_at::text, responded_by, responded_at::text
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
            RETURNING id, opportunity_id, strategic_analysis_id, amount, currency,
                      status, description_fr, valid_until::text, proposed_by,
                      proposed_at::text, responded_by, responded_at::text
        """),
        {"status": data.status, "responded_by": affiliate_id, "id": quote_id},
    ).mappings().first()
    db.commit()

    return {"disclaimer": OSOA_DISCLAIMER, "quote": dict(row)}
