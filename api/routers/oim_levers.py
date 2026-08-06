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


@router.post("/levers", summary="Créer un levier stratégique (catalogue référentiel)")
def create_lever(
    data: LeverCreate,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    try:
        row = db.execute(
            text("""
                INSERT INTO rf.strategic_levers
                    (lever_code, label_fr, label_en, description_fr, description_en)
                VALUES
                    (:lever_code, :label_fr, :label_en, :description_fr, :description_en)
                RETURNING lever_code, label_fr, label_en, description_fr, description_en,
                          domain_pillar_code, family, approval_status, is_active, created_at::text
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


@router.get("/levers", summary="Lister les leviers stratégiques (catalogue référentiel)")
def list_levers(active_only: bool = Query(default=True), db: Session = Depends(get_db)):
    sql = """
        SELECT lever_code, label_fr, label_en, description_fr, description_en,
               domain_pillar_code, family, approval_status, is_active, created_at::text
        FROM rf.strategic_levers
    """
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
    evidence_type: str
    relevance_weight: float = Field(..., ge=0, le=1)
    comment: Optional[str] = None


@router.post(
    "/analyses/{analysis_id}/levers",
    summary="Lier une analyse 5_POURQUOI (ou toute analyse) à un levier stratégique -- preuve de justification",
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

    lever = db.execute(
        text("SELECT lever_code FROM rf.strategic_levers WHERE lever_code = :code"),
        {"code": data.lever_code},
    ).mappings().first()
    if not lever:
        raise HTTPException(status_code=422, detail={
            "fr": f"lever_code '{data.lever_code}' introuvable dans rf.strategic_levers.",
            "en": f"lever_code '{data.lever_code}' not found in rf.strategic_levers.",
        })

    try:
        row = db.execute(
            text("""
                INSERT INTO mg.lever_evidence (lever_code, analysis_id, evidence_type, relevance_weight, comment)
                VALUES (:lever_code, :analysis_id, :evidence_type, :relevance_weight, :comment)
                RETURNING id, lever_code, analysis_id, evidence_type, relevance_weight, comment, created_at::text
            """),
            {
                "lever_code": data.lever_code,
                "analysis_id": analysis_id,
                "evidence_type": data.evidence_type,
                "relevance_weight": data.relevance_weight,
                "comment": data.comment,
            },
        ).mappings().first()
        db.commit()
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=409, detail={
            "fr": f"Erreur à la liaison : {e}",
            "en": f"Linking error: {e}",
        })
    return dict(row)


@router.get(
    "/levers/{lever_code}/evidence",
    summary="Lister les analyses justifiant un levier stratégique",
)
def list_lever_evidence(lever_code: str, db: Session = Depends(get_db)):
    rows = db.execute(
        text("""
            SELECT le.id, le.lever_code, le.analysis_id, le.evidence_type,
                   le.relevance_weight, le.comment, le.created_at::text
            FROM mg.lever_evidence le
            WHERE le.lever_code = :lever_code
            ORDER BY le.relevance_weight DESC
        """),
        {"lever_code": lever_code},
    ).mappings().all()
    return {"count": len(rows), "items": [dict(r) for r in rows]}
