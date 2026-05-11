-- ============================================================
-- OSA / ISA — P7C
-- View: ma.v_semantic_dynamic_aggregation_engine
-- Purpose:
--   Convert P7B6 semantic strategic weights into dynamic ISA aggregation inputs.
--
-- Safe dependency contract:
--   ma.v_semantic_strategic_weighting_engine
--   rf.dynamic_aggregation_policy
--
-- Design:
--   - No raw indicator values are consumed here.
--   - This view produces aggregation weights and readiness logic.
--   - L4/L5 score computation can join this view to normalized indicator values later.
-- ============================================================

CREATE OR REPLACE VIEW ma.v_semantic_dynamic_aggregation_engine AS

WITH base AS (
    SELECT
        w.indicator_code,
        w.pillar_code,
        w.indicator_name,
        w.semantic_code,

        COALESCE(w.semantic_sovereignty_class, 'UNKNOWN') AS semantic_sovereignty_class,
        COALESCE(w.strategic_weighting_class, 'WEIGHT_UNKNOWN') AS strategic_weighting_class,
        COALESCE(w.isa_weighting_decision, 'USE_AS_CONTEXTUAL_WEIGHT') AS isa_weighting_decision,
        COALESCE(w.ml_weighting_decision, 'ML_WEIGHT_CONTEXTUAL') AS ml_weighting_decision,
        COALESCE(w.forecast_weighting_decision, 'NO_FORECAST_WEIGHT') AS forecast_weighting_decision,

        COALESCE(w.semantic_confidence_dynamic, 0.000)::NUMERIC AS semantic_confidence_dynamic,
        COALESCE(w.semantic_operational_score, 0.000)::NUMERIC AS semantic_operational_score,
        COALESCE(w.semantic_forecastability_score, 0.000)::NUMERIC AS semantic_forecastability_score,
        COALESCE(w.semantic_sovereignty_score, 0.000)::NUMERIC AS semantic_sovereignty_score,
        COALESCE(w.semantic_sovereignty_vulnerability, 1.000)::NUMERIC AS semantic_sovereignty_vulnerability,

        COALESCE(w.isa_dynamic_weight, 0.000)::NUMERIC AS isa_dynamic_weight,
        COALESCE(w.ml_dynamic_weight, 0.000)::NUMERIC AS ml_dynamic_weight,
        COALESCE(w.forecast_dynamic_weight, 0.000)::NUMERIC AS forecast_dynamic_weight,
        COALESCE(w.sovereignty_dynamic_weight, 0.000)::NUMERIC AS sovereignty_dynamic_weight,
        COALESCE(w.systemic_vulnerability_weight, 1.000)::NUMERIC AS systemic_vulnerability_weight

    FROM ma.v_semantic_strategic_weighting_engine w
),
policy_joined AS (
    SELECT
        b.*,
        COALESCE(p.aggregation_mode, 'DEFAULT_CONTROLLED') AS aggregation_mode,
        COALESCE(p.pillar_weight_factor, 1.000)::NUMERIC AS pillar_weight_factor,
        COALESCE(p.isa_score_factor, 1.000)::NUMERIC AS isa_score_factor,
        COALESCE(p.vulnerability_factor, 1.000)::NUMERIC AS vulnerability_factor,
        COALESCE(p.resilience_factor, 1.000)::NUMERIC AS resilience_factor,
        COALESCE(p.min_aggregation_weight, 0.050)::NUMERIC AS min_aggregation_weight,
        COALESCE(p.max_aggregation_weight, 1.250)::NUMERIC AS max_aggregation_weight,
        COALESCE(p.include_in_core_isa, TRUE) AS include_in_core_isa,
        COALESCE(p.include_in_vulnerability_index, TRUE) AS include_in_vulnerability_index,
        COALESCE(p.include_in_resilience_index, TRUE) AS include_in_resilience_index,
        p.notes AS aggregation_policy_notes
    FROM base b
    LEFT JOIN rf.dynamic_aggregation_policy p
        ON p.semantic_code = b.semantic_code
),
scored AS (
    SELECT
        p.*,

        CASE
            WHEN p.strategic_weighting_class = 'WEIGHT_LOCKED_GAP'
              OR p.isa_weighting_decision = 'USE_AS_GAP_NOT_CORE_WEIGHT'
                THEN FALSE
            ELSE p.include_in_core_isa
        END AS effective_include_in_core_isa,

        CASE
            WHEN p.isa_weighting_decision IN ('USE_AS_VULNERABILITY_WEIGHT', 'USE_AS_GAP_NOT_CORE_WEIGHT')
                THEN TRUE
            ELSE p.include_in_vulnerability_index
        END AS effective_include_in_vulnerability_index,

        CASE
            WHEN p.strategic_weighting_class IN ('WEIGHT_CORE_STRONG', 'WEIGHT_CORE_CONTROLLED')
                THEN p.include_in_resilience_index
            ELSE FALSE
        END AS effective_include_in_resilience_index,

        ROUND(
            GREATEST(
                p.min_aggregation_weight,
                LEAST(
                    p.max_aggregation_weight,
                    (
                        p.isa_dynamic_weight
                      * p.semantic_confidence_dynamic
                      * GREATEST(p.semantic_operational_score, 0.050)
                      * GREATEST(p.semantic_sovereignty_score, 0.050)
                      * p.pillar_weight_factor
                      * p.isa_score_factor
                    )
                )
            ),
            3
        ) AS final_isa_aggregation_weight,

        ROUND(
            GREATEST(
                p.min_aggregation_weight,
                LEAST(
                    p.max_aggregation_weight,
                    (
                        p.ml_dynamic_weight
                      * p.semantic_confidence_dynamic
                      * GREATEST(p.semantic_operational_score, 0.050)
                      * p.pillar_weight_factor
                    )
                )
            ),
            3
        ) AS final_ml_aggregation_weight,

        ROUND(
            CASE
                WHEN p.forecast_weighting_decision = 'NO_FORECAST_WEIGHT'
                    THEN 0::NUMERIC
                ELSE GREATEST(
                    0::NUMERIC,
                    LEAST(
                        p.max_aggregation_weight,
                        (
                            p.forecast_dynamic_weight
                          * p.semantic_confidence_dynamic
                          * GREATEST(p.semantic_forecastability_score, 0.000)
                          * p.pillar_weight_factor
                        )
                    )
                )
            END,
            3
        ) AS final_forecast_aggregation_weight,

        ROUND(
            GREATEST(
                p.min_aggregation_weight,
                LEAST(
                    p.max_aggregation_weight,
                    (
                        p.sovereignty_dynamic_weight
                      * p.semantic_confidence_dynamic
                      * GREATEST(p.semantic_sovereignty_score, 0.050)
                      * p.pillar_weight_factor
                    )
                )
            ),
            3
        ) AS final_sovereignty_aggregation_weight,

        ROUND(
            GREATEST(
                0::NUMERIC,
                LEAST(
                    p.max_aggregation_weight,
                    (
                        p.systemic_vulnerability_weight
                      * p.vulnerability_factor
                      * GREATEST(p.semantic_sovereignty_vulnerability, 0.000)
                    )
                )
            ),
            3
        ) AS final_vulnerability_aggregation_weight

    FROM policy_joined p
),
classified AS (
    SELECT
        s.*,

        CASE
            WHEN s.strategic_weighting_class = 'WEIGHT_LOCKED_GAP'
                THEN 'AGGREGATION_LOCKED_GAP'
            WHEN s.final_isa_aggregation_weight >= 0.750
                THEN 'AGGREGATION_CORE_STRONG'
            WHEN s.final_isa_aggregation_weight >= 0.500
                THEN 'AGGREGATION_CORE_CONTROLLED'
            WHEN s.final_vulnerability_aggregation_weight >= 0.900
                THEN 'AGGREGATION_VULNERABILITY_DOMINANT'
            WHEN s.final_isa_aggregation_weight >= 0.250
                THEN 'AGGREGATION_CONTEXTUAL'
            ELSE 'AGGREGATION_WEAK_SIGNAL'
        END AS dynamic_aggregation_class,

        CASE
            WHEN s.strategic_weighting_class = 'WEIGHT_LOCKED_GAP'
                THEN 'EXCLUDE_FROM_CORE_INCLUDE_AS_GAP'
            WHEN s.effective_include_in_core_isa = TRUE
             AND s.final_isa_aggregation_weight >= 0.500
                THEN 'INCLUDE_IN_CORE_ISA_DYNAMIC'
            WHEN s.effective_include_in_vulnerability_index = TRUE
             AND s.final_vulnerability_aggregation_weight >= 0.700
                THEN 'INCLUDE_IN_VULNERABILITY_INDEX'
            WHEN s.effective_include_in_core_isa = TRUE
                THEN 'INCLUDE_AS_CONTROLLED_CONTEXT'
            ELSE 'CONTEXT_ONLY_NOT_CORE'
        END AS dynamic_isa_aggregation_decision,

        CASE
            WHEN s.final_ml_aggregation_weight >= 0.650 THEN 'ML_AGGREGATION_HIGH'
            WHEN s.final_ml_aggregation_weight >= 0.400 THEN 'ML_AGGREGATION_CONTROLLED'
            ELSE 'ML_AGGREGATION_CONTEXTUAL'
        END AS dynamic_ml_aggregation_decision,

        CASE
            WHEN s.final_forecast_aggregation_weight >= 0.550 THEN 'FORECAST_AGGREGATION_READY'
            WHEN s.final_forecast_aggregation_weight > 0.000 THEN 'FORECAST_AGGREGATION_LIMITED'
            ELSE 'FORECAST_AGGREGATION_DISABLED'
        END AS dynamic_forecast_aggregation_decision,

        CASE
            WHEN s.final_vulnerability_aggregation_weight >= 1.000 THEN 'SYSTEMIC_VULNERABILITY_CRITICAL'
            WHEN s.final_vulnerability_aggregation_weight >= 0.750 THEN 'SYSTEMIC_VULNERABILITY_HIGH'
            WHEN s.final_vulnerability_aggregation_weight >= 0.500 THEN 'SYSTEMIC_VULNERABILITY_MODERATE'
            ELSE 'SYSTEMIC_VULNERABILITY_LOW'
        END AS systemic_vulnerability_class

    FROM scored s
)

