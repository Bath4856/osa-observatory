"""
OSA Observatory -- Module d'authentification JWT
Sprint 17 -- 27 mai 2026

Architecture deux tokens :
    Access token  : JWT HS256, 15 min, stateless
    Refresh token : JWT HS256, 30 jours, enregistré en base (mg.refresh_tokens)

Compatibilité descendante Sprint 14 (90 jours) :
    Le header X-Api-Key continue d'être accepté par les routers existants
    via security.py (inchangé). Les nouveaux endpoints /auth/* émettent
    et consomment des Bearer JWT. Les deux mécanismes coexistent.

Claims access token :
    sub            : str(affiliation_id)
    access_level   : STANDARD | PREMIUM | EXPERT  (= effective_access_class)
    institution    : country_iso3
    affiliation_id : int
    jti            : UUID unique (révocable)
    type           : "access"
    iat / exp      : timestamps standard

Claims refresh token :
    sub            : str(affiliation_id)
    token_family   : UUID (détection réutilisation)
    jti            : UUID unique
    type           : "refresh"
    iat / exp      : timestamps standard

Dépendances FastAPI exportées (Bearer JWT uniquement) :
    get_current_token()  -> dict claims
    require_standard()   -> dict claims, 403 si insuffisant
    require_premium()    -> dict claims, 403 si insuffisant
    require_expert()     -> dict claims, 403 si insuffisant

Note : les routers Sprint 14-16 utilisent security.py (X-Api-Key) sans
modification. Ce module ajoute la couche JWT en parallèle.
"""

import hashlib
import logging
import os
import secrets
import smtplib
import uuid
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from datetime import datetime, timedelta, timezone
from typing import Optional

import jwt
from dotenv import load_dotenv
from pathlib import Path
load_dotenv(Path(__file__).parent.parent / ".env")   # charge api/.env au démarrage
from fastapi import APIRouter, Depends, Header, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel
from sqlalchemy import text

from api.db import SessionLocal, get_db

log = logging.getLogger("osa_auth")

# ---------------------------------------------------------------------------
# Configuration -- chargée depuis .env via variables d'environnement
# ---------------------------------------------------------------------------
_JWT_ALGORITHM = "HS256"

_LEVEL_HIERARCHY: dict[str, int] = {
    "STANDARD": 1,
    "PREMIUM":  2,
    "EXPERT":   3,
}

_bearer = HTTPBearer(auto_error=False)


def _secret() -> str:
    """Charge OSA_JWT_SECRET depuis l'environnement. Lève 500 si absent."""
    s = os.environ.get("OSA_JWT_SECRET", "")
    if not s:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="OSA_JWT_SECRET non configure -- contacter le Secretariat technique OSA.",
        )
    return s


def _access_expire_minutes() -> int:
    return int(os.environ.get("OSA_JWT_ACCESS_EXPIRE_MIN", "15"))


def _refresh_expire_days() -> int:
    return int(os.environ.get("OSA_JWT_REFRESH_EXPIRE_DAYS", "30"))


