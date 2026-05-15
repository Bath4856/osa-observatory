/* P7I early-warning engine: GREEN/YELLOW/ORANGE/RED */
CREATE OR REPLACE VIEW ma.v_isa_early_warning_engine AS
WITH scored AS (
    SELECT
        s.*,
        COALESCE(w.systemic_weight, 1.000)::NUMERIC AS systemic_weight,
        COALESCE(w.fragility_weight, 1.000)::NUMERIC AS fragility_weight,
        COALESCE(w.propagation_weight, 1.000)::NUMERIC AS propagation_weight,
        LEAST(1.000, GREATEST(0.000,
            (
                0.22 * COALESCE(s.strategic_risk_score, 0) +
                0.18 * COALESCE(s.threat_score, 0) +
                0.14 * COALESCE(s.weakness_score, 0) +
                0.14 * COALESCE(s.vulnerability_observed_score, 0) +
                0.10 * (1 - COALESCE(s.resilience_observed_score, 0)) +
                0.08 * CASE WHEN s.forecast_blocking_reason = 'LOW_CONFIDENCE' THEN 1 ELSE 0 END +
                0.06 * CASE WHEN s.forecast_blocking_reason = 'VOLATILITY_WARNING' THEN 1 ELSE 0 END +
                0.08 * LEAST(1.000, GREATEST(0.000, ABS(LEAST(0, COALESCE(s.stress_isa_delta, 0))) * 8))
            ) * COALESCE(w.systemic_weight, 1.000)
        ))::NUMERIC AS sovereign_risk_score,
        LEAST(1.000, GREATEST(0.000,
            (
                0.30 * COALESCE(s.weakness_score, 0) +
                0.20 * COALESCE(s.threat_score, 0) +
                0.20 * (1 - COALESCE(s.resilience_observed_score, 0)) +
                0.15 * CASE WHEN s.forecast_blocking_reason IN ('LOW_CONFIDENCE','LOW_COMPLETENESS') THEN 1 ELSE 0 END +
                0.15 * COALESCE(s.diagnostic_priority_score, 0)
            ) * COALESCE(w.fragility_weight, 1.000)
        ))::NUMERIC AS fragility_warning_score,
        LEAST(1.000, GREATEST(0.000,
            (
                0.30 * CASE WHEN s.forecast_blocking_reason = 'VOLATILITY_WARNING' THEN 1 ELSE 0 END +
                0.25 * LEAST(1.000, ABS(COALESCE(s.isa_trend_slope, 0)) * 20) +
                0.20 * COALESCE(s.strategic_risk_score, 0) +
                0.15 * COALESCE(s.vulnerability_observed_score, 0) +
                0.10 * CASE WHEN s.stress_isa_delta < -0.04 THEN 1 ELSE 0 END
            ) * COALESCE(w.propagation_weight, 1.000)
        ))::NUMERIC AS stress_propagation_score
    FROM ma.v_p7i_risk_source s
    LEFT JOIN rf.isa_early_warning_pillar_weight w
      ON w.pillar_code = s.pillar_code
), final_score AS (
    SELECT
        *,
        LEAST(1.000, GREATEST(0.000,
            0.50 * sovereign_risk_score +
            0.30 * fragility_warning_score +
            0.20 * stress_propagation_score
        ))::NUMERIC AS early_warning_score,
        LEAST(1.000, GREATEST(0.000,
            0.40 * observation_confidence +
            0.25 * forecast_observation_confidence +
            0.25 * central_simulation_confidence +
            0.10 * COALESCE(data_completeness, 0)
        ))::NUMERIC AS early_warning_confidence
    FROM scored
)
SELECT
    f.country_iso3,
    f.year,
    f.pillar_code,
    f.publication_status,
    f.publication_decision,
    ROUND(f.isa_observed_score, 3)::NUMERIC(8,3) AS isa_observed_score,
    ROUND(f.sovereignty_observed_score, 3)::NUMERIC(8,3) AS sovereignty_observed_score,
    ROUND(f.vulnerability_observed_score, 3)::NUMERIC(8,3) AS vulnerability_observed_score,
    ROUND(f.resilience_observed_score, 3)::NUMERIC(8,3) AS resilience_observed_score,
    f.strategic_diagnostic_role,
    f.strategic_attention_class,
    f.forecast_policy_code,
    f.forecast_trend_status,
    f.forecast_blocking_reason,
    ROUND(f.central_isa_delta, 3)::NUMERIC(8,3) AS central_isa_delta,
    ROUND(f.stress_isa_delta, 3)::NUMERIC(8,3) AS stress_isa_delta,
    ROUND(f.sovereign_risk_score, 3)::NUMERIC(6,3) AS sovereign_risk_score,
    ROUND(f.fragility_warning_score, 3)::NUMERIC(6,3) AS fragility_warning_score,
    ROUND(f.stress_propagation_score, 3)::NUMERIC(6,3) AS stress_propagation_score,
    ROUND(f.early_warning_score, 3)::NUMERIC(6,3) AS early_warning_score,
    ROUND(f.early_warning_confidence, 3)::NUMERIC(6,3) AS early_warning_confidence,
    p.alert_level::TEXT AS sovereign_alert_level,
    p.alert_rank::INT AS alert_rank,
    p.alert_label::TEXT AS alert_label,
    p.recommended_governance_action::TEXT AS recommended_governance_action,
    CASE
        WHEN f.early_warning_confidence < 0.350 THEN 'WARNING_LOW_CONFIDENCE_CONTEXTUAL'
        WHEN p.alert_level IN ('RED','ORANGE') THEN 'WARNING_REQUIRES_STRATEGIC_REVIEW'
        WHEN p.alert_level = 'YELLOW' THEN 'WARNING_REQUIRES_MONITORING'
        ELSE 'WARNING_MONITOR'
    END::TEXT AS early_warning_decision,
    CASE
        WHEN p.alert_level = 'RED' THEN 'CRITICAL_SOVEREIGN_ALERT'
        WHEN p.alert_level = 'ORANGE' THEN 'HIGH_SOVEREIGN_ALERT'
        WHEN p.alert_level = 'YELLOW' THEN 'MODERATE_SOVEREIGN_ALERT'
        ELSE 'LOW_SOVEREIGN_ALERT'
    END::TEXT AS early_warning_class
FROM final_score f
JOIN rf.isa_early_warning_policy p
  ON f.early_warning_score >= p.min_risk_score
 AND f.early_warning_score < CASE WHEN p.alert_level = 'RED' THEN 1.001 ELSE p.max_risk_score END;
