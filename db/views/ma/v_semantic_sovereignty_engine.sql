-- ============================================================
-- OSA / ISA — P7B5
-- View: ma.v_semantic_sovereignty_engine
-- ============================================================

CREATE OR REPLACE VIEW ma.v_semantic_sovereignty_engine AS

WITH base AS (
    SELECT
        f.indicator_code,
        f.pillar_code,
        f.indicator_name,
        f.semantic_code,

        f.semantic_confidence_dynamic,
        f.semantic_operational_score,
        f.semantic_forecastability_score,

        f.semantic_operational_status,
        f.isa_operational_decision,
        f.l2_imputation_decision,
        f.ml_operational_decision,

        f.semantic_forecast_status,
        f.ml_forecast_decision,
        f.allowed_forecast_horizon_years,

        -- colonnes enrichies depuis v_semantic_operational_policy_engine
        COALESCE(o.matrix_sovereignty_weight, 0.700)::NUMERIC AS matrix_sovereignty_weight,
        COALESCE(o.physicality_score,  0.500)::NUMERIC AS physicality_score,
        COALESCE(o.dependency_score,   0.500)::NUMERIC AS dependency_score,
        COALESCE(o.resilience_score,   0.500)::NUMERIC AS resilience_score,
        COALESCE(o.strategic_priority, 0.700)::NUMERIC AS strategic_priority,
        COALESCE(o.p7b1_ml_priority,   0.750)::NUMERIC AS ml_priority,
        COALESCE(o.volatility_class,  'MEDIUM')         AS volatility_class,
        COALESCE(o.risk_profile,      'GENERAL_RISK')   AS risk_profile

    FROM ma.v_semantic_forecastability_engine f
    LEFT JOIN ma.v_semantic_operational_policy_engine o
        ON o.indicator_code = f.indicator_code
),

policy_joined AS (
    SELECT
        b.*,

        COALESCE(p.sovereignty_floor, 0.300)::NUMERIC AS sovereignty_floor,
        COALESCE(p.sovereignty_ceiling, 0.950)::NUMERIC AS sovereignty_ceiling,
        COALESCE(p.base_sovereignty_weight, b.matrix_sovereignty_weight, 0.700)::NUMERIC AS base_sovereignty_weight,
        COALESCE(p.physicality_boost, 0.000)::NUMERIC AS physicality_boost,
        COALESCE(p.resilience_boost, 0.000)::NUMERIC AS resilience_boost,
        COALESCE(p.dependency_penalty, 0.000)::NUMERIC AS dependency_penalty,
        COALESCE(p.locked_review_penalty, 0.120)::NUMERIC AS locked_review_penalty,
        COALESCE(p.forecast_disabled_penalty, 0.060)::NUMERIC AS forecast_disabled_penalty,
        COALESCE(p.weak_confidence_penalty, 0.050)::NUMERIC AS weak_confidence_penalty,
        COALESCE(p.sovereignty_role, 'GENERAL_SIGNAL') AS sovereignty_role,
        p.notes AS sovereignty_policy_notes

    FROM base b
    LEFT JOIN rf.semantic_sovereignty_policy p
        ON p.semantic_code = b.semantic_code
),

scored AS (
    SELECT
        p.*,

        CASE WHEN p.physicality_score >= 0.800
            THEN p.physicality_boost ELSE 0::NUMERIC
        END AS applied_physicality_boost,

        CASE WHEN p.resilience_score >= 0.700
            THEN p.resilience_boost ELSE 0::NUMERIC
        END AS applied_resilience_boost,

        CASE WHEN p.dependency_score >= 0.700
            THEN p.dependency_penalty ELSE 0::NUMERIC
        END AS applied_dependency_penalty,

        CASE WHEN p.semantic_operational_status = 'OPERATION_LOCKED_REVIEW'
              OR p.isa_operational_decision = 'ISA_INCLUDE_AS_GAP_LOCKED'
            THEN p.locked_review_penalty ELSE 0::NUMERIC
        END AS applied_locked_review_penalty,

        CASE WHEN p.semantic_forecast_status IN ('FORECAST_DISABLED','FORECAST_DISABLED_REVIEW')
              OR p.ml_forecast_decision IN ('NO_FORECAST_UNTIL_REVIEW','NO_FORECAST_EVENT_OR_POLICY')
            THEN p.forecast_disabled_penalty ELSE 0::NUMERIC
        END AS applied_forecast_disabled_penalty,

        CASE WHEN p.semantic_confidence_dynamic < 0.650
            THEN p.weak_confidence_penalty ELSE 0::NUMERIC
        END AS applied_weak_confidence_penalty

    FROM policy_joined p
),

