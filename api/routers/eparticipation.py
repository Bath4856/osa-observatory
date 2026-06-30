"""
OSA Observatory -- Sprint 30 Lot D1
Router E-Participation -- Contributions tracables affilies authentifies
GET /api/v1/consultation/my-contributions
"""
from typing import Optional, List
from fastapi import APIRouter, Depends, Header, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text
from pydantic import BaseModel
from api.db import get_db
from api.routers.auth_affiliates import get_current_affiliate

router = APIRouter(
    prefix="/api/v1/consultation",
    tags=["E-participation"],
)

# Roles avec acces a l'historique complet (D1)
FULL_HISTORY_ROLES = {"ADMIN", "COMITE_TECH", "COMITE_SCI", "COMITE_ETHIQUE"}

class TicketHistoryItem(BaseModel):
    ticket_ref:   str
    ticket_type:  str
    status:       str
    subject:      Optional[str] = None
    submitter_name: Optional[str] = None
    country_iso3: Optional[str] = None
    pillar_code:  Optional[str] = None
    created_at:   str
    resolved_at:  Optional[str] = None


@router.get("/my-contributions",
    response_model=List[TicketHistoryItem],
    summary="Historique des contributions -- D1",
    description=(
        "Retourne l'historique des contributions. "
        "AFFILIE : ses propres contributions uniquement. "
        "ADMIN/COMITE_TECH/COMITE_SCI/COMITE_ETHIQUE : historique complet."
    ),
)
def get_my_contributions(
    limit: int = 50,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    affiliate_id = int(payload["sub"])
    role = payload.get("role", "AFFILIE")

    if role in FULL_HISTORY_ROLES:
        rows = db.execute(text("""
            SELECT ticket_ref, ticket_type, status, subject,
                   submitter_name, country_iso3, pillar_code,
                   created_at, resolved_at
            FROM mg.pilot_tickets
            ORDER BY created_at DESC
            LIMIT :limit
        """), {"limit": limit}).mappings().all()
    else:
        rows = db.execute(text("""
            SELECT ticket_ref, ticket_type, status, subject,
                   submitter_name, country_iso3, pillar_code,
                   created_at, resolved_at
            FROM mg.pilot_tickets
            WHERE affiliate_id = :affiliate_id
            ORDER BY created_at DESC
            LIMIT :limit
        """), {"affiliate_id": affiliate_id, "limit": limit}).mappings().all()

    return [
        {
            "ticket_ref":     r["ticket_ref"],
            "ticket_type":    r["ticket_type"],
            "status":         r["status"],
            "subject":        r["subject"],
            "submitter_name": r["submitter_name"],
            "country_iso3":   r["country_iso3"],
            "pillar_code":    r["pillar_code"],
            "created_at":     str(r["created_at"]),
            "resolved_at":    str(r["resolved_at"]) if r["resolved_at"] else None,
        }
        for r in rows
    ]


class ContributionCreate(BaseModel):
    ticket_type:    str
    subject:        str
    description:    str
    country_iso3:   Optional[str] = None
    pillar_code:    Optional[str] = None
    indicator_code: Optional[str] = None
    year_concerned: Optional[int] = None
    evidence_url:   Optional[str] = None


@router.post("/contributions",
    summary="Soumettre une contribution tracable -- D1",
    description="Soumission authentifiee liee a affiliate_id. Roles : tous affilies actifs.")
def submit_contribution(
    data: ContributionCreate,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    affiliate_id = int(payload["sub"])
    email = payload.get("email", "")

    allowed_types = ("QUESTION", "SUGGESTION")
    if data.ticket_type not in allowed_types:
        raise HTTPException(
            status_code=400,
            detail=f"Type {data.ticket_type} non autorise. Utiliser QUESTION ou SUGGESTION."
        )

    affiliate = db.execute(
        text("SELECT first_name, last_name FROM mg.affiliates WHERE id = :id"),
        {"id": affiliate_id}
    ).mappings().first()
    full_name = f"{affiliate['first_name']} {affiliate['last_name']}" if affiliate else email

    row = db.execute(text("""
        INSERT INTO mg.pilot_tickets
            (ticket_type, subject, description,
             submitter_email, submitter_name, affiliate_id,
             country_iso3, pillar_code, indicator_code, year_concerned,
             evidence_url)
        VALUES
            (:type, :subject, :description,
             :email, :name, :affiliate_id,
             :iso3, :pillar, :indicator, :year,
             :evidence)
        RETURNING ticket_id, ticket_ref, status, created_at
    """), {
        "type":        data.ticket_type,
        "subject":     data.subject,
        "description": data.description,
        "email":       email,
        "name":        full_name,
        "affiliate_id": affiliate_id,
        "iso3":        data.country_iso3.upper() if data.country_iso3 else None,
        "pillar":      data.pillar_code.upper() if data.pillar_code else None,
        "indicator":   data.indicator_code.upper() if data.indicator_code else None,
        "year":        data.year_concerned,
        "evidence":    data.evidence_url,
    }).mappings().one()
    db.commit()

    return {
        "ticket_ref": row["ticket_ref"],
        "ticket_id":  row["ticket_id"],
        "status":     row["status"],
        "created_at": str(row["created_at"]),
        "message":    f"Contribution {row['ticket_ref']} enregistree et liee a votre profil affilie.",
    }
