"""
OSA Observatory -- Sprint 15
Router E-participation -- Consultation souveraine africaine

Endpoints publics (Couche 0) :
  GET  /api/v1/consultation/topics              -- sujets ouverts
  GET  /api/v1/consultation/topics/{iso3}       -- sujets par pays
  GET  /api/v1/consultation/topics/type/{type}  -- sujets par type
  POST /api/v1/consultation/submit              -- soumettre une reponse

Endpoints affilies (Couche 1) :
  GET  /api/v1/consultation/queue               -- file prioritaire complete
  GET  /api/v1/consultation/queue/{iso3}        -- file par pays
  GET  /api/v1/consultation/priorities          -- agregat engagement par pays

Endpoints admin (Expert) :
  GET  /api/v1/consultation/admin/pending       -- reponses en attente moderation
  POST /api/v1/consultation/admin/moderate/{id} -- approuver ou rejeter
"""

import json
from fastapi import APIRouter, Depends, Query, HTTPException
from fastapi.responses import JSONResponse, Response
from pydantic import BaseModel
from sqlalchemy import text
from sqlalchemy.orm import Session
from typing import Optional
from api.db import get_db
from api.security import (
    validate_standard_access,
    validate_expert_access,
)

router = APIRouter(prefix="/api/v1/consultation", tags=["E-participation"])

_DISCLAIMER = (
    "OSA Observatory -- Observatoire de la Souverainete Africaine. "
    "Citizen contributions are moderated before publication. "
    "Scientific and doctrinal reviews feed the OSA Scientific Council agenda. "
    "open.osa-observatory.org/consult"
)

_VALID_TYPES = {
    "RISK_EVIDENCE_REVIEW",
    "OPPORTUNITY_EXPLORATION_FEEDBACK",
    "WEAKNESS_DIAGNOSTIC_REVIEW",
    "STRENGTH_REPLICATION_FEEDBACK",
    "GENERAL_OBSERVATORY_FEEDBACK",
    "SCIENTIFIC_FRAMEWORK_REVIEW",
    "DOCTRINE_REVIEW",
}

_VALID_POSITIONS = {"SUPPORT", "CHALLENGE", "NEUTRAL", "EVIDENCE"}


def _json(data) -> Response:
    return Response(
        content=json.dumps(data, ensure_ascii=False, default=str),
        media_type="application/json; charset=utf-8"
    )

def _rows(db: Session, sql: str, params: dict = None) -> list:
    result = db.execute(text(sql), params or {})
    return [dict(r) for r in result.mappings().all()]


# ── Schemas Pydantic ──────────────────────────────────────────
class ConsultationSubmit(BaseModel):
    country_iso3:       str
    year:               int
    pillar_code:        Optional[str] = None
    consultation_type:  str
    response_text:      str
    evidence_url:       Optional[str] = None
    position:           Optional[str] = None
    submitter_label:    Optional[str] = None
    is_anonymous:       bool = True


class ModerationDecision(BaseModel):
    decision:       str   # APPROVED ou REJECTED
    moderation_note: Optional[str] = None


# ── COUCHE 0 -- ENDPOINTS PUBLICS ─────────────────────────────

@router.get(
    "/topics",
    summary="Sujets de consultation ouverts -- 54 pays",
    description=(
        "Retourne les sujets de consultation souveraine ouverts. "
        "Inclut consultations scientifiques et doctrinales OSA. "
        "Acces libre -- Couche 0."
    ),
)
async def get_topics(
    db:           Session       = Depends(get_db),
    topic_type:   Optional[str] = Query(default=None, description="Type de consultation"),
    region:       Optional[str] = Query(default=None),
    priority:     Optional[int] = Query(default=None, description="Priorite 1=CRITICAL 2=HIGH 3=STANDARD"),
):
    data = _rows(db, """
        SELECT *
        FROM pub.v_isa_public_consultation_topics
        WHERE (:type     IS NULL OR consultation_type = :type)
          AND (:region   IS NULL OR region_code       = :region)
          AND (:priority IS NULL OR queue_priority    = :priority)
        ORDER BY queue_priority, country_iso3, pillar_code
    """, {
        "type":     topic_type.upper() if topic_type else None,
        "region":   region.upper()     if region     else None,
        "priority": priority,
    })
    return _json({
        "count":       len(data),
        "disclaimer":  _DISCLAIMER,
        "consultation_types": sorted(_VALID_TYPES),
        "data":        data,
    })


