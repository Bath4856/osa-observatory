"""
OSA Observatory -- OIM, Lot 4
api/routers/oim_requirements.py

Exigences de transformation (mg.transformation_requirements) -- pont
entre OIM (chemin interne, via un objectif strategique) et OSOA
(chemin externe, via une opportunite). Aucun endpoint n'existait
avant ce soir pour creer une exigence, quel que soit le chemin --
jusqu'ici teste uniquement en SQL direct (session du 17-18 juillet).
"""
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import text
from pydantic import BaseModel, Field, model_validator

from api.db import get_db
from api.routers.auth_affiliates import get_current_affiliate

router = APIRouter(
    prefix="/api/v2/oim",
    tags=["OIM - Exigences de transformation"],
)


class RequirementCreate(BaseModel):
    origin_type: str = Field(..., description="INTERNAL ou EXTERNAL")
    objective_id: Optional[int] = None
    opportunity_id: Optional[int] = None
    label_fr: str
    label_en: str
    description_fr: Optional[str] = None
    description_en: Optional[str] = None

    @model_validator(mode="after")
    def _check_origin(self):
        if self.origin_type not in ("INTERNAL", "EXTERNAL"):
            raise ValueError("origin_type doit être INTERNAL ou EXTERNAL")
        if self.origin_type == "INTERNAL":
            if not self.objective_id or self.opportunity_id:
                raise ValueError("origin_type=INTERNAL exige objective_id et exclut opportunity_id")
        else:
            if not self.opportunity_id or self.objective_id:
                raise ValueError("origin_type=EXTERNAL exige opportunity_id et exclut objective_id")
        return self


@router.post(
    "/requirements",
    summary="Créer une exigence de transformation (chemin interne OIM ou externe OSOA)",
)
def create_requirement(
    data: RequirementCreate,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    affiliate_id = int(payload["sub"])

    if data.origin_type == "INTERNAL":
        obj = db.execute(
            text("SELECT id FROM mg.strategic_objectives WHERE id = :id"),
            {"id": data.objective_id},
        ).mappings().first()
        if not obj:
            raise HTTPException(status_code=422, detail={
                "fr": f"objective_id {data.objective_id} introuvable dans mg.strategic_objectives.",
                "en": f"objective_id {data.objective_id} not found in mg.strategic_objectives.",
            })
    else:
        opp = db.execute(
            text("SELECT id FROM osoa.opportunities WHERE id = :id"),
            {"id": data.opportunity_id},
        ).mappings().first()
        if not opp:
            raise HTTPException(status_code=422, detail={
                "fr": f"opportunity_id {data.opportunity_id} introuvable dans osoa.opportunities.",
                "en": f"opportunity_id {data.opportunity_id} not found in osoa.opportunities.",
            })

    row = db.execute(
        text("""
            INSERT INTO mg.transformation_requirements
                (origin_type, objective_id, opportunity_id, label_fr, label_en,
                 description_fr, description_en, created_by)
            VALUES
                (:origin_type, :objective_id, :opportunity_id, :label_fr, :label_en,
                 :description_fr, :description_en, :created_by)
            RETURNING id, origin_type, objective_id, opportunity_id, label_fr, label_en,
                      description_fr, description_en, status, created_by, created_at::text
        """),
        {
            "origin_type": data.origin_type,
            "objective_id": data.objective_id,
            "opportunity_id": data.opportunity_id,
            "label_fr": data.label_fr,
            "label_en": data.label_en,
            "description_fr": data.description_fr,
            "description_en": data.description_en,
            "created_by": affiliate_id,
        },
    ).mappings().first()
    db.commit()
    return dict(row)


@router.get("/requirements", summary="Lister les exigences de transformation")
def list_requirements(
    origin_type: Optional[str] = Query(default=None),
    status: Optional[str] = Query(default=None),
    db: Session = Depends(get_db),
):
    sql = """
        SELECT id, origin_type, objective_id, opportunity_id, label_fr, label_en,
               description_fr, description_en, status, created_by, created_at::text
        FROM mg.transformation_requirements WHERE 1=1
    """
    params: dict = {}
    if origin_type:
        sql += " AND origin_type = :origin_type"
        params["origin_type"] = origin_type
    if status:
        sql += " AND status = :status"
        params["status"] = status
    sql += " ORDER BY created_at DESC"

    rows = db.execute(text(sql), params).mappings().all()
    return {"count": len(rows), "items": [dict(r) for r in rows]}


@router.get("/requirements/{requirement_id}", summary="Consulter une exigence de transformation")
def get_requirement(requirement_id: int, db: Session = Depends(get_db)):
    row = db.execute(
        text("""
            SELECT id, origin_type, objective_id, opportunity_id, label_fr, label_en,
                   description_fr, description_en, status, created_by, created_at::text
            FROM mg.transformation_requirements WHERE id = :id
        """),
        {"id": requirement_id},
    ).mappings().first()
    if not row:
        raise HTTPException(status_code=404, detail={"fr": "Exigence introuvable.", "en": "Requirement not found."})
    return dict(row)
