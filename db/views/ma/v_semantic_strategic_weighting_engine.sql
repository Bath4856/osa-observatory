-- ============================================================
-- OSA / ISA — P7B6
-- View: ma.v_semantic_strategic_weighting_engine
-- Purpose:
--   Convert P7B5 semantic sovereignty signals into dynamic weights:
--     - ISA dynamic weight
--     - ML dynamic weight
--     - Forecast dynamic weight
--     - Sovereignty dynamic weight
--     - Systemic vulnerability weight
--
-- Contract:
--   Uses ONLY validated P7B5 view:
--     ma.v_semantic_sovereignty_engine
--   and RF policy:
--     rf.semantic_weighting_policy
-- ============================================================

CREATE OR REPLACE VIEW ma.v_semantic_strategic_weighting_engine AS

WITH base AS (
    SELECT
        s.indicator_code,
        s.pillar_code,
        s.indicator_name,
        s.semantic_code,

        s.semantic_confidence_dynamic,
        s.semantic_operational_score,
        s.semantic_forecastability_score,
        s.semantic_sovereignty_score,
        s.semantic_sovereignty_vulnerability,
        s.semantic_sovereignty_class,
        s.isa_sovereignty_decision,
        s.sovereignty_reason,

        s.semantic_operational_status,
        s.isa_operational_decision,
        s.l2_imputation_decision,
        s.ml_operational_decision,

        s.semantic_forecast_status,
        s.ml_forecast_decision,
        s.allowed_forecast_horizon_years,

        s.matrix_sovereignty_weight,
        s.physicality_score,
        s.dependency_score,
        s.resilience_score,
        s.strategic_priority,
        s.ml_priority,
        s.volatility_class,
        s.risk_profile,
        s.sovereignty_role

    FROM ma.v_semantic_sovereignty_engine s
),

policy_joined AS (
    SELECT
        b.*,

        COALESCE(p.isa_base_weight, 0.700)::NUMERIC AS isa_base_weight,
        COALESCE(p.ml_base_weight, 0.700)::NUMERIC AS ml_base_weight,
        COALESCE(p.forecast_base_weight, 0.650)::NUMERIC AS forecast_base_weight,
        COALESCE(p.sovereignty_base_weight, 0.750)::NUMERIC AS sovereignty_base_weight,
        COALESCE(p.vulnerability_base_weight, 0.500)::NUMERIC AS vulnerability_base_weight,

        COALESCE(p.strong_sovereignty_bonus, 0.080)::NUMERIC AS strong_sovereignty_bonus,
        COALESCE(p.controlled_sovereignty_bonus, 0.040)::NUMERIC AS controlled_sovereignty_bonus,
        COALESCE(p.locked_gap_penalty, 0.200)::NUMERIC AS locked_gap_penalty,
        COALESCE(p.weak_signal_penalty, 0.120)::NUMERIC AS weak_signal_penalty,
        COALESCE(p.dependency_penalty_factor, 0.080)::NUMERIC AS dependency_penalty_factor,
        COALESCE(p.vulnerability_amplifier, 0.250)::NUMERIC AS vulnerability_amplifier,

        COALESCE(p.normalization_mode, 'CONFIDENCE_AWARE') AS normalization_mode,
        COALESCE(p.weighting_mode, 'DYNAMIC_SEMANTIC') AS weighting_mode,
        p.notes AS weighting_policy_notes

    FROM base b
    LEFT JOIN rf.semantic_weighting_policy p
        ON p.semantic_code = b.semantic_code
),

signals AS (
    SELECT
        p.*,

        CASE
            WHEN p.semantic_sovereignty_class = 'SOVEREIGNTY_STRONG'
                THEN p.strong_sovereignty_bonus
            ELSE 0::NUMERIC
        END AS applied_strong_sovereignty_bonus,

        CASE
            WHEN p.semantic_sovereignty_class = 'SOVEREIGNTY_CONTROLLED'
                THEN p.controlled_sovereignty_bonus
            ELSE 0::NUMERIC
        END AS applied_controlled_sovereignty_bonus,

        CASE
            WHEN p.semantic_sovereignty_class = 'SOVEREIGNTY_GAP_LOCKED'
              OR p.semantic_operational_status = 'OPERATION_LOCKED_REVIEW'
              OR p.isa_sovereignty_decision = 'USE_AS_STRUCTURAL_GAP'
                THEN p.locked_gap_penalty
            ELSE 0::NUMERIC
        END AS applied_locked_gap_penalty,

        CASE
            WHEN p.semantic_sovereignty_class IN ('SOVEREIGNTY_WEAK_SIGNAL', 'SOVEREIGNTY_FRAGILE_BUT_INFORMATIVE')
                THEN p.weak_signal_penalty
            ELSE 0::NUMERIC
        END AS applied_weak_signal_penalty,

        ROUND((p.dependency_score * p.dependency_penalty_factor)::NUMERIC, 3)
            AS applied_dependency_penalty,

        ROUND((p.semantic_sovereignty_vulnerability * p.vulnerability_amplifier)::NUMERIC, 3)
            AS applied_vulnerability_amplification,

        CASE
            WHEN p.semantic_forecast_status IN ('FORECAST_DISABLED', 'FORECAST_DISABLED_REVIEW')
              OR p.ml_forecast_decision IN ('NO_FORECAST_UNTIL_REVIEW', 'NO_FORECAST_EVENT_OR_POLICY')
                THEN 1
            ELSE 0
        END AS forecast_disabled_flag,

        CASE
            WHEN p.semantic_operational_status = 'OPERATION_LOCKED_REVIEW'
                THEN 1
            ELSE 0
        END AS locked_review_flag

    FROM policy_joined p
),

