"""
OSA Observatory -- OSOA (OSA Strategic Opportunity Assessment)
api/routers/osoa.py

Premier lot d'endpoints exposant osoa.opportunities (ADR-008, modele de
donnees deploye le 17-18 juillet 2026, jamais expose via API jusqu'ici --
tout teste uniquement en SQL direct via psql). Prefixe /api/v2/osoa,
distinct de /api/v2/opportunities (deja pris par api/routers/opportunities.py,
concept different : pub.mv_isa_opportunity_catalog, catalogue P7Z
d'opportunites d'intervention souveraine, sans rapport avec OSOA).

Doctrine ADR-010 (20 juillet 2026) appliquee :
  - Une opportunite EXTERNAL ne peut etre creee que si le client associe a
    un KYC status='VERIFIED' -- decision actee explicitement, bloque a la
    creation plutot qu'a une etape ulterieure du workflow.
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


class OpportunityItem(BaseModel):
    id: int
    code: str
    title_fr: str
    title_en: Optional[str] = None
    origin_type: str
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
        if not data.origin_project_family_id or data.client_id or data.deliverable_id:
            raise HTTPException(status_code=422, detail={
                "fr": "Une opportunité INTERNAL exige origin_project_family_id et exclut client_id/deliverable_id.",
                "en": "An INTERNAL opportunity requires origin_project_family_id and excludes client_id/deliverable_id.",
            })
    else:  # EXTERNAL
        if not data.client_id or not data.deliverable_id or data.origin_project_family_id:
            raise HTTPException(status_code=422, detail={
                "fr": "Une opportunité EXTERNAL exige client_id et deliverable_id, et exclut origin_project_family_id.",
                "en": "An EXTERNAL opportunity requires client_id and deliverable_id, and excludes origin_project_family_id.",
            })

        # Blocage KYC -- ADR-010, decision actee le 20 juillet 2026
        client = db.execute(
            text("SELECT kyc_status FROM osoa.clients WHERE id = :id"),
            {"id": data.client_id},
        ).mappings().first()
        if not client:
            raise HTTPException(status_code=404, detail={
                "fr": "Client introuvable.",
                "en": "Client not found.",
            })
        if client["kyc_status"] != "VERIFIED":
            raise HTTPException(status_code=403, detail={
                "fr": f"KYC du client non vérifié (statut actuel : {client['kyc_status']}). "
                      f"Une opportunité EXTERNAL exige un KYC VERIFIED (ADR-010).",
                "en": f"Client KYC not verified (current status: {client['kyc_status']}). "
                      f"An EXTERNAL opportunity requires a VERIFIED KYC (ADR-010).",
            })

    try:
        row = db.execute(
            text("""
                INSERT INTO osoa.opportunities
                    (code, title_fr, title_en, origin_type,
                     origin_project_family_id, client_id, deliverable_id, created_by)
                VALUES
                    (:code, :title_fr, :title_en, :origin_type,
                     :origin_project_family_id, :client_id, :deliverable_id, :created_by)
                RETURNING id, code, title_fr, title_en, origin_type, current_phase,
                          status, client_id, deliverable_id, origin_project_family_id,
                          created_at::text, updated_at::text
            """),
            {
                "code": data.code,
                "title_fr": data.title_fr,
                "title_en": data.title_en,
                "origin_type": data.origin_type,
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
            SELECT id, code, title_fr, title_en, origin_type, current_phase,
                   status, client_id, deliverable_id, origin_project_family_id,
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
    db: Session = Depends(get_db),
):
    sql = """
        SELECT id, code, title_fr, title_en, origin_type, current_phase,
               status, client_id, deliverable_id, origin_project_family_id,
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
    sql += " ORDER BY created_at DESC"

    rows = db.execute(text(sql), params).mappings().all()
    return {"disclaimer": OSOA_DISCLAIMER, "count": len(rows), "items": [dict(r) for r in rows]}