calc AS (
    SELECT
        s.*,

        ROUND(GREATEST(s.sovereignty_floor, LEAST(s.sovereignty_ceiling, (
            s.base_sovereignty_weight    * 0.30
          + s.matrix_sovereignty_weight  * 0.20
          + s.semantic_confidence_dynamic * 0.15
          + s.semantic_operational_score  * 0.15
          + s.semantic_forecastability_score * 0.10
          + s.strategic_priority          * 0.10
          + s.applied_physicality_boost
          + s.applied_resilience_boost
          - s.applied_dependency_penalty
          - s.applied_locked_review_penalty
          - s.applied_forecast_disabled_penalty
          - s.applied_weak_confidence_penalty
        )))::NUMERIC, 3) AS semantic_sovereignty_score

    FROM scored s
),

finalized AS (
    SELECT
        c.*,

        ROUND(LEAST(1::NUMERIC, GREATEST(0::NUMERIC, (
            (1::NUMERIC - c.semantic_sovereignty_score) * 0.50
          + c.dependency_score * 0.25
          + CASE WHEN c.semantic_operational_status = 'OPERATION_LOCKED_REVIEW'
              OR c.semantic_forecast_status = 'FORECAST_DISABLED_REVIEW'
            THEN 0.15 ELSE 0::NUMERIC END
          + CASE WHEN c.semantic_code IN ('DEPENDENCY','PRESSURE','EVENT')
            THEN 0.10 ELSE 0::NUMERIC END
        )))::NUMERIC, 3) AS semantic_sovereignty_vulnerability,

        CASE
            WHEN c.semantic_operational_status = 'OPERATION_LOCKED_REVIEW'
                THEN 'SOVEREIGNTY_GAP_LOCKED'
            WHEN c.semantic_sovereignty_score >= 0.850
                THEN 'SOVEREIGNTY_STRONG'
            WHEN c.semantic_sovereignty_score >= 0.700
                THEN 'SOVEREIGNTY_CONTROLLED'
            WHEN c.semantic_sovereignty_score >= 0.550
                THEN 'SOVEREIGNTY_FRAGILE_BUT_INFORMATIVE'
            ELSE 'SOVEREIGNTY_WEAK_SIGNAL'
        END AS semantic_sovereignty_class,

        CASE
            WHEN c.semantic_operational_status = 'OPERATION_LOCKED_REVIEW'
                THEN 'USE_AS_STRUCTURAL_GAP'
            WHEN c.semantic_sovereignty_score >= 0.750
                THEN 'USE_IN_ISA_WEIGHTED_CORE'
            WHEN c.semantic_sovereignty_score >= 0.600
                THEN 'USE_IN_ISA_WITH_MONITORING'
            ELSE 'USE_AS_CONTEXTUAL_VULNERABILITY'
        END AS isa_sovereignty_decision,

        CASE
            WHEN c.semantic_operational_status = 'OPERATION_LOCKED_REVIEW'
                THEN 'LOCKED_OPERATIONAL_REVIEW'
            WHEN c.semantic_forecast_status IN ('FORECAST_DISABLED','FORECAST_DISABLED_REVIEW')
                THEN 'LOW_OR_DISABLED_FORECASTABILITY'
            WHEN c.dependency_score >= 0.700
                THEN 'HIGH_DEPENDENCY_EXPOSURE'
            WHEN c.semantic_confidence_dynamic < 0.650
                THEN 'LOW_DYNAMIC_CONFIDENCE'
            ELSE 'SOVEREIGNTY_SIGNAL_GOVERNED'
        END AS sovereignty_reason

    FROM calc c
)

SELECT
    indicator_code, pillar_code, indicator_name, semantic_code,
    semantic_confidence_dynamic, semantic_operational_score, semantic_forecastability_score,
    semantic_sovereignty_score, semantic_sovereignty_vulnerability,
    semantic_sovereignty_class, isa_sovereignty_decision, sovereignty_reason,
    semantic_operational_status, isa_operational_decision,
    l2_imputation_decision, ml_operational_decision,
    semantic_forecast_status, ml_forecast_decision, allowed_forecast_horizon_years,
    matrix_sovereignty_weight, physicality_score, dependency_score,
    resilience_score, strategic_priority, ml_priority, volatility_class, risk_profile,
    sovereignty_role, sovereignty_floor, sovereignty_ceiling, base_sovereignty_weight,
    physicality_boost, resilience_boost, dependency_penalty,
    locked_review_penalty, forecast_disabled_penalty, weak_confidence_penalty,
    applied_physicality_boost, applied_resilience_boost, applied_dependency_penalty,
    applied_locked_review_penalty, applied_forecast_disabled_penalty,
    applied_weak_confidence_penalty, sovereignty_policy_notes
FROM finalized;
