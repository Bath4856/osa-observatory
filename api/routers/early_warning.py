"""
OSA ISA Public API — Early Warning router
Covers: P7I-AMAR (Civilian Protection Risk) and P7I-AMAR-GENECO (Conflict Economy Exposure).

Views consumed:
  ma.v_p7i_amar_dashboard            — AMAR atrocity precursor engine
  ma.v_p7i_amar_geneco_dashboard     — GENECO conflict economy exposure
  ma.v_p7i_amar_composite_dashboard  — AMAR + GENECO composite
  mg.v_public_p7i_amar_alerts        — persisted AMAR alerts (public)
  mg.v_public_p7i_amar_geneco_alerts — persisted GENECO alerts (public)
"""

from typing import Optional, List
from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text
from pydantic import BaseModel, Field

from api.db import get_db

router = APIRouter(
    prefix="/api/v2/early-warning",
    tags=["Early Warning & Conflict Risk"],
)

# ── Schemas ───────────────────────────────────────────────────────────────────

class AmarAlert(BaseModel):
    country_iso3: str = Field(description="ISO 3166-1 alpha-3 country code.")
    year: int
    risk_band: str = Field(description="Alert band: GREEN / YELLOW / ORANGE / RED / BLACK.")
    risk_score: float = Field(description="Civilian protection risk score (0–1).")
    confidence_score: float = Field(description="Data confidence score (0–1).")
    risk_interpretation: Optional[str] = None
    recommended_action: Optional[str] = None
    structural_fragility_score: Optional[float] = None
    conflict_escalation_score: Optional[float] = None
    governance_breakdown_score: Optional[float] = None
    humanitarian_stress_score: Optional[float] = None
    resource_conflict_score: Optional[float] = None
    information_polarization_score: Optional[float] = None
    methodology_note: str = Field(
        default=(
            "This indicator provides an early-warning signal for prevention purposes. "
            "It does not constitute a legal qualification of atrocity, genocide, "
            "or criminal responsibility."
        )
    )


class GenecoAlert(BaseModel):
    country_iso3: str = Field(description="ISO 3166-1 alpha-3 country code.")
    year: int
    risk_band: str = Field(description="Exposure band: GREEN / YELLOW / ORANGE / RED / BLACK.")
    risk_score: float = Field(description="Conflict-economy exposure score (0–1).")
    confidence_score: float = Field(description="Data confidence score (0–1).")
    risk_class: Optional[str] = None
    recommended_action: Optional[str] = None
    resource_capture_risk: Optional[float] = None
    logistics_enabling_risk: Optional[float] = None
    institutional_capture_risk: Optional[float] = None
    civilian_exploitation_risk: Optional[float] = None
    narrative_weaponization_risk: Optional[float] = None
    public_disclaimer: str = Field(
        default=(
            "Conflict-economy exposure signal. "
            "This is not legal attribution and not a genocide determination."
        )
    )


class CompositeAlert(BaseModel):
    country_iso3: str
    year: int
    atrocity_precursor_score: float
    geneco_exposure_score: float
    amar_composite_score: float
    amar_composite_confidence: float
    atrocity_risk_band: Optional[str] = None
    geneco_risk_band: Optional[str] = None
    amar_composite_band: str
    resource_capture_risk: Optional[float] = None
    logistics_enabling_risk: Optional[float] = None
    institutional_capture_risk: Optional[float] = None
    civilian_exploitation_risk: Optional[float] = None
    narrative_weaponization_risk: Optional[float] = None
    composite_recommended_action: Optional[str] = None
    methodology_note: str = Field(
        default=(
            "Composite early-warning signal combining civilian protection risk and "
            "conflict-economy exposure. For prevention purposes only. "
            "Does not constitute a legal qualification."
        )
    )


# ── AMAR endpoints ────────────────────────────────────────────────────────────