def _sha256(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def _utcnow() -> datetime:
    return datetime.now(tz=timezone.utc)

# ---------------------------------------------------------------------------
# OTP -- One-Time Password
# ---------------------------------------------------------------------------
def _otp_dev_mode() -> bool:
    return os.environ.get("OSA_OTP_DEV_MODE", "false").lower() == "true"

def _otp_expire_minutes() -> int:
    return int(os.environ.get("OSA_OTP_EXPIRE_MIN", "10"))

def _otp_max_attempts() -> int:
    return int(os.environ.get("OSA_OTP_MAX_ATTEMPTS", "3"))

def _send_otp_email(contact_email: str, institution_name: str, code: str) -> None:
    """
    Envoie le code OTP par email via SMTP Gandi (mail.gandi.net:587 STARTTLS).
    Variables requises dans api/.env :
        OSA_SMTP_HOST, OSA_SMTP_PORT, OSA_SMTP_USER, OSA_SMTP_PASSWORD, OSA_SMTP_FROM
    """
    smtp_host     = os.environ.get("OSA_SMTP_HOST", "mail.gandi.net")
    smtp_port     = int(os.environ.get("OSA_SMTP_PORT", "587"))
    smtp_user     = os.environ.get("OSA_SMTP_USER", "")
    smtp_password = os.environ.get("OSA_SMTP_PASSWORD", "")
    smtp_from     = os.environ.get("OSA_SMTP_FROM", smtp_user)

    if not smtp_user or not smtp_password:
        raise HTTPException(
            status_code=500,
            detail="Configuration SMTP manquante -- contacter le Secretariat technique OSA.",
        )

    expire_min = _otp_expire_minutes()

    # Corps texte brut
    body_text = (
        f"OSA Observatory -- Code d'authentification\n"
        f"\n"
        f"Institution : {institution_name}\n"
        f"\n"
        f"Votre code OTP : {code}\n"
        f"\n"
        f"Ce code est valable {expire_min} minutes.\n"
        f"Ne le partagez avec personne.\n"
        f"\n"
        f"Si vous n'etes pas a l'origine de cette demande,\n"
        f"contactez immediatement : contact@osa-observatory.africa\n"
        f"\n"
        f"-- Secretariat technique OSA Observatory\n"
    )

    # Corps HTML
    body_html = f"""<!DOCTYPE html>
<html>
<body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
  <div style="background: #1F4E79; padding: 20px; border-radius: 8px 8px 0 0;">
    <h2 style="color: white; margin: 0;">OSA Observatory</h2>
    <p style="color: #BDD7EE; margin: 4px 0 0;">Code d'authentification</p>
  </div>
  <div style="border: 1px solid #D6E4F0; padding: 30px; border-radius: 0 0 8px 8px;">
    <p>Institution : <strong>{institution_name}</strong></p>
    <div style="background: #F2F7FC; border-left: 4px solid #2E75B6;
                padding: 20px; text-align: center; margin: 20px 0;">
      <p style="margin: 0 0 8px; color: #555;">Votre code OTP</p>
      <span style="font-size: 36px; font-weight: bold; letter-spacing: 8px;
                   color: #1F4E79;">{code}</span>
      <p style="margin: 8px 0 0; color: #888; font-size: 13px;">
        Valable {expire_min} minutes -- usage unique
      </p>
    </div>
    <p style="color: #555; font-size: 13px;">
      Ne partagez pas ce code. Si vous n'etes pas a l'origine de cette demande,
      contactez <a href="mailto:contact@osa-observatory.africa">contact@osa-observatory.africa</a>.
    </p>
  </div>
  <p style="color: #AAA; font-size: 11px; text-align: center; margin-top: 16px;">
    OSA Observatory -- Secretariat technique -- noreply@osa-observatory.africa
  </p>
</body>
</html>"""

    msg = MIMEMultipart("alternative")
    msg["Subject"] = f"OSA Observatory -- Code OTP : {code[:3]}***"
    msg["From"]    = smtp_from
    msg["To"]      = contact_email

    msg.attach(MIMEText(body_text, "plain", "utf-8"))
    msg.attach(MIMEText(body_html,  "html",  "utf-8"))

    try:
        with smtplib.SMTP(smtp_host, smtp_port, timeout=10) as server:
            server.ehlo()
            server.starttls()
            server.ehlo()
            server.login(smtp_user, smtp_password)
            server.sendmail(smtp_from, [contact_email], msg.as_bytes())
    except smtplib.SMTPAuthenticationError:
        log.error("SMTP auth error -- verifier OSA_SMTP_USER / OSA_SMTP_PASSWORD")
        raise HTTPException(
            status_code=500,
            detail="Erreur d'envoi email -- contacter le Secretariat technique OSA.",
        )
    except smtplib.SMTPException as exc:
        log.error("SMTP error : %s", exc)
        raise HTTPException(
            status_code=500,
            detail="Erreur d'envoi email -- contacter le Secretariat technique OSA.",
        )
    except Exception as exc:
        log.error("Email send error : %s", exc)
        raise HTTPException(
            status_code=500,
            detail="Erreur d'envoi email -- contacter le Secretariat technique OSA.",
        )


def _generate_otp_code() -> str:
    """Génère un code OTP à 6 chiffres. secrets.randbelow garantit l'uniformité."""
    return f"{secrets.randbelow(1_000_000):06d}"

def _store_otp(api_key_hash: str, code: str, db) -> None:
    """
    Stocke le hash du code OTP en base.
    Invalide tout code précédent actif pour cette clé.
    """
    code_hash = _sha256(code)
    expires_at = _utcnow() + timedelta(minutes=_otp_expire_minutes())

    # Invalider les codes précédents non utilisés
    db.execute(text("""
        UPDATE mg.otp_codes
        SET used_at = NOW()
        WHERE api_key_hash = :api_key_hash
          AND used_at IS NULL
          AND expires_at > NOW()
    """), {"api_key_hash": api_key_hash})

    db.execute(text("""
        INSERT INTO mg.otp_codes (api_key_hash, code_hash, expires_at)
        VALUES (:api_key_hash, :code_hash, :expires_at)
    """), {
        "api_key_hash": api_key_hash,
        "code_hash":    code_hash,
        "expires_at":   expires_at,
    })
    db.commit()

def _verify_otp(api_key_hash: str, code: str, db) -> None:
    """
    Vérifie un code OTP.
    Lève HTTPException 401 si invalide, expiré, ou trop de tentatives.
    Marque le code comme utilisé si valide.
    """
    code_hash = _sha256(code)

    row = db.execute(text("""
        SELECT id, code_hash, expires_at, used_at, attempt_count
        FROM mg.otp_codes
        WHERE api_key_hash = :api_key_hash
          AND used_at IS NULL
          AND expires_at > NOW()
        ORDER BY created_at DESC
        LIMIT 1
    """), {"api_key_hash": api_key_hash}).mappings().fetchone()

    if not row:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Code OTP inexistant ou expire -- demander un nouveau code via POST /auth/otp/request.",
            headers={"X-OSA-Error": "OTP_NOT_FOUND"},
        )

    max_attempts = _otp_max_attempts()

    if row["code_hash"] != code_hash:
        new_count = row["attempt_count"] + 1

        if new_count >= max_attempts:
            # Dernière tentative épuisée -- invalider le code
            db.execute(text(
                "UPDATE mg.otp_codes SET attempt_count = :count, used_at = NOW() WHERE id = :id"
            ), {"count": new_count, "id": row["id"]})
            db.commit()
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=f"Trop de tentatives ({max_attempts} max) -- code invalide. Demander un nouveau code via POST /auth/otp/request.",
                headers={"X-OSA-Error": "OTP_MAX_ATTEMPTS"},
            )
        else:
            # Incrémenter le compteur
            db.execute(text(
                "UPDATE mg.otp_codes SET attempt_count = :count WHERE id = :id"
            ), {"count": new_count, "id": row["id"]})
            db.commit()
            remaining = max_attempts - new_count
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=f"Code OTP incorrect. {remaining} tentative(s) restante(s).",
                headers={"X-OSA-Error": "OTP_INVALID"},
            )

    # Code valide -- marquer comme utilisé
    db.execute(text(
        "UPDATE mg.otp_codes SET used_at = NOW() WHERE id = :id"
    ), {"id": row["id"]})
    db.commit()

