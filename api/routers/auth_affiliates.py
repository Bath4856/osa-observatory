"""
OSA Observatory -- Sprint 30 Lot C
Router Auth -- Authentification JWT affilies OSA
POST /api/v2/auth/login
GET  /api/v2/auth/me
DELETE /api/v2/auth/logout
"""
import os
import jwt
import hashlib
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException, Header
from sqlalchemy.orm import Session
from sqlalchemy import text
from pydantic import BaseModel
from typing import Optional
from passlib.context import CryptContext
from api.db import get_db

router = APIRouter(
    prefix="/api/v2/affiliates/auth",
    tags=["Authentification affilies OSA"],
)

JWT_SECRET    = os.getenv("JWT_SECRET", "osa-observatory-secret-key-change-in-prod")
JWT_ALGORITHM = "HS256"
JWT_EXPIRE_H  = 24

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# ── Schemas ───────────────────────────────────────────────────────────────────

class LoginRequest(BaseModel):
    email:    str
    password: str

class LoginResponse(BaseModel):
    token:        str
    affiliate_id: int
    email:        str
    role:         str
    expires_in:   int

# ── Helpers ───────────────────────────────────────────────────────────────────

def hash_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()

# Roles internes de confiance -- jamais soumis au plafond STANDARD
# (500 req/jour) du limiteur de debit, concu a l'origine pour des
# consommateurs publics/externes, pas pour l'automatisation technique
# interne (ex. sequenceur batch). Decouvert le 11 aout 2026 : access_level
# n'etait jamais renseigne dans le JWT, donc TOUS les comptes retombaient
# silencieusement sur STANDARD, y compris les comptes techniques internes.
EXPERT_ROLES = {"COMITE_TECH", "ADMIN", "COMITE_SCI"}


def create_jwt(affiliate_id: int, email: str, role: str) -> str:
    access_level = "EXPERT" if role in EXPERT_ROLES else "STANDARD"
    payload = {
        "sub":  str(affiliate_id),
        "email": email,
        "role":  role,
        "access_level": access_level,
        "exp":   datetime.utcnow() + timedelta(hours=JWT_EXPIRE_H),
        "iat":   datetime.utcnow(),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)

def verify_jwt(token: str) -> dict:
    try:
        return jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expire.")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Token invalide.")

def get_current_affiliate(
    authorization: Optional[str] = Header(None),
    db: Session = Depends(get_db)
) -> dict:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Authentification requise.")
    token = authorization.split(" ", 1)[1]
    payload = verify_jwt(token)
    # Verifier que la session est active en base
    token_hash = hash_token(token)
    session = db.execute(
        text("SELECT id FROM mg.affiliate_sessions WHERE token_hash = :h AND expires_at > NOW()"),
        {"h": token_hash}
    ).mappings().first()
    if not session:
        raise HTTPException(status_code=401, detail="Session expiree ou revoquee.")
    return payload

# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.post("/login", response_model=LoginResponse,
    summary="Authentification affilie OSA",
    description="Login email + mot de passe. Retourne un JWT valide 24h.")
def login(data: LoginRequest, db: Session = Depends(get_db)):
    # Chercher l'affilie
    affiliate = db.execute(text("""
        SELECT a.id, a.email, a.password_hash, a.status,
               r.role_code
        FROM mg.affiliates a
        LEFT JOIN mg.affiliate_roles r ON r.affiliate_id = a.id
        WHERE a.email = :email
        ORDER BY r.granted_at DESC
        LIMIT 1
    """), {"email": data.email.lower().strip()}).mappings().first()

    if not affiliate:
        raise HTTPException(status_code=401, detail="Email ou mot de passe incorrect.")
    # AFFILIATED (auto-activation par confirmation email, cf. R1
    # AFFILIATION_WORKFLOW_REVISION_001) et ACTIVE (comptes institutionnels /
    # fondateurs) sont tous deux des comptes pleinement utilisables. Bug
    # decouvert le 5 juillet 2026 : rien dans le code ne promeut jamais
    # AFFILIATED vers ACTIVE -- un compte auto-active via confirm-email ne
    # pouvait donc jamais se connecter avant ce correctif.
    if affiliate["status"] not in ("ACTIVE", "AFFILIATED"):
        raise HTTPException(status_code=403, detail={
            "fr": "Compte non actif. Contactez l'equipe OSA Observatory.",
            "en": "Account not active. Please contact the OSA Observatory team."
        })
    if not affiliate["password_hash"]:
        raise HTTPException(status_code=401, detail="Mot de passe non configure.")
    if not pwd_context.verify(data.password, affiliate["password_hash"]):
        raise HTTPException(status_code=401, detail="Email ou mot de passe incorrect.")

    role  = affiliate["role_code"] or "AFFILIE"
    token = create_jwt(affiliate["id"], affiliate["email"], role)

    # Enregistrer la session
    db.execute(text("""
        INSERT INTO mg.affiliate_sessions
            (affiliate_id, token_hash, expires_at)
        VALUES
            (:id, :hash, NOW() + INTERVAL '24 hours')
    """), {"id": affiliate["id"], "hash": hash_token(token)})
    db.commit()

    return {
        "token":        token,
        "affiliate_id": affiliate["id"],
        "email":        affiliate["email"],
        "role":         role,
        "expires_in":   JWT_EXPIRE_H * 3600,
    }


@router.get("/me",
    summary="Profil affilié connecté",
    description="Retourne le profil de l'affilié authentifié.")
