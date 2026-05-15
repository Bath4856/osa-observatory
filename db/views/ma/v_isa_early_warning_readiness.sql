/* P7I readiness by pillar and alert level */
CREATE OR REPLACE VIEW ma.v_isa_early_warning_readiness AS
SELECT
    pillar_code,
    sovereign_alert_level,
    COUNT(*)::INT AS nb_warning_rows,
    COUNT(DISTINCT country_iso3)::INT AS nb_countries,
    COUNT(DISTINCT year)::INT AS nb_years,
    ROUND(AVG(early_warning_score), 3)::NUMERIC(6,3) AS avg_early_warning_score,
    ROUND(AVG(early_warning_confidence), 3)::NUMERIC(6,3) AS avg_early_warning_confidence,
    SUM(CASE WHEN early_warning_decision = 'WARNING_REQUIRES_STRATEGIC_REVIEW' THEN 1 ELSE 0 END)::INT AS nb_strategic_review,
    SUM(CASE WHEN early_warning_decision = 'WARNING_LOW_CONFIDENCE_CONTEXTUAL' THEN 1 ELSE 0 END)::INT AS nb_low_confidence,
    SUM(CASE WHEN forecast_blocking_reason = 'VOLATILITY_WARNING' THEN 1 ELSE 0 END)::INT AS nb_volatility_warning,
    CASE
        WHEN AVG(early_warning_confidence) < 0.350 THEN 'P7I_WARNING_CONTEXTUAL_LOW_CONFIDENCE'
        WHEN SUM(CASE WHEN sovereign_alert_level = 'RED' THEN 1 ELSE 0 END) > 0 THEN 'P7I_WARNING_CRITICAL_PRESENT'
        WHEN SUM(CASE WHEN sovereign_alert_level = 'ORANGE' THEN 1 ELSE 0 END) > 0 THEN 'P7I_WARNING_HIGH_PRESENT'
        WHEN SUM(CASE WHEN sovereign_alert_level = 'YELLOW' THEN 1 ELSE 0 END) > 0 THEN 'P7I_WARNING_MODERATE_PRESENT'
        ELSE 'P7I_WARNING_GREEN_MONITORING'
    END::TEXT AS p7i_warning_readiness_status
FROM ma.v_isa_early_warning_engine
GROUP BY pillar_code, sovereign_alert_level;