@router.get(
    "/topics/{iso3}",
    summary="Sujets de consultation -- un pays",
)
async def get_country_topics(iso3: str, db: Session = Depends(get_db)):
    data = _rows(db, """
        SELECT * FROM pub.v_isa_public_consultation_topics
        WHERE country_iso3 = :iso3
        ORDER BY queue_priority, pillar_code
    """, {"iso3": iso3.upper()})
    if not data:
        return JSONResponse(status_code=404,
            content={"error": f"Country {iso3.upper()} not found"})
    return _json({"country_iso3": iso3.upper(), "disclaimer": _DISCLAIMER, "data": data})


@router.get(
    "/topics/type/{consultation_type}",
    summary="Sujets par type de consultation",
    description=(
        "Types disponibles : RISK_EVIDENCE_REVIEW, OPPORTUNITY_EXPLORATION_FEEDBACK, "
        "WEAKNESS_DIAGNOSTIC_REVIEW, STRENGTH_REPLICATION_FEEDBACK, "
        "GENERAL_OBSERVATORY_FEEDBACK, SCIENTIFIC_FRAMEWORK_REVIEW, DOCTRINE_REVIEW"
    ),
)
async def get_topics_by_type(
    consultation_type: str,
    db: Session = Depends(get_db),
):
    ctype = consultation_type.upper()
    if ctype not in _VALID_TYPES:
        raise HTTPException(status_code=400,
            detail=f"Invalid consultation type. Valid types: {sorted(_VALID_TYPES)}")
    data = _rows(db, """
        SELECT * FROM pub.v_isa_public_consultation_topics
        WHERE consultation_type = :type
        ORDER BY queue_priority, country_iso3
    """, {"type": ctype})
    return _json({
        "consultation_type": ctype,
        "count":             len(data),
        "disclaimer":        _DISCLAIMER,
        "data":              data,
    })


@router.post(
    "/submit",
    summary="Soumettre une reponse de consultation",
    description=(
        "Soumet une reponse citoyenne ou institutionnelle. "
        "La reponse est en attente de moderation avant publication. "
        "Les retours SCIENTIFIC_FRAMEWORK_REVIEW et DOCTRINE_REVIEW "
        "alimentent l agenda du Conseil scientifique OSA."
    ),
)
async def submit_response(
    data: ConsultationSubmit,
    db:   Session = Depends(get_db),
):
    # Validation type
    if data.consultation_type not in _VALID_TYPES:
        raise HTTPException(status_code=400,
            detail=f"Invalid consultation_type. Valid: {sorted(_VALID_TYPES)}")
    if data.position and data.position.upper() not in _VALID_POSITIONS:
        raise HTTPException(status_code=400,
            detail=f"Invalid position. Valid: {sorted(_VALID_POSITIONS)}")
    if len(data.response_text.strip()) < 20:
        raise HTTPException(status_code=400,
            detail="response_text must be at least 20 characters")

    row = db.execute(text("""
        INSERT INTO mg.consultation_responses
            (country_iso3, year, pillar_code, consultation_type,
             response_text, evidence_url, position,
             submitter_label, is_anonymous,
             moderation_status, is_public)
        VALUES
            (:iso3, :year, :pillar, :ctype,
             :text, :url, :position,
             :label, :anon,
             'PENDING', FALSE)
        RETURNING response_id, created_at
    """), {
        "iso3":     data.country_iso3.upper(),
        "year":     data.year,
        "pillar":   data.pillar_code.upper() if data.pillar_code else None,
        "ctype":    data.consultation_type.upper(),
        "text":     data.response_text.strip(),
        "url":      data.evidence_url,
        "position": data.position.upper() if data.position else None,
        "label":    data.submitter_label if not data.is_anonymous else None,
        "anon":     data.is_anonymous,
    }).mappings().fetchone()
    db.commit()

    # Message specifique pour consultations scientifiques/doctrinales
    if data.consultation_type in ("SCIENTIFIC_FRAMEWORK_REVIEW", "DOCTRINE_REVIEW"):
        note = (
            "Your contribution will be reviewed by the OSA moderation team "
            "and submitted to the OSA Scientific Council agenda."
        )
    else:
        note = (
            "Your contribution will be reviewed by the OSA moderation team "
            "before publication."
        )

    return _json({
        "status":       "SUBMITTED",
        "response_id":  row["response_id"],
        "created_at":   str(row["created_at"]),
        "moderation":   "PENDING",
        "note":         note,
    })