def get_me(
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db)
):
    affiliate = db.execute(text("""
        SELECT a.id, a.email, a.first_name, a.last_name,
               a.org_name, a.affiliate_type, a.country, a.function_title,
               a.status, a.created_at,
               array_agg(r.role_code) AS roles
        FROM mg.affiliates a
        LEFT JOIN mg.affiliate_roles r ON r.affiliate_id = a.id
        WHERE a.id = :id
        GROUP BY a.id
    """), {"id": int(payload["sub"])}).mappings().first()

    if not affiliate:
        raise HTTPException(status_code=404, detail="Affilié non trouvé.")

    # KYC minimal : fonction + pays (org_name est deja obligatoire des la
    # creation). Sert au bandeau de rappel doux cote portail -- jamais
    # bloquant (decision du 11 juillet 2026 : "le moins contraignant").
    kyc_complete = bool(affiliate["function_title"]) and bool(affiliate["country"])

    return {
        "affiliate_id": affiliate["id"],
        "email":        affiliate["email"],
        "first_name":   affiliate["first_name"],
        "last_name":    affiliate["last_name"],
        "org_name":     affiliate["org_name"],
        "affiliate_type": affiliate["affiliate_type"],
        "country":      affiliate["country"],
        "function_title": affiliate["function_title"],
        "status":       affiliate["status"],
        "roles":        affiliate["roles"],
        "kyc_complete": kyc_complete,
        "created_at":   str(affiliate["created_at"]),
    }


@router.delete("/logout",
    summary="Deconnexion affilié",
    description="Révoque le token JWT actif.")
def logout(
    authorization: Optional[str] = Header(None),
    db: Session = Depends(get_db)
):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Authentification requise.")
    token = authorization.split(" ", 1)[1]
    token_hash = hash_token(token)
    db.execute(
        text("DELETE FROM mg.affiliate_sessions WHERE token_hash = :h"),
        {"h": token_hash}
    )
    db.commit()
    return {"message": "Deconnexion reussie."}


import bcrypt
from pydantic import BaseModel as _BaseModel, Field
from api.utils.password_policy import validate_password_strength


class ProfileUpdate(_BaseModel):
    function_title: Optional[str] = Field(None, max_length=200)
    country: Optional[str] = Field(None, max_length=100)
    org_name: Optional[str] = Field(None, max_length=300)


@router.patch("/me",
    summary="Compléter son profil (KYC)",
    description="Met à jour fonction, pays, organisation -- jamais bloquant, complète le profil après activation.")
def update_profile(
    body: ProfileUpdate,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db)
):
    affiliate_id = int(payload["sub"])
    fields = body.dict(exclude_unset=True)
    if not fields:
        return {"message": {"fr": "Aucune modification.", "en": "No changes."}}

    set_clause = ", ".join(f"{k} = :{k}" for k in fields)
    fields["id"] = affiliate_id
    db.execute(text(f"UPDATE mg.affiliates SET {set_clause} WHERE id = :id"), fields)
    db.commit()

    return {"message": {"fr": "Profil mis à jour.", "en": "Profile updated."}}


class PasswordChange(_BaseModel):
    current_password: str
    new_password: str = Field(..., min_length=8)


@router.patch("/me/password",
    summary="Changer son mot de passe",
    description="Exige l'ancien mot de passe -- jamais l'un sans l'autre.")
def change_password(
    body: PasswordChange,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db)
):
    affiliate_id = int(payload["sub"])
    affiliate = db.execute(text("SELECT password_hash FROM mg.affiliates WHERE id = :id"),
                            {"id": affiliate_id}).mappings().first()

    if not affiliate or not affiliate["password_hash"] or \
       not bcrypt.checkpw(body.current_password.encode("utf-8"), affiliate["password_hash"].encode("utf-8")):
        raise HTTPException(status_code=403, detail={
            "fr": "Mot de passe actuel incorrect.",
            "en": "Current password is incorrect."
        })

    error = validate_password_strength(body.new_password)
    if error:
        raise HTTPException(status_code=422, detail={"fr": error, "en": error})

    new_hash = bcrypt.hashpw(body.new_password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")
    db.execute(text("UPDATE mg.affiliates SET password_hash = :h WHERE id = :id"),
               {"h": new_hash, "id": affiliate_id})
    db.commit()

    return {"message": {"fr": "Mot de passe modifié.", "en": "Password changed."}}


# ── Dependance COMITE_SCI ──────────────────────────────────────────────────────
# Meme discipline que require_admin ci-dessous : requete fraiche sur
# mg.affiliate_roles, jamais le seul champ "role" du JWT.
def require_comite_sci(
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db)
) -> dict:
    affiliate_id = int(payload["sub"])
    is_comite_sci = db.execute(text("""
        SELECT 1 FROM mg.affiliate_roles
        WHERE affiliate_id = :id AND role_code = 'COMITE_SCI'
    """), {"id": affiliate_id}).first()
    if not is_comite_sci:
        raise HTTPException(status_code=403, detail={
            "fr": "Accès réservé au Conseil Scientifique.",
            "en": "Access restricted to the Scientific Council."
        })
    return payload


# ── Dependance ADMIN ──────────────────────────────────────────────────────────
# Ne se fie jamais au seul champ "role" du JWT (login ne retient que le
# role le plus recemment accorde, cf. ORDER BY granted_at DESC LIMIT 1
# ci-dessus -- limitation preexistante, non corrigee ici). Requete fraiche
# sur mg.affiliate_roles, comme /me le fait deja avec array_agg, pour
# couvrir correctement un affilie ayant plusieurs roles simultanes.
def require_admin(
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db)
) -> dict:
    affiliate_id = int(payload["sub"])
    is_admin = db.execute(text("""
        SELECT 1 FROM mg.affiliate_roles
        WHERE affiliate_id = :id AND role_code = 'ADMIN'
    """), {"id": affiliate_id}).first()
    if not is_admin:
        raise HTTPException(status_code=403, detail={
            "fr": "Accès réservé aux administrateurs.",
            "en": "Access restricted to administrators."
        })
    return payload
