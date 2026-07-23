"""
OSA Observatory -- OIM, Lot 6 (dernier maillon de la chaine)
api/routers/oim_projects.py

Catalogue des familles de projets compatibles (mg.project_families,
vide a ce jour -- terminologie ADR-OSA-OIM-001 finale, "Projet
recommande" renomme en "Famille de projets compatibles") et liaison
N:N ponderee depuis les patrons d'intervention (mg.pattern_project_families).
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
    tags=["OIM - Familles de projets"],
)


# ── Catalogue des familles de projets ────────────────────────────────────────────

class ProjectFamilyCreate(BaseModel):
    label_fr: str
    label_en: str
    description_fr: Optional[str] = None
    description_en: Optional[str] = None


@router.post("/project-families", summary="Créer une famille de projets compatibles (catalogue)")
def create_project_family(
    data: ProjectFamilyCreate,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    row = db.execute(
        text("""
            INSERT INTO mg.project_families
                (label_fr, label_en, description_fr, description_en)
            VALUES
                (:label_fr, :label_en, :description_fr, :description_en)
            RETURNING id, label_fr, label_en, description_fr, description_en,
                      status, created_at::text
        """),
        data.model_dump(),
    ).mappings().first()
    db.commit()
    return dict(row)


@router.get("/project-families", summary="Lister les familles de projets compatibles")
def list_project_families(status: Optional[str] = Query(default=None), db: Session = Depends(get_db)):
    sql = "SELECT id, label_fr, label_en, description_fr, description_en, status, created_at::text FROM mg.project_families WHERE 1=1"
    params: dict = {}
    if status:
        sql += " AND status = :status"
        params["status"] = status
    sql += " ORDER BY label_fr"
    rows = db.execute(text(sql), params).mappings().all()
    return {"count": len(rows), "items": [dict(r) for r in rows]}


# ── Liaison patron -> famille de projets ──────────────────────────────────────────

class PatternProjectFamilyCreate(BaseModel):
    family_id: int
    relevance_weight: float = Field(..., ge=0, le=1)


@router.post(
    "/patterns/{pattern_code}/project-families",
    summary="Lier un patron d'intervention à une famille de projets",
)
def link_pattern_project_family(
    pattern_code: str,
    data: PatternProjectFamilyCreate,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    pattern = db.execute(
        text("SELECT pattern_code FROM mg.intervention_patterns WHERE pattern_code = :code"),
        {"code": pattern_code},
    ).mappings().first()
    if not pattern:
        raise HTTPException(status_code=404, detail={"fr": "Patron introuvable.", "en": "Pattern not found."})

    family = db.execute(
        text("SELECT id FROM mg.project_families WHERE id = :id"),
        {"id": data.family_id},
    ).mappings().first()
    if not family:
        raise HTTPException(status_code=422, detail={
            "fr": f"family_id {data.family_id} introuvable dans mg.project_families.",
            "en": f"family_id {data.family_id} not found in mg.project_families.",
        })

    try:
        row = db.execute(
            text("""
                INSERT INTO mg.pattern_project_families (pattern_code, family_id, relevance_weight)
                VALUES (:pattern_code, :family_id, :relevance_weight)
                RETURNING pattern_code, family_id, relevance_weight, created_at::text
            """),
            {"pattern_code": pattern_code, "family_id": data.family_id, "relevance_weight": data.relevance_weight},
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
    "/patterns/{pattern_code}/project-families",
    summary="Lister les familles de projets liées à un patron",
)
def list_pattern_project_families(pattern_code: str, db: Session = Depends(get_db)):
    rows = db.execute(
        text("""
            SELECT ppf.pattern_code, ppf.family_id, ppf.relevance_weight, ppf.created_at::text,
                   pf.label_fr, pf.label_en
            FROM mg.pattern_project_families ppf
            JOIN mg.project_families pf ON pf.id = ppf.family_id
            WHERE ppf.pattern_code = :pattern_code
            ORDER BY ppf.relevance_weight DESC
        """),
        {"pattern_code": pattern_code},
    ).mappings().all()
    return {"count": len(rows), "items": [dict(r) for r in rows]}