def _requires_otp(affiliation_id) -> bool:
    """
    Détermine si une clé nécessite un OTP.
    Les clés EXPERT sans affiliation (affiliation_id IS NULL) en sont exemptées.
    """
    return affiliation_id is not None




# ---------------------------------------------------------------------------
# Schémas Pydantic
# ---------------------------------------------------------------------------
class TokenResponse(BaseModel):
    access_token:  str
    refresh_token: str
    token_type:    str = "bearer"
    expires_in:    int
    access_level:  str
    institution:   str


class RefreshRequest(BaseModel):
    refresh_token: str


class RevokeRequest(BaseModel):
    refresh_token: Optional[str] = None


# ---------------------------------------------------------------------------
# Création des tokens
# ---------------------------------------------------------------------------
def _make_access_token(affiliation_id: int, access_level: str, institution: str) -> str:
    now = _utcnow()
    payload = {
        "sub":            str(affiliation_id) if affiliation_id is not None else "internal",
        "affiliation_id": affiliation_id,
        "access_level":   access_level,
        "institution":    institution,
        "jti":            str(uuid.uuid4()),
        "type":           "access",
        "iat":            now,
        "exp":            now + timedelta(minutes=_access_expire_minutes()),
    }
    return jwt.encode(payload, _secret(), algorithm=_JWT_ALGORITHM)


