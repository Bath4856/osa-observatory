"""
OSA Observatory -- Sprint 19 post-runbook
Router tickets pilote -- D2.3
Canal 2 : soumission API + administration cellule de revue

Endpoints :
  PUBLIC  POST /api/v1/tickets              -- soumettre QUESTION/SUGGESTION
  STANDARD POST /api/v1/tickets/secure      -- soumettre CONTESTATION/DEMANDE_CORRECTION/DEMANDE_ACCES
  EXPERT  GET  /api/v1/admin/tickets        -- lister tickets
  EXPERT  GET  /api/v1/admin/tickets/{ref}  -- detail ticket
  EXPERT  PATCH /api/v1/admin/tickets/{ref} -- traiter ticket
  EXPERT  GET  /api/v1/admin/tickets/stats  -- metriques pilote
"""

import json
from typing import Optional
from datetime import datetime
from fastapi import APIRouter, Depends, Query, HTTPException
from fastapi.responses import Response
from sqlalchemy import text
from sqlalchemy.orm import Session
from pydantic import BaseModel, Field

from api.db import get_db
from api.security import validate_standard_access, validate_expert_access

# ── Deux routers : public + admin ─────────────────────────────
public_router = APIRouter(prefix="/api/v1", tags=["Tickets Pilote -- Public"])
admin_router  = APIRouter(prefix="/api/v1/admin", tags=["Tickets Pilote -- Administration"])

# ── Helpers ───────────────────────────────────────────────────
def _json(data) -> Response:
    return Response(
        content=json.dumps(data, ensure_ascii=False, default=str),
        media_type="application/json; charset=utf-8"
    )

# ── Schemas ───────────────────────────────────────────────────
class TicketPublicCreate(BaseModel):
    ticket_type:    str  = Field(..., description="QUESTION ou SUGGESTION uniquement")
    subject:        str  = Field(..., max_length=200)
    description:    str
    submitter_email: Optional[str] = None
    submitter_name:  Optional[str] = None
    country_iso3:    Optional[str] = Field(None, max_length=3)
    year_concerned:  Optional[int] = None
    pillar_code:     Optional[str] = Field(None, max_length=10)
    indicator_code:  Optional[str] = Field(None, max_length=30)
    evidence_url:    Optional[str] = None

class TicketSecureCreate(BaseModel):
    ticket_type:    str  = Field(..., description="CONTESTATION / DEMANDE_CORRECTION / DEMANDE_ACCES")
    subject:        str  = Field(..., max_length=200)
    description:    str
    priority:       str  = Field(default="NORMAL", description="URGENT / NORMAL / LOW")
    country_iso3:   Optional[str] = Field(None, max_length=3)
    year_concerned: Optional[int] = None
    pillar_code:    Optional[str] = Field(None, max_length=10)
    indicator_code: Optional[str] = Field(None, max_length=30)
    dataset_code:   Optional[str] = None
    evidence_url:   Optional[str] = None

class TicketUpdate(BaseModel):
    status:          Optional[str] = None
    assigned_to:     Optional[str] = None
    priority:        Optional[str] = None
    pol_level:       Optional[str] = Field(None, description="N1/N2/N3/N4")
    pol_ref:         Optional[str] = None
    resolution_note: Optional[str] = None
    resolved_at:     Optional[str] = None


# ══════════════════════════════════════════════════════════════
# ENDPOINTS PUBLICS
# ══════════════════════════════════════════════════════════════

