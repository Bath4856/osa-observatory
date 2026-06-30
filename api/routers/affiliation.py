"""
OSA Observatory -- Sprint 30 Lot B -- REVISE R1 (AFFILIATION_WORKFLOW_REVISION_001)
Router Affiliation -- Auto-activation par confirmation email
POST /api/v1/affiliation/request
GET  /api/v1/affiliation/confirm-email/{token}
"""
import os
import smtplib
import uuid
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text
from pydantic import BaseModel, Field
from typing import Optional
from api.db import get_db

router = APIRouter(
    prefix="/api/v1/affiliation",
    tags=["Affiliation OSA"],
)

TOKEN_EXPIRY_HOURS = 48

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

def _smtp_send(to_email: str, subject: str, body: str):
    smtp_host = os.getenv("SMTP_HOST", "mail.gandi.net")
    smtp_port = int(os.getenv("SMTP_PORT", "587"))
    smtp_user = os.getenv("SMTP_USER", "noreply@osa-observatory.africa")
    smtp_pass = os.getenv("SMTP_PASSWORD", "")
    smtp_from = os.getenv("SMTP_FROM", smtp_user)

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"]    = smtp_from
    msg["To"]      = to_email
    msg.attach(MIMEText(body, "plain", "utf-8"))

    with smtplib.SMTP(smtp_host, smtp_port, timeout=15) as s:
        s.ehlo()
        s.starttls()
        s.ehlo()
        s.login(smtp_user, smtp_pass)
        s.sendmail(smtp_from, to_email, msg.as_string())


def send_confirmation_link_email(to_email: str, first_name: str, last_name: str, token: str):
    confirm_url = f"https://open.osa-observatory.africa/confirm-email?token={token}"

    body_fr = f"""Madame, Monsieur {last_name},

Merci pour votre demande d'affiliation a l'Observatoire de la Souverainete Africaine (OSA).

Pour activer votre compte affilie, veuillez confirmer votre adresse email en cliquant sur le lien suivant (valide {TOKEN_EXPIRY_HOURS}h) :

{confirm_url}

Une fois votre email confirme, vous aurez immediatement acces a votre espace de contribution.

---
OSA Observatory -- Observatoire de la Souverainete Africaine
open.osa-observatory.africa
"""

    body_en = f"""Dear {first_name} {last_name},

Thank you for your affiliation request to the African Sovereignty Observatory (OSA).

To activate your affiliate account, please confirm your email address by clicking the link below (valid {TOKEN_EXPIRY_HOURS}h):

{confirm_url}

Once your email is confirmed, you will have immediate access to your contribution space.

---
OSA Observatory -- African Sovereignty Observatory
open.osa-observatory.africa
"""

    _smtp_send(
        to_email,
        "Confirmez votre adresse email -- OSA Observatory / Confirm your email",
        body_fr + "\n\n---\n\n" + body_en
    )


def send_welcome_email(to_email: str, first_name: str, last_name: str):
    body_fr = f"""Madame, Monsieur {last_name},

Votre adresse email a ete confirmee. Votre compte affilie OSA Observatory est desormais actif.

Vous pouvez acceder a votre espace de contribution sur open.osa-observatory.africa.

L'OSA distingue les espaces de contribution des espaces de validation scientifique : en tant qu'affilie, vous participez a la production collective des connaissances. Les comites scientifique, technique et d'ethique assurent l'expertise, l'evaluation et la validation des analyses officielles.

Bienvenue a l'Observatoire de la Souverainete Africaine.

---
OSA Observatory -- Observatoire de la Souverainete Africaine
open.osa-observatory.africa
"""

    body_en = f"""Dear {first_name} {last_name},

Your email address has been confirmed. Your OSA Observatory affiliate account is now active.

You can access your contribution space at open.osa-observatory.africa.

OSA distinguishes contribution spaces from scientific validation spaces: as an affiliate, you contribute to the collective production of knowledge. The scientific, technical and ethics committees ensure the expertise, evaluation and validation of official analyses.

Welcome to the African Sovereignty Observatory.

---
OSA Observatory -- African Sovereignty Observatory
open.osa-observatory.africa
"""

    _smtp_send(
        to_email,
        "Bienvenue a l'OSA Observatory / Welcome to OSA Observatory",
        body_fr + "\n\n---\n\n" + body_en
    )

# ── Endpoint 1 : demande d'affiliation ─────────────────────────────────────────