def _make_refresh_token(
    affiliation_id: int,
    token_family: str,
    api_key_hash: Optional[str],
    user_agent: Optional[str],
    ip_address: Optional[str],
    db,
    access_level: str = "STANDARD",
    institution: str = "UNK",
) -> tuple[str, str]:
    """
    Crée un refresh token, l'enregistre en base.
    Retourne (raw_token, jti).
    """
    now = _utcnow()
    jti_val = str(uuid.uuid4())
    expires_at = now + timedelta(days=_refresh_expire_days())

    payload = {
        "sub":          str(affiliation_id) if affiliation_id is not None else "internal",
        "token_family": token_family,
        "jti":          jti_val,
        "type":         "refresh",
        "access_level": access_level,
        "institution":  institution,
        "iat":          now,
        "exp":          expires_at,
    }
    raw = jwt.encode(payload, _secret(), algorithm=_JWT_ALGORITHM)
    token_hash = _sha256(raw)

    db.execute(text("""
        INSERT INTO mg.refresh_tokens
            (jti, affiliation_id, api_key_hash, token_hash, token_family,
             expires_at, user_agent, ip_address)
        VALUES
            (:jti, :affiliation_id, :api_key_hash, :token_hash, CAST(:token_family AS uuid),
             :expires_at, :user_agent, :ip_address)
        ON CONFLICT (jti) DO NOTHING
    """), {
        "jti":            jti_val,
        "affiliation_id": affiliation_id,
        "api_key_hash":   api_key_hash,
        "token_hash":     token_hash,
        "token_family":   token_family,
        "expires_at":     expires_at,
        "user_agent":     user_agent,
        "ip_address":     ip_address,
    })
    db.commit()
    return raw, jti_val


# ---------------------------------------------------------------------------
# Décodage et validation
# ---------------------------------------------------------------------------
def _decode_jwt(token: str) -> dict:
    """Décode un JWT. Lève HTTPException 401 avec code OSA si invalide."""
    try:
        return jwt.decode(token, _secret(), algorithms=[_JWT_ALGORITHM])
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token expire -- renouveler via POST /auth/refresh.",
            headers={"WWW-Authenticate": "Bearer", "X-OSA-Error": "TOKEN_EXPIRED"},
        )
    except jwt.InvalidTokenError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Token invalide : {exc}",
            headers={"WWW-Authenticate": "Bearer", "X-OSA-Error": "TOKEN_INVALID"},
        )


def _is_revoked(jti: str, db) -> bool:
    row = db.execute(
        text("SELECT 1 FROM mg.revoked_tokens WHERE jti = CAST(:jti AS uuid) AND expires_at > NOW()"),
        {"jti": jti},
    ).fetchone()
    return row is not None


def _add_to_blacklist(
    jti: str,
    affiliation_id: int,
    token_type: str,
    expires_at: datetime,
    reason: str,
    revoked_by: str,
    db,
) -> None:
    db.execute(text("""
        INSERT INTO mg.revoked_tokens
            (jti, affiliation_id, token_type, expires_at, reason, revoked_by)
        VALUES
            (CAST(:jti AS uuid), :affiliation_id, :token_type, :expires_at, :reason, :revoked_by)
        ON CONFLICT (jti) DO NOTHING
    """), {
        "jti":            jti,
        "affiliation_id": affiliation_id,
        "token_type":     token_type,
        "expires_at":     expires_at,
        "reason":         reason,
        "revoked_by":     revoked_by,
    })
    db.commit()


