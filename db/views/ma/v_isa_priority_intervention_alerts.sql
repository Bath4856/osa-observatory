/* P7I priority intervention alerts: joins warning engine with P7F candidate interventions */
CREATE OR REPLACE VIEW ma.v_isa_priority_intervention_alerts AS
WITH base AS (
    SELECT
        e.country_iso3,
        e.year,
        e.pillar_code,
        c.intervention_family_code::TEXT AS intervention_family_code,
        c.intervention_family_label::TEXT AS intervention_family_label,
        c.strategic_objective::TEXT AS strategic_objective,
        c.recommended_action::TEXT AS recommended_action,
        c.candidate_intervention_status::TEXT AS candidate_intervention_status,
        e.sovereign_alert_level,
        e.early_warning_class,
        e.early_warning_score,
        e.early_warning_confidence,
        e.fragility_warning_score,
        e.stress_propagation_score,
        e.forecast_blocking_reason,
        e.strategic_diagnostic_role,
        LEAST(1.000, GREATEST(0.000,
            0.45 * e.early_warning_score +
            0.25 * COALESCE(c.priority_score, 0) +
            0.15 * e.fragility_warning_score +
            0.10 * CASE WHEN e.sovereign_alert_level IN ('RED','ORANGE') THEN 1 ELSE 0 END +
            0.05 * CASE WHEN e.forecast_blocking_reason IN ('LOW_CONFIDENCE','VOLATILITY_WARNING') THEN 1 ELSE 0 END
        ))::NUMERIC AS intervention_alert_priority_score
    FROM ma.v_isa_early_warning_engine e
    LEFT JOIN ma.v_isa_candidate_intervention_catalog c
      ON c.country_iso3 = e.country_iso3
     AND c.year = e.year
     AND c.pillar_code = e.pillar_code
)
SELECT
    b.country_iso3,
    b.year,
    b.pillar_code,
    b.intervention_family_code,
    b.intervention_family_label,
    b.strategic_objective,
    b.recommended_action,
    b.candidate_intervention_status,
    b.sovereign_alert_level,
    b.early_warning_class,
    ROUND(b.early_warning_score, 3)::NUMERIC(6,3) AS early_warning_score,
    ROUND(b.early_warning_confidence, 3)::NUMERIC(6,3) AS early_warning_confidence,
    ROUND(b.intervention_alert_priority_score, 3)::NUMERIC(6,3) AS intervention_alert_priority_score,
    pp.priority_class::TEXT AS intervention_priority_class,
    pp.priority_label::TEXT AS intervention_priority_label,
    pp.intervention_action::TEXT AS priority_intervention_action,
    CASE
        WHEN b.early_warning_confidence < 0.350 THEN 'INTERVENTION_ALERT_CONTEXTUAL_LOW_CONFIDENCE'
        WHEN pp.priority_class = 'PRIORITY_CRITICAL' THEN 'INTERVENTION_ALERT_URGENT_REVIEW'
        WHEN pp.priority_class = 'PRIORITY_HIGH' THEN 'INTERVENTION_ALERT_HIGH_PRIORITY'
        WHEN pp.priority_class = 'PRIORITY_STANDARD' THEN 'INTERVENTION_ALERT_STANDARD_PRIORITY'
        ELSE 'INTERVENTION_ALERT_MONITOR'
    END::TEXT AS priority_intervention_alert_status
FROM base b
JOIN rf.isa_priority_alert_policy pp
  ON b.intervention_alert_priority_score >= pp.min_priority_score
 AND b.intervention_alert_priority_score < CASE WHEN pp.priority_class = 'PRIORITY_CRITICAL' THEN 1.001 ELSE pp.max_priority_score END;
