-- ============================================================
-- OSA / ISA — Public P7I-AMAR Alerts View
-- P8-compatible public-safe view.
-- ============================================================

CREATE OR REPLACE VIEW mg.v_public_p7i_amar_alerts AS
SELECT
    country_iso3,
    year,
    risk_code,
    risk_band,
    ROUND(risk_score, 3)::numeric(6,3) AS risk_score,
    ROUND(confidence_score, 3)::numeric(6,3) AS confidence_score,
    source_engine,
    public_narrative,
    created_at,
    updated_at
FROM mg.early_warning_alerts
WHERE source_engine = 'P7I-AMAR'
  AND risk_code = 'ATROCITY_PRECURSOR';