@public_router.post(
    "/tickets",
    summary="Soumettre une QUESTION ou SUGGESTION (public)",
    description=(
        "Soumission publique sans authentification. "
        "Types autorisés : QUESTION, SUGGESTION uniquement. "
        "Pour CONTESTATION ou DEMANDE_CORRECTION, utiliser POST /api/v1/tickets/secure (JWT requis)."
    ),
)
async def submit_public_ticket(
    data: TicketPublicCreate,
    db:   Session = Depends(get_db),
):
    # Validation type
    allowed = ("QUESTION", "SUGGESTION")
    if data.ticket_type not in allowed:
        raise HTTPException(
            status_code=400,
            detail=f"Type {data.ticket_type} non autorisé en soumission publique. "
                   f"Utiliser /tickets/secure pour CONTESTATION / DEMANDE_CORRECTION / DEMANDE_ACCES."
        )

    row = db.execute(text("""
        INSERT INTO mg.pilot_tickets
            (ticket_type, subject, description,
             submitter_email, submitter_name,
             country_iso3, year_concerned, pillar_code, indicator_code,
             evidence_url)
        VALUES
            (:type, :subject, :description,
             :email, :name,
             :iso3, :year, :pillar, :indicator,
             :evidence)
        RETURNING ticket_id, ticket_ref, status, created_at
    """), {
        "type":       data.ticket_type,
        "subject":    data.subject,
        "description":data.description,
        "email":      data.submitter_email,
        "name":       data.submitter_name,
        "iso3":       data.country_iso3.upper() if data.country_iso3 else None,
        "year":       data.year_concerned,
        "pillar":     data.pillar_code.upper() if data.pillar_code else None,
        "indicator":  data.indicator_code.upper() if data.indicator_code else None,
        "evidence":   data.evidence_url,
    }).mappings().one()
    db.commit()

    return _json({
        "ticket_ref":  row["ticket_ref"],
        "ticket_id":   row["ticket_id"],
        "status":      row["status"],
        "created_at":  str(row["created_at"]),
        "message":     f"Ticket {row['ticket_ref']} enregistré. "
                       f"Réponse sous 72h à {data.submitter_email or 'votre contact OSA'}.",
    })


# ══════════════════════════════════════════════════════════════
# ENDPOINTS AUTHENTIFIÉS (STANDARD+)
# ══════════════════════════════════════════════════════════════

@public_router.post(
    "/tickets/secure",
    summary="Soumettre CONTESTATION / DEMANDE_CORRECTION / DEMANDE_ACCES (JWT Standard)",
    description=(
        "Soumission authentifiée. L'affiliation_id est automatiquement "
        "renseigné depuis le token JWT. "
        "Types autorisés : CONTESTATION, DEMANDE_CORRECTION, DEMANDE_ACCES."
    ),
)
async def submit_secure_ticket(
    data: TicketSecureCreate,
    db:   Session = Depends(get_db),
    auth: dict    = Depends(validate_standard_access),
):
    allowed = ("CONTESTATION", "DEMANDE_CORRECTION", "DEMANDE_ACCES")
    if data.ticket_type not in allowed:
        raise HTTPException(
            status_code=400,
            detail=f"Type {data.ticket_type} non autorisé ici. "
                   f"Utiliser /tickets pour QUESTION / SUGGESTION."
        )

    # Priorité auto selon type
    priority = data.priority
    if data.ticket_type in ("CONTESTATION", "DEMANDE_CORRECTION") and priority == "NORMAL":
        priority = "URGENT"

    affiliation_id = auth.get("affiliation_id")

    row = db.execute(text("""
        INSERT INTO mg.pilot_tickets
            (ticket_type, priority, subject, description,
             affiliation_id, submitter_email,
             country_iso3, year_concerned, pillar_code, indicator_code,
             dataset_code, evidence_url)
        VALUES
            (:type, :priority, :subject, :description,
             :affil, :email,
             :iso3, :year, :pillar, :indicator,
             :dataset, :evidence)
        RETURNING ticket_id, ticket_ref, status, priority, created_at
    """), {
        "type":       data.ticket_type,
        "priority":   priority,
        "subject":    data.subject,
        "description":data.description,
        "affil":      affiliation_id,
        "email":      auth.get("email"),
        "iso3":       data.country_iso3.upper() if data.country_iso3 else None,
        "year":       data.year_concerned,
        "pillar":     data.pillar_code.upper() if data.pillar_code else None,
        "indicator":  data.indicator_code.upper() if data.indicator_code else None,
        "dataset":    data.dataset_code,
        "evidence":   data.evidence_url,
    }).mappings().one()
    db.commit()

    return _json({
        "ticket_ref":     row["ticket_ref"],
        "ticket_id":      row["ticket_id"],
        "status":         row["status"],
        "priority":       row["priority"],
        "affiliation_id": affiliation_id,
        "created_at":     str(row["created_at"]),
        "message":        f"Ticket {row['ticket_ref']} enregistré avec priorité {row['priority']}. "
                          f"La cellule de revue OSA vous répondra sous "
                          + ("24h." if row["priority"] == "URGENT" else "72h."),
    })


