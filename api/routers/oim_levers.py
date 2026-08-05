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


# ── Liaison cause racine (analyse 5_POURQUOI validee) -> levier ─────────────────
# Reconciliation du 5 aout 2026 : root_cause_id (-> mg.pillar_root_causes,
# Chaine A jamais utilisee, supprimee) devient analysis_id (->
# osoa.strategic_analyses.id, la 5_POURQUOI de la Chaine B, idealement
# PROMOTED).

class RootCauseLeverCreate(BaseModel):
    lever_code: str
    relevance_weight: float = Field(..., ge=0, le=1)


@router.post(
    "/analyses/{analysis_id}/levers",
    summary="Lier une analyse 5_POURQUOI (cause racine) à un levier stratégique",
)
def link_root_cause_lever(
    analysis_id: int,
    data: RootCauseLeverCreate,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    analysis = db.execute(
        text("SELECT id, method FROM osoa.strategic_analyses WHERE id = :id"),
        {"id": analysis_id},
    ).mappings().first()
    if not analysis:
        raise HTTPException(status_code=404, detail={"fr": "Analyse introuvable.", "en": "Analysis not found."})
    if analysis["method"] != "5_POURQUOI":
        raise HTTPException(status_code=422, detail={
            "fr": f"L'analyse {analysis_id} est de méthode '{analysis['method']}', pas '5_POURQUOI' -- seule une analyse 5 Pourquoi porte une cause racine.",
            "en": f"Analysis {analysis_id} has method '{analysis['method']}', not '5_POURQUOI' -- only a 5 Whys analysis carries a root cause.",
        })

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
                INSERT INTO mg.root_cause_levers (analysis_id, lever_code, relevance_weight)
                VALUES (:analysis_id, :lever_code, :relevance_weight)
                RETURNING analysis_id, lever_code, relevance_weight, created_at::text
            """),
            {"analysis_id": analysis_id, "lever_code": data.lever_code, "relevance_weight": data.relevance_weight},
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
    "/analyses/{analysis_id}/levers",
    summary="Lister les leviers liés à une analyse 5_POURQUOI",
)
def list_root_cause_levers(analysis_id: int, db: Session = Depends(get_db)):
    rows = db.execute(
        text("""
            SELECT rcl.analysis_id, rcl.lever_code, rcl.relevance_weight, rcl.created_at::text,
                   sl.label_fr, sl.label_en
            FROM mg.root_cause_levers rcl
            JOIN mg.strategic_levers sl ON sl.lever_code = rcl.lever_code
            WHERE rcl.analysis_id = :analysis_id
            ORDER BY rcl.relevance_weight DESC
        """),
        {"analysis_id": analysis_id},
    ).mappings().all()
    return {"count": len(rows), "items": [dict(r) for r in rows]}