@router.get(
    "/civilian-protection",
    response_model=List[AmarAlert],
    summary="Civilian Protection Risk — all countries",
    description=(
        "Provides P7I-AMAR civilian protection risk scores for all 54 African countries. "
        "Aggregated by country and year, covering structural fragility, conflict escalation, "
        "governance breakdown, humanitarian stress, resource conflict, and information polarization. "
        "This is an early-warning signal for prevention purposes. "
        "It does not constitute a legal qualification of atrocity or genocide."
    ),
)
def get_amar_all(
    year: Optional[int] = Query(None, description="Filter by year (2010–2024)."),
    band: Optional[str] = Query(None, description="Filter by risk band: GREEN, YELLOW, ORANGE, RED, BLACK."),
    limit: int = Query(54, ge=1, le=500),
    db: Session = Depends(get_db),
):
    sql = """
        SELECT
            country_iso3, year, risk_band,
            risk_score, confidence_score,
            risk_interpretation, recommended_action,
            structural_fragility_score, conflict_escalation_score,
            governance_breakdown_score, humanitarian_stress_score,
            resource_conflict_score, information_polarization_score
        FROM ma.v_p7i_amar_dashboard
        WHERE 1=1
          {year_filter}
          {band_filter}
        ORDER BY year DESC, risk_score DESC
        LIMIT :limit
    """
    params = {"limit": limit}
    year_filter = "AND year = :year" if year else ""
    band_filter = "AND risk_band = :band" if band else ""
    if year:
        params["year"] = year
    if band:
        params["band"] = band.upper()

    rows = db.execute(
        text(sql.format(year_filter=year_filter, band_filter=band_filter)),
        params,
    ).mappings().all()

    return [dict(r) for r in rows]


@router.get(
    "/civilian-protection/{iso3}",
    response_model=List[AmarAlert],
    summary="Civilian Protection Risk — single country",
    description=(
        "Provides P7I-AMAR civilian protection risk scores for a single country "
        "across all available years (2010–2024)."
    ),
)
def get_amar_country(
    iso3: str,
    db: Session = Depends(get_db),
):
    iso3 = iso3.upper()
    rows = db.execute(
        text("""
            SELECT
                country_iso3, year, risk_band,
                risk_score, confidence_score,
                risk_interpretation, recommended_action,
                structural_fragility_score, conflict_escalation_score,
                governance_breakdown_score, humanitarian_stress_score,
                resource_conflict_score, information_polarization_score
            FROM ma.v_p7i_amar_dashboard
            WHERE country_iso3 = :iso3
            ORDER BY year DESC
        """),
        {"iso3": iso3},
    ).mappings().all()

    if not rows:
        raise HTTPException(status_code=404, detail=f"No AMAR data found for {iso3}.")
    return [dict(r) for r in rows]


# ── GENECO endpoints ──────────────────────────────────────────────────────────

@router.get(
    "/conflict-economy",
    response_model=List[GenecoAlert],
    summary="Conflict Economy Exposure — all countries",
    description=(
        "Provides P7I-AMAR-GENECO conflict-economy exposure scores for all 54 African countries. "
        "Covers resource capture risk, logistics enabling conditions, institutional capture, "
        "civilian exploitation, and narrative weaponization. "
        "This is a conflict-economy exposure signal for prevention and due-diligence purposes. "
        "It does not constitute legal attribution or a genocide determination."
    ),
)
def get_geneco_all(
    year: Optional[int] = Query(None, description="Filter by year (2010–2024)."),
    band: Optional[str] = Query(None, description="Filter by exposure band: GREEN, YELLOW, ORANGE, RED, BLACK."),
    limit: int = Query(54, ge=1, le=500),
    db: Session = Depends(get_db),
):
    params = {"limit": limit}
    year_filter = "AND year = :year" if year else ""
    band_filter = "AND risk_band = :band" if band else ""
    if year:
        params["year"] = year
    if band:
        params["band"] = band.upper()

    sql = """
        SELECT
            country_iso3, year, risk_band,
            risk_score, confidence_score, risk_class,
            recommended_action,
            resource_capture_risk, logistics_enabling_risk,
            institutional_capture_risk, civilian_exploitation_risk,
            narrative_weaponization_risk
        FROM ma.v_p7i_amar_geneco_dashboard
        WHERE 1=1
          {year_filter}
          {band_filter}
        ORDER BY year DESC, risk_score DESC
        LIMIT :limit
    """.format(year_filter=year_filter, band_filter=band_filter)

    rows = db.execute(text(sql), params).mappings().all()
    return [dict(r) for r in rows]


