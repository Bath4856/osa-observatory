"""
OSA ISA Public API — AMAR Trigger Engine router
Covers: pub.amar_triggers / pub.v_amar_trigger_log

Taxonomy (4 classes, Option B — GAF finding_id=23):
  TRIGGER_EXCEPTIONAL           — THR >= 0.40 (independent of WKN)
  TRIGGER_CRITICAL              — THR >= 0.20, WKN >= 0.70, conf > 0
  TRIGGER_ACTIVE                — THR >= 0.20 (other cases)
  TRIGGER_DIAGNOSTIC_INCOMPLETE — THR in [0.20, 0.40[, WKN absent or conf = 0
"""

from typing import Optional, List
from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text
from pydantic import BaseModel, Field

from api.db import get_db

router = APIRouter(
    prefix="/api/v2/amar",
    tags=["AMAR Trigger Engine"],
)

# ── Schemas ───────────────────────────────────────────────────────────────────

class AmarTrigger(BaseModel):
    country_iso3: str = Field(description="ISO 3166-1 alpha-3 country code.")
    year: int
    pillar_code: str = Field(description="OSA pillar code (e.g. PMIN, PENV).")
    trigger_class: str = Field(
        description=(
            "Trigger classification: TRIGGER_EXCEPTIONAL | TRIGGER_CRITICAL | "
            "TRIGGER_ACTIVE | TRIGGER_DIAGNOSTIC_INCOMPLETE."
        )
    )
    severity_rank: int = Field(description="Severity rank: 1 (highest) to 4.")
    trigger_label: str = Field(description="Human-readable trigger label.")
    thr_score: float = Field(description="Threat score at trigger time (0–1).")
    wkn_score: Optional[float] = Field(
        default=None,
        description="Structural weakness score at trigger time (0–1). Null if data unavailable."
    )
    wkn_confidence: Optional[float] = Field(
        default=None,
        description="Structural weakness confidence (0–1)."
    )
    wkn_missing: bool = Field(
        description=(
            "True if structural weakness data was unavailable at trigger time. "
            "A TRIGGER_EXCEPTIONAL may have wkn_missing=true — "
            "the signal remains valid; incompleteness is published as a data quality attribute."
        )
    )
    data_quality_note: Optional[str] = Field(
        default=None,
        description="Data quality note when structural context is incomplete or low-confidence."
    )
    publication_status: Optional[str] = Field(
        default=None,
        description="Publication status for this year: OFFICIAL | PRELIMINARY | COLLECTING."
    )
    methodology_note: str = Field(
        default=(
            "The AMAR Trigger Engine detects exceptional threat signals that bypass "
            "the aggregate Strategic Risk Score. A trigger indicates an analytically "
            "significant threat signal requiring human review. "
            "It does not constitute a legal qualification of atrocity, conflict, "
            "or criminal responsibility."
        )
    )


# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.get(
    "/triggers",
    response_model=List[AmarTrigger],
    summary="AMAR Trigger Engine — all triggers",
    description=(
        "Returns all AMAR Trigger Engine activations across 54 African countries "
        "and 10 sovereign pillars (backfill 2020–2024, updated annually). "
        "A trigger is activated when the pillar-level threat score (THR) exceeds the "
        "operational threshold (0.20), regardless of the aggregate Strategic Risk Score. "
        "Four classes: TRIGGER_EXCEPTIONAL (THR ≥ 0.40), TRIGGER_CRITICAL, "
        "TRIGGER_ACTIVE, TRIGGER_DIAGNOSTIC_INCOMPLETE. "
        "Reference: GAF-AMAR-TRIGGER-002 (ops.audit_findings finding_id=23)."
    ),
)
def get_triggers(
    year: Optional[int] = Query(
        None,
        description="Filter by year (2020–2024).",
        ge=2020, le=2030
    ),
    country: Optional[str] = Query(
        None,
        description="Filter by ISO3 country code (e.g. SDN, COD).",
        min_length=3, max_length=3
    ),
    pillar: Optional[str] = Query(
        None,
        description="Filter by pillar code (e.g. PMIN, PENV, PMIL).",
        max_length=10
    ),
    trigger_class: Optional[str] = Query(
        None,
        description=(
            "Filter by trigger class: TRIGGER_EXCEPTIONAL, TRIGGER_CRITICAL, "
            "TRIGGER_ACTIVE, TRIGGER_DIAGNOSTIC_INCOMPLETE."
        ),
        alias="class"
    ),
    limit: int = Query(200, ge=1, le=1000),
    db: Session = Depends(get_db),
):
    filters = []
    params: dict = {"limit": limit}

    if year:
        filters.append("t.year = :year")
        params["year"] = year
    if country:
        filters.append("t.country_iso3 = :country")
        params["country"] = country.upper()
    if pillar:
        filters.append("t.pillar_code = :pillar")
        params["pillar"] = pillar.upper()
    if trigger_class:
        filters.append("t.trigger_class = :trigger_class")
        params["trigger_class"] = trigger_class.upper()

    where = ("WHERE " + " AND ".join(filters)) if filters else ""

    sql = text(f"""
        SELECT
            t.country_iso3,
            t.year,
            t.pillar_code,
            t.trigger_class,
            CASE t.trigger_class
                WHEN 'TRIGGER_EXCEPTIONAL'           THEN 1
                WHEN 'TRIGGER_CRITICAL'              THEN 2
                WHEN 'TRIGGER_ACTIVE'                THEN 3
                WHEN 'TRIGGER_DIAGNOSTIC_INCOMPLETE' THEN 4
            END                                         AS severity_rank,
            CASE t.trigger_class
                WHEN 'TRIGGER_EXCEPTIONAL'
                    THEN 'Exceptional threat signal — immediate review required'
                WHEN 'TRIGGER_CRITICAL'
                    THEN 'Critical threat — confirmed structural vulnerability'
                WHEN 'TRIGGER_ACTIVE'
                    THEN 'Active threat signal — analytical review recommended'
                WHEN 'TRIGGER_DIAGNOSTIC_INCOMPLETE'
                    THEN 'Active signal — structural data incomplete'
            END                                         AS trigger_label,
            t.thr_score,
            t.wkn_score,
            t.wkn_confidence,
            t.wkn_missing,
            CASE
                WHEN t.wkn_missing
                    THEN 'Structural context unavailable — classification based on threat signal only'
                WHEN t.wkn_confidence < 0.50
                    THEN 'Low structural confidence (conf=' || ROUND(t.wkn_confidence, 3)::TEXT || ')'
                ELSE NULL
            END                                         AS data_quality_note,
            pp.status                                   AS publication_status
        FROM pub.amar_triggers t
        LEFT JOIN rf.publication_policy pp ON pp.year = t.year
        {where}
        ORDER BY t.year DESC, severity_rank ASC, t.thr_score DESC
        LIMIT :limit
    """)

    rows = db.execute(sql, params).mappings().all()
    return [dict(r) for r in rows]


@router.get(
    "/triggers/{iso3}",
    response_model=List[AmarTrigger],
    summary="AMAR Trigger Engine — single country",
    description=(
        "Returns all AMAR Trigger Engine activations for a single country "
        "across all available years (2020–2024). "
        "Returns 404 if no trigger has ever been activated for this country."
    ),
)
def get_triggers_country(
    iso3: str,
    db: Session = Depends(get_db),
):
    iso3 = iso3.upper()

    rows = db.execute(
        text("""
            SELECT
                t.country_iso3,
                t.year,
                t.pillar_code,
                t.trigger_class,
                CASE t.trigger_class
                    WHEN 'TRIGGER_EXCEPTIONAL'           THEN 1
                    WHEN 'TRIGGER_CRITICAL'              THEN 2
                    WHEN 'TRIGGER_ACTIVE'                THEN 3
                    WHEN 'TRIGGER_DIAGNOSTIC_INCOMPLETE' THEN 4
                END                                         AS severity_rank,
                CASE t.trigger_class
                    WHEN 'TRIGGER_EXCEPTIONAL'
                        THEN 'Exceptional threat signal — immediate review required'
                    WHEN 'TRIGGER_CRITICAL'
                        THEN 'Critical threat — confirmed structural vulnerability'
                    WHEN 'TRIGGER_ACTIVE'
                        THEN 'Active threat signal — analytical review recommended'
                    WHEN 'TRIGGER_DIAGNOSTIC_INCOMPLETE'
                        THEN 'Active signal — structural data incomplete'
                END                                         AS trigger_label,
                t.thr_score,
                t.wkn_score,
                t.wkn_confidence,
                t.wkn_missing,
                CASE
                    WHEN t.wkn_missing
                        THEN 'Structural context unavailable — classification based on threat signal only'
                    WHEN t.wkn_confidence < 0.50
                        THEN 'Low structural confidence (conf=' || ROUND(t.wkn_confidence, 3)::TEXT || ')'
                    ELSE NULL
                END                                         AS data_quality_note,
                pp.status                                   AS publication_status
            FROM pub.amar_triggers t
            LEFT JOIN rf.publication_policy pp ON pp.year = t.year
            WHERE t.country_iso3 = :iso3
            ORDER BY t.year DESC, severity_rank ASC, t.thr_score DESC
        """),
        {"iso3": iso3},
    ).mappings().all()

    if not rows:
        raise HTTPException(
            status_code=404,
            detail=f"No AMAR trigger found for {iso3}. "
                   f"This country has not exceeded the operational THR threshold (0.20) "
                   f"on any pillar between 2020 and 2024."
        )
    return [dict(r) for r in rows]