weights_raw AS (
    SELECT
        s.*,

        ROUND(
            (
                s.isa_base_weight
                * (
                    0.30 * s.semantic_sovereignty_score
                  + 0.22 * s.semantic_confidence_dynamic
                  + 0.18 * s.semantic_operational_score
                  + 0.12 * s.semantic_forecastability_score
                  + 0.18 * s.strategic_priority
                )
                + s.applied_strong_sovereignty_bonus
                + s.applied_controlled_sovereignty_bonus
                - s.applied_locked_gap_penalty
                - s.applied_weak_signal_penalty
                - s.applied_dependency_penalty
            )::NUMERIC,
            3
        ) AS isa_dynamic_weight_raw,

        ROUND(
            (
                s.ml_base_weight
                * (
                    0.25 * s.ml_priority
                  + 0.20 * s.semantic_confidence_dynamic
                  + 0.20 * s.semantic_operational_score
                  + 0.15 * s.semantic_forecastability_score
                  + 0.20 * s.semantic_sovereignty_score
                )
                - CASE WHEN s.ml_operational_decision = 'ML_USE_AS_CONTEXT_ONLY' THEN 0.120 ELSE 0::NUMERIC END
                - CASE WHEN s.forecast_disabled_flag = 1 THEN 0.100 ELSE 0::NUMERIC END
                - s.applied_locked_gap_penalty * 0.50
            )::NUMERIC,
            3
        ) AS ml_dynamic_weight_raw,

        ROUND(
            (
                CASE
                    WHEN s.forecast_disabled_flag = 1 THEN 0::NUMERIC
                    ELSE
                        s.forecast_base_weight
                        * (
                            0.35 * s.semantic_forecastability_score
                          + 0.25 * s.semantic_confidence_dynamic
                          + 0.20 * s.semantic_operational_score
                          + 0.20 * s.semantic_sovereignty_score
                        )
                        - s.applied_weak_signal_penalty * 0.50
                END
            )::NUMERIC,
            3
        ) AS forecast_dynamic_weight_raw,

        ROUND(
            (
                s.sovereignty_base_weight
                * (
                    0.45 * s.semantic_sovereignty_score
                  + 0.20 * s.matrix_sovereignty_weight
                  + 0.15 * s.semantic_confidence_dynamic
                  + 0.10 * s.resilience_score
                  + 0.10 * (1::NUMERIC - s.dependency_score)
                )
                + s.applied_strong_sovereignty_bonus
                + s.applied_controlled_sovereignty_bonus
                - s.applied_locked_gap_penalty
                - s.applied_dependency_penalty
            )::NUMERIC,
            3
        ) AS sovereignty_dynamic_weight_raw,

        ROUND(
            LEAST(
                1.250::NUMERIC,
                GREATEST(
                    0.000::NUMERIC,
                    (
                        s.vulnerability_base_weight
                      + s.applied_vulnerability_amplification
                      + s.dependency_score * 0.200
                      + CASE WHEN s.locked_review_flag = 1 THEN 0.180 ELSE 0::NUMERIC END
                      + CASE WHEN s.semantic_code IN ('EVENT', 'PRESSURE', 'DEPENDENCY') THEN 0.120 ELSE 0::NUMERIC END
                      - s.resilience_score * 0.100
                    )
                )
            )::NUMERIC,
            3
        ) AS systemic_vulnerability_weight

    FROM signals s
),

