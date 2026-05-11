-- ============================================================
-- OSA / ISA — P7B4
-- View: ma.v_semantic_forecastability_engine
-- ============================================================

CREATE OR REPLACE VIEW ma.v_semantic_forecastability_engine AS

WITH base AS (
    SELECT
        o.indicator_code,
        o.pillar_code,
        o.indicator_name,
        o.semantic_code,
        COALESCE(o.semantic_confidence_dynamic, 0.000)::NUMERIC AS semantic_confidence_dynamic,
        COALESCE(o.semantic_operational_score, 0.000)::NUMERIC AS semantic_operational_score,
        COALESCE(o.semantic_operational_status, 'UNKNOWN_OPERATION_STATUS') AS semantic_operational_status,
        COALESCE(o.isa_operational_decision, 'UNKNOWN_ISA_DECISION') AS isa_operational_decision,
        COALESCE(o.l2_imputation_decision, 'UNKNOWN_IMPUTATION_DECISION') AS l2_imputation_decision,
        COALESCE(o.ml_operational_decision, 'UNKNOWN_ML_DECISION') AS ml_operational_decision
    FROM ma.v_semantic_operational_policy_engine o
),
policy AS (
    SELECT
        b.*,
        COALESCE(p.forecast_policy, 'CONTEXT_FORECAST') AS forecast_policy,
        COALESCE(p.base_forecastability, 0.600)::NUMERIC AS base_forecastability,
        COALESCE(p.min_forecast_confidence, 0.600)::NUMERIC AS min_forecast_confidence,
        COALESCE(p.max_forecast_horizon_years, 3)::SMALLINT AS max_forecast_horizon_years,
        COALESCE(p.volatility_penalty, 0.050)::NUMERIC AS volatility_penalty,
        COALESCE(p.locked_review_penalty, 0.250)::NUMERIC AS locked_review_penalty,
        COALESCE(p.event_forecast_allowed, TRUE) AS event_forecast_allowed,
        COALESCE(p.physical_forecast_requires_certification, FALSE) AS physical_forecast_requires_certification,
        COALESCE(p.ml_forecast_weight, 0.750)::NUMERIC AS ml_forecast_weight,
        COALESCE(p.smoothing_policy, 'STANDARD_SMOOTHING') AS smoothing_policy,
        COALESCE(p.drift_monitoring_policy, 'STANDARD_DRIFT_MONITORING') AS drift_monitoring_policy,
        p.operational_notes AS forecast_policy_notes
    FROM base b
    LEFT JOIN rf.semantic_forecast_policy p ON p.semantic_code = b.semantic_code
),
penalties AS (
    SELECT
        p.*,
        CASE WHEN p.semantic_operational_status = 'OPERATION_LOCKED_REVIEW'
            THEN p.locked_review_penalty ELSE 0::NUMERIC END AS applied_locked_review_penalty,
        CASE WHEN p.ml_operational_decision = 'ML_FORECAST_DISABLED'
            THEN 0.300::NUMERIC ELSE 0::NUMERIC END AS applied_ml_disabled_penalty,
        CASE WHEN p.forecast_policy IN ('FORECAST_DISABLED', 'CONTEXT_ONLY')
            THEN 0.200::NUMERIC ELSE 0::NUMERIC END AS applied_policy_penalty,
        CASE WHEN p.semantic_code = 'EVENT' AND p.event_forecast_allowed = FALSE
            THEN 0.250::NUMERIC ELSE 0::NUMERIC END AS applied_event_penalty,
        CASE WHEN p.semantic_code = 'PHYSICAL'
             AND p.physical_forecast_requires_certification = TRUE
             AND p.semantic_operational_status = 'OPERATION_LOCKED_REVIEW'
            THEN 0.300::NUMERIC ELSE 0::NUMERIC END AS applied_physical_certification_penalty,
        CASE WHEN p.semantic_operational_status = 'OPERATION_MONITOR'
            THEN p.volatility_penalty ELSE 0::NUMERIC END AS applied_monitoring_penalty
    FROM policy p
),
scored AS (
    SELECT
        x.*,
        ROUND(GREATEST(0::NUMERIC, LEAST(1::NUMERIC, (
            x.semantic_confidence_dynamic * 0.350
          + x.semantic_operational_score  * 0.250
          + x.base_forecastability        * 0.200
          + x.ml_forecast_weight          * 0.200
          - x.applied_locked_review_penalty
          - x.applied_ml_disabled_penalty
          - x.applied_policy_penalty
          - x.applied_event_penalty
          - x.applied_physical_certification_penalty
          - x.applied_monitoring_penalty
        )))::NUMERIC, 3) AS semantic_forecastability_score
    FROM penalties x
),
finalized AS (
    SELECT
        s.*,
        CASE
            WHEN s.semantic_operational_status = 'OPERATION_LOCKED_REVIEW'
                THEN 'FORECAST_DISABLED_REVIEW'
            WHEN s.ml_operational_decision = 'ML_FORECAST_DISABLED'
              OR s.forecast_policy = 'FORECAST_DISABLED'
                THEN 'FORECAST_DISABLED'
            WHEN s.forecast_policy = 'CONTEXT_ONLY'
                THEN 'CONTEXT_ONLY'
            WHEN s.semantic_forecastability_score >= 0.750
             AND s.semantic_confidence_dynamic >= s.min_forecast_confidence
                THEN 'FORECAST_READY'
            WHEN s.semantic_forecastability_score >= 0.550
                THEN 'FORECAST_LIMITED'
            ELSE 'CONTEXT_ONLY'
        END AS semantic_forecast_status,
        CASE
            WHEN s.semantic_operational_status = 'OPERATION_LOCKED_REVIEW'
                THEN 'NO_FORECAST_UNTIL_REVIEW'
            WHEN s.ml_operational_decision = 'ML_FORECAST_DISABLED'
              OR s.forecast_policy = 'FORECAST_DISABLED'
                THEN 'NO_FORECAST_EVENT_OR_POLICY'
            WHEN s.semantic_forecastability_score >= 0.750
                THEN 'USE_AS_FORECAST_FEATURE'
            WHEN s.semantic_forecastability_score >= 0.550
                THEN 'USE_AS_LIMITED_FORECAST_FEATURE'
            ELSE 'USE_AS_CONTEXT_ONLY'
        END AS ml_forecast_decision,
        CASE
            WHEN s.semantic_operational_status = 'OPERATION_LOCKED_REVIEW'
                THEN 0
            WHEN s.ml_operational_decision = 'ML_FORECAST_DISABLED'
              OR s.forecast_policy IN ('FORECAST_DISABLED', 'CONTEXT_ONLY')
                THEN 0
            WHEN s.semantic_forecastability_score >= 0.750
             AND s.semantic_confidence_dynamic >= s.min_forecast_confidence
                THEN s.max_forecast_horizon_years
            WHEN s.semantic_forecastability_score >= 0.550
                THEN LEAST(s.max_forecast_horizon_years, 2)
            ELSE 0
        END AS allowed_forecast_horizon_years,
        CASE
            WHEN s.semantic_operational_status = 'OPERATION_LOCKED_REVIEW'
                THEN 'LOCKED_OPERATIONAL_REVIEW'
            WHEN s.ml_operational_decision = 'ML_FORECAST_DISABLED'
                THEN 'ML_FORECAST_DISABLED_BY_P7B3'
            WHEN s.semantic_code = 'EVENT'
                THEN 'EVENT_SIGNAL_MONITOR_ONLY'
            WHEN s.semantic_code = 'PHYSICAL'
             AND s.physical_forecast_requires_certification = TRUE
                THEN 'PHYSICAL_FORECAST_REQUIRES_CERTIFICATION'
            WHEN s.semantic_forecastability_score < 0.550
                THEN 'LOW_FORECASTABILITY_SCORE'
            ELSE 'FORECASTABILITY_ACCEPTABLE'
        END AS forecastability_reason
    FROM scored s
)
SELECT
    indicator_code, pillar_code, indicator_name, semantic_code,
    semantic_confidence_dynamic, semantic_operational_score,
    semantic_operational_status, isa_operational_decision,
    l2_imputation_decision, ml_operational_decision,
    forecast_policy, base_forecastability, min_forecast_confidence,
    max_forecast_horizon_years, volatility_penalty, locked_review_penalty,
    event_forecast_allowed, physical_forecast_requires_certification,
    ml_forecast_weight, smoothing_policy, drift_monitoring_policy,
    applied_locked_review_penalty, applied_ml_disabled_penalty,
    applied_policy_penalty, applied_event_penalty,
    applied_physical_certification_penalty, applied_monitoring_penalty,
    semantic_forecastability_score, semantic_forecast_status,
    ml_forecast_decision, allowed_forecast_horizon_years,
    forecastability_reason, forecast_policy_notes
FROM finalized;
