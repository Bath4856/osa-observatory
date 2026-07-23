"""
OSA Observatory -- OIM, Lot 3
api/routers/oim_objectives.py

Objectifs strategiques (mg.strategic_objectives) et liaison N:N
ponderee depuis les leviers (mg.lever_objectives).
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
    tags=["OIM - Objectifs"],
)


def _validate_pillar_code(db: Session, pillar_code: str):
    row = db.execute(
        text("SELECT pillar_code FROM mg.working_groups WHERE pillar_code = :code"),
        {"code": pillar_code},
    ).mappings().first()
    if not row:
        raise HTTPException(status_code=422, detail={
            "fr": f"pillar_code '{pillar_code}' introuvable dans mg.working_groups.",
            "en": f"pillar_code '{pillar_code}' not found in mg.working_groups.",
        })


# ── Objectifs strategiques ──────────────────────────────────────────────────────

class ObjectiveCreate(BaseModel):
    pillar_code: str
    country_iso3: Optional[str] = Field(None, min_length=3, max_length=3)
    label_fr: str
    label_en: str
    description_fr: Optional[str] = None
    description_en: Optional[str] = None


@router.post("/objectives", summary="Créer un objectif stratégique")
def create_objective(
    data: ObjectiveCreate,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    affiliate_id = int(payload["sub"])
    _validate_pillar_code(db, data.pillar_code)

    row = db.execute(
        text("""
            INSERT INTO mg.strategic_objectives
                (pillar_code, country_iso3, label_fr, label_en, description_fr, description_en, created_by)
            VALUES
                (:pillar_code, :country_iso3, :label_fr, :label_en, :description_fr, :description_en, :created_by)
            RETURNING id, pillar_code, country_iso3, label_fr, label_en, description_fr,
                      description_en, status, created_by, created_at::text
        """),
        {
            "pillar_code": data.pillar_code,
            "country_iso3": data.country_iso3.upper() if data.country_iso3 else None,
            "label_fr": data.label_fr,
            "label_en": data.label_en,
            "description_fr": data.description_fr,
            "description_en": data.description_en,
            "created_by": affiliate_id,
        },
    ).mappings().first()
    db.commit()
    return dict(row)


@router.get("/objectives", summary="Lister les objectifs stratégiques")
def list_objectives(
    pillar_code: Optional[str] = Query(default=None),
    country_iso3: Optional[str] = Query(default=None),
    status: Optional[str] = Query(default=None),
    db: Session = Depends(get_db),
):
    sql = """
        SELECT id, pillar_code, country_iso3, label_fr, label_en, description_fr,
               description_en, status, created_by, created_at::text
        FROM mg.strategic_objectives WHERE 1=1
    """
    params: dict = {}
    if pillar_code:
        sql += " AND pillar_code = :pillar_code"
        params["pillar_code"] = pillar_code
    if country_iso3:
        sql += " AND country_iso3 = :country_iso3"
        params["country_iso3"] = country_iso3.upper()
    if status:
        sql += " AND status = :status"
        params["status"] = status
    sql += " ORDER BY created_at DESC"

    rows = db.execute(text(sql), params).mappings().all()
    return {"count": len(rows), "items": [dict(r) for r in rows]}


@router.get("/objectives/{objective_id}", summary="Consulter un objectif stratégique")
def get_objective(objective_id: int, db: Session = Depends(get_db)):
    row = db.execute(
        text("""
            SELECT id, pillar_code, country_iso3, label_fr, label_en, description_fr,
                   description_en, status, created_by, created_at::text
            FROM mg.strategic_objectives WHERE id = :id
        """),
        {"id": objective_id},
    ).mappings().first()
    if not row:
        raise HTTPException(status_code=404, detail={"fr": "Objectif introuvable.", "en": "Objective not found."})
    return dict(row)


# ── Liaison levier -> objectif ────────────────────────────────────────────────────

class LeverObjectiveCreate(BaseModel):
    objective_id: int
    relevance_weight: float = Field(..., ge=0, le=1)


@router.post(
    "/levers/{lever_code}/objectives",
    summary="Lier un levier stratégique à un objectif",
)
def link_lever_objective(
    lever_code: str,
    data: LeverObjectiveCreate,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    lever = db.execute(
        text("SELECT lever_code FROM mg.strategic_levers WHERE lever_code = :code"),
        {"code": lever_code},
    ).mappings().first()
    if not lever:
        raise HTTPException(status_code=404, detail={"fr": "Levier introuvable.", "en": "Lever not found."})

    objective = db.execute(
        text("SELECT id FROM mg.strategic_objectives WHERE id = :id"),
        {"id": data.objective_id},
    ).mappings().first()
    if not objective:
        raise HTTPException(status_code=422, detail={
            "fr": f"objective_id {data.objective_id} introuvable dans mg.strategic_objectives.",
            "en": f"objective_id {data.objective_id} not found in mg.strategic_objectives.",
        })

    try:
        row = db.execute(
            text("""
                INSERT INTO mg.lever_objectives (lever_code, objective_id, relevance_weight)
                VALUES (:lever_code, :objective_id, :relevance_weight)
                RETURNING lever_code, objective_id, relevance_weight, created_at::text
            """),
            {"lever_code": lever_code, "objective_id": data.objective_id, "relevance_weight": data.relevance_weight},
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
    "/levers/{lever_code}/objectives",
    summary="Lister les objectifs liés à un levier",
)
def list_lever_objectives(lever_code: str, db: Session = Depends(get_db)):
    rows = db.execute(
        text("""
            SELECT lo.lever_code, lo.objective_id, lo.relevance_weight, lo.created_at::text,
                   so.label_fr, so.label_en
            FROM mg.lever_objectives lo
            JOIN mg.strategic_objectives so ON so.id = lo.objective_id
            WHERE lo.lever_code = :lever_code
            ORDER BY lo.relevance_weight DESC
        """),
        {"lever_code": lever_code},
    ).mappings().all()
    return {"count": len(rows), "items": [dict(r) for r in rows]}
