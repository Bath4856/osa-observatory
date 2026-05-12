-- ============================================================
-- OSA / ISA — P7G
-- View: ma.v_isa_forecast_country_year
-- Purpose:
--   Aggregate P7G pillar forecasts to country/year forecasts.
-- ============================================================

CREATE OR REPLACE VIEW ma.v_isa_forecast_country_year AS
WITH p AS (
    SELECT *
    FROM ma.v_isa_forecast_projection_engine
),
agg AS (
    SELECT
        country_iso3,
        forecast_year,
        horizon_code,
        horizon_years,
        MAX(last_observed_year) AS last_observed_year,
        COUNT(*)::INT AS nb_pillars_forecasted,
        SUM(CASE WHEN forecast_decision IN ('USE_AS_PREDICTIVE_SIGNAL','USE_WITH_VOLATILITY_WARNING') THEN 1 ELSE 0 END)::INT AS nb_predictive_pillars,
        SUM(CASE WHEN forecast_decision = 'USE_AS_INDICATIVE_SIGNAL' THEN 1 ELSE 0 END)::INT AS nb_indicative_pillars,
        SUM(CASE WHEN forecast_decision IN ('REVIEW_BEFORE_USE','DO_NOT_USE_FORECAST') THEN 1 ELSE 0 END)::INT AS nb_review_pillars,

        ROUND(AVG(forecast_isa_score), 3) AS country_forecast_isa_score,
        ROUND(AVG(forecast_isa_low), 3) AS country_forecast_isa_low,
        ROUND(AVG(forecast_isa_high), 3) AS country_forecast_isa_high,
        ROUND(AVG(forecast_sovereignty_score), 3) AS country_forecast_sovereignty_score,
        ROUND(AVG(forecast_vulnerability_score), 3) AS country_forecast_vulnerability_score,
        ROUND(AVG(forecast_resilience_score), 3) AS country_forecast_resilience_score,
        ROUND(AVG(forecast_confidence), 3) AS country_forecast_confidence,
        ROUND(AVG(forecast_uncertainty), 3) AS country_forecast_uncertainty
    FROM p
    GROUP BY country_iso3, forecast_year, horizon_code, horizon_years
)
SELECT
    a.*,
    CASE
        WHEN nb_pillars_forecasted = 0 THEN 0::NUMERIC
        ELSE ROUND(nb_predictive_pillars::NUMERIC / NULLIF(nb_pillars_forecasted,0), 3)
    END AS forecast_coverage_ratio,
    CASE
        WHEN nb_review_pillars > 0 THEN 'COUNTRY_FORECAST_REVIEW_REQUIRED'
        WHEN country_forecast_confidence >= 0.750 THEN 'COUNTRY_FORECAST_READY_STRONG'
        WHEN country_forecast_confidence >= 0.600 THEN 'COUNTRY_FORECAST_READY_CONTROLLED'
        WHEN country_forecast_confidence >= 0.450 THEN 'COUNTRY_FORECAST_INDICATIVE'
        ELSE 'COUNTRY_FORECAST_WEAK'
    END AS country_forecast_status,
    CASE
        WHEN nb_review_pillars > 0 THEN 'REVIEW_PILLAR_FORECASTS_BEFORE_PUBLIC_USE'
        WHEN horizon_years <= 1 AND country_forecast_confidence >= 0.600 THEN 'OPEN_DATA_LIMITED_PUBLICATION'
        WHEN country_forecast_confidence >= 0.600 THEN 'EXPERT_OR_PREMIUM_USE'
        ELSE 'INTERNAL_MONITORING_ONLY'
    END AS country_forecast_publication_scope
FROM agg a;
