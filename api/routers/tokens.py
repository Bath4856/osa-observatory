"""
OSA Observatory -- Sprint 14
Router gestion tokens et affiliations

Endpoints :
  POST /api/v1/admin/affiliations          -- creer une affiliation
  GET  /api/v1/admin/affiliations          -- lister les affiliations
  GET  /api/v1/admin/affiliations/{id}     -- detail affiliation
  POST /api/v1/admin/affiliations/{id}/keys -- generer une cle API
  DELETE /api/v1/admin/keys/{key_id}       -- revoquer une cle
  GET  /api/v1/admin/keys/{key_id}/status  -- statut d une cle
  GET  /api/v1/me                          -- profil de l affilié (token requis)

Note : les endpoints /admin/ sont protégés par validate_expert_access.
/api/v1/me est protege par validate_standard_access ou premium.
"""

from datetime import date
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import Response
from pydantic import BaseModel
from sqlalchemy import text
from sqlalchemy.orm import Session
from api.db import get_db
from api.security import (
    validate_expert_access,
    validate_standard_access,
    generate_api_key,
)
import json

router = APIRouter(prefix="/api/v1/admin", tags=["Administration -- Affiliations"])
public_router = APIRouter(prefix="/api/v1", tags=["Affiliation -- Profil"])


# ── Schemas Pydantic ──────────────────────────────────────────
class AffiliationCreate(BaseModel):
    institution_name:   str
    country_iso3:       Optional[str] = None
    institution_type:   str           = "MINISTRY"
    access_level:       str           = "STANDARD"
    contact_email:      Optional[str] = None
    subscription_start: date          = date.today()
    subscription_end:   Optional[date] = None
    auto_renew:         bool          = False
    notes:              Optional[str] = None


# ── Helper JSON UTF-8 ─────────────────────────────────────────
def _json(data) -> Response:
    return Response(
        content=json.dumps(data, ensure_ascii=False, default=str),
        media_type="application/json; charset=utf-8"
    )


# ── 1. Creer une affiliation ──────────────────────────────────
@router.post(
    "/affiliations",
    summary="Creer une nouvelle affiliation OSA",
    description="Cree un abonnement S1 (STANDARD) ou S2 (PREMIUM). Expert requis.",
)
async def create_affiliation(
    data: AffiliationCreate,
    db:   Session = Depends(get_db),
    auth: dict    = Depends(validate_expert_access),
):
    if data.access_level not in ("STANDARD", "PREMIUM"):
        raise HTTPException(status_code=400, detail="access_level must be STANDARD or PREMIUM")
    if data.institution_type not in ("MINISTRY", "CENTRAL_BANK", "REGIONAL", "UNIVERSITY", "OTHER"):
        raise HTTPException(status_code=400, detail="Invalid institution_type")

    row = db.execute(text("""
        INSERT INTO rf.affiliations
            (institution_name, country_iso3, institution_type, access_level,
             contact_email, subscription_start, subscription_end, auto_renew, notes)
        VALUES
            (:name, :iso3, :itype, :level,
             :email, :start, :end, :renew, :notes)
        RETURNING affiliation_id, institution_name, access_level, subscription_start
    """), {
        "name":  data.institution_name,
        "iso3":  data.country_iso3,
        "itype": data.institution_type,
        "level": data.access_level,
        "email": data.contact_email,
        "start": data.subscription_start,
        "end":   data.subscription_end,
        "renew": data.auto_renew,
        "notes": data.notes,
    }).mappings().fetchone()
    db.commit()

    return _json({
        "status": "CREATED",
        "affiliation_id": row["affiliation_id"],
        "institution_name": row["institution_name"],
        "access_level": row["access_level"],
        "subscription_start": str(row["subscription_start"]),
        "message": f"Affiliation created. Use POST /api/v1/admin/affiliations/{row['affiliation_id']}/keys to generate API keys.",
    })


# ── 2. Lister les affiliations ────────────────────────────────
@router.get(
    "/affiliations",
    summary="Lister les affiliations actives",
)
async def list_affiliations(
    db:     Session       = Depends(get_db),
    auth:   dict          = Depends(validate_expert_access),
    status: Optional[str] = None,
    level:  Optional[str] = None,
):
    rows = db.execute(text("""
        SELECT affiliation_id, institution_name, country_iso3, country_name_fr,
               institution_type, access_level, status, subscription_status,
               subscription_start, subscription_end, days_remaining,
               nb_active_keys, auto_renew
        FROM rf.v_active_affiliations
        WHERE (:status IS NULL OR status = :status)
          AND (:level  IS NULL OR access_level = :level)
        ORDER BY access_level, institution_name
    """), {
        "status": status.upper() if status else None,
        "level":  level.upper()  if level  else None,
    }).mappings().all()
    return _json({"count": len(rows), "affiliations": [dict(r) for r in rows]})


# ── 3. Detail affiliation ─────────────────────────────────────
@router.get(
    "/affiliations/{affiliation_id}",
    summary="Detail d une affiliation",
)
async def get_affiliation(
    affiliation_id: int,
    db:   Session = Depends(get_db),
    auth: dict    = Depends(validate_expert_access),
):
    row = db.execute(text("""
        SELECT * FROM rf.v_active_affiliations
        WHERE affiliation_id = :id
    """), {"id": affiliation_id}).mappings().fetchone()
    if not row:
        raise HTTPException(status_code=404, detail=f"Affiliation {affiliation_id} not found")
    return _json(dict(row))