@public_router.get(
    "/tickets/{ticket_ref}",
    summary="Consulter son propre ticket (JWT Standard)",
    description="Un partenaire peut consulter l'état de son ticket via sa référence OSA-YYYY-NNNN.",
)
async def get_my_ticket(
    ticket_ref: str,
    db:   Session = Depends(get_db),
    auth: dict    = Depends(validate_standard_access),
):
    affiliation_id = auth.get("affiliation_id")
    row = db.execute(text("""
        SELECT ticket_ref, ticket_type, priority, status,
               subject, country_iso3, year_concerned, pillar_code,
               resolution_note, created_at, updated_at, resolved_at
        FROM mg.pilot_tickets
        WHERE ticket_ref = :ref
          AND (affiliation_id = :affil OR :affil IS NULL)
    """), {"ref": ticket_ref.upper(), "affil": affiliation_id}).mappings().one_or_none()

    if not row:
        raise HTTPException(status_code=404, detail=f"Ticket {ticket_ref} introuvable.")

    return _json(dict(row))


# ══════════════════════════════════════════════════════════════
# ENDPOINTS ADMIN (EXPERT)
# ══════════════════════════════════════════════════════════════

@admin_router.get(
    "/tickets/stats",
    summary="Métriques pilote tickets (Expert)",
)
async def get_tickets_stats(
    db:   Session = Depends(get_db),
    auth: dict    = Depends(validate_expert_access),
):
    row = db.execute(text("""
        SELECT
            COUNT(*)                                                        AS total_tickets,
            COUNT(*) FILTER (WHERE ticket_type='QUESTION')                  AS questions,
            COUNT(*) FILTER (WHERE ticket_type='CONTESTATION')              AS contestations,
            COUNT(*) FILTER (WHERE ticket_type='DEMANDE_ACCES')             AS demandes_acces,
            COUNT(*) FILTER (WHERE ticket_type='DEMANDE_CORRECTION')        AS demandes_correction,
            COUNT(*) FILTER (WHERE ticket_type='SUGGESTION')                AS suggestions,
            COUNT(*) FILTER (WHERE status='OUVERT')                         AS ouverts,
            COUNT(*) FILTER (WHERE status='EN_TRAITEMENT')                  AS en_traitement,
            COUNT(*) FILTER (WHERE status='ESCALADE')                       AS escalades,
            COUNT(*) FILTER (WHERE status='RESOLU')                         AS resolus,
            ROUND(100.0*COUNT(*) FILTER (WHERE status='RESOLU')
                  /NULLIF(COUNT(*),0),1)                                    AS taux_resolution,
            ROUND(AVG(EXTRACT(EPOCH FROM (resolved_at-created_at))/3600)
                  FILTER (WHERE status='RESOLU'),1)                         AS temps_moyen_resolution_h,
            COUNT(*) FILTER (WHERE priority='URGENT' AND status='OUVERT')   AS urgents_non_traites
        FROM mg.pilot_tickets
    """)).mappings().one()
    return _json(dict(row))


