"""
OSA Observatory -- Sprint 30 Lot B -- REVISE R2 (ADR-002 §2)
Router Affiliation -- Auto-activation par confirmation email
POST /api/v1/affiliation/request
POST /api/v1/affiliation/confirm-email/{token}  (definition du mot de passe fusionnee, session 11 juillet 2026 ;
                                                  KYC conditionnel a la cooptation, ADR-002 §2, 12 juillet 2026)
POST /api/v1/affiliation/request-password-reset
POST /api/v1/affiliation/reset-password/{token}
"""
import os
import smtplib
import uuid
import bcrypt
import json
import hashlib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text
from pydantic import BaseModel, Field
from typing import Optional
from api.db import get_db
from fastapi import Request
from api.utils.password_policy import validate_password_strength

router = APIRouter(
    prefix="/api/v1/affiliation",
    tags=["Affiliation OSA"],
)

TOKEN_EXPIRY_HOURS = 48
PASSWORD_RESET_EXPIRY_HOURS = 2  # plus court qu'une confirmation d'affiliation -- fenetre de securite reduite

# ── Emission d'evenements d'identite (ADR-001) ─────────────────────────────────
# N'emet reellement un evenement que si ce code tourne en PREPROD -- seul
# environnement source autorise a synchroniser vers PROD (DEV exclu, PROD
# est la cible terminale). Verifie a l'execution via OSA_ENVIRONMENT, pas
# en dur -- meme code deploye sur les 3 environnements.
def emit_identity_event(db: Session, event_type: str, affiliate_uuid, payload: dict):
    if os.getenv("OSA_ENVIRONMENT", "").upper() != "PREPROD":
        return
    payload_json = json.dumps(payload, sort_keys=True, default=str)
    payload_hash = hashlib.sha256(payload_json.encode("utf-8")).hexdigest()
    db.execute(text("""
        INSERT INTO mg.identity_events
            (event_type, affiliate_uuid, source_environment, target_environment,
             payload, payload_hash, validated_at)
        VALUES
            (:event_type, :affiliate_uuid, 'PREPROD', 'PROD', CAST(:payload AS jsonb), :payload_hash, NOW())
    """), {
        "event_type": event_type, "affiliate_uuid": str(affiliate_uuid),
        "payload": payload_json, "payload_hash": payload_hash,
    })

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
    smtp_host = os.getenv("OSA_SMTP_HOST", "mail.gandi.net")
    smtp_port = int(os.getenv("OSA_SMTP_PORT", "587"))
    smtp_user = os.getenv("OSA_SMTP_USER", "noreply@osa-observatory.africa")
    smtp_pass = os.getenv("OSA_SMTP_PASSWORD", "")
    smtp_from = os.getenv("OSA_SMTP_FROM", smtp_user)

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

# ── Rate-limiting + journalisation ───────────────────────────────────────────

def log_security_event(db, event_type: str, severity: str = None,
                        ip: str = None, email: str = None,
                        endpoint: str = None, details: dict = None,
                        affiliate_id: int = None):
    import json
    try:
        # Recuperer la severite par defaut si non fournie
        if not severity:
            row = db.execute(
                text("SELECT default_severity FROM mg.event_types WHERE code = :code"),
                {"code": event_type}
            ).mappings().first()
            severity = row["default_severity"] if row else "INFO"

        domain = email.split("@")[1] if email and "@" in email else None

        db.execute(text("""
            INSERT INTO mg.security_events
                (event_type, severity, ip_address, email, domain,
                 endpoint, affiliate_id, details)
            VALUES
                (:event_type, :severity, :ip, :email, :domain,
                 :endpoint, :affiliate_id, :details)
        """), {
            "event_type":   event_type,
            "severity":     severity,
            "ip":           ip,
            "email":        email,
            "domain":       domain,
            "endpoint":     endpoint,
            "affiliate_id": affiliate_id,
            "details":      json.dumps(details) if details else None,
        })
        db.commit()
    except Exception:
        pass  # Ne jamais bloquer sur la journalisation


