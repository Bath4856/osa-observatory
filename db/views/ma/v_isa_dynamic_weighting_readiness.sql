-- ============================================================
-- OSA / ISA — P7B6
-- View: ma.v_isa_dynamic_weighting_readiness
-- Purpose:
--   Aggregated readiness for dynamic ISA/ML/forecast/sovereignty weighting.
-- ============================================================

CREATE OR REPLACE VIEW ma.v_isa_dynamic_weighting_readiness AS

SELECT
    pillar_code,
    semantic_code,

    COUNT(*) AS nb_indicators,

    ROUND(AVG(isa_dynamic_weight), 3) AS avg_isa_dynamic_weight,
    ROUND(AVG(ml_dynamic_weight), 3) AS avg_ml_dynamic_weight,
    ROUND(AVG(forecast_dynamic_weight), 3) AS avg_forecast_dynamic_weight,
    ROUND(AVG(sovereignty_dynamic_weight), 3) AS avg_sovereignty_dynamic_weight,
    ROUND(AVG(systemic_vulnerability_weight), 3) AS avg_systemic_vulnerability_weight,

    ROUND(AVG(semantic_sovereignty_score), 3) AS avg_sovereignty_score,
    ROUND(AVG(semantic_confidence_dynamic), 3) AS avg_dynamic_confidence,

    COUNT(*) FILTER (WHERE strategic_weighting_class = 'WEIGHT_CORE_STRONG') AS nb_weight_core_strong,
    COUNT(*) FILTER (WHERE strategic_weighting_class = 'WEIGHT_CORE_CONTROLLED') AS nb_weight_core_controlled,
    COUNT(*) FILTER (WHERE strategic_weighting_class = 'WEIGHT_MONITORED') AS nb_weight_monitored,
    COUNT(*) FILTER (WHERE strategic_weighting_class = 'WEIGHT_VULNERABILITY_SIGNAL') AS nb_weight_vulnerability_signal,
    COUNT(*) FILTER (WHERE strategic_weighting_class = 'WEIGHT_LOCKED_GAP') AS nb_weight_locked_gap,
    COUNT(*) FILTER (WHERE strategic_weighting_class = 'WEIGHT_CONTEXTUAL') AS nb_weight_contextual,

    COUNT(*) FILTER (WHERE forecast_weighting_decision = 'NO_FORECAST_WEIGHT') AS nb_no_forecast_weight,
    COUNT(*) FILTER (WHERE ml_weighting_decision = 'ML_WEIGHT_HIGH') AS nb_ml_weight_high,

    ROUND(
        AVG(
            CASE
                WHEN strategic_weighting_class = 'WEIGHT_CORE_STRONG' THEN 1.000
                WHEN strategic_weighting_class = 'WEIGHT_CORE_CONTROLLED' THEN 0.850
                WHEN strategic_weighting_class = 'WEIGHT_MONITORED' THEN 0.650
                WHEN strategic_weighting_class = 'WEIGHT_VULNERABILITY_SIGNAL' THEN 0.600
                WHEN strategic_weighting_class = 'WEIGHT_LOCKED_GAP' THEN 0.350
                ELSE 0.300
            END
        )::NUMERIC,
        3
    ) AS dynamic_weighting_readiness_score,

    CASE
        WHEN COUNT(*) FILTER (WHERE strategic_weighting_class = 'WEIGHT_LOCKED_GAP') > 0
            THEN 'NEEDS_WEIGHTING_REVIEW'

        WHEN AVG(isa_dynamic_weight) >= 0.850
         AND AVG(sovereignty_dynamic_weight) >= 0.850
            THEN 'DYNAMIC_WEIGHTING_READY_STRONG'

        WHEN AVG(isa_dynamic_weight) >= 0.700
            THEN 'DYNAMIC_WEIGHTING_READY_CONTROLLED'

        WHEN AVG(systemic_vulnerability_weight) >= 0.700
            THEN 'DYNAMIC_WEIGHTING_VULNERABILITY_DOMINANT'

        WHEN AVG(isa_dynamic_weight) >= 0.500
            THEN 'DYNAMIC_WEIGHTING_MONITORED'

        ELSE 'DYNAMIC_WEIGHTING_CONTEXTUAL'
    END AS dynamic_weighting_readiness_status

FROM ma.v_semantic_strategic_weighting_engine
GROUP BY
    pillar_code,
    semantic_code;
