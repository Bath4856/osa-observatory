"""
OSA Observatory -- OIM, Lot 5
api/routers/oim_patterns.py

Catalogue des patrons d'intervention (mg.intervention_patterns, vide
a ce jour) et liaison N:N ponderee depuis les exigences de
transformation (mg.requirement_pattern_matches).
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
    tags=["OIM - Patrons d'intervention"],
)


# ── Catalogue des patrons ────────────────────────────────────────────────────────

class PatternCreate(BaseModel):
    pattern_code: str = Field(..., min_length=1, max_length=100)
    label_fr: str
    label_en: str
    description_fr: Optional[str] = None
    description_en: Optional[str] = None


@router.post("/patterns", summary="Créer un patron d'intervention (catalogue)")
def create_pattern(
    data: PatternCreate,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    try:
        row = db.execute(
            text("""
                INSERT INTO mg.intervention_patterns
                    (pattern_code, label_fr, label_en, description_fr, description_en)
                VALUES
                    (:pattern_code, :label_fr, :label_en, :description_fr, :description_en)
                RETURNING pattern_code, label_fr, label_en, description_fr, description_en,
                          is_active, created_at::text
            """),
            data.model_dump(),
        ).mappings().first()
        db.commit()
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=409, detail={
            "fr": f"Erreur à la création (pattern_code déjà utilisé ?) : {e}",
            "en": f"Creation error (pattern_code already used?): {e}",
        })
    return dict(row)


@router.get("/patterns", summary="Lister les patrons d'intervention")
def list_patterns(active_only: bool = Query(default=True), db: Session = Depends(get_db)):
    sql = "SELECT pattern_code, label_fr, label_en, description_fr, description_en, is_active, created_at::text FROM mg.intervention_patterns"
    if active_only:
        sql += " WHERE is_active = true"
    sql += " ORDER BY label_fr"
    rows = db.execute(text(sql)).mappings().all()
    return {"count": len(rows), "items": [dict(r) for r in rows]}


# ── Liaison exigence -> patron ────────────────────────────────────────────────────

class RequirementPatternCreate(BaseModel):
    pattern_code: str
    relevance_weight: float = Field(..., ge=0, le=1)


@router.post(
    "/requirements/{requirement_id}/patterns",
    summary="Lier une exigence de transformation à un patron d'intervention",
)
def link_requirement_pattern(
    requirement_id: int,
    data: RequirementPatternCreate,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    req = db.execute(
        text("SELECT id FROM mg.transformation_requirements WHERE id = :id"),
        {"id": requirement_id},
    ).mappings().first()
    if not req:
        raise HTTPException(status_code=404, detail={"fr": "Exigence introuvable.", "en": "Requirement not found."})

    pattern = db.execute(
        text("SELECT pattern_code FROM mg.intervention_patterns WHERE pattern_code = :code"),
        {"code": data.pattern_code},
    ).mappings().first()
    if not pattern:
        raise HTTPException(status_code=422, detail={
            "fr": f"pattern_code '{data.pattern_code}' introuvable dans mg.intervention_patterns.",
            "en": f"pattern_code '{data.pattern_code}' not found in mg.intervention_patterns.",
        })

    try:
        row = db.execute(
            text("""
                INSERT INTO mg.requirement_pattern_matches (requirement_id, pattern_code, relevance_weight)
                VALUES (:requirement_id, :pattern_code, :relevance_weight)
                RETURNING requirement_id, pattern_code, relevance_weight, created_at::text
            """),
            {"requirement_id": requirement_id, "pattern_code": data.pattern_code, "relevance_weight": data.relevance_weight},
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
    "/requirements/{requirement_id}/patterns",
    summary="Lister les patrons liés à une exigence",
)
def list_requirement_patterns(requirement_id: int, db: Session = Depends(get_db)):
    rows = db.execute(
        text("""
            SELECT rpm.requirement_id, rpm.pattern_code, rpm.relevance_weight, rpm.created_at::text,
                   ip.label_fr, ip.label_en
            FROM mg.requirement_pattern_matches rpm
            JOIN mg.intervention_patterns ip ON ip.pattern_code = rpm.pattern_code
            WHERE rpm.requirement_id = :requirement_id
            ORDER BY rpm.relevance_weight DESC
        """),
        {"requirement_id": requirement_id},
    ).mappings().all()
    return {"count": len(rows), "items": [dict(r) for r in rows]}