# ── 4. Generer une cle API ────────────────────────────────────
@router.post(
    "/affiliations/{affiliation_id}/keys",
    summary="Generer une cle API pour une affiliation",
    description=(
        "Genere une cle API pour l affiliation specifiee. "
        "La cle brute est retournee UNE SEULE FOIS -- elle n est jamais stockee. "
        "Seul le hash SHA-256 est conserve en base."
    ),
)
async def generate_key(
    affiliation_id: int,
    db:   Session = Depends(get_db),
    auth: dict    = Depends(validate_expert_access),
    label: Optional[str] = None,
):
    # Verifier que l affiliation existe et est active
    aff = db.execute(text("""
        SELECT affiliation_id, institution_name, access_level, status,
               nb_active_keys,
               (SELECT max_keys_per_affiliation FROM rf.access_level_policy
                WHERE access_level = a.access_level) AS max_keys,
               (SELECT rate_limit_per_hour FROM rf.access_level_policy
                WHERE access_level = a.access_level) AS rate_limit
        FROM rf.v_active_affiliations a
        WHERE affiliation_id = :id
    """), {"id": affiliation_id}).mappings().fetchone()

    if not aff:
        raise HTTPException(status_code=404, detail=f"Affiliation {affiliation_id} not found")
    if aff["status"] != "ACTIVE":
        raise HTTPException(status_code=403, detail=f"Affiliation is {aff['status']}")
    if aff["nb_active_keys"] >= (aff["max_keys"] or 3):
        raise HTTPException(
            status_code=409,
            detail=f"Max keys reached ({aff['max_keys']}) for {aff['access_level']} level"
        )

    # Generer la cle
    raw_key, hashed = generate_api_key()
    owner = label or aff["institution_name"]

    key_row = db.execute(text("""
        INSERT INTO mg.api_key_registry
            (api_key_hash, owner_label, access_class, affiliation_id, rate_limit_per_hour)
        VALUES
            (:hash, :owner, :level, :aff_id, :rate)
        RETURNING api_key_id, created_at
    """), {
        "hash":   hashed,
        "owner":  owner,
        "level":  aff["access_level"],
        "aff_id": affiliation_id,
        "rate":   aff["rate_limit"] or 500,
    }).mappings().fetchone()
    db.commit()

    return _json({
        "status":         "KEY_GENERATED",
        "api_key_id":     key_row["api_key_id"],
        "api_key":        raw_key,
        "access_level":   aff["access_level"],
        "institution":    aff["institution_name"],
        "rate_limit":     aff["rate_limit"],
        "created_at":     str(key_row["created_at"]),
        "warning":        "Store this key securely -- it will NOT be shown again.",
        "usage":          "Add header: X-Api-Key: <your_key>",
    })


# ── 5. Revoquer une cle ───────────────────────────────────────
@router.delete(
    "/keys/{key_id}",
    summary="Revoquer une cle API",
)
async def revoke_key(
    key_id: int,
    db:     Session = Depends(get_db),
    auth:   dict    = Depends(validate_expert_access),
):
    result = db.execute(text("""
        UPDATE mg.api_key_registry
        SET is_active = FALSE
        WHERE api_key_id = :id
        RETURNING api_key_id, owner_label, access_class
    """), {"id": key_id}).mappings().fetchone()
    db.commit()

    if not result:
        raise HTTPException(status_code=404, detail=f"Key {key_id} not found")
    return _json({
        "status":    "REVOKED",
        "api_key_id": result["api_key_id"],
        "owner":     result["owner_label"],
    })


# ── 6. Statut d une cle ───────────────────────────────────────
@router.get(
    "/keys/{key_id}/status",
    summary="Statut d une cle API",
)
async def key_status(
    key_id: int,
    db:     Session = Depends(get_db),
    auth:   dict    = Depends(validate_expert_access),
):
    row = db.execute(text("""
        SELECT api_key_id, owner_label, access_class, effective_access_class,
               is_active, access_granted, rate_limit_per_hour,
               requests_today, last_reset_date, last_used_at,
               institution_name, affiliation_status, subscription_end
        FROM mg.v_api_key_status
        WHERE api_key_id = :id
    """), {"id": key_id}).mappings().fetchone()

    if not row:
        raise HTTPException(status_code=404, detail=f"Key {key_id} not found")
    return _json(dict(row))


# ── 7. Profil affilié (token requis) ─────────────────────────
@public_router.get(
    "/me",
    summary="Profil de l affilie -- token requis",
    description="Retourne le profil et les droits d acces de l affilié authentifie.",
)
async def get_my_profile(
    db:   Session = Depends(get_db),
    auth: dict    = Depends(validate_standard_access),
):
    row = db.execute(text("""
        SELECT api_key_id, owner_label, access_class, effective_access_class,
               rate_limit_per_hour, requests_today, last_used_at,
               institution_name, affiliation_status, subscription_end
        FROM mg.v_api_key_status
        WHERE api_key_id = (
            SELECT api_key_id FROM mg.api_key_registry
            WHERE api_key_hash = :hashed AND is_active = TRUE
            LIMIT 1
        )
    """), {"hashed": auth.get("api_key_hash", "")}).mappings().fetchone()

    return _json({
        "profile": dict(row) if row else auth,
        "access": {
            "couche_0": True,
            "couche_1": auth.get("effective_access_class") in ("STANDARD", "PREMIUM", "EXPERT"),
            "couche_2": auth.get("effective_access_class") in ("PREMIUM", "EXPERT"),
        },
        "endpoints": {
            "open_data": "/opendata/",
            "scores":    "/api/v2/countries/",
            "predictive": "/api/v2/predictive/" if auth.get("effective_access_class") in ("PREMIUM", "EXPERT") else None,
        }
    })