# ---------------------------------------------------------------------------
# Dependency FastAPI -- Bearer JWT uniquement
# (les routers Sprint 14-16 continuent via security.py / X-Api-Key)
# ---------------------------------------------------------------------------
async def get_current_token(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(_bearer),
    db=Depends(get_db),
) -> dict:
    """
    Dependency Bearer JWT.
    Lève 401 si token absent, expiré, invalide ou révoqué.
    """
    if not credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Bearer token JWT requis -- obtenir via POST /auth/token.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    claims = _decode_jwt(credentials.credentials)

    if claims.get("type") != "access":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Type de token incorrect (refresh token fourni a la place de l'access token).",
            headers={"WWW-Authenticate": "Bearer", "X-OSA-Error": "WRONG_TOKEN_TYPE"},
        )

    jti = claims.get("jti")
    if jti and _is_revoked(jti, db):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token revoque.",
            headers={"WWW-Authenticate": "Bearer", "X-OSA-Error": "TOKEN_REVOKED"},
        )

    return claims


async def require_standard(claims: dict = Depends(get_current_token)) -> dict:
    """Dependency Couche 1 -- STANDARD ou supérieur."""
    if _LEVEL_HIERARCHY.get(claims.get("access_level", ""), 0) < _LEVEL_HIERARCHY["STANDARD"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Acces Couche 1 requis (affilie Standard). "
                   "Contacter le Secretariat technique OSA pour une affiliation.",
        )
    return claims


async def require_premium(claims: dict = Depends(get_current_token)) -> dict:
    """Dependency Couche 2 -- PREMIUM ou supérieur."""
    if _LEVEL_HIERARCHY.get(claims.get("access_level", ""), 0) < _LEVEL_HIERARCHY["PREMIUM"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Acces Couche 2 requis (affilie Premium). "
                   "Niveau actuel insuffisant -- contacter le Secretariat technique OSA.",
        )
    return claims


async def require_expert(claims: dict = Depends(get_current_token)) -> dict:
    """Dependency Expert -- usage interne OSA uniquement."""
    if _LEVEL_HIERARCHY.get(claims.get("access_level", ""), 0) < _LEVEL_HIERARCHY["EXPERT"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Acces Expert OSA requis. Endpoint reserve au Secretariat technique.",
        )
    return claims


# ---------------------------------------------------------------------------
# Router /auth/*
# ---------------------------------------------------------------------------
router = APIRouter(prefix="/auth", tags=["Authentification JWT"])


@router.post(
    "/token",
    response_model=TokenResponse,
    summary="Obtenir un access + refresh token JWT depuis une clé API OSA",
    description=(
        "Échange une clé API OSA (header X-Api-Key, format osa_...) contre "
        "un access token JWT (15 min) et un refresh token (30 jours). "
        "La clé API Sprint 14 reste valide pendant la période de grâce (90 jours)."
    ),
)
async def get_token(
    request: Request,
    x_api_key: str = Header(default=None, alias="X-Api-Key"),
    x_otp_code: str = Header(default=None, alias="X-Otp-Code"),
    db=Depends(get_db),
):
    """
    Échange clé API OSA → JWT.

    Headers requis :
      X-Api-Key   : clé API OSA (format osa_...)
      X-Otp-Code  : code OTP à 6 chiffres (requis si affiliation présente)
                    Obtenir via POST /auth/otp/request

    Les clés EXPERT sans affiliation sont exemptées de l'OTP.
    """
    # Lire la clé depuis header ou query
    raw_key = x_api_key or request.query_params.get("api_key")
    if not raw_key:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Cle API requise -- fournir via header X-Api-Key ou query param ?api_key=",
        )

    hashed = _sha256(raw_key)

    # Valider via mg.v_api_key_status (même vue que security.py)
    row = db.execute(text("""
        SELECT
            v.affiliation_id,
            v.effective_access_class,
            v.access_granted,
            v.institution_name,
            COALESCE(a.country_iso3, 'UNK') AS country_iso3,
            k.legacy_expires_at
        FROM mg.v_api_key_status v
        LEFT JOIN rf.affiliations a ON a.affiliation_id = v.affiliation_id
        JOIN mg.api_key_registry k ON k.api_key_hash = v.api_key_hash
        WHERE v.api_key_hash = :hashed
    """), {"hashed": hashed}).mappings().fetchone()

    if not row:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED,
                            detail="Cle API invalide.")

    if not row["access_granted"]:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED,
                            detail="Cle API inactive ou affiliation suspendue.")

    # Vérifier la période de grâce
    legacy_exp = row["legacy_expires_at"]
    if legacy_exp is not None:
        exp_aware = legacy_exp.replace(tzinfo=timezone.utc) if legacy_exp.tzinfo is None else legacy_exp
        if _utcnow() > exp_aware:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Periode de grace expiree -- cette cle API n'accepte plus l'echange JWT. "
                       "Contacter le Secretariat technique OSA.",
            )

    affiliation_id = row["affiliation_id"]
    access_level   = row["effective_access_class"] or "STANDARD"
    institution    = row["country_iso3"]

    # Vérification OTP -- obligatoire si affiliation présente
    if _requires_otp(affiliation_id):
        if not x_otp_code:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Code OTP requis -- demander un code via POST /auth/otp/request.",
                headers={"X-OSA-Error": "OTP_REQUIRED"},
            )
        _verify_otp(hashed, x_otp_code, db)

    # Émettre les tokens
    access_token = _make_access_token(affiliation_id, access_level, institution)
    token_family = str(uuid.uuid4())
    refresh_token_raw, _ = _make_refresh_token(
        affiliation_id=affiliation_id,
        token_family=token_family,
        api_key_hash=hashed,
        user_agent=request.headers.get("User-Agent"),
        ip_address=str(request.client.host) if request.client else None,
        db=db,
        access_level=access_level,
        institution=institution,
    )

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token_raw,
        expires_in=_access_expire_minutes() * 60,
        access_level=access_level,
        institution=institution,
    )




