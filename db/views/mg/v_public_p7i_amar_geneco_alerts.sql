-- ============================================================
-- OSA / ISA — Public P7I-AMAR-GENECO Alerts
-- Public-safe wording: exposure and prevention, no attribution.
-- ============================================================

CREATE OR REPLACE VIEW mg.v_public_p7i_amar_geneco_alerts AS
SELECT
    country_iso3,
    year,
    risk_code,
    risk_band,
    ROUND(risk_score, 3)::numeric(6,3) AS risk_score,
    ROUND(confidence_score, 3)::numeric(6,3) AS confidence_score,
    risk_class,
    recommended_action,
    'Conflict-economy exposure signal. This is not legal attribution and not a genocide determination.'::text AS public_disclaimer
FROM ma.v_p7i_amar_geneco_dashboard;