SELECT
    indicator_code,
    pillar_code,
    indicator_name,
    semantic_code,

    semantic_sovereignty_class,
    strategic_weighting_class,
    isa_weighting_decision,
    ml_weighting_decision,
    forecast_weighting_decision,

    semantic_confidence_dynamic,
    semantic_operational_score,
    semantic_forecastability_score,
    semantic_sovereignty_score,
    semantic_sovereignty_vulnerability,

    isa_dynamic_weight,
    ml_dynamic_weight,
    forecast_dynamic_weight,
    sovereignty_dynamic_weight,
    systemic_vulnerability_weight,

    aggregation_mode,
    pillar_weight_factor,
    isa_score_factor,
    vulnerability_factor,
    resilience_factor,
    min_aggregation_weight,
    max_aggregation_weight,

    effective_include_in_core_isa,
    effective_include_in_vulnerability_index,
    effective_include_in_resilience_index,

    final_isa_aggregation_weight,
    final_ml_aggregation_weight,
    final_forecast_aggregation_weight,
    final_sovereignty_aggregation_weight,
    final_vulnerability_aggregation_weight,

    dynamic_aggregation_class,
    dynamic_isa_aggregation_decision,
    dynamic_ml_aggregation_decision,
    dynamic_forecast_aggregation_decision,
    systemic_vulnerability_class,

    aggregation_policy_notes

FROM classified;