@router.post(
    "/otp/request",
    summary="Demander un code OTP pour la double authentification",
    description=(
        "Génère un code OTP à 6 chiffres valable 10 minutes et l'envoie "
        "à l'adresse email de l'affiliation. "
        "En mode développement (OSA_OTP_DEV_MODE=true), le code est loggué "
        "dans uvicorn au lieu d'être envoyé par email. "
        "Les clés EXPERT sans affiliation sont exemptées -- utiliser POST /auth/token directement."
    ),
)
async def request_otp(
    request: Request,
    x_api_key: str = Header(default=None, alias="X-Api-Key"),
    db=Depends(get_db),
):
    if not x_api_key:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Cle API requise -- header X-Api-Key.",
        )

    hashed = _sha256(x_api_key)

    # Valider la clé via v_api_key_status
    row = db.execute(text("""
        SELECT
            v.affiliation_id,
            v.access_granted,
            v.effective_access_class,
            a.contact_email,
            a.institution_name
        FROM mg.v_api_key_status v
        LEFT JOIN rf.affiliations a ON a.affiliation_id = v.affiliation_id
        WHERE v.api_key_hash = :hashed
    """), {"hashed": hashed}).mappings().fetchone()

    if not row or not row["access_granted"]:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Cle API invalide ou inactive.",
        )

    # Clé EXPERT sans affiliation -- pas d'OTP
    if not _requires_otp(row["affiliation_id"]):
        return {
            "message": "Cle EXPERT interne OSA -- OTP non requis. Utiliser POST /auth/token directement.",
            "otp_required": False,
        }

    # Vérifier que l'email est renseigné
    contact_email = row["contact_email"]
    if not contact_email:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=(
                "Aucune adresse email configuree pour cette affiliation. "
                "Contacter le Secretariat technique OSA pour mettre a jour le profil."
            ),
        )

    # Générer et stocker le code
    code = _generate_otp_code()
    _store_otp(hashed, code, db)

    # Livraison du code
    if _otp_dev_mode():
        # Mode developpement -- log uvicorn uniquement (OSA_OTP_DEV_MODE=true)
        log.warning(
            "OSA OTP DEV MODE -- institution=%s email=%s code=%s expires_in=%dmin",
            row["institution_name"],
            contact_email,
            code,
            _otp_expire_minutes(),
        )
        delivery_info = f"[DEV] Code logue dans uvicorn pour {contact_email}"
    else:
        # Mode production -- envoi SMTP via mail.gandi.net
        _send_otp_email(contact_email, row["institution_name"], code)
        at = contact_email.find("@")
        delivery_info = f"Code envoye a {contact_email[:3]}***{contact_email[at:]}"

    return {
        "message": "Code OTP genere.",
        "delivery": delivery_info,
        "expires_in": _otp_expire_minutes() * 60,
        "otp_required": True,
        "next_step": "POST /auth/token avec headers X-Api-Key + X-Otp-Code",
    }
