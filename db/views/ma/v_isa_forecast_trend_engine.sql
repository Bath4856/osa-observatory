-- Patch : corriger l'ordre des conditions dans v_isa_forecast_trend_engine
-- LOW_CONFIDENCE doit être évalué avant INSUFFICIENT_HISTORY

CREATE OR REPLACE VIEW ma.v_isa_forecast_trend_engine AS
WITH src AS (
    SELECT
        country_iso3::TEXT AS country_iso3,
        year::INT AS year,
        pillar_code::TEXT AS pillar_code,
        COALESCE(data_completeness, 0)::NUMERIC AS data_completeness,
        COALESCE(observation_confidence, 0)::NUMERIC AS observation_confidence,
        COALESCE(isa_observed_score, 0)::NUMERIC AS isa_observed_score,
        COALESCE(sovereignty_observed_score, 0)::NUMERIC AS sovereignty_observed_score,
        COALESCE(vulnerability_observed_score, 0)::NUMERIC AS vulnerability_observed_score,
        COALESCE(resilience_observed_score, 0)::NUMERIC AS resilience_observed_score,
        COALESCE(forecast_readiness_score, 0)::NUMERIC AS forecast_readiness_score,
        COALESCE(ml_readiness_score, 0)::NUMERIC AS ml_readiness_score,
        COALESCE(strategic_risk_score, 0)::NUMERIC AS strategic_risk_score,
        COALESCE(strategic_upside_score, 0)::NUMERIC AS strategic_upside_score,
        COALESCE(diagnostic_priority_score, 0)::NUMERIC AS diagnostic_priority_score
    FROM ma.v_p7g_forecast_source
),
hist AS (
    SELECT
        country_iso3,
        pillar_code,
        COUNT(*)::INT AS history_years,
        MIN(year)::INT AS first_year,
        MAX(year)::INT AS last_observed_year,
        AVG(data_completeness)::NUMERIC AS avg_data_completeness,
        AVG(observation_confidence)::NUMERIC AS avg_observation_confidence,
        AVG(isa_observed_score)::NUMERIC AS avg_isa_score,
        AVG(sovereignty_observed_score)::NUMERIC AS avg_sovereignty_score,
        AVG(vulnerability_observed_score)::NUMERIC AS avg_vulnerability_score,
        AVG(resilience_observed_score)::NUMERIC AS avg_resilience_score,
        AVG(forecast_readiness_score)::NUMERIC AS avg_forecast_readiness_score,
        AVG(ml_readiness_score)::NUMERIC AS avg_ml_readiness_score,
        AVG(strategic_risk_score)::NUMERIC AS avg_strategic_risk_score,
        AVG(strategic_upside_score)::NUMERIC AS avg_strategic_upside_score,
        AVG(diagnostic_priority_score)::NUMERIC AS avg_diagnostic_priority_score
    FROM src
    GROUP BY country_iso3, pillar_code
),
last_values AS (
    SELECT DISTINCT ON (country_iso3, pillar_code)
        country_iso3,
        pillar_code,
        year::INT AS last_observed_year,
        isa_observed_score::NUMERIC AS last_isa_observed_score,
        sovereignty_observed_score::NUMERIC AS last_sovereignty_observed_score,
        vulnerability_observed_score::NUMERIC AS last_vulnerability_observed_score,
        resilience_observed_score::NUMERIC AS last_resilience_observed_score,
        forecast_readiness_score::NUMERIC AS last_forecast_readiness_score,
        ml_readiness_score::NUMERIC AS last_ml_readiness_score
    FROM src
    ORDER BY country_iso3, pillar_code, year DESC
),
slope_calc AS (
    SELECT
        s.country_iso3,
        s.pillar_code,
        CASE
            WHEN COUNT(*) < 2 THEN 0::NUMERIC
            ELSE COALESCE(
                REGR_SLOPE(s.isa_observed_score::DOUBLE PRECISION, s.year::DOUBLE PRECISION),
                0
            )::NUMERIC
        END AS isa_trend_slope,
        COALESCE(STDDEV_POP(s.isa_observed_score), 0)::NUMERIC AS isa_volatility
    FROM src s
    GROUP BY s.country_iso3, s.pillar_code
),
policy_eval AS (
    SELECT
        h.country_iso3,
        h.pillar_code,
        h.history_years,
        h.first_year,
        h.last_observed_year,
        h.avg_data_completeness,
        h.avg_observation_confidence,
        h.avg_isa_score,
        h.avg_sovereignty_score,
        h.avg_vulnerability_score,
        h.avg_resilience_score,
        h.avg_forecast_readiness_score,
        h.avg_ml_readiness_score,
        sc.isa_trend_slope,
        sc.isa_volatility,
        lv.last_isa_observed_score,
        lv.last_sovereignty_observed_score,
        lv.last_vulnerability_observed_score,
        lv.last_resilience_observed_score,
        lv.last_forecast_readiness_score,
        lv.last_ml_readiness_score,
        h.avg_strategic_risk_score,
        h.avg_strategic_upside_score,
        h.avg_diagnostic_priority_score,

        CASE
            WHEN h.history_years >= 5
             AND h.avg_data_completeness >= 0.700
             AND h.avg_observation_confidence >= 0.600
                THEN 'ROBUST_FORECAST'
            WHEN h.history_years >= 4
             AND h.avg_data_completeness >= 0.600
             AND h.avg_observation_confidence >= 0.500
                THEN 'CONTROLLED_FORECAST'
            WHEN h.history_years >= 3
             AND h.avg_data_completeness >= 0.500
             AND h.avg_observation_confidence >= 0.400
                THEN 'LIMITED_FORECAST'
            ELSE 'NO_FORECAST'
        END::TEXT AS forecast_policy_code,

        CASE
            WHEN sc.isa_trend_slope > 0.010 THEN 'IMPROVING'
            WHEN sc.isa_trend_slope < -0.010 THEN 'DETERIORATING'
            WHEN sc.isa_volatility >= 0.080 THEN 'VOLATILE'
            ELSE 'STABLE'
        END::TEXT AS forecast_trend_class
    FROM hist h
    JOIN slope_calc sc
      ON sc.country_iso3 = h.country_iso3
     AND sc.pillar_code = h.pillar_code
    JOIN last_values lv
      ON lv.country_iso3 = h.country_iso3
     AND lv.pillar_code = h.pillar_code
),
joined_policy AS (
    SELECT
        p.*,
        COALESCE(fp.min_history_years, 99)::INT AS min_history_years,
        COALESCE(fp.min_data_completeness, 0.999)::NUMERIC(6,3) AS min_data_completeness,
        COALESCE(fp.min_observation_confidence, 0.999)::NUMERIC(6,3) AS min_observation_confidence,
        COALESCE(fp.short_horizon_years, 0)::INT AS short_horizon_years,
        COALESCE(fp.medium_horizon_years, 0)::INT AS medium_horizon_years,
        COALESCE(fp.long_horizon_years, 0)::INT AS long_horizon_years,
        COALESCE(fp.min_forecast_confidence, 0.999)::NUMERIC(6,3) AS min_forecast_confidence,
        COALESCE(fp.uncertainty_multiplier, 1.000)::NUMERIC(6,3) AS uncertainty_multiplier,
        COALESCE(fp.drift_warning_threshold, 0.080)::NUMERIC(6,3) AS drift_warning_threshold,
        CASE p.forecast_policy_code
            WHEN 'ROBUST_FORECAST'     THEN 'Prévision robuste'
            WHEN 'CONTROLLED_FORECAST' THEN 'Prévision contrôlée'
            WHEN 'LIMITED_FORECAST'    THEN 'Prévision indicative limitée'
            ELSE                            'Prévision désactivée'
        END::TEXT AS trend_label,
        CASE p.forecast_policy_code
            WHEN 'ROBUST_FORECAST'     THEN 'Use for controlled predictive intelligence'
            WHEN 'CONTROLLED_FORECAST' THEN 'Use with monitoring'
            WHEN 'LIMITED_FORECAST'    THEN 'Use as indicative signal only'
            ELSE                            'Do not forecast'
        END::TEXT AS forecast_recommended_use
    FROM policy_eval p
    LEFT JOIN rf.isa_forecast_policy fp
        ON fp.forecast_policy_code = p.forecast_policy_code
)
SELECT
    country_iso3,
    pillar_code,
    history_years,
    first_year,
    last_observed_year,
    ROUND(avg_data_completeness, 3)::NUMERIC(6,3)          AS avg_data_completeness,
    ROUND(avg_observation_confidence, 3)::NUMERIC(6,3)     AS avg_observation_confidence,
    ROUND(avg_isa_score, 3)::NUMERIC(8,3)                  AS avg_isa_score,
    ROUND(avg_sovereignty_score, 3)::NUMERIC(8,3)          AS avg_sovereignty_score,
    ROUND(avg_vulnerability_score, 3)::NUMERIC(8,3)        AS avg_vulnerability_score,
    ROUND(avg_resilience_score, 3)::NUMERIC(8,3)           AS avg_resilience_score,
    ROUND(avg_forecast_readiness_score, 3)::NUMERIC(8,3)   AS avg_forecast_readiness_score,
    ROUND(avg_ml_readiness_score, 3)::NUMERIC(8,3)         AS avg_ml_readiness_score,
    ROUND(isa_trend_slope, 6)::NUMERIC(12,6)               AS isa_trend_slope,
    ROUND(isa_volatility, 6)::NUMERIC(12,6)                AS isa_volatility,
    ROUND(last_isa_observed_score, 3)::NUMERIC(8,3)        AS last_isa_observed_score,
    ROUND(last_sovereignty_observed_score, 3)::NUMERIC(8,3) AS last_sovereignty_observed_score,
    ROUND(last_vulnerability_observed_score, 3)::NUMERIC(8,3) AS last_vulnerability_observed_score,
    ROUND(last_resilience_observed_score, 3)::NUMERIC(8,3) AS last_resilience_observed_score,
    ROUND(last_forecast_readiness_score, 3)::NUMERIC(8,3)  AS last_forecast_readiness_score,
    ROUND(last_ml_readiness_score, 3)::NUMERIC(8,3)        AS last_ml_readiness_score,
    ROUND(avg_strategic_risk_score, 3)::NUMERIC(8,3)       AS avg_strategic_risk_score,
    ROUND(avg_strategic_upside_score, 3)::NUMERIC(8,3)     AS avg_strategic_upside_score,
    ROUND(avg_diagnostic_priority_score, 3)::NUMERIC(8,3)  AS avg_diagnostic_priority_score,

    forecast_policy_code,
    forecast_trend_class,
    trend_label,
    min_history_years,
    min_data_completeness,
    min_observation_confidence,
    short_horizon_years,
    medium_horizon_years,
    long_horizon_years,
    min_forecast_confidence,
    uncertainty_multiplier,
    drift_warning_threshold,
    forecast_recommended_use,

    -- ── CORRECTION : LOW_CONFIDENCE évalué EN PREMIER ──────────────────────
    CASE
        WHEN avg_observation_confidence < min_observation_confidence
            THEN 'FORECAST_DISABLED_LOW_CONFIDENCE'
        WHEN history_years < min_history_years
            THEN 'FORECAST_DISABLED_INSUFFICIENT_HISTORY'
        WHEN avg_data_completeness < min_data_completeness
            THEN 'FORECAST_DISABLED_LOW_COMPLETENESS'
        WHEN isa_volatility >= drift_warning_threshold
            THEN 'FORECAST_ENABLED_WITH_VOLATILITY_WARNING'
        WHEN forecast_policy_code = 'ROBUST_FORECAST'
            THEN 'FORECAST_READY_ROBUST'
        WHEN forecast_policy_code = 'CONTROLLED_FORECAST'
            THEN 'FORECAST_READY_CONTROLLED'
        WHEN forecast_policy_code = 'LIMITED_FORECAST'
            THEN 'FORECAST_LIMITED_INDICATIVE'
        ELSE 'FORECAST_REVIEW_REQUIRED'
    END::TEXT AS forecast_trend_status,

    CASE
        WHEN avg_observation_confidence < min_observation_confidence
            THEN 'LOW_CONFIDENCE'
        WHEN history_years < min_history_years
            THEN 'INSUFFICIENT_HISTORY'
        WHEN avg_data_completeness < min_data_completeness
            THEN 'LOW_COMPLETENESS'
        WHEN isa_volatility >= drift_warning_threshold
            THEN 'VOLATILITY_WARNING'
        ELSE 'FORECAST_ALLOWED'
    END::TEXT AS forecast_blocking_reason

FROM joined_policy;