-- ============================================================
-- OSA / ISA — P7C
-- View: ma.v_isa_dynamic_aggregation_readiness
-- Purpose:
--   Aggregate P7C dynamic aggregation readiness by pillar and semantic family.
-- ============================================================

CREATE OR REPLACE VIEW ma.v_isa_dynamic_aggregation_readiness AS

WITH grouped AS (
    SELECT
        pillar_code,
        semantic_code,
        COUNT(*) AS nb_indicators,

        ROUND(AVG(final_isa_aggregation_weight), 3) AS avg_final_isa_weight,
        ROUND(AVG(final_ml_aggregation_weight), 3) AS avg_final_ml_weight,
        ROUND(AVG(final_forecast_aggregation_weight), 3) AS avg_final_forecast_weight,
        ROUND(AVG(final_sovereignty_aggregation_weight), 3) AS avg_final_sovereignty_weight,
        ROUND(AVG(final_vulnerability_aggregation_weight), 3) AS avg_final_vulnerability_weight,

        COUNT(*) FILTER (WHERE dynamic_aggregation_class = 'AGGREGATION_CORE_STRONG') AS nb_core_strong,
        COUNT(*) FILTER (WHERE dynamic_aggregation_class = 'AGGREGATION_CORE_CONTROLLED') AS nb_core_controlled,
        COUNT(*) FILTER (WHERE dynamic_aggregation_class = 'AGGREGATION_LOCKED_GAP') AS nb_locked_gap,
        COUNT(*) FILTER (WHERE dynamic_aggregation_class = 'AGGREGATION_VULNERABILITY_DOMINANT') AS nb_vulnerability_dominant,
        COUNT(*) FILTER (WHERE dynamic_forecast_aggregation_decision = 'FORECAST_AGGREGATION_DISABLED') AS nb_forecast_disabled,

        COUNT(*) FILTER (WHERE dynamic_isa_aggregation_decision = 'INCLUDE_IN_CORE_ISA_DYNAMIC') AS nb_include_core_dynamic,
        COUNT(*) FILTER (WHERE dynamic_isa_aggregation_decision = 'INCLUDE_IN_VULNERABILITY_INDEX') AS nb_include_vulnerability,
        COUNT(*) FILTER (WHERE dynamic_isa_aggregation_decision = 'EXCLUDE_FROM_CORE_INCLUDE_AS_GAP') AS nb_exclude_core_gap

    FROM ma.v_semantic_dynamic_aggregation_engine
    GROUP BY pillar_code, semantic_code
)

SELECT
    pillar_code,
    semantic_code,
    nb_indicators,
    avg_final_isa_weight,
    avg_final_ml_weight,
    avg_final_forecast_weight,
    avg_final_sovereignty_weight,
    avg_final_vulnerability_weight,
    nb_core_strong,
    nb_core_controlled,
    nb_locked_gap,
    nb_vulnerability_dominant,
    nb_forecast_disabled,
    nb_include_core_dynamic,
    nb_include_vulnerability,
    nb_exclude_core_gap,

    CASE
        WHEN nb_locked_gap > 0 THEN 'AGGREGATION_NEEDS_GAP_REVIEW'
        WHEN nb_vulnerability_dominant >= GREATEST(1, nb_indicators / 2) THEN 'AGGREGATION_VULNERABILITY_DOMINANT'
        WHEN avg_final_isa_weight >= 0.700 THEN 'DYNAMIC_AGGREGATION_READY_STRONG'
        WHEN avg_final_isa_weight >= 0.500 THEN 'DYNAMIC_AGGREGATION_READY_CONTROLLED'
        WHEN avg_final_vulnerability_weight >= 0.850 THEN 'DYNAMIC_AGGREGATION_RISK_SIGNAL'
        ELSE 'DYNAMIC_AGGREGATION_CONTEXTUAL'
    END AS dynamic_aggregation_readiness_status

FROM grouped;