@router.post(
    "/refresh",
    response_model=TokenResponse,
    summary="Renouveler l'access token via le refresh token",
    description=(
        "Rotation automatique : l'ancien refresh token est révoqué, "
        "un nouveau couple access + refresh est émis. "
        "La réutilisation d'un refresh token révoqué révoque toute la famille (token_family)."
    ),
)
async def refresh_token_endpoint(
    body: RefreshRequest,
    request: Request,
    db=Depends(get_db),
):
    # Décoder sans vérification de révocation (le refresh n'est pas dans revoked_tokens)
    try:
        claims = jwt.decode(body.refresh_token, _secret(), algorithms=[_JWT_ALGORITHM])
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED,
                            detail="Refresh token expire -- se reconnecter via POST /auth/token.")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED,
                            detail="Refresh token invalide.")

    if claims.get("type") != "refresh":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED,
                            detail="Type de token incorrect.")

    token_hash    = _sha256(body.refresh_token)
    affiliation_id = int(claims["sub"])
    token_family  = claims["token_family"]

    # Chercher en base
    rt_row = db.execute(text("""
        SELECT id, is_revoked, token_family
        FROM mg.refresh_tokens
        WHERE token_hash = :token_hash
    """), {"token_hash": token_hash}).mappings().fetchone()

    if not rt_row:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED,
                            detail="Refresh token inconnu.")

    # Détection réutilisation (vol potentiel) -- révoquer toute la famille
    if rt_row["is_revoked"]:
        db.execute(text("""
            UPDATE mg.refresh_tokens
            SET is_revoked = TRUE, revoked_at = NOW()
            WHERE token_family = CAST(:family AS uuid) AND is_revoked = FALSE
        """), {"family": str(rt_row["token_family"])})
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=(
                "Refresh token deja revoque -- toute la famille a ete invalidee. "
                "Si vous n'etes pas a l'origine de cette action, "
                "contacter le Secretariat technique OSA immediatement."
            ),
            headers={"X-OSA-Error": "TOKEN_FAMILY_REVOKED"},
        )

    # Révoquer l'ancien refresh token
    db.execute(text("""
        UPDATE mg.refresh_tokens
        SET is_revoked = TRUE, revoked_at = NOW()
        WHERE id = :rt_id
    """), {"rt_id": rt_row["id"]})
    db.commit()

    # Lire access_level et institution depuis les claims du refresh token
    # (évite une relecture base et gère correctement les clés EXPERT sans affiliation)
    access_level = claims.get("access_level") or "STANDARD"
    institution  = claims.get("institution") or "UNK"

    # Émettre les nouveaux tokens (même famille -- chaîne continue)
    new_access = _make_access_token(affiliation_id, access_level, institution)
    new_refresh, _ = _make_refresh_token(
        affiliation_id=affiliation_id,
        token_family=token_family,
        api_key_hash=None,
        user_agent=request.headers.get("User-Agent"),
        ip_address=str(request.client.host) if request.client else None,
        db=db,
        access_level=access_level,
        institution=institution,
    )

    return TokenResponse(
        access_token=new_access,
        refresh_token=new_refresh,
        expires_in=_access_expire_minutes() * 60,
        access_level=access_level,
        institution=institution,
    )


