-- ============================================================
-- OSA / ISA — P7D
-- View: ma.v_dynamic_scores_engine
-- Purpose:
--   Transform P7C dynamic aggregation outputs into executable
--   dynamic score components.
--
-- Source contract:
--   ma.v_semantic_dynamic_aggregation_engine
--
-- Design safeguards:
--   - Uses only validated P7C columns.
--   - No country/year join here: this is the scoring doctrine layer.
--   - COALESCE everywhere on numeric scoring inputs.
--   - Bounds scores with floors/ceilings to prevent runaway weights.
-- ============================================================

CREATE OR REPLACE VIEW ma.v_dynamic_scores_engine AS

WITH source AS (
    SELECT
        s.indicator_code,
        s.pillar_code,
        s.indicator_name,
        s.semantic_code,

        COALESCE(s.semantic_confidence_dynamic, 0.000)::NUMERIC AS semantic_confidence_dynamic,
        COALESCE(s.semantic_operational_score, 0.000)::NUMERIC AS semantic_operational_score,
        COALESCE(s.semantic_forecastability_score, 0.000)::NUMERIC AS semantic_forecastability_score,
        COALESCE(s.semantic_sovereignty_score, 0.000)::NUMERIC AS semantic_sovereignty_score,
        COALESCE(s.semantic_sovereignty_vulnerability, 0.000)::NUMERIC AS semantic_sovereignty_vulnerability,

        COALESCE(s.final_isa_aggregation_weight, 0.000)::NUMERIC AS final_isa_aggregation_weight,
        COALESCE(s.final_ml_aggregation_weight, 0.000)::NUMERIC AS final_ml_aggregation_weight,
        COALESCE(s.final_forecast_aggregation_weight, 0.000)::NUMERIC AS final_forecast_aggregation_weight,
        COALESCE(s.final_sovereignty_aggregation_weight, 0.000)::NUMERIC AS final_sovereignty_aggregation_weight,
        COALESCE(s.final_vulnerability_aggregation_weight, 0.000)::NUMERIC AS final_vulnerability_aggregation_weight,

        s.dynamic_aggregation_class,
        s.dynamic_isa_aggregation_decision,
        s.dynamic_ml_aggregation_decision,
        s.dynamic_forecast_aggregation_decision,
        s.systemic_vulnerability_class,
        s.semantic_sovereignty_class

    FROM ma.v_semantic_dynamic_aggregation_engine s
),
policy AS (
    SELECT
        src.*,
        COALESCE(p.scoring_mode, 'DEFAULT_SCORE') AS scoring_mode,
        COALESCE(p.performance_factor, 1.000)::NUMERIC AS performance_factor,
        COALESCE(p.sovereignty_factor, 1.000)::NUMERIC AS sovereignty_factor,
        COALESCE(p.vulnerability_factor, 1.000)::NUMERIC AS vulnerability_factor,
        COALESCE(p.resilience_factor, 1.000)::NUMERIC AS resilience_factor,
        COALESCE(p.forecast_factor, 1.000)::NUMERIC AS forecast_factor,
        COALESCE(p.include_in_dynamic_score, TRUE) AS include_in_dynamic_score,
        p.notes AS score_policy_notes
    FROM source src
    LEFT JOIN rf.dynamic_score_policy p
        ON p.semantic_code = src.semantic_code
),
scored AS (
    SELECT
        p.*,

        ROUND(
            LEAST(
                1.500,
                GREATEST(
                    0.000,
                    p.final_isa_aggregation_weight
                    * p.semantic_confidence_dynamic
                    * p.semantic_operational_score
                    * p.performance_factor
                )
            ),
            3
        ) AS dynamic_isa_score_component,

        ROUND(
            LEAST(
                1.500,
                GREATEST(
                    0.000,
                    p.final_sovereignty_aggregation_weight
                    * p.semantic_sovereignty_score
                    * p.sovereignty_factor
                )
            ),
            3
        ) AS dynamic_sovereignty_score_component,

        ROUND(
            LEAST(
                1.500,
                GREATEST(
                    0.000,
                    p.final_vulnerability_aggregation_weight
                    * (1.000 + p.semantic_sovereignty_vulnerability)
                    * p.vulnerability_factor
                )
            ),
            3
        ) AS dynamic_vulnerability_score_component,

        ROUND(
            LEAST(
                1.500,
                GREATEST(
                    0.000,
                    (
                        p.final_isa_aggregation_weight
                        * p.semantic_operational_score
                        * p.resilience_factor
                    )
                    - (
                        p.final_vulnerability_aggregation_weight
                        * p.semantic_sovereignty_vulnerability
                        * 0.250
                    )
                )
            ),
            3
        ) AS dynamic_resilience_score_component,

        ROUND(
            LEAST(
                1.500,
                GREATEST(
                    0.000,
                    p.final_forecast_aggregation_weight
                    * p.semantic_forecastability_score
                    * p.forecast_factor
                )
            ),
            3
        ) AS dynamic_forecast_score_component,

        ROUND(
            LEAST(
                1.500,
                GREATEST(
                    0.000,
                    p.final_ml_aggregation_weight
                    * p.semantic_confidence_dynamic
                    * COALESCE(NULLIF(p.semantic_operational_score, 0), 0.500)
                )
            ),
            3
        ) AS dynamic_ml_score_component

    FROM policy p
),
finalized AS (
    SELECT
        s.*,

        CASE
            WHEN s.dynamic_aggregation_class = 'AGGREGATION_LOCKED_GAP'
                THEN 'DYNAMIC_SCORE_LOCKED_GAP'
            WHEN s.dynamic_isa_aggregation_decision = 'INCLUDE_IN_CORE_ISA_DYNAMIC'
             AND s.dynamic_isa_score_component >= 0.650
                THEN 'DYNAMIC_SCORE_CORE_STRONG'
            WHEN s.dynamic_isa_aggregation_decision = 'INCLUDE_IN_CORE_ISA_DYNAMIC'
                THEN 'DYNAMIC_SCORE_CORE_CONTROLLED'
            WHEN s.dynamic_isa_aggregation_decision = 'INCLUDE_IN_VULNERABILITY_INDEX'
                THEN 'DYNAMIC_SCORE_VULNERABILITY_SIGNAL'
            WHEN s.dynamic_isa_aggregation_decision = 'CONTEXT_ONLY_NOT_CORE'
                THEN 'DYNAMIC_SCORE_CONTEXT_ONLY'
            ELSE 'DYNAMIC_SCORE_MONITORED'
        END AS dynamic_score_class,

        CASE
            WHEN s.dynamic_aggregation_class = 'AGGREGATION_LOCKED_GAP'
                THEN 'EXCLUDE_SCORE_UNTIL_GAP_REVIEW'
            WHEN s.include_in_dynamic_score IS TRUE
             AND s.dynamic_isa_aggregation_decision = 'INCLUDE_IN_CORE_ISA_DYNAMIC'
                THEN 'USE_IN_DYNAMIC_ISA_SCORE'
            WHEN s.dynamic_isa_aggregation_decision = 'INCLUDE_AS_CONTROLLED_CONTEXT'
                THEN 'USE_AS_CONTROLLED_SCORE_CONTEXT'
            WHEN s.dynamic_isa_aggregation_decision = 'INCLUDE_IN_VULNERABILITY_INDEX'
                THEN 'USE_IN_DYNAMIC_VULNERABILITY_SCORE'
            ELSE 'USE_AS_CONTEXTUAL_SCORE_SIGNAL'
        END AS dynamic_score_decision,

        CASE
            WHEN s.dynamic_vulnerability_score_component >= 0.900
                THEN 'SCORE_VULNERABILITY_HIGH'
            WHEN s.dynamic_vulnerability_score_component >= 0.550
                THEN 'SCORE_VULNERABILITY_MODERATE'
            ELSE 'SCORE_VULNERABILITY_LOW'
        END AS dynamic_score_vulnerability_class,

        CASE
            WHEN s.dynamic_forecast_score_component <= 0
                THEN 'SCORE_FORECAST_DISABLED'
            WHEN s.dynamic_forecast_score_component >= 0.500
                THEN 'SCORE_FORECAST_READY'
            ELSE 'SCORE_FORECAST_LIMITED'
        END AS dynamic_score_forecast_class

    FROM scored s
)
SELECT *
FROM finalized;
