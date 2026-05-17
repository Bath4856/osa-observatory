-- ============================================================
-- OSA / ISA — P7I-AMAR Alert Refresh
-- Persists AMAR alerts into mg.early_warning_alerts.
-- ============================================================

BEGIN;

INSERT INTO mg.early_warning_alerts (
    country_iso3,
    year,
    risk_code,
    risk_band,
    risk_score,
    confidence_score,
    source_engine,
    public_narrative,
    created_at,
    updated_at
)
SELECT
    country_iso3,
    year,
    risk_code,
    risk_band,
    risk_score,
    confidence_score,
    'P7I-AMAR' AS source_engine,
    public_narrative,
    NOW(),
    NOW()
FROM ma.v_p7i_amar_dashboard
ON CONFLICT (country_iso3, year, risk_code, source_engine)
DO UPDATE SET
    risk_band = EXCLUDED.risk_band,
    risk_score = EXCLUDED.risk_score,
    confidence_score = EXCLUDED.confidence_score,
    public_narrative = EXCLUDED.public_narrative,
    updated_at = NOW();

COMMIT;