weights_final AS (
    SELECT
        w.*,

        ROUND(GREATEST(0.050::NUMERIC, LEAST(1.250::NUMERIC, w.isa_dynamic_weight_raw))::NUMERIC, 3)
            AS isa_dynamic_weight,

        ROUND(GREATEST(0.000::NUMERIC, LEAST(1.200::NUMERIC, w.ml_dynamic_weight_raw))::NUMERIC, 3)
            AS ml_dynamic_weight,

        ROUND(GREATEST(0.000::NUMERIC, LEAST(1.100::NUMERIC, w.forecast_dynamic_weight_raw))::NUMERIC, 3)
            AS forecast_dynamic_weight,

        ROUND(GREATEST(0.050::NUMERIC, LEAST(1.250::NUMERIC, w.sovereignty_dynamic_weight_raw))::NUMERIC, 3)
            AS sovereignty_dynamic_weight

    FROM weights_raw w
),

classified AS (
    SELECT
        f.*,

        CASE
            WHEN f.locked_review_flag = 1
                THEN 'WEIGHT_LOCKED_GAP'

            WHEN f.isa_dynamic_weight >= 0.850
             AND f.sovereignty_dynamic_weight >= 0.850
                THEN 'WEIGHT_CORE_STRONG'

            WHEN f.isa_dynamic_weight >= 0.700
                THEN 'WEIGHT_CORE_CONTROLLED'

            WHEN f.systemic_vulnerability_weight >= 0.750
                THEN 'WEIGHT_VULNERABILITY_SIGNAL'

            WHEN f.isa_dynamic_weight >= 0.500
                THEN 'WEIGHT_MONITORED'

            ELSE 'WEIGHT_CONTEXTUAL'
        END AS strategic_weighting_class,

        CASE
            WHEN f.locked_review_flag = 1
                THEN 'USE_AS_GAP_NOT_CORE_WEIGHT'

            WHEN f.isa_dynamic_weight >= 0.850
                THEN 'USE_AS_CORE_ISA_WEIGHT'

            WHEN f.isa_dynamic_weight >= 0.650
                THEN 'USE_AS_CONTROLLED_ISA_WEIGHT'

            WHEN f.systemic_vulnerability_weight >= 0.700
                THEN 'USE_AS_VULNERABILITY_WEIGHT'

            ELSE 'USE_AS_CONTEXTUAL_WEIGHT'
        END AS isa_weighting_decision,

        CASE
            WHEN f.forecast_dynamic_weight = 0
                THEN 'NO_FORECAST_WEIGHT'

            WHEN f.forecast_dynamic_weight >= 0.700
                THEN 'FORECAST_WEIGHT_STRONG'

            WHEN f.forecast_dynamic_weight >= 0.450
                THEN 'FORECAST_WEIGHT_LIMITED'

            ELSE 'FORECAST_WEIGHT_CONTEXTUAL'
        END AS forecast_weighting_decision,

        CASE
            WHEN f.ml_dynamic_weight >= 0.800
                THEN 'ML_WEIGHT_HIGH'

            WHEN f.ml_dynamic_weight >= 0.550
                THEN 'ML_WEIGHT_CONTROLLED'

            WHEN f.ml_dynamic_weight > 0
                THEN 'ML_WEIGHT_CONTEXTUAL'

            ELSE 'ML_WEIGHT_DISABLED'
        END AS ml_weighting_decision

    FROM weights_final f
)

SELECT
    indicator_code,
    pillar_code,
    indicator_name,
    semantic_code,

    semantic_confidence_dynamic,
    semantic_operational_score,
    semantic_forecastability_score,
    semantic_sovereignty_score,
    semantic_sovereignty_vulnerability,
    semantic_sovereignty_class,
    isa_sovereignty_decision,
    sovereignty_reason,

    isa_dynamic_weight,
    ml_dynamic_weight,
    forecast_dynamic_weight,
    sovereignty_dynamic_weight,
    systemic_vulnerability_weight,

    strategic_weighting_class,
    isa_weighting_decision,
    forecast_weighting_decision,
    ml_weighting_decision,

    semantic_operational_status,
    isa_operational_decision,
    l2_imputation_decision,
    ml_operational_decision,

    semantic_forecast_status,
    ml_forecast_decision,
    allowed_forecast_horizon_years,

    matrix_sovereignty_weight,
    physicality_score,
    dependency_score,
    resilience_score,
    strategic_priority,
    ml_priority,
    volatility_class,
    risk_profile,
    sovereignty_role,

    isa_base_weight,
    ml_base_weight,
    forecast_base_weight,
    sovereignty_base_weight,
    vulnerability_base_weight,

    applied_strong_sovereignty_bonus,
    applied_controlled_sovereignty_bonus,
    applied_locked_gap_penalty,
    applied_weak_signal_penalty,
    applied_dependency_penalty,
    applied_vulnerability_amplification,

    forecast_disabled_flag,
    locked_review_flag,
    normalization_mode,
    weighting_mode,
    weighting_policy_notes

FROM classified;
