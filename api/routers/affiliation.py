"""
OSA Observatory -- Sprint 30 Lot B
Router Affiliation -- Workflow demande d'affiliation
POST /api/v1/affiliation/request
"""
import os
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text
from pydantic import BaseModel, EmailStr, Field
from typing import Optional
from api.db import get_db

router = APIRouter(
    prefix="/api/v1/affiliation",
    tags=["Affiliation OSA"],
)

# ── Schema ────────────────────────────────────────────────────────────────────

class AffiliationRequest(BaseModel):
    last_name:      str   = Field(..., min_length=1, max_length=100)
    first_name:     str   = Field(..., min_length=1, max_length=100)
    function_title: Optional[str] = Field(None, max_length=200)
    email:          str   = Field(..., min_length=5, max_length=255)
    org_name:       str   = Field(..., min_length=1, max_length=300)
    affiliate_type: str   = Field(..., min_length=1, max_length=50)
    country:        Optional[str] = Field(None, max_length=100)
    motivation:     Optional[str] = None

# ── Email helper ──────────────────────────────────────────────────────────────

def send_confirmation_email(to_email: str, first_name: str, last_name: str, ticket_ref: str):
    smtp_host = os.getenv("SMTP_HOST", "mail.gandi.net")
    smtp_port = int(os.getenv("SMTP_PORT", "587"))
    smtp_user = os.getenv("SMTP_USER", "noreply@osa-observatory.africa")
    smtp_pass = os.getenv("SMTP_PASSWORD", "")
    smtp_from = os.getenv("SMTP_FROM", smtp_user)

    subject_fr = "Demande d'affiliation OSA Observatory — Confirmation de réception"

    body_fr = f"""Madame, Monsieur {last_name},

Nous avons bien reçu votre demande d'affiliation à l'Observatoire de la Souveraineté Africaine (OSA).

Référence de votre demande : {ticket_ref}

Votre demande sera examinée par l'équipe de l'Observatoire. Si elle est acceptée, vous recevrez un courrier électronique vous indiquant les prochaines étapes pour accéder à l'espace de contribution.

Nous vous remercions de l'intérêt que vous portez aux travaux de l'OSA.

---
OSA Observatory — Observatoire de la Souveraineté Africaine
open.osa-observatory.africa
"""

    body_en = f"""Dear {first_name} {last_name},

We have received your affiliation request to the African Sovereignty Observatory (OSA).

Reference: {ticket_ref}

Your request will be reviewed by the Observatory team. If accepted, you will receive an email with the next steps to access the contribution space.

Thank you for your interest in OSA's work.

---
OSA Observatory — African Sovereignty Observatory
open.osa-observatory.africa
"""

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject_fr
    msg["From"]    = smtp_from
    msg["To"]      = to_email
    msg.attach(MIMEText(body_fr + "\n\n---\n\n" + body_en, "plain", "utf-8"))

    with smtplib.SMTP(smtp_host, smtp_port, timeout=15) as s:
        s.ehlo()
        s.starttls()
        s.ehlo()
        s.login(smtp_user, smtp_pass)
        s.sendmail(smtp_from, to_email, msg.as_string())

# ── Endpoint ──────────────────────────────────────────────────────────────────

@router.post(
    "/request",
    summary="Soumettre une demande d'affiliation OSA",
    description=(
        "Enregistre une demande d'affiliation dans mg.affiliates (PENDING) "
        "et mg.pilot_tickets, et envoie un email de confirmation."
    ),
)
def submit_affiliation_request(
    data: AffiliationRequest,
    db:   Session = Depends(get_db),
):
    # 1. Verifier si email deja enregistre
    existing = db.execute(
        text("SELECT id, status FROM mg.affiliates WHERE email = :email"),
        {"email": data.email.lower().strip()}
    ).mappings().first()

    if existing:
        if existing["status"] == "ACTIVE":
            raise HTTPException(status_code=409, detail="Un compte actif existe deja pour cet email.")
        elif existing["status"] == "PENDING":
            raise HTTPException(status_code=409, detail="Une demande est deja en cours pour cet email.")

    # 2. Creer l'affilie en PENDING
    affiliate = db.execute(text("""
        INSERT INTO mg.affiliates
            (last_name, first_name, function_title, email,
             org_name, affiliate_type, country, motivation, status)
        VALUES
            (:last_name, :first_name, :function_title, :email,
             :org_name, :affiliate_type, :country, :motivation, 'PENDING')
        RETURNING id
    """), {
        "last_name":      data.last_name.strip(),
        "first_name":     data.first_name.strip(),
        "function_title": data.function_title,
        "email":          data.email.lower().strip(),
        "org_name":       data.org_name.strip(),
        "affiliate_type": data.affiliate_type,
        "country":        data.country,
        "motivation":     data.motivation,
    }).mappings().one()

    affiliate_id = affiliate["id"]

    # 3. Creer le ticket DEMANDE_AFFILIATION
    ticket = db.execute(text("""
        INSERT INTO mg.pilot_tickets
            (ticket_type, subject, description,
             submitter_email, submitter_name, affiliation_id)
        VALUES
            ('QUESTION',
             'DEMANDE_AFFILIATION -- ' || :org_name,
             :motivation,
             :email, :full_name, :affiliate_id)
        RETURNING ticket_id, ticket_ref, status, created_at
    """), {
        "org_name":     data.org_name.strip(),
        "motivation":   data.motivation or "",
        "email":        data.email.lower().strip(),
        "full_name":    f"{data.first_name} {data.last_name}",
        "affiliate_id": affiliate_id,
    }).mappings().one()

    # 4. Mettre a jour ticket_ref dans affiliates
    db.execute(text("""
        UPDATE mg.affiliates SET ticket_ref = :ref WHERE id = :id
    """), {"ref": ticket["ticket_ref"], "id": affiliate_id})

    db.commit()

    # 5. Envoyer email de confirmation
    email_sent = False
    try:
        send_confirmation_email(
            to_email   = data.email.lower().strip(),
            first_name = data.first_name.strip(),
            last_name  = data.last_name.strip(),
            ticket_ref = ticket["ticket_ref"],
        )
        email_sent = True
    except Exception as e:
        # Ne pas bloquer si email echoue -- la demande est enregistree
        pass

    return {
        "ticket_ref":  ticket["ticket_ref"],
        "affiliate_id": affiliate_id,
        "status":      "PENDING",
        "email_sent":  email_sent,
        "message": (
            "Votre demande d'affiliation a bien ete enregistree. "
            "Elle sera examinee par l'equipe de l'Observatoire Africain de la Souverainete. "
            f"Reference : {ticket['ticket_ref']}"
        ),
    }
