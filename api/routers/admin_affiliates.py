"""
OSA Observatory -- Systeme des premiers affilies (preprod)
Router Admin -- Pre-creation d'affilies fondateurs par cooptation stricte
POST /api/v2/affiliates/admin/preaffiliate
Reserve au role ADMIN (require_admin). Ne passe jamais par le formulaire
public /api/v1/affiliation/request -- creation directe, sur decision de
l'administrateur (cooptation stricte, cf. plan D1-D6).
"""
import os
import smtplib
from email.mime.text import MIMEText
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text
from pydantic import BaseModel, Field
from typing import Optional, Literal
from api.db import get_db
from api.routers.auth_affiliates import require_admin

router = APIRouter(
    prefix="/api/v2/affiliates/admin",
    tags=["Administration -- affiliation fondatrice"],
)

# ── Config e-mail (reprend _smtp_send d'affiliation.py, dupliquee ici
#    volontairement : le domaine de confirmation doit varier selon
#    l'environnement d'execution, contrairement a la fonction d'origine
#    qui pointe en dur vers la production) ─────────────────────────────
def _smtp_send(to_email: str, subject: str, body: str):
    # Bug decouvert le 5 juillet 2026 : les variables reelles sont prefixees
    # OSA_SMTP_* (verifie dans api/.env.preprod), pas SMTP_* -- meme defaut
    # errone que dans affiliation.py (jamais corrige depuis sa creation,
    # cf. commit 6b11c64). Sans le prefixe, smtp_pass tombe sur "" et
    # l'authentification Gandi echoue silencieusement (exception avalee
    # plus bas pour ne pas annuler la creation de l'affilie).
    smtp_host = os.getenv("OSA_SMTP_HOST", "mail.gandi.net")
    smtp_port = int(os.getenv("OSA_SMTP_PORT", "587"))
    smtp_user = os.getenv("OSA_SMTP_USER", "noreply@osa-observatory.africa")
    smtp_pass = os.getenv("OSA_SMTP_PASSWORD", "")
    smtp_from = os.getenv("OSA_SMTP_FROM", smtp_user)

    msg = MIMEText(body, "plain", "utf-8")
    msg["Subject"] = subject
    msg["From"] = smtp_from
    msg["To"] = to_email

    with smtplib.SMTP(smtp_host, smtp_port, timeout=15) as s:
        s.starttls()
        s.login(smtp_user, smtp_pass)
        s.sendmail(smtp_from, [to_email], msg.as_string())


def send_founder_confirmation_email(
    to_email: str, first_name: str, last_name: str,
    token: str, base_url: str, expiry_days: int
):
    confirm_url = f"{base_url}/confirm-email?token={token}"

    body_fr = f"""Cher/Chère {first_name} {last_name},

Vous avez été invité(e) à rejoindre le cercle fondateur de l'Observatoire de
la Souveraineté Africaine (OSA), pour participer à la validation de la
plateforme avant son lancement institutionnel.

Pour activer votre accès, cliquez sur le lien suivant (valide {expiry_days} jours,
usage unique) -- vous y choisirez vous-même votre mot de passe :

{confirm_url}

---
OSA Observatory -- Observatoire de la Souveraineté Africaine
"""

    body_en = f"""Dear {first_name} {last_name},

You have been invited to join the founding circle of the African Sovereignty
Observatory (OSA), to help validate the platform ahead of its institutional
launch.

To activate your access, click the link below (valid {expiry_days} days,
single use) -- you will choose your own password there:

{confirm_url}

---
OSA Observatory -- African Sovereignty Observatory
"""

    _smtp_send(
        to_email,
        "Invitation -- Cercle fondateur OSA Observatory / Founding circle invitation",
        body_fr + "\n\n---\n\n" + body_en
    )


# ── Schemas ───────────────────────────────────────────────────────────────────

class CommitteeTarget(BaseModel):
    type: Literal["COMMITTEE"]
    committee_code: str = Field(..., description="COMITE_TECH, COMITE_SCI ou COMITE_ETHIQUE")


class WorkingGroupTarget(BaseModel):
    type: Literal["WORKING_GROUP"]
    pillar_code: str = Field(..., description="Code du pilier, ex. PGEO")


class PreaffiliateRequest(BaseModel):
    first_name: str
    last_name: str
    email: str
    org_name: str = "OSA Observatory"
    affiliate_type: str = "FONDATEUR"
    target: dict = Field(..., description='{"type": "COMMITTEE", "committee_code": "COMITE_TECH"} ou {"type": "WORKING_GROUP", "pillar_code": "PGEO"}')
    token_expiry_days: int = Field(30, description="Duree de validite du lien de confirmation (jours)")
    base_url: str = Field(..., description="Domaine de l'environnement cible, ex. https://preprod.osa-observatory.africa")
    send_email: bool = Field(True, description="False pour generer le lien sans envoyer d'e-mail (flyer/QR)")


class PreaffiliateResponse(BaseModel):
    affiliate_id: int
    email: str
    confirm_url: str
    expires_at: str
    email_sent: bool
    email_error: Optional[str] = None


# ── Endpoint ──────────────────────────────────────────────────────────────────

