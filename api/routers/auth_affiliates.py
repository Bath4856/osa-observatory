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

def create_jwt(affiliate_id: int, email: str, role: str) -> str:
    payload = {
        "sub":  str(affiliate_id),
        "email": email,
        "role":  role,
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
    if affiliate["status"] != "ACTIVE":
        raise HTTPException(status_code=403, detail="Compte non actif. Contactez l'OSA.")
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
               a.org_name, a.affiliate_type, a.country,
               a.status, a.created_at,
               array_agg(r.role_code) AS roles
        FROM mg.affiliates a
        LEFT JOIN mg.affiliate_roles r ON r.affiliate_id = a.id
        WHERE a.id = :id
        GROUP BY a.id
    """), {"id": int(payload["sub"])}).mappings().first()

    if not affiliate:
        raise HTTPException(status_code=404, detail="Affilié non trouvé.")

    return {
        "affiliate_id": affiliate["id"],
        "email":        affiliate["email"],
        "first_name":   affiliate["first_name"],
        "last_name":    affiliate["last_name"],
        "org_name":     affiliate["org_name"],
        "affiliate_type": affiliate["affiliate_type"],
        "country":      affiliate["country"],
        "status":       affiliate["status"],
        "roles":        affiliate["roles"],
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
