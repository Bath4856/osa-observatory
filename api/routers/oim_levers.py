"""
OSA Observatory -- OIM, Lot 2
api/routers/oim_levers.py

Catalogue des leviers strategiques (mg.strategic_levers, vide a ce jour)
et liaison N:N ponderee vers les causes racines (mg.root_cause_levers).
"""
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import text
from pydantic import BaseModel, Field

from api.db import get_db
from api.routers.auth_affiliates import get_current_affiliate

router = APIRouter(
    prefix="/api/v2/oim",
    tags=["OIM - Leviers"],
)


# ── Catalogue des leviers ────────────────────────────────────────────────────────

class LeverCreate(BaseModel):
    lever_code: str = Field(..., min_length=1, max_length=100)
    label_fr: str
    label_en: str
    description_fr: Optional[str] = None
    description_en: Optional[str] = None


@router.post("/levers", summary="Créer un levier stratégique (catalogue)")
def create_lever(
    data: LeverCreate,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    try:
        row = db.execute(
            text("""
                INSERT INTO mg.strategic_levers
                    (lever_code, label_fr, label_en, description_fr, description_en)
                VALUES
                    (:lever_code, :label_fr, :label_en, :description_fr, :description_en)
                RETURNING lever_code, label_fr, label_en, description_fr, description_en,
                          is_active, created_at::text
            """),
            data.model_dump(),
        ).mappings().first()
        db.commit()
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=409, detail={
            "fr": f"Erreur à la création (lever_code déjà utilisé ?) : {e}",
            "en": f"Creation error (lever_code already used?): {e}",
        })
    return dict(row)


@router.get("/levers", summary="Lister les leviers stratégiques")
def list_levers(active_only: bool = Query(default=True), db: Session = Depends(get_db)):
    sql = "SELECT lever_code, label_fr, label_en, description_fr, description_en, is_active, created_at::text FROM mg.strategic_levers"
    if active_only:
        sql += " WHERE is_active = true"
    sql += " ORDER BY label_fr"
    rows = db.execute(text(sql)).mappings().all()
    return {"count": len(rows), "items": [dict(r) for r in rows]}


# ── Liaison cause racine -> levier ────────────────────────────────────────────────

class RootCauseLeverCreate(BaseModel):
    lever_code: str
    relevance_weight: float = Field(..., ge=0, le=1)


@router.post(
    "/root-causes/{root_cause_id}/levers",
    summary="Lier une cause racine à un levier stratégique",
)
def link_root_cause_lever(
    root_cause_id: int,
    data: RootCauseLeverCreate,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    rc = db.execute(
        text("SELECT id FROM mg.pillar_root_causes WHERE id = :id"),
        {"id": root_cause_id},
    ).mappings().first()
    if not rc:
        raise HTTPException(status_code=404, detail={"fr": "Cause racine introuvable.", "en": "Root cause not found."})

    lever = db.execute(
        text("SELECT lever_code FROM mg.strategic_levers WHERE lever_code = :code"),
        {"code": data.lever_code},
    ).mappings().first()
    if not lever:
        raise HTTPException(status_code=422, detail={
            "fr": f"lever_code '{data.lever_code}' introuvable dans mg.strategic_levers.",
            "en": f"lever_code '{data.lever_code}' not found in mg.strategic_levers.",
        })

    try:
        row = db.execute(
            text("""
                INSERT INTO mg.root_cause_levers (root_cause_id, lever_code, relevance_weight)
                VALUES (:root_cause_id, :lever_code, :relevance_weight)
                RETURNING root_cause_id, lever_code, relevance_weight, created_at::text
            """),
            {"root_cause_id": root_cause_id, "lever_code": data.lever_code, "relevance_weight": data.relevance_weight},
        ).mappings().first()
        db.commit()
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=409, detail={
            "fr": f"Erreur à la liaison (déjà existante ?) : {e}",
            "en": f"Linking error (already exists?): {e}",
        })
    return dict(row)


@router.get(
    "/root-causes/{root_cause_id}/levers",
    summary="Lister les leviers liés à une cause racine",
)
def list_root_cause_levers(root_cause_id: int, db: Session = Depends(get_db)):
    rows = db.execute(
        text("""
            SELECT rcl.root_cause_id, rcl.lever_code, rcl.relevance_weight, rcl.created_at::text,
                   sl.label_fr, sl.label_en
            FROM mg.root_cause_levers rcl
            JOIN mg.strategic_levers sl ON sl.lever_code = rcl.lever_code
            WHERE rcl.root_cause_id = :root_cause_id
            ORDER BY rcl.relevance_weight DESC
        """),
        {"root_cause_id": root_cause_id},
    ).mappings().all()
    return {"count": len(rows), "items": [dict(r) for r in rows]}