@router.post(
    "/revoke",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Révoquer le refresh token courant (déconnexion)",
)
async def revoke_token(
    body: RevokeRequest,
    claims: dict = Depends(get_current_token),
    db=Depends(get_db),
):
    """
    Révoque le refresh token fourni + inscrit le jti de l'access token en liste noire.
    """
    affiliation_id = int(claims["sub"])

    if body.refresh_token:
        token_hash = _sha256(body.refresh_token)
        db.execute(text("""
            UPDATE mg.refresh_tokens
            SET is_revoked = TRUE, revoked_at = NOW()
            WHERE token_hash = :token_hash AND affiliation_id = :affiliation_id
        """), {"token_hash": token_hash, "affiliation_id": affiliation_id})
        db.commit()

    jti = claims.get("jti")
    if jti:
        exp_ts  = claims.get("exp")
        exp_dt  = (
            datetime.fromtimestamp(exp_ts, tz=timezone.utc)
            if exp_ts
            else _utcnow() + timedelta(minutes=_access_expire_minutes())
        )
        _add_to_blacklist(jti, affiliation_id, "access", exp_dt, "LOGOUT", "user", db)


@router.get(
    "/me",
    summary="Profil de l'affilié authentifié via JWT",
    description="Retourne les claims décodés et le profil affiliation. Accès Bearer JWT requis.",
)
async def get_me(
    claims: dict = Depends(get_current_token),
    db=Depends(get_db),
):
    affiliation_id = int(claims["sub"])

    row = db.execute(text("""
        SELECT
            institution_name,
            country_iso3,
            institution_type,
            status,
            subscription_start,
            subscription_end
        FROM rf.affiliations
        WHERE affiliation_id = :id
    """), {"id": affiliation_id}).mappings().fetchone()

    if not row:
        raise HTTPException(status_code=404, detail="Affiliation introuvable.")

    access_level = claims.get("access_level", "STANDARD")

    return {
        "affiliation_id":   affiliation_id,
        "institution_name": row["institution_name"],
        "country_iso3":     row["country_iso3"],
        "institution_type": row["institution_type"],
        "status":           row["status"],
        "subscription": {
            "start": row["subscription_start"].isoformat() if row["subscription_start"] else None,
            "end":   row["subscription_end"].isoformat()   if row["subscription_end"]   else None,
        },
        "access_rights": {
            "couche_0": True,
            "couche_1": _LEVEL_HIERARCHY.get(access_level, 0) >= 1,
            "couche_2": _LEVEL_HIERARCHY.get(access_level, 0) >= 2,
        },
        "token_type": claims.get("type"),
        "disclaimer": (
            "OSA Observatory -- Donnees souveraines africaines. "
            "Usage strictement institutionnel. "
            "Redistribution interdite sans accord du Secretariat technique OSA."
        ),
    }


@router.post(
    "/revoke-all/{target_affiliation_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="[EXPERT] Révoquer tous les tokens d'une affiliation",
    description="Révoque tous les refresh tokens actifs d'une affiliation (cas de compromission). Accès EXPERT requis.",
)
async def revoke_all(
    target_affiliation_id: int,
    claims: dict = Depends(require_expert),
    db=Depends(get_db),
):
    # Révoquer tous les refresh tokens actifs
    db.execute(text("""
        UPDATE mg.refresh_tokens
        SET is_revoked = TRUE, revoked_at = NOW()
        WHERE affiliation_id = :id AND is_revoked = FALSE
    """), {"id": target_affiliation_id})

    # Inscrire tous les jti encore valides en liste noire
    rows = db.execute(text("""
        SELECT jti, expires_at FROM mg.refresh_tokens
        WHERE affiliation_id = :id AND expires_at > NOW()
    """), {"id": target_affiliation_id}).fetchall()

    for row in rows:
        db.execute(text("""
            INSERT INTO mg.revoked_tokens
                (jti, affiliation_id, token_type, expires_at, reason, revoked_by)
            VALUES
                (CAST(:jti AS uuid), :affiliation_id, 'refresh', :expires_at, 'COMPROMISED', :by)
            ON CONFLICT (jti) DO NOTHING
        """), {
            "jti":            str(row[0]),
            "affiliation_id": target_affiliation_id,
            "expires_at":     row[1],
            "by":             claims.get("sub", "expert"),
        })

    db.commit()
    log.warning(
        "revoke-all declenche sur affiliation_id=%s par expert sub=%s",
        target_affiliation_id, claims.get("sub")
    )