def check_rate_limit(db, endpoint: str, ip: str = None,
                     email: str = None) -> dict:
    """
    Verifie les limites de taux depuis mg.rate_limit_policies.
    Retourne {"allowed": True} ou {"allowed": False, "action": ..., "retry_after": ...}
    """
    from datetime import datetime, timedelta

    policies = db.execute(text("""
        SELECT key_type, window_minutes, max_requests, action
        FROM mg.rate_limit_policies
        WHERE endpoint = :endpoint AND is_active = TRUE
        ORDER BY key_type
    """), {"endpoint": endpoint}).mappings().all()

    for policy in policies:
        key_type = policy["key_type"]
        window   = policy["window_minutes"]
        max_req  = policy["max_requests"]
        action   = policy["action"]

        if key_type == "IP" and not ip:
            continue
        if key_type == "EMAIL" and not email:
            continue
        if key_type == "DOMAIN" and not email:
            continue

        if key_type == "IP":
            key_value = ip
        elif key_type == "EMAIL":
            key_value = email
        else:
            key_value = email.split("@")[1] if "@" in email else email

        window_start = datetime.utcnow() - timedelta(minutes=window)

        count_row = db.execute(text("""
            SELECT COALESCE(SUM(count), 0) AS total
            FROM mg.rate_limit_counters
            WHERE key_type = :key_type AND key_value = :key_value
            AND endpoint = :endpoint AND window_start >= :window_start
        """), {
            "key_type":     key_type,
            "key_value":    key_value,
            "endpoint":     endpoint,
            "window_start": window_start,
        }).mappings().first()

        total = int(count_row["total"]) if count_row else 0

        if total >= max_req:
            return {
                "allowed":     False,
                "action":      action,
                "key_type":    key_type,
                "retry_after": window,
            }

        # Incrementer le compteur
        try:
            now_window = datetime.utcnow().replace(second=0, microsecond=0)
            db.execute(text("""
                INSERT INTO mg.rate_limit_counters
                    (key_type, key_value, endpoint, window_start, count)
                VALUES (:key_type, :key_value, :endpoint, :window_start, 1)
                ON CONFLICT (key_type, key_value, endpoint, window_start)
                DO UPDATE SET count = mg.rate_limit_counters.count + 1
            """), {
                "key_type":     key_type,
                "key_value":    key_value,
                "endpoint":     endpoint,
                "window_start": now_window,
            })
        except Exception:
            pass

    return {"allowed": True}


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
    data:    AffiliationRequest,
    request: Request,
    db:      Session = Depends(get_db),
):
    email    = data.email.lower().strip()
    ip       = request.client.host if request.client else None
    endpoint = "/api/v1/affiliation/request"

    # R4.1 -- Rate-limiting pilote par mg.rate_limit_policies
    rl = check_rate_limit(db, endpoint=endpoint, ip=ip, email=email)
    if not rl["allowed"]:
        event_map = {"IP": "RATE_LIMIT_IP", "EMAIL": "RATE_LIMIT_EMAIL", "DOMAIN": "RATE_LIMIT_DOMAIN"}
        log_security_event(db, event_type=event_map.get(rl["key_type"], "RATE_LIMIT_IP"),
                           ip=ip, email=email, endpoint=endpoint,
                           details={"action": rl["action"], "retry_after": rl["retry_after"]})
        if rl["action"] == "CAPTCHA":
            log_security_event(db, event_type="CAPTCHA_TRIGGERED",
                               ip=ip, email=email, endpoint=endpoint,
                               details={"reason": f"Rate limit {rl['key_type']} depasse"})
            raise HTTPException(status_code=429, detail={
                "fr": "Verification de securite requise.",
                "en": "Security verification required.",
                "captcha_required": True,
                "retry_after": rl["retry_after"]
            })
        raise HTTPException(status_code=429, detail={
            "fr": f"Trop de demandes. Veuillez reessayer dans {rl['retry_after']} minutes.",
            "en": f"Too many requests. Please try again in {rl['retry_after']} minutes.",
            "captcha_required": False,
            "retry_after": rl["retry_after"]
        })

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

    # R4.2 -- Journaliser la demande
    log_security_event(db, event_type="AFFILIATION_REQUEST",
                       ip=ip, email=email, endpoint=endpoint,
                       affiliate_id=affiliate_id,
                       details={"org_name": data.org_name, "country": data.country})

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
    "/confirm-email/{token}/info",
    summary="Consulter l'identité associée à un lien de confirmation (sans le consommer)",
    description=(
        "Retourne l'e-mail et le nom de la personne associée au token, pour "
        "affichage en lecture seule avant saisie du mot de passe. Ne marque "
        "jamais le token comme utilisé -- lecture seule, sans effet."
    ),
)
def confirm_email_info(token: str, db: Session = Depends(get_db)):
    token_row = db.execute(text("""
        SELECT t.affiliate_id, t.expires_at, t.used_at, a.first_name, a.last_name, a.email
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

    # Destination (comite ou groupe de travail) -- decidee par la cooptation,
    # affichee en lecture seule : le flyer est un document de gouvernance
    # (lettre de mission), la destination ne se negocie pas au formulaire.
    committee = db.execute(text("""
        SELECT c.label_fr, c.label_en
        FROM mg.committee_memberships cm
        JOIN mg.committees c ON c.code = cm.committee
        WHERE cm.affiliate_id = :aff_id AND cm.status = 'ACTIVE'
        LIMIT 1
    """), {"aff_id": token_row["affiliate_id"]}).mappings().first()

    working_group = db.execute(text("""
        SELECT wg.label_fr, wg.label_en, wg.pillar_code
        FROM mg.working_group_members wgm
        JOIN mg.working_groups wg ON wg.pillar_code = wgm.pillar_code
        WHERE wgm.affiliate_id = :aff_id AND wgm.status IN ('INVITED', 'ACTIVE')
        LIMIT 1
    """), {"aff_id": token_row["affiliate_id"]}).mappings().first()

    destination_fr = destination_en = None
    if committee:
        destination_fr, destination_en = committee["label_fr"], committee["label_en"]
    elif working_group:
        destination_fr = f"{working_group['label_fr']} ({working_group['pillar_code']})"
        destination_en = f"{working_group['label_en']} ({working_group['pillar_code']})"

    return {
        "email": token_row["email"],
        "first_name": token_row["first_name"],
        "last_name": token_row["last_name"],
        "destination_fr": destination_fr,
        "destination_en": destination_en,
    }


# ── Cooptation vs affiliation volontaire (ADR-002 §2) ─────────────────────────
# Deux parcours metier distincts partagent le meme endpoint technique de
# confirmation -- la separation ne se fait jamais via OSA_ENVIRONMENT
# (interdit explicitement par l'ADR-002), mais via l'etat reel des donnees :
# un affilie deja rattache a un comite ou un groupe de travail AVANT sa
# confirmation est necessairement issu d'une cooptation (admin_affiliates.py
# / preaffiliate), jamais du formulaire public /affiliation/request. Le KYC
# n'est donc obligatoire que si ce rattachement prealable existe.
def _has_pending_cooptation(db: Session, affiliate_id: int) -> bool:
    row = db.execute(text("""
        SELECT 1 FROM mg.committee_memberships WHERE affiliate_id = :id
        UNION
        SELECT 1 FROM mg.working_group_members WHERE affiliate_id = :id
        LIMIT 1
    """), {"id": affiliate_id}).first()
    return row is not None


# ── Endpoint 2 : confirmation email + definition du mot de passe + KYC ────────
# Decision actee (session du 11 juillet 2026, revisee suite au retour de
# Theo sur la gouvernance de cooptation) : mot de passe ET KYC fusionnes
# dans le meme formulaire de confirmation. KYC obligatoire uniquement pour
# la procedure de cooptation (organisation pilotee) -- jamais force pour
# l'affiliation volontaire (/api/v1/affiliation/request). Revision ADR-002
# §2 du 12 juillet 2026 : function_title/country deviennent optionnels au
# niveau du schema Pydantic ; l'obligation reelle est verifiee dans le
# corps de la fonction via _has_pending_cooptation (etat des donnees, pas
# de branche sur l'environnement). Le compte ne devient actif qu'une fois
# les conditions requises completes -- le token n'est marque utilise
# qu'apres succes complet.

class ConfirmEmailBody(BaseModel):
    password: str = Field(..., min_length=8, description="Choisi par l'affilié -- jamais généré côté serveur")
    function_title: Optional[str] = Field(None, max_length=200, description="KYC -- obligatoire uniquement si l'affilié est issu d'une cooptation")
    country: Optional[str] = Field(None, max_length=100, description="KYC -- obligatoire uniquement si l'affilié est issu d'une cooptation")


@router.post(
    "/confirm-email/{token}",
    summary="Confirmer l'email et définir son mot de passe -- action unique",
    description=(
        "Valide le token et définit le mot de passe en une seule transaction. "
        "Le compte ne devient AFFILIATED qu'une fois cette action complète. "
        "KYC (fonction, pays) obligatoire uniquement pour les affiliés issus "
        "d'une cooptation -- déterminé par l'existence d'un rattachement "
        "comité/groupe de travail préalable, jamais par l'environnement d'exécution."
    ),
)
def confirm_email(token: str, body: ConfirmEmailBody, db: Session = Depends(get_db)):
    token_row = db.execute(text("""
        SELECT t.id, t.affiliate_id, t.expires_at, t.used_at,
               a.first_name, a.last_name, a.email, a.status, a.org_name
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

    error = validate_password_strength(body.password)
    if error:
        # Token NON marque utilise -- l'affilie peut retenter avec un mot
        # de passe conforme sans avoir a redemander un nouveau lien.
        raise HTTPException(status_code=422, detail={"fr": error, "en": error})

    # KYC obligatoire uniquement si cet affilie est issu d'une cooptation
    # (rattachement comite/groupe de travail deja existant a ce stade).
    # Cf. ADR-002 §2 -- separation metier, jamais via OSA_ENVIRONMENT.
    kyc_required = _has_pending_cooptation(db, token_row["affiliate_id"])
    if kyc_required:
        if not body.function_title or not body.function_title.strip() \
           or not body.country or not body.country.strip():
            raise HTTPException(status_code=422, detail={
                "fr": "Fonction et pays sont obligatoires pour finaliser l'inscription (cooptation).",
                "en": "Function and country are required to complete registration (cooptation)."
            })

    function_title = body.function_title.strip() if body.function_title else None
    country = body.country.strip() if body.country else None

    password_hash = bcrypt.hashpw(body.password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")

    # COALESCE : ne jamais ecraser une valeur existante avec NULL quand le
    # champ n'est pas fourni (affiliation volontaire, KYC differe a /me).
    updated = db.execute(text("""
        UPDATE mg.affiliates
        SET status = 'AFFILIATED', password_hash = :pwd,
            function_title = COALESCE(:function_title, function_title),
            country = COALESCE(:country, country)
        WHERE id = :id
        RETURNING identity_uuid
    """), {
        "id": token_row["affiliate_id"], "pwd": password_hash,
        "function_title": function_title, "country": country,
    }).mappings().first()
    affiliate_uuid = updated["identity_uuid"]

    # La confirmation d'identite vaut acceptation de l'invitation au groupe
    # de travail -- INVITED -> ACTIVE. accepted_at obligatoire des que le
    # statut passe a ACTIVE (contrainte chk_accepted_coherence).
    activated_wg = db.execute(text("""
        UPDATE mg.working_group_members
        SET status = 'ACTIVE', accepted_at = NOW()
        WHERE affiliate_id = :id AND status = 'INVITED'
        RETURNING pillar_code
    """), {"id": token_row["affiliate_id"]}).mappings().first()

    db.execute(text("""
        UPDATE mg.email_confirmation_tokens SET used_at = NOW() WHERE id = :id
    """), {"id": token_row["id"]})

    # ── Emission des evenements d'identite (ADR-001, sans effet hors preprod) ──
    base_payload = {
        "identity_uuid": str(affiliate_uuid),
        "email": token_row["email"],
        "first_name": token_row["first_name"],
        "last_name": token_row["last_name"],
        "org_name": token_row["org_name"],
        "function_title": function_title,
        "country": country,
        "status": "AFFILIATED",
    }
    emit_identity_event(db, "AFFILIATE_CONFIRMED", affiliate_uuid, base_payload)

    committee_row = db.execute(text("""
        SELECT committee, start_date FROM mg.committee_memberships
        WHERE affiliate_id = :id AND status = 'ACTIVE'
        ORDER BY start_date DESC LIMIT 1
    """), {"id": token_row["affiliate_id"]}).mappings().first()
    if committee_row:
        emit_identity_event(db, "COMMITTEE_MEMBERSHIP_GRANTED", affiliate_uuid, {
            **base_payload,
            "committee": committee_row["committee"],
            "start_date": committee_row["start_date"],
        })

    if activated_wg:
        emit_identity_event(db, "WORKING_GROUP_ACTIVATED", affiliate_uuid, {
            **base_payload,
            "pillar_code": activated_wg["pillar_code"],
        })

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
            "fr": "Votre email a été confirmé et votre mot de passe défini. Votre compte affilié est désormais actif.",
            "en": "Your email has been confirmed and your password set. Your affiliate account is now active."
        },
    }


# ── Endpoint 3 : mot de passe oublié ──────────────────────────────────────────
# Reutilise le meme patron que la confirmation d'affiliation (token UUID,
# usage unique, expiration) mais dans une table dediee (mg.password_reset_tokens)
# -- semantique distincte, evite toute ambiguite d'audit entre "confirmation
# d'identite initiale" et "reinitialisation d'un mot de passe existant".
# Expiration volontairement plus courte (2h) qu'une confirmation d'affiliation.

class PasswordResetRequest(BaseModel):
    email: str


@router.post(
    "/request-password-reset",
    summary="Demander une réinitialisation de mot de passe",
    description=(
        "Envoie un lien de réinitialisation si l'adresse correspond à un "
        "compte actif. Réponse identique dans tous les cas (existant ou non) "
        "pour ne jamais révéler si une adresse est enregistrée."
    ),
)
def request_password_reset(body: PasswordResetRequest, db: Session = Depends(get_db)):
    generic_response = {
        "message": {
            "fr": "Si cette adresse correspond à un compte, un lien de réinitialisation vient d'être envoyé.",
            "en": "If this address matches an account, a reset link has just been sent."
        }
    }

    email_norm = body.email.lower().strip()
    affiliate = db.execute(text("""
        SELECT id, first_name, last_name, email, status
        FROM mg.affiliates
        WHERE email = :email AND status IN ('ACTIVE', 'AFFILIATED')
    """), {"email": email_norm}).mappings().first()

    if not affiliate:
        return generic_response  # jamais reveler l'absence du compte

    import datetime
    expires_at = datetime.datetime.utcnow() + datetime.timedelta(hours=PASSWORD_RESET_EXPIRY_HOURS)
    token_row = db.execute(text("""
        INSERT INTO mg.password_reset_tokens (affiliate_id, expires_at)
        VALUES (:aff_id, :expires_at)
        RETURNING token
    """), {"aff_id": affiliate["id"], "expires_at": expires_at}).mappings().first()
    db.commit()

    reset_url = f"https://open.osa-observatory.africa/reset-password?token={token_row['token']}"
    try:
        _smtp_send(
            affiliate["email"],
            "Réinitialisation de votre mot de passe -- OSA Observatory",
            f"""Bonjour {affiliate['first_name']},

Une demande de réinitialisation de mot de passe a été effectuée pour votre compte.
Si vous êtes à l'origine de cette demande, cliquez sur le lien suivant (valide {PASSWORD_RESET_EXPIRY_HOURS}h) :

{reset_url}

Si vous n'êtes pas à l'origine de cette demande, ignorez simplement ce message --
votre mot de passe actuel reste inchangé.

---
OSA Observatory
"""
        )
    except Exception:
        pass  # ne jamais reveler un echec technique specifique a l'appelant

    return generic_response


class PasswordResetSubmit(BaseModel):
    password: str = Field(..., min_length=8)


@router.post(
    "/reset-password/{token}",
    summary="Finaliser la réinitialisation du mot de passe",
)
def reset_password(token: str, body: PasswordResetSubmit, db: Session = Depends(get_db)):
    token_row = db.execute(text("""
        SELECT id, affiliate_id, expires_at, used_at
        FROM mg.password_reset_tokens
        WHERE token = :token
    """), {"token": token}).mappings().first()

    if not token_row:
        raise HTTPException(status_code=404, detail={
            "fr": "Lien de réinitialisation invalide.",
            "en": "Invalid reset link."
        })
    if token_row["used_at"]:
        raise HTTPException(status_code=400, detail={
            "fr": "Ce lien a déjà été utilisé.",
            "en": "This link has already been used."
        })

    import datetime
    if token_row["expires_at"] < datetime.datetime.utcnow():
        raise HTTPException(status_code=400, detail={
            "fr": "Ce lien a expiré. Veuillez refaire une demande.",
            "en": "This link has expired. Please request a new one."
        })

    error = validate_password_strength(body.password)
    if error:
        raise HTTPException(status_code=422, detail={"fr": error, "en": error})

    password_hash = bcrypt.hashpw(body.password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")

    # Cas "activation post-propagation" : ce compte n'a jamais eu de mot
    # de passe en prod (cree par le synchroniseur d'identite, ADR-001) --
    # ce lien sert alors a l'activer, pas a "reinitialiser" un mot de
    # passe qui n'a jamais existe ici. Transition PROD_PENDING_ACTIVATION
    # -> AFFILIATED en plus de la definition du mot de passe.
    db.execute(text("""
        UPDATE mg.affiliates
        SET password_hash = :pwd,
            status = CASE WHEN status = 'PROD_PENDING_ACTIVATION' THEN 'AFFILIATED' ELSE status END
        WHERE id = :id
    """), {"id": token_row["affiliate_id"], "pwd": password_hash})
    db.execute(text("UPDATE mg.password_reset_tokens SET used_at = NOW() WHERE id = :id"),
               {"id": token_row["id"]})
    db.commit()

    return {
        "message": {
            "fr": "Votre mot de passe a été réinitialisé. Vous pouvez maintenant vous connecter.",
            "en": "Your password has been reset. You can now log in."
        }
    }


# ── Endpoint 4 : synchronisation d'identite (ADR-001) ─────────────────────────
# Appele uniquement par le service identity_synchronizer.py -- jamais par
# le portail public. Protege par un secret partage (pas une session
# utilisateur : c'est un appel machine-a-machine entre deux instances de
# l'API, pas une action humaine authentifiee). Reutilise les memes
# requetes parametrees SQLAlchemy que le reste du fichier -- aucune
# construction de SQL par concatenation, quel que soit le contenu du
# payload (noms, pays etc. peuvent contenir des apostrophes).

SYNC_SHARED_SECRET = os.getenv("IDENTITY_SYNC_SECRET", "")


def send_activation_email(to_email: str, first_name: str, last_name: str, token: str):
    # Distinct de send_founder_confirmation_email et du flux "mot de passe
    # oublie" -- ce compte n'a jamais eu de mot de passe en prod, ce n'est
    # ni une premiere invitation (l'identite est deja validee en preprod)
    # ni un oubli. Reutilise le meme token/table que reset-password
    # (meme mecanique technique), semantique metier distincte (ADR-001,
    # proposition de Theo D. Bakang).
    activation_url = f"https://open.osa-observatory.africa/reset-password?token={token}"

    body_fr = f"""Madame, Monsieur {last_name},

Votre identité, validée lors de la phase de test de l'OSA Observatory, vient
d'être transférée vers la plateforme officielle.

Pour activer votre compte en production, choisissez votre mot de passe
(distinct de celui utilisé en phase de test) en suivant ce lien :

{activation_url}

---
OSA Observatory -- Observatoire de la Souveraineté Africaine
"""

    body_en = f"""Dear {first_name} {last_name},

Your identity, validated during the OSA Observatory testing phase, has just
been transferred to the official platform.

To activate your account in production, choose your password (distinct from
the one used during the testing phase) by following this link:

{activation_url}

---
OSA Observatory -- African Sovereignty Observatory
"""

    _smtp_send(
        to_email,
        "Activez votre compte OSA Observatory / Activate your OSA Observatory account",
        body_fr + "\n\n---\n\n" + body_en
    )


class SyncEventPayload(BaseModel):
    event_type: str
    affiliate_uuid: str
    payload: dict


@router.post(
    "/sync/apply-event",
    summary="[Interne] Appliquer un événement d'identité propagé",
    description="Réservé au service identity_synchronizer.py -- protégé par secret partagé, pas une session utilisateur.",
)
def apply_sync_event(body: SyncEventPayload, request: Request, db: Session = Depends(get_db)):
    if not SYNC_SHARED_SECRET or request.headers.get("X-Sync-Secret") != SYNC_SHARED_SECRET:
        raise HTTPException(status_code=403, detail="Accès refusé.")

    p = body.payload

    if body.event_type == "AFFILIATE_CONFIRMED":
        existing = db.execute(text("SELECT id, status FROM mg.affiliates WHERE identity_uuid = :uuid"),
                               {"uuid": body.affiliate_uuid}).mappings().first()

        if existing:
            # Deja propage anterieurement -- mise a jour du profil
            # uniquement, jamais du statut ni du mot de passe.
            db.execute(text("""
                UPDATE mg.affiliates
                SET first_name = :first_name, last_name = :last_name,
                    org_name = :org_name, function_title = :function_title,
                    country = :country
                WHERE identity_uuid = :uuid
            """), {**p, "uuid": body.affiliate_uuid})
            db.commit()
            return {"applied": True, "action": "updated", "affiliate_id": existing["id"]}

        try:
            new_row = db.execute(text("""
                INSERT INTO mg.affiliates
                    (identity_uuid, last_name, first_name, email, org_name,
                     affiliate_type, function_title, country, status)
                VALUES
                    (:uuid, :last_name, :first_name, :email, :org_name,
                     'FONDATEUR', :function_title, :country, 'PROD_PENDING_ACTIVATION')
                RETURNING id
            """), {**p, "uuid": body.affiliate_uuid}).mappings().first()
        except Exception as e:
            db.rollback()
            raise HTTPException(status_code=409, detail=(
                f"Conflit à la création (email déjà utilisé sous une autre identité ?) : {e}"
            ))

        import datetime, uuid as uuid_mod
        token_row = db.execute(text("""
            INSERT INTO mg.password_reset_tokens (affiliate_id, expires_at)
            VALUES (:aff_id, :expires_at)
            RETURNING token
        """), {
            "aff_id": new_row["id"],
            "expires_at": datetime.datetime.utcnow() + datetime.timedelta(days=30),
        }).mappings().first()
        db.commit()

        try:
            send_activation_email(p["email"], p["first_name"], p["last_name"], str(token_row["token"]))
        except Exception:
            pass  # le compte existe deja ; un echec d'envoi n'annule rien

        return {"applied": True, "action": "created", "affiliate_id": new_row["id"]}

    elif body.event_type == "COMMITTEE_MEMBERSHIP_GRANTED":
        affiliate = db.execute(text("SELECT id FROM mg.affiliates WHERE identity_uuid = :uuid"),
                                {"uuid": body.affiliate_uuid}).mappings().first()
        if not affiliate:
            raise HTTPException(status_code=409, detail="Affilié inconnu -- événement AFFILIATE_CONFIRMED requis au préalable.")

        db.execute(text("""
            INSERT INTO mg.committee_memberships (affiliate_id, committee, start_date, status)
            VALUES (:aff_id, :committee, :start_date, 'ACTIVE')
            ON CONFLICT DO NOTHING
        """), {"aff_id": affiliate["id"], "committee": p["committee"], "start_date": p["start_date"]})
        db.commit()
        return {"applied": True, "action": "committee_membership_synced"}

    elif body.event_type == "WORKING_GROUP_ACTIVATED":
        affiliate = db.execute(text("SELECT id FROM mg.affiliates WHERE identity_uuid = :uuid"),
                                {"uuid": body.affiliate_uuid}).mappings().first()
        if not affiliate:
            raise HTTPException(status_code=409, detail="Affilié inconnu -- événement AFFILIATE_CONFIRMED requis au préalable.")

        # invited_by = leur propre id : placeholder deliberé -- la personne
        # qui a reellement invite existe cote preprod, pas cote prod (id
        # non correspondant). Pas de FK vers un admin factice.
        db.execute(text("""
            INSERT INTO mg.working_group_members (pillar_code, affiliate_id, invited_by, status, accepted_at)
            VALUES (:pillar_code, :aff_id, :aff_id, 'ACTIVE', NOW())
            ON CONFLICT DO NOTHING
        """), {"pillar_code": p["pillar_code"], "aff_id": affiliate["id"]})
        db.commit()
        return {"applied": True, "action": "working_group_synced"}

    raise HTTPException(status_code=422, detail=f"Type d'événement non pris en charge : {body.event_type}")
