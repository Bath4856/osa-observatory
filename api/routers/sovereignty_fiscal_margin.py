"""
OSA ISA Public API — Sovereignty Fiscal Margin router
Sprint 9D — Mai 2026

Endpoints :
  GET /api/v2/sovereignty/fiscal-margin          — marge souveraine tous pays
  GET /api/v2/sovereignty/fiscal-margin/{iso3}   — marge souveraine pays unique

Indicateur : GEO_SOVEREIGN_MARGIN (COMPUTED L3, Doctrine OSA v1)
Source     : ma.indicator_values WHERE indicator_code = 'GEO_SOVEREIGN_MARGIN'
Access     : PUBLIC

Doctrine OSA v1 :
  GEO_SOVEREIGN_MARGIN est un signal d'opportunité souveraine — pas de défaillance.
  Un score élevé indique un potentiel de mobilisation fiscale non encore exploité.
  Publication : Fiscal Sovereign Margin — Mobilisable Revenue Gap.
  Jamais qualifié de capture institutionnelle ou de corruption.
"""
from typing import Optional, List
from fastapi import APIRouter, Depends, Query, Path
from sqlalchemy.orm import Session
from sqlalchemy import text
from pydantic import BaseModel, Field
from api.db import get_db

router = APIRouter(
    prefix="/api/v2/sovereignty",
    tags=["Sovereignty"],
)

class FiscalMarginItem(BaseModel):
    country_iso3:        str             = Field(..., description="Code ISO3 pays OSA (3 lettres)")
    year:                int             = Field(..., description="Année de référence")
    fiscal_margin_score: Optional[float] = Field(None, description="Marge de souveraineté fiscale mobilisable (0–1). Score élevé = grand potentiel souverain.")
    confidence_score:    Optional[float] = Field(None, description="Indice de confiance (0–1)")
    value_status:        Optional[str]   = Field(None, description="Statut de la valeur (OBSERVED, IMPUTED, COMPUTED)")
    doctrine_note:       str             = Field(
        default="Signal d'opportunité souveraine — Fiscal Sovereign Margin. "
                "Score élevé = potentiel de mobilisation fiscale non encore exploité. "
                "Doctrine OSA v1.",
        description="Note doctrinale OSA v1"
    )

@router.get(
    "/fiscal-margin",
    summary="Marge de souveraineté fiscale — tous pays (Doctrine OSA v1)",
    description=(
        "Retourne la marge de souveraineté fiscale mobilisable (GEO_SOVEREIGN_MARGIN) "
        "pour tous les pays africains OSA. "
        "Calculé comme l'inverse de l'écart fiscal normalisé (1 − ECO_PUBLIC_LEAKAGE). "
        "Un score élevé indique un potentiel de mobilisation fiscale domestique "
        "non encore exploité. "
        "Doctrine OSA v1 : signal d'opportunité souveraine — pas de défaillance. "
        "Source : ma.indicator_values WHERE indicator_code = 'GEO_SOVEREIGN_MARGIN'."
    ),
    response_model=List[FiscalMarginItem]
)
def list_fiscal_margin(
    year:   Optional[int] = Query(None, ge=2010, le=2030, description="Filtrer par année (ex: 2024)"),
    limit:  int           = Query(810, ge=1, le=5000, description="Nombre max de résultats"),
    db:     Session       = Depends(get_db),
):
    sql = """
        SELECT
            iv.country_iso3,
            iv.year,
            ROUND(iv.processed_value::numeric, 4)  AS fiscal_margin_score,
            ROUND(iv.confidence_score::numeric, 4)  AS confidence_score,
            iv.value_status
        FROM ma.indicator_values iv
        WHERE iv.indicator_code = 'GEO_SOVEREIGN_MARGIN'
          AND iv.layer_id = 3
          AND iv.processed_value IS NOT NULL
          :where_year
        ORDER BY iv.year DESC, iv.processed_value DESC
        LIMIT :limit
    """
    where_year = "AND iv.year = :year" if year else ""
    sql = sql.replace(":where_year", where_year)

    params = {"limit": limit}
    if year:
        params["year"] = year

    rows = db.execute(text(sql), params).fetchall()
    return [
        FiscalMarginItem(
            country_iso3=r.country_iso3,
            year=r.year,
            fiscal_margin_score=r.fiscal_margin_score,
            confidence_score=r.confidence_score,
            value_status=r.value_status,
        )
        for r in rows
    ]


@router.get(
    "/fiscal-margin/{iso3}",
    summary="Marge de souveraineté fiscale — pays unique (Doctrine OSA v1)",
    description=(
        "Retourne la série temporelle de la marge de souveraineté fiscale "
        "(GEO_SOVEREIGN_MARGIN) pour un pays africain OSA. "
        "Doctrine OSA v1 : signal d'opportunité souveraine."
    ),
    response_model=List[FiscalMarginItem]
)
def get_fiscal_margin_by_country(
    iso3: str = Path(..., min_length=3, max_length=3, description="Code ISO3 pays (ex: NGA)"),
    year: Optional[int] = Query(None, ge=2010, le=2030, description="Filtrer par année"),
    db:   Session = Depends(get_db),
):
    sql = """
        SELECT
            iv.country_iso3,
            iv.year,
            ROUND(iv.processed_value::numeric, 4)  AS fiscal_margin_score,
            ROUND(iv.confidence_score::numeric, 4)  AS confidence_score,
            iv.value_status
        FROM ma.indicator_values iv
        WHERE iv.indicator_code = 'GEO_SOVEREIGN_MARGIN'
          AND iv.layer_id = 3
          AND iv.country_iso3 = :iso3
          AND iv.processed_value IS NOT NULL
          :where_year
        ORDER BY iv.year DESC
    """
    where_year = "AND iv.year = :year" if year else ""
    sql = sql.replace(":where_year", where_year)

    params = {"iso3": iso3.upper()}
    if year:
        params["year"] = year

    rows = db.execute(text(sql), params).fetchall()
    return [
        FiscalMarginItem(
            country_iso3=r.country_iso3,
            year=r.year,
            fiscal_margin_score=r.fiscal_margin_score,
            confidence_score=r.confidence_score,
            value_status=r.value_status,
        )
        for r in rows
    ]