@router.post(
    "/request",
    summary="Soumettre une demande d'affiliation OSA",
    description=(
        "Cree l'affilie en statut PENDING_EMAIL et envoie un email de confirmation. "
        "Le compte s'active automatiquement des confirmation -- aucune validation manuelle."
    ),
)
def submit_affiliation_request(
    data: AffiliationRequest,
    db:   Session = Depends(get_db),
):
    email = data.email.lower().strip()

    existing = db.execute(
        text("SELECT id, status FROM mg.affiliates WHERE email = :email"),
        {"email": email}
    ).mappings().first()

    if existing:
        if existing["status"] in ("ACTIVE", "AFFILIATED"):
            raise HTTPException(status_code=409, detail={
                "fr": "Un compte actif existe déjà pour cet email.",
                "en": "An active account already exists for this email."
            })
        elif existing["status"] in ("PENDING", "PENDING_EMAIL"):
            raise HTTPException(status_code=409, detail={
                "fr": "Une demande est déjà en cours pour cet email. Vérifiez votre boîte mail.",
                "en": "A request is already pending for this email. Please check your inbox."
            })

    affiliate = db.execute(text("""
        INSERT INTO mg.affiliates
            (last_name, first_name, function_title, email,
             org_name, affiliate_type, country, motivation, status)
        VALUES
            (:last_name, :first_name, :function_title, :email,
             :org_name, :affiliate_type, :country, :motivation, 'PENDING_EMAIL')
        RETURNING id
    """), {
        "last_name":      data.last_name.strip(),
        "first_name":     data.first_name.strip(),
        "function_title": data.function_title,
        "email":          email,
        "org_name":       data.org_name.strip(),
        "affiliate_type": data.affiliate_type,
        "country":        data.country,
        "motivation":     data.motivation,
    }).mappings().one()

    affiliate_id = affiliate["id"]

    token_row = db.execute(text("""
        INSERT INTO mg.email_confirmation_tokens
            (affiliate_id, expires_at)
        VALUES
            (:affiliate_id, NOW() + INTERVAL '%s hours')
        RETURNING token
    """ % TOKEN_EXPIRY_HOURS), {"affiliate_id": affiliate_id}).mappings().one()

    db.commit()

    email_sent = False
    try:
        send_confirmation_link_email(
            to_email   = email,
            first_name = data.first_name.strip(),
            last_name  = data.last_name.strip(),
            token      = str(token_row["token"]),
        )
        email_sent = True
    except Exception:
        pass

    return {
        "affiliate_id": affiliate_id,
        "status":       "PENDING_EMAIL",
        "email_sent":   email_sent,
        "message": {
            "fr": "Vérifiez votre boîte mail pour confirmer votre adresse et activer votre compte affilié.",
            "en": "Please check your inbox to confirm your email and activate your affiliate account."
        },
    }


# ── Endpoint 2 : confirmation email ────────────────────────────────────────────

@router.get(
    "/confirm-email/{token}",
    summary="Confirmer l'email -- activation automatique R1",
    description="Valide le token, active le compte affilie (AFFILIATED). Aucune intervention humaine.",
)
def confirm_email(token: str, db: Session = Depends(get_db)):
    token_row = db.execute(text("""
        SELECT t.id, t.affiliate_id, t.expires_at, t.used_at,
               a.first_name, a.last_name, a.email, a.status
        FROM mg.email_confirmation_tokens t
        JOIN mg.affiliates a ON a.id = t.affiliate_id
        WHERE t.token = :token
    """), {"token": token}).mappings().first()

    if not token_row:
        raise HTTPException(status_code=404, detail={
            "fr": "Lien de confirmation invalide.",
            "en": "Invalid confirmation link."
        })

    if token_row["used_at"]:
        raise HTTPException(status_code=400, detail={
            "fr": "Ce lien a déjà été utilisé.",
            "en": "This link has already been used."
        })

    import datetime
    if token_row["expires_at"] < datetime.datetime.utcnow():
        raise HTTPException(status_code=400, detail={
            "fr": "Ce lien a expiré. Veuillez soumettre une nouvelle demande d'affiliation.",
            "en": "This link has expired. Please submit a new affiliation request."
        })

    db.execute(text("""
        UPDATE mg.affiliates SET status = 'AFFILIATED' WHERE id = :id
    """), {"id": token_row["affiliate_id"]})

    db.execute(text("""
        UPDATE mg.email_confirmation_tokens SET used_at = NOW() WHERE id = :id
    """), {"id": token_row["id"]})

    db.commit()

    try:
        send_welcome_email(
            to_email   = token_row["email"],
            first_name = token_row["first_name"],
            last_name  = token_row["last_name"],
        )
    except Exception:
        pass

    return {
        "affiliate_id": token_row["affiliate_id"],
        "status":       "AFFILIATED",
        "message": {
            "fr": "Votre email a été confirmé. Votre compte affilié est désormais actif.",
            "en": "Your email has been confirmed. Your affiliate account is now active."
        },
    }