@router.get(
    "/conflict-economy/{iso3}",
    response_model=List[GenecoAlert],
    summary="Conflict Economy Exposure — single country",
    description=(
        "Provides P7I-AMAR-GENECO conflict-economy exposure scores for a single country "
        "across all available years (2010–2024)."
    ),
)
def get_geneco_country(
    iso3: str,
    db: Session = Depends(get_db),
):
    iso3 = iso3.upper()
    rows = db.execute(
        text("""
            SELECT
                country_iso3, year, risk_band,
                risk_score, confidence_score, risk_class,
                recommended_action,
                resource_capture_risk, logistics_enabling_risk,
                institutional_capture_risk, civilian_exploitation_risk,
                narrative_weaponization_risk
            FROM ma.v_p7i_amar_geneco_dashboard
            WHERE country_iso3 = :iso3
            ORDER BY year DESC
        """),
        {"iso3": iso3},
    ).mappings().all()

    if not rows:
        raise HTTPException(status_code=404, detail=f"No GENECO data found for {iso3}.")
    return [dict(r) for r in rows]


# ── Composite endpoint ────────────────────────────────────────────────────────

@router.get(
    "/composite",
    response_model=List[CompositeAlert],
    summary="Composite Early Warning — AMAR + GENECO",
    description=(
        "Provides the P7I-AMAR composite score combining civilian protection risk (70%) "
        "and conflict-economy exposure (30%) for all 54 African countries. "
        "Intended for integrated sovereign risk assessment. "
        "For prevention purposes only. Does not constitute a legal qualification."
    ),
)
def get_composite_all(
    year: Optional[int] = Query(None, description="Filter by year (2010–2024)."),
    band: Optional[str] = Query(None, description="Filter by composite band: GREEN, YELLOW, ORANGE, RED, BLACK."),
    limit: int = Query(54, ge=1, le=500),
    db: Session = Depends(get_db),
):
    params = {"limit": limit}
    year_filter = "AND year = :year" if year else ""
    band_filter = "AND amar_composite_band = :band" if band else ""
    if year:
        params["year"] = year
    if band:
        params["band"] = band.upper()

    sql = """
        SELECT
            country_iso3, year,
            atrocity_precursor_score, geneco_exposure_score,
            amar_composite_score, amar_composite_confidence,
            atrocity_risk_band, geneco_risk_band, amar_composite_band,
            resource_capture_risk, logistics_enabling_risk,
            institutional_capture_risk, civilian_exploitation_risk,
            narrative_weaponization_risk, composite_recommended_action
        FROM ma.v_p7i_amar_composite_dashboard
        WHERE 1=1
          {year_filter}
          {band_filter}
        ORDER BY year DESC, amar_composite_score DESC
        LIMIT :limit
    """.format(year_filter=year_filter, band_filter=band_filter)

    rows = db.execute(text(sql), params).mappings().all()
    return [dict(r) for r in rows]


@router.get(
    "/composite/{iso3}",
    response_model=List[CompositeAlert],
    summary="Composite Early Warning — single country",
    description=(
        "Provides the P7I-AMAR composite score for a single country "
        "across all available years (2010–2024)."
    ),
)
def get_composite_country(
    iso3: str,
    db: Session = Depends(get_db),
):
    iso3 = iso3.upper()
    rows = db.execute(
        text("""
            SELECT
                country_iso3, year,
                atrocity_precursor_score, geneco_exposure_score,
                amar_composite_score, amar_composite_confidence,
                atrocity_risk_band, geneco_risk_band, amar_composite_band,
                resource_capture_risk, logistics_enabling_risk,
                institutional_capture_risk, civilian_exploitation_risk,
                narrative_weaponization_risk, composite_recommended_action
            FROM ma.v_p7i_amar_composite_dashboard
            WHERE country_iso3 = :iso3
            ORDER BY year DESC
        """),
        {"iso3": iso3},
    ).mappings().all()

    if not rows:
        raise HTTPException(status_code=404, detail=f"No composite data found for {iso3}.")
    return [dict(r) for r in rows]
