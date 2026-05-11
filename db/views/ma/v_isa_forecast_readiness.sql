-- ============================================================
-- OSA / ISA — P7B4
-- View: ma.v_isa_forecast_readiness
-- Role:
--   Aggregates semantic forecastability by pillar and semantic family.
-- ============================================================

CREATE OR REPLACE VIEW ma.v_isa_forecast_readiness AS

SELECT
    pillar_code,
    semantic_code,
    COUNT(*) AS nb_indicators,

    ROUND(AVG(semantic_confidence_dynamic), 3) AS avg_dynamic_confidence,
    ROUND(AVG(semantic_operational_score), 3) AS avg_operational_score,
    ROUND(AVG(semantic_forecastability_score), 3) AS avg_forecastability_score,

    COUNT(*) FILTER (WHERE semantic_forecast_status = 'FORECAST_READY') AS nb_forecast_ready,
    COUNT(*) FILTER (WHERE semantic_forecast_status = 'FORECAST_LIMITED') AS nb_forecast_limited,
    COUNT(*) FILTER (WHERE semantic_forecast_status = 'CONTEXT_ONLY') AS nb_context_only,
    COUNT(*) FILTER (WHERE semantic_forecast_status = 'FORECAST_DISABLED') AS nb_forecast_disabled,
    COUNT(*) FILTER (WHERE semantic_forecast_status = 'FORECAST_DISABLED_REVIEW') AS nb_forecast_disabled_review,

    ROUND(AVG(allowed_forecast_horizon_years), 2) AS avg_allowed_forecast_horizon_years,

    CASE
        WHEN COUNT(*) FILTER (WHERE semantic_forecast_status = 'FORECAST_DISABLED_REVIEW') > 0
            THEN 'NEEDS_FORECAST_GOVERNANCE_REVIEW'

        WHEN AVG(semantic_forecastability_score) >= 0.750
            THEN 'FORECAST_READY_STRONG'

        WHEN AVG(semantic_forecastability_score) >= 0.600
            THEN 'FORECAST_READY_CONTROLLED'

        WHEN COUNT(*) FILTER (WHERE semantic_forecast_status = 'FORECAST_DISABLED') > 0
          OR AVG(semantic_forecastability_score) < 0.500
            THEN 'FORECAST_WEAK_OR_CONTEXTUAL'

        ELSE 'FORECAST_LIMITED_MONITORING'
    END AS forecast_readiness_status

FROM ma.v_semantic_forecastability_engine
GROUP BY pillar_code, semantic_code;
