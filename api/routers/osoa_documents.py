"""
OSA Observatory -- OSOA, dépôts de documents
api/routers/osoa_documents.py

Fichier separe de osoa.py (deja volumineux, ~1000 lignes) pour eviter
la derive de taille deja constatee cette session.

Cycle reel du procurement (clarifie par Theo, 23-24 juillet 2026) :
  AMI -> shortlist (SHORTLISTED) -> DP, ou arret (REJECTED)
  AO/AOI/DP -> resultat de negociation : RETAINED (lancement du
              projet) ou ELIMINATED (proposition non retenue)

procurement_stage (AMI/AO/AOI/DP) est distinct de document_type
(REFERENCE/INSTITUTIONNEL/FINANCIER/TECHNIQUE/JURIDIQUE/SCIENTIFIQUE,
deja existant -- nature du contenu, pas etape du cycle).

L'issue (outcome) est portee par le DEPOT, pas par l'opportunite --
une opportunite peut recevoir plusieurs depots successifs dans le
temps (AMI puis DP), chacun garde son propre type/issue, rien n'est
ecrase. Le statut de l'opportunite (osoa.opportunities.status) se
deduit automatiquement de l'issue du depot le plus recent, gere ici
cote applicatif (pas de trigger SQL, pour rester lisible/testable).
"""
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import text
from pydantic import BaseModel, Field, model_validator

from api.db import get_db
from api.routers.auth_affiliates import get_current_affiliate

router = APIRouter(
    prefix="/api/v2/osoa",
    tags=["OSOA - Dépôts de documents"],
)

DOCUMENT_TYPES = ("REFERENCE", "INSTITUTIONNEL", "FINANCIER", "TECHNIQUE", "JURIDIQUE", "SCIENTIFIQUE")
PROCUREMENT_STAGES = ("AMI", "AO", "AOI", "DP")

STAGE_OUTCOMES = {
    "AMI": ("SHORTLISTED", "REJECTED"),
    "AO": ("RETAINED", "ELIMINATED"),
    "AOI": ("RETAINED", "ELIMINATED"),
    "DP": ("RETAINED", "ELIMINATED"),
}

# Consequence sur le statut de l'opportunite parente. None = pas de
# changement (ex. SHORTLISTED : l'opportunite reste ACTIVE, on attend
# le prochain depot -- le DP -- pas de cloture).
OUTCOME_TO_OPPORTUNITY_STATUS = {
    "SHORTLISTED": None,
    "REJECTED": "ABANDONED",
    "RETAINED": "CLOSED",
    "ELIMINATED": "ABANDONED",
}


class DocumentDepositCreate(BaseModel):
    procurement_stage: str = Field(..., description="AMI, AO, AOI ou DP")
    document_type: str = Field(..., description="REFERENCE, INSTITUTIONNEL, FINANCIER, TECHNIQUE, JURIDIQUE ou SCIENTIFIQUE")
    title: str
    file_reference: str

    @model_validator(mode="after")
    def _check_values(self):
        if self.procurement_stage not in PROCUREMENT_STAGES:
            raise ValueError(f"procurement_stage doit être l'une de {PROCUREMENT_STAGES}")
        if self.document_type not in DOCUMENT_TYPES:
            raise ValueError(f"document_type doit être l'une de {DOCUMENT_TYPES}")
        return self