@router.post("/preaffiliate", response_model=PreaffiliateResponse,
    summary="Pré-création d'un affilié fondateur (cooptation stricte)",
    description=(
        "Réservé au rôle ADMIN. Crée directement un affilié (statut PENDING_EMAIL, "
        "pas via le formulaire public), l'inscrit dans le comité ou le groupe de "
        "travail cible, génère un lien de confirmation à usage unique et l'envoie "
        "par e-mail (optionnel -- peut être désactivé pour générer un QR code "
        "destiné à un flyer)."
    ))
def preaffiliate(
    data: PreaffiliateRequest,
    admin: dict = Depends(require_admin),
    db: Session = Depends(get_db),
):
    email_norm = data.email.lower().strip()

    existing = db.execute(
        text("SELECT id FROM mg.affiliates WHERE email = :email"),
        {"email": email_norm}
    ).first()
    if existing:
        raise HTTPException(status_code=409, detail=f"Un affilié existe déjà pour {email_norm}.")

    target_type = data.target.get("type")
    if target_type not in ("COMMITTEE", "WORKING_GROUP"):
        raise HTTPException(status_code=422, detail='target.type doit être "COMMITTEE" ou "WORKING_GROUP".')

    admin_id = int(admin["sub"])

    # 1) Creation de l'affilie -- password_hash reste NULL : l'affilie
    #    choisira lui-meme son mot de passe lors de la confirmation
    #    (fusionne dans confirm-email, decision du 11 juillet 2026).
    new_affiliate = db.execute(text("""
        INSERT INTO mg.affiliates
            (last_name, first_name, email, org_name, affiliate_type, status)
        VALUES
            (:last_name, :first_name, :email, :org_name, :affiliate_type, 'PENDING_EMAIL')
        RETURNING id
    """), {
        "last_name": data.last_name, "first_name": data.first_name,
        "email": email_norm, "org_name": data.org_name,
        "affiliate_type": data.affiliate_type,
    }).mappings().first()
    affiliate_id = new_affiliate["id"]

    # 2) Rattachement -- comite (cooptation directe, approuvee par l'admin
    #    appelant) ou groupe de travail (invitation, statut INVITED)
    if target_type == "COMMITTEE":
        committee_code = data.target.get("committee_code")
        committee_exists = db.execute(
            text("SELECT 1 FROM mg.committees WHERE code = :c"),
            {"c": committee_code}
        ).first()
        if not committee_exists:
            db.rollback()
            raise HTTPException(status_code=422, detail=f"Comité inconnu : {committee_code}")

        cooptation = db.execute(text("""
            INSERT INTO mg.cooptation_proposals
                (affiliate_id, proposed_by, target_committee, justification, status, reviewed_by, effective_from, reviewed_at)
            VALUES
                (:aff_id, :admin_id, :committee, CAST(:justification AS jsonb), 'APPROVED', :admin_id, CURRENT_DATE, NOW())
            RETURNING id
        """), {
            "aff_id": affiliate_id, "admin_id": admin_id, "committee": committee_code,
            "justification": '{"note": "Pré-création fondatrice -- cercle des premiers affiliés"}',
        }).mappings().first()

        db.execute(text("""
            INSERT INTO mg.committee_memberships
                (affiliate_id, committee, appointed_from, start_date, status)
            VALUES
                (:aff_id, :committee, :coopt_id, CURRENT_DATE, 'ACTIVE')
        """), {"aff_id": affiliate_id, "committee": committee_code, "coopt_id": cooptation["id"]})

    else:  # WORKING_GROUP
        pillar_code = data.target.get("pillar_code")
        wg_exists = db.execute(
            text("SELECT 1 FROM mg.working_groups WHERE pillar_code = :p"),
            {"p": pillar_code}
        ).first()
        if not wg_exists:
            db.rollback()
            raise HTTPException(status_code=422, detail=f"Groupe de travail inconnu : {pillar_code}")

        db.execute(text("""
            INSERT INTO mg.working_group_members
                (pillar_code, affiliate_id, invited_by, status)
            VALUES
                (:pillar, :aff_id, :admin_id, 'INVITED')
        """), {"pillar": pillar_code, "aff_id": affiliate_id, "admin_id": admin_id})

    # 3) Token de confirmation, expiration parametrable (30 jours par defaut
    #    pour ce lot fondateur, cf. decision D4 -- au lieu des 48h standard)
    expires_at = datetime.utcnow() + timedelta(days=data.token_expiry_days)
    token_row = db.execute(text("""
        INSERT INTO mg.email_confirmation_tokens (affiliate_id, expires_at)
        VALUES (:aff_id, :expires_at)
        RETURNING token
    """), {"aff_id": affiliate_id, "expires_at": expires_at}).mappings().first()
    token = str(token_row["token"])

    db.commit()

    confirm_url = f"{data.base_url}/confirm-email?token={token}"

    email_sent = False
    email_error = None
    if data.send_email:
        try:
            send_founder_confirmation_email(
                email_norm, data.first_name, data.last_name,
                token, data.base_url, data.token_expiry_days
            )
            email_sent = True
        except Exception as e:
            email_sent = False  # l'affilie et le lien existent deja ; l'echec d'envoi n'annule rien
            email_error = str(e)

    return {
        "affiliate_id": affiliate_id,
        "email": email_norm,
        "confirm_url": confirm_url,
        "expires_at": expires_at.isoformat(),
        "email_sent": email_sent,
        "email_error": email_error,
    }