# ── COUCHE 1 -- ENDPOINTS AFFILIÉS ───────────────────────────

@router.get(
    "/queue",
    summary="File de consultation prioritaire -- Couche 1",
    description="Retourne la file de consultation complete avec priorites P7J. Affilie standard requis.",
)
async def get_queue(
    db:     Session       = Depends(get_db),
    auth:   dict          = Depends(validate_standard_access),
    region: Optional[str] = Query(default=None),
    ctype:  Optional[str] = Query(default=None, alias="type"),
):
    data = _rows(db, """
        SELECT * FROM ma.v_isa_eparticipation_queue
        WHERE (:region IS NULL OR region_code        = :region)
          AND (:type   IS NULL OR consultation_type  = :type)
        ORDER BY queue_priority, intervention_priority_score DESC
    """, {
        "region": region.upper() if region else None,
        "type":   ctype.upper()  if ctype  else None,
    })
    return _json({
        "count":  len(data),
        "access": "Couche 1 -- Standard",
        "data":   data,
    })


@router.get(
    "/queue/{iso3}",
    summary="File de consultation -- un pays -- Couche 1",
)
async def get_country_queue(
    iso3: str,
    db:   Session = Depends(get_db),
    auth: dict    = Depends(validate_standard_access),
):
    data = _rows(db, """
        SELECT * FROM ma.v_isa_eparticipation_queue
        WHERE country_iso3 = :iso3
        ORDER BY queue_priority, intervention_priority_score DESC
    """, {"iso3": iso3.upper()})
    if not data:
        return JSONResponse(status_code=404,
            content={"error": f"Country {iso3.upper()} not found"})
    return _json({"country_iso3": iso3.upper(), "access": "Couche 1", "data": data})


@router.get(
    "/priorities",
    summary="Priorites engagement e-participation -- Couche 1",
)
async def get_priorities(
    db:     Session       = Depends(get_db),
    auth:   dict          = Depends(validate_standard_access),
    region: Optional[str] = Query(default=None),
):
    data = _rows(db, """
        SELECT * FROM ma.v_isa_eparticipation_priorities
        WHERE (:region IS NULL OR region_code = :region)
        ORDER BY nb_priority_critical DESC, total_consultations DESC
    """, {"region": region.upper() if region else None})
    return _json({
        "count":  len(data),
        "access": "Couche 1 -- Standard",
        "data":   data,
    })


# ── ADMIN -- ENDPOINTS EXPERT ─────────────────────────────────

@router.get(
    "/admin/pending",
    summary="Reponses en attente de moderation -- Expert",
)
async def get_pending(
    db:   Session = Depends(get_db),
    auth: dict    = Depends(validate_expert_access),
):
    data = _rows(db, """
        SELECT
            response_id, country_iso3, year, pillar_code,
            consultation_type, response_text, position,
            evidence_url, submitter_label, is_anonymous,
            created_at
        FROM mg.consultation_responses
        WHERE moderation_status = 'PENDING'
        ORDER BY created_at ASC
    """)
    return _json({"count": len(data), "access": "Expert", "data": data})


@router.post(
    "/admin/moderate/{response_id}",
    summary="Approuver ou rejeter une reponse -- Expert",
)
async def moderate_response(
    response_id: int,
    decision:    ModerationDecision,
    db:          Session = Depends(get_db),
    auth:        dict    = Depends(validate_expert_access),
):
    if decision.decision.upper() not in ("APPROVED", "REJECTED"):
        raise HTTPException(status_code=400,
            detail="decision must be APPROVED or REJECTED")

    is_public = decision.decision.upper() == "APPROVED"

    row = db.execute(text("""
        UPDATE mg.consultation_responses
        SET moderation_status = :decision,
            moderated_at      = NOW(),
            moderation_note   = :note,
            is_public         = :public,
            updated_at        = NOW()
        WHERE response_id = :id
        RETURNING response_id, country_iso3, consultation_type, moderation_status
    """), {
        "decision": decision.decision.upper(),
        "note":     decision.moderation_note,
        "public":   is_public,
        "id":       response_id,
    }).mappings().fetchone()
    db.commit()

    if not row:
        raise HTTPException(status_code=404,
            detail=f"Response {response_id} not found")

    return _json({
        "status":       "MODERATED",
        "response_id":  row["response_id"],
        "country_iso3": row["country_iso3"],
        "consultation_type": row["consultation_type"],
        "moderation_status": row["moderation_status"],
        "is_public":    is_public,
    })
