"""
OSA Observatory -- OIM (Operational Intervention Model), Lot 1
api/routers/oim_diagnostic.py

Diagnostic par pilier (mg.pillar_5whys_analysis) et causes racines
(mg.pillar_root_causes) -- premier maillon de la chaine OIM, jamais
expose via API jusqu'ici (ADR-004 Phase 1, construit et teste
uniquement en SQL direct depuis plusieurs sessions).

country_iso3 nullable par conception (ADR-004) : NULL = portee
panafricaine, valeur = portee pays -- les deux sont legitimes.
"""
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import text
from pydantic import BaseModel, Field
import json

from api.db import get_db
from api.routers.auth_affiliates import get_current_affiliate

router = APIRouter(
    prefix="/api/v2/oim",
    tags=["OIM - Diagnostic"],
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


# ── Analyses 5 Pourquoi ────────────────────────────────────────────────────────

class AnalysisCreate(BaseModel):
    pillar_code: str
    country_iso3: Optional[str] = Field(None, min_length=3, max_length=3)
    version: int = Field(1, ge=1)
    content: dict
    status: str = Field("DRAFT", description="DRAFT, VALIDATED ou ARCHIVED")


@router.post(
    "/analyses",
    summary="Créer une analyse 5 Pourquoi pour un pilier",
    description="country_iso3 omis = portée panafricaine, renseigné = portée pays.",
)
def create_analysis(
    data: AnalysisCreate,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    affiliate_id = int(payload["sub"])
    _validate_pillar_code(db, data.pillar_code)
    if data.status not in ("DRAFT", "VALIDATED", "ARCHIVED"):
        raise HTTPException(status_code=422, detail={
            "fr": "status doit être DRAFT, VALIDATED ou ARCHIVED.",
            "en": "status must be DRAFT, VALIDATED or ARCHIVED.",
        })

    try:
        row = db.execute(
            text("""
                INSERT INTO mg.pillar_5whys_analysis
                    (pillar_code, country_iso3, version, content, status, created_by)
                VALUES
                    (:pillar_code, :country_iso3, :version, CAST(:content AS jsonb), :status, :created_by)
                RETURNING id, pillar_code, country_iso3, version, content, status,
                          created_by, created_at::text, updated_at::text
            """),
            {
                "pillar_code": data.pillar_code,
                "country_iso3": data.country_iso3.upper() if data.country_iso3 else None,
                "version": data.version,
                "content": json.dumps(data.content),
                "status": data.status,
                "created_by": affiliate_id,
            },
        ).mappings().first()
        db.commit()
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=409, detail={
            "fr": f"Erreur à la création (version déjà utilisée pour ce pilier/pays ?) : {e}",
            "en": f"Creation error (version already used for this pillar/country?): {e}",
        })

    return dict(row)


@router.get(
    "/analyses",
    summary="Lister les analyses 5 Pourquoi",
)
def list_analyses(
    pillar_code: Optional[str] = Query(default=None),
    country_iso3: Optional[str] = Query(default=None, description="Omettre pour inclure toutes les portées"),
    status: Optional[str] = Query(default=None),
    db: Session = Depends(get_db),
):
    sql = """
        SELECT id, pillar_code, country_iso3, version, content, status,
               created_by, created_at::text, updated_at::text
        FROM mg.pillar_5whys_analysis
        WHERE 1=1
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


@router.get("/analyses/{analysis_id}", summary="Consulter une analyse 5 Pourquoi")
def get_analysis(analysis_id: int, db: Session = Depends(get_db)):
    row = db.execute(
        text("""
            SELECT id, pillar_code, country_iso3, version, content, status,
                   created_by, created_at::text, updated_at::text
            FROM mg.pillar_5whys_analysis WHERE id = :id
        """),
        {"id": analysis_id},
    ).mappings().first()
    if not row:
        raise HTTPException(status_code=404, detail={"fr": "Analyse introuvable.", "en": "Analysis not found."})
    return dict(row)


# ── Causes racines ──────────────────────────────────────────────────────────────

class RootCauseCreate(BaseModel):
    cause_category_5m_code: str
    description_fr: str
    description_en: Optional[str] = None


@router.post(
    "/analyses/{analysis_id}/root-causes",
    summary="Ajouter une cause racine à une analyse 5 Pourquoi",
    description="pillar_code/country_iso3 hérités de l'analyse parente, jamais ressaisis.",
)
def create_root_cause(
    analysis_id: int,
    data: RootCauseCreate,
    payload: dict = Depends(get_current_affiliate),
    db: Session = Depends(get_db),
):
    affiliate_id = int(payload["sub"])

    analysis = db.execute(
        text("SELECT id, pillar_code, country_iso3 FROM mg.pillar_5whys_analysis WHERE id = :id"),
        {"id": analysis_id},
    ).mappings().first()
    if not analysis:
        raise HTTPException(status_code=404, detail={"fr": "Analyse introuvable.", "en": "Analysis not found."})

    cat = db.execute(
        text("SELECT code FROM rf.cause_category_5m WHERE code = :code"),
        {"code": data.cause_category_5m_code},
    ).mappings().first()
    if not cat:
        raise HTTPException(status_code=422, detail={
            "fr": f"cause_category_5m_code '{data.cause_category_5m_code}' introuvable dans rf.cause_category_5m.",
            "en": f"cause_category_5m_code '{data.cause_category_5m_code}' not found in rf.cause_category_5m.",
        })

    row = db.execute(
        text("""
            INSERT INTO mg.pillar_root_causes
                (analysis_id, pillar_code, country_iso3, cause_category_5m_code,
                 description_fr, description_en, created_by)
            VALUES
                (:analysis_id, :pillar_code, :country_iso3, :cause_category_5m_code,
                 :description_fr, :description_en, :created_by)
            RETURNING id, analysis_id, pillar_code, country_iso3, cause_category_5m_code,
                      description_fr, description_en, status, created_by, created_at::text
        """),
        {
            "analysis_id": analysis_id,
            "pillar_code": analysis["pillar_code"],
            "country_iso3": analysis["country_iso3"],
            "cause_category_5m_code": data.cause_category_5m_code,
            "description_fr": data.description_fr,
            "description_en": data.description_en,
            "created_by": affiliate_id,
        },
    ).mappings().first()
    db.commit()
    return dict(row)


@router.get(
    "/analyses/{analysis_id}/root-causes",
    summary="Lister les causes racines d'une analyse",
)
def list_root_causes(analysis_id: int, db: Session = Depends(get_db)):
    rows = db.execute(
        text("""
            SELECT id, analysis_id, pillar_code, country_iso3, cause_category_5m_code,
                   description_fr, description_en, status, created_by, created_at::text
            FROM mg.pillar_root_causes
            WHERE analysis_id = :analysis_id
            ORDER BY created_at
        """),
        {"analysis_id": analysis_id},
    ).mappings().all()
    return {"count": len(rows), "items": [dict(r) for r in rows]}