@admin_router.get(
    "/tickets",
    summary="Lister les tickets pilote (Expert)",
)
async def list_tickets(
    db:          Session       = Depends(get_db),
    auth:        dict          = Depends(validate_expert_access),
    ticket_type: Optional[str] = Query(None),
    status:      Optional[str] = Query(None),
    priority:    Optional[str] = Query(None),
    limit:       int           = Query(50, ge=1, le=200),
):
    rows = db.execute(text("""
        SELECT t.ticket_ref, t.ticket_type, t.priority, t.status,
               t.subject, t.country_iso3, t.year_concerned, t.pillar_code,
               t.submitter_email, t.assigned_to, t.pol_level,
               t.created_at, t.updated_at,
               a.institution_name AS affiliation_name
        FROM mg.pilot_tickets t
        LEFT JOIN rf.affiliations a ON a.affiliation_id = t.affiliation_id
        WHERE (:type IS NULL OR t.ticket_type = :type)
          AND (:status IS NULL OR t.status = :status)
          AND (:priority IS NULL OR t.priority = :priority)
        ORDER BY
            CASE t.priority WHEN 'URGENT' THEN 1 WHEN 'NORMAL' THEN 2 ELSE 3 END,
            t.created_at ASC
        LIMIT :limit
    """), {
        "type":     ticket_type,
        "status":   status,
        "priority": priority,
        "limit":    limit,
    }).mappings().all()

    return _json({"count": len(rows), "tickets": [dict(r) for r in rows]})


@admin_router.get(
    "/tickets/{ticket_ref}",
    summary="Détail d'un ticket (Expert)",
)
async def get_ticket_detail(
    ticket_ref: str,
    db:   Session = Depends(get_db),
    auth: dict    = Depends(validate_expert_access),
):
    row = db.execute(text("""
        SELECT t.*,
               a.institution_name, a.access_level AS affiliation_level
        FROM mg.pilot_tickets t
        LEFT JOIN rf.affiliations a ON a.affiliation_id = t.affiliation_id
        WHERE t.ticket_ref = :ref
    """), {"ref": ticket_ref.upper()}).mappings().one_or_none()

    if not row:
        raise HTTPException(status_code=404, detail=f"Ticket {ticket_ref} introuvable.")
    return _json(dict(row))


@admin_router.patch(
    "/tickets/{ticket_ref}",
    summary="Traiter un ticket (Expert)",
    description="Mise à jour du statut, assignation, classification POL-OSA-001, note de résolution.",
)
async def update_ticket(
    ticket_ref: str,
    data: TicketUpdate,
    db:   Session = Depends(get_db),
    auth: dict    = Depends(validate_expert_access),
):
    # Construire la mise à jour dynamique
    updates = {}
    if data.status is not None:
        updates["status"] = data.status
        if data.status == "RESOLU" and data.resolved_at is None:
            updates["resolved_at"] = "now()"
    if data.assigned_to is not None:
        updates["assigned_to"] = data.assigned_to
    if data.priority is not None:
        updates["priority"] = data.priority
    if data.pol_level is not None:
        updates["pol_level"] = data.pol_level
    if data.pol_ref is not None:
        updates["pol_ref"] = data.pol_ref
    if data.resolution_note is not None:
        updates["resolution_note"] = data.resolution_note

    if not updates:
        raise HTTPException(status_code=400, detail="Aucun champ à mettre à jour.")

    # Construire SET clause
    set_parts = []
    params = {"ref": ticket_ref.upper()}
    for k, v in updates.items():
        if v == "now()":
            set_parts.append(f"{k} = now()")
        else:
            set_parts.append(f"{k} = :{k}")
            params[k] = v

    set_clause = ", ".join(set_parts)

    row = db.execute(text(f"""
        UPDATE mg.pilot_tickets
        SET {set_clause}
        WHERE ticket_ref = :ref
        RETURNING ticket_ref, status, priority, assigned_to,
                  pol_level, updated_at
    """), params).mappings().one_or_none()

    if not row:
        raise HTTPException(status_code=404, detail=f"Ticket {ticket_ref} introuvable.")
    db.commit()

    return _json({
        "ticket_ref": row["ticket_ref"],
        "status":     row["status"],
        "priority":   row["priority"],
        "assigned_to":row["assigned_to"],
        "pol_level":  row["pol_level"],
        "updated_at": str(row["updated_at"]),
        "message":    f"Ticket {row['ticket_ref']} mis à jour.",
    })
