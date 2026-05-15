/* P7I fragility warnings: combined fragility + alert state */
CREATE OR REPLACE VIEW ma.v_isa_fragility_warning_engine AS
SELECT
    e.country_iso3,
    e.year,
    e.pillar_code,
    e.sovereign_alert_level,
    e.early_warning_class,
    e.forecast_blocking_reason,
    e.strategic_diagnostic_role,
    ROUND(e.fragility_warning_score, 3)::NUMERIC(6,3) AS fragility_warning_score,
    ROUND(e.stress_propagation_score, 3)::NUMERIC(6,3) AS stress_propagation_score,
    ROUND(e.early_warning_score, 3)::NUMERIC(6,3) AS early_warning_score,
    ROUND(e.early_warning_confidence, 3)::NUMERIC(6,3) AS early_warning_confidence,
    CASE
        WHEN e.sovereign_alert_level = 'RED' OR e.fragility_warning_score >= 0.750 THEN 'FRAGILITY_CRITICAL'
        WHEN e.sovereign_alert_level = 'ORANGE' OR e.fragility_warning_score >= 0.550 THEN 'FRAGILITY_HIGH'
        WHEN e.sovereign_alert_level = 'YELLOW' OR e.fragility_warning_score >= 0.350 THEN 'FRAGILITY_MODERATE'
        ELSE 'FRAGILITY_LOW'
    END::TEXT AS fragility_warning_class,
    CASE
        WHEN e.forecast_blocking_reason = 'LOW_CONFIDENCE' THEN 'IMPROVE_EVIDENCE_AND_SOURCE_CONFIDENCE'
        WHEN e.forecast_blocking_reason = 'VOLATILITY_WARNING' THEN 'MONITOR_VOLATILITY_AND_STRESS_PROPAGATION'
        WHEN e.sovereign_alert_level IN ('RED','ORANGE') THEN 'PRIORITIZE_MITIGATION_AND_EXPERT_REVIEW'
        ELSE 'CONTINUE_OBSERVATORY_MONITORING'
    END::TEXT AS fragility_recommended_action
FROM ma.v_isa_early_warning_engine e;
