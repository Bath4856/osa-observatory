-- ============================================================
-- OSA / ISA — P7G
-- View: ma.v_isa_forecast_readiness_p7g
-- Purpose:
--   Readiness summary by pillar and forecast status.
-- ============================================================

CREATE OR REPLACE VIEW ma.v_isa_forecast_readiness_p7g AS
SELECT
    pillar_code,
    horizon_code,
    horizon_years,
    COUNT(*)::INT AS nb_country_pillar_forecasts,
    ROUND(AVG(forecast_isa_score), 3) AS avg_forecast_isa_score,
    ROUND(AVG(forecast_confidence), 3) AS avg_forecast_confidence,
    ROUND(AVG(forecast_uncertainty), 3) AS avg_forecast_uncertainty,
    SUM(CASE WHEN forecast_decision = 'USE_AS_PREDICTIVE_SIGNAL' THEN 1 ELSE 0 END)::INT AS nb_predictive,
    SUM(CASE WHEN forecast_decision = 'USE_WITH_VOLATILITY_WARNING' THEN 1 ELSE 0 END)::INT AS nb_volatility_warning,
    SUM(CASE WHEN forecast_decision = 'USE_AS_INDICATIVE_SIGNAL' THEN 1 ELSE 0 END)::INT AS nb_indicative,
    SUM(CASE WHEN forecast_decision IN ('REVIEW_BEFORE_USE','DO_NOT_USE_FORECAST') THEN 1 ELSE 0 END)::INT AS nb_review,
    CASE
        WHEN SUM(CASE WHEN forecast_decision IN ('REVIEW_BEFORE_USE','DO_NOT_USE_FORECAST') THEN 1 ELSE 0 END) > 0
            THEN 'P7G_FORECAST_REVIEW_REQUIRED'
        WHEN AVG(forecast_confidence) >= 0.750
            THEN 'P7G_FORECAST_READY_STRONG'
        WHEN AVG(forecast_confidence) >= 0.600
            THEN 'P7G_FORECAST_READY_CONTROLLED'
        WHEN AVG(forecast_confidence) >= 0.450
            THEN 'P7G_FORECAST_INDICATIVE'
        ELSE 'P7G_FORECAST_WEAK'
    END AS p7g_forecast_readiness_status
FROM ma.v_isa_forecast_projection_engine
GROUP BY pillar_code, horizon_code, horizon_years;