@router.post(
    "/opportunities/{opportunity_id}/documents",
    summary="Déposer un document pour une opportunité OSOA",
    description=(
        "Le dépôt est toujours attribué à l'affilié authentifié -- aucun accès "
        "direct client à ce jour (doctrine 'pas de boîte noire', osoa.clients "
        "n'a pas de mécanisme de connexion propre)."
    ),
)
def create_document_deposit(
    opportunity_id: int,
    data: DocumentDepositCreate,
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

    row = db.execute(
        text("""
            INSERT INTO osoa.document_deposits
                (opportunity_id, deposited_by_affiliate_id, procurement_stage,
                 document_type, title, file_reference)
            VALUES
                (:opportunity_id, :affiliate_id, :procurement_stage,
                 :document_type, :title, :file_reference)
            RETURNING id, opportunity_id, deposited_by_client_id, deposited_by_affiliate_id,
                      procurement_stage, document_type, title, file_reference,
                      outcome, deposited_at::text
        """),
        {
            "opportunity_id": opportunity_id,
            "affiliate_id": affiliate_id,
            "procurement_stage": data.procurement_stage,
            "document_type": data.document_type,
            "title": data.title,
            "file_reference": data.file_reference,
        },
    ).mappings().first()
    db.commit()
    return dict(row)


@router.get(
    "/opportunities/{opportunity_id}/documents",
    summary="Lister les dépôts de documents d'une opportunité OSOA",
)
def list_document_deposits(
    opportunity_id: int,
    procurement_stage: Optional[str] = Query(default=None),
    db: Session = Depends(get_db),
):
    sql = """
        SELECT id, opportunity_id, deposited_by_client_id, deposited_by_affiliate_id,
               procurement_stage, document_type, title, file_reference,
               outcome, deposited_at::text
        FROM osoa.document_deposits
        WHERE opportunity_id = :opportunity_id
    """
    params: dict = {"opportunity_id": opportunity_id}
    if procurement_stage:
        sql += " AND procurement_stage = :procurement_stage"
        params["procurement_stage"] = procurement_stage
    sql += " ORDER BY deposited_at DESC"

    rows = db.execute(text(sql), params).mappings().all()
    return {"count": len(rows), "items": [dict(r) for r in rows]}


class OutcomeUpdate(BaseModel):
    outcome: str = Field(..., description="SHORTLISTED/REJECTED (AMI) ou RETAINED/ELIMINATED (AO/AOI/DP)")


@router.post(
    "/documents/{deposit_id}/outcome",
    summary="Enregistrer l'issue d'un dépôt (shortlist AMI, ou résultat de négociation AO/AOI/DP)",
    description=(
        "Met à jour automatiquement le statut de l'opportunité parente selon "
        "l'issue : REJECTED/ELIMINATED -> ABANDONED, RETAINED -> CLOSED, "
        "SHORTLISTED -> aucun changement (on attend le dépôt DP suivant)."
    ),
)
def set_deposit_outcome(
    deposit_id: int,
    data: OutcomeUpdate,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    deposit = db.execute(
        text("SELECT id, opportunity_id, procurement_stage, outcome FROM osoa.document_deposits WHERE id = :id"),
        {"id": deposit_id},
    ).mappings().first()
    if not deposit:
        raise HTTPException(status_code=404, detail={"fr": "Dépôt introuvable.", "en": "Deposit not found."})

    if deposit["outcome"] is not None:
        raise HTTPException(status_code=409, detail={
            "fr": f"Ce dépôt a déjà une issue enregistrée : {deposit['outcome']}.",
            "en": f"This deposit already has a recorded outcome: {deposit['outcome']}.",
        })

    allowed = STAGE_OUTCOMES[deposit["procurement_stage"]]
    if data.outcome not in allowed:
        raise HTTPException(status_code=422, detail={
            "fr": f"Pour l'étape {deposit['procurement_stage']}, outcome doit être l'une de {allowed}.",
            "en": f"For stage {deposit['procurement_stage']}, outcome must be one of {allowed}.",
        })

    updated_deposit = db.execute(
        text("""
            UPDATE osoa.document_deposits SET outcome = :outcome
            WHERE id = :id
            RETURNING id, opportunity_id, procurement_stage, document_type, outcome, deposited_at::text
        """),
        {"outcome": data.outcome, "id": deposit_id},
    ).mappings().first()

    new_opportunity_status = OUTCOME_TO_OPPORTUNITY_STATUS[data.outcome]
    if new_opportunity_status:
        db.execute(
            text("UPDATE osoa.opportunities SET status = :status, updated_at = NOW() WHERE id = :id"),
            {"status": new_opportunity_status, "id": deposit["opportunity_id"]},
        )

    db.commit()

    return {
        "deposit": dict(updated_deposit),
        "opportunity_status_updated_to": new_opportunity_status,
    }
