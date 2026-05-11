-- ============================================================
-- OSA / ISA — P7B2
-- View: ma.v_semantic_confidence_engine
-- Purpose:
--   Dynamic semantic confidence engine.
--
-- Depends on:
--   ma.v_signal_semantic_engine_v3
--   rf.semantic_governance_matrix
--   rf.semantic_confidence_policy
--
-- Important:
--   rf.semantic_confidence_policy uses:
--     base_confidence_floor / ceiling
--     physical_penalty
--     event_penalty
--     critical_review_penalty
--     weak_governance_penalty
--     hybrid_bonus
--     strategic_bonus
--     governed_bonus
--     ml_priority_bonus
--     volatility_penalty
-- ============================================================

CREATE OR REPLACE VIEW ma.v_semantic_confidence_engine AS

WITH base_semantic AS (
    SELECT
        s.indicator_code,
        s.pillar_code,
        s.indicator_name,
        s.nature_code,

        s.semantic_code,
        s.secondary_semantic_code,
        s.tertiary_semantic_code,

        COALESCE(s.semantic_confidence, 0.650)::NUMERIC AS semantic_confidence_base,
        s.semantic_source,
        s.hybrid_rule_code,
        s.hybrid_rationale,

        COALESCE(s.dominance_weight, 1.000)::NUMERIC AS dominance_weight,
        COALESCE(s.hybrid_weight, 0.000)::NUMERIC AS hybrid_weight,
        COALESCE(s.strategic_criticality, 0.500)::NUMERIC AS strategic_criticality,

        COALESCE(s.semantic_sovereignty_weight, 0.800)::NUMERIC AS p7a_sovereignty_weight,
        COALESCE(s.semantic_forecastability, 0.650)::NUMERIC AS p7a_forecastability,

        s.p7a2_semantic_code,
        s.p7a2_semantic_confidence,
        s.p7a2_status,

        s.semantic_governance_status,
        s.next_action

    FROM ma.v_signal_semantic_engine_v3 s
),

governed AS (
    SELECT
        b.*,

        COALESCE(g.trust_level, 0.700)::NUMERIC AS matrix_trust_level,
        COALESCE(g.sovereignty_weight, b.p7a_sovereignty_weight, 0.800)::NUMERIC AS matrix_sovereignty_weight,
        COALESCE(g.volatility_class, 'MEDIUM') AS volatility_class,
        COALESCE(g.forecastability, b.p7a_forecastability, 0.650)::NUMERIC AS matrix_forecastability,
        COALESCE(g.imputation_policy, 'MODERATE') AS imputation_policy,
        COALESCE(g.ml_priority, 0.750)::NUMERIC AS ml_priority,
        COALESCE(g.risk_profile, 'GENERAL_RISK') AS risk_profile,
        COALESCE(g.physicality_score, 0.500)::NUMERIC AS physicality_score,
        COALESCE(g.dependency_score, 0.500)::NUMERIC AS dependency_score,
        COALESCE(g.resilience_score, 0.500)::NUMERIC AS resilience_score,
        COALESCE(g.strategic_priority, 0.700)::NUMERIC AS strategic_priority,
        COALESCE(g.governance_mode, 'MODERATE') AS governance_mode

    FROM base_semantic b
    LEFT JOIN rf.semantic_governance_matrix g
        ON g.semantic_code = b.semantic_code
),

policy_joined AS (
    SELECT
        gov.*,

        COALESCE(p.base_confidence_floor, 0.300)::NUMERIC AS base_confidence_floor,
        COALESCE(p.base_confidence_ceiling, 0.980)::NUMERIC AS base_confidence_ceiling,
        COALESCE(p.physical_penalty, 0.000)::NUMERIC AS physical_penalty,
        COALESCE(p.event_penalty, 0.000)::NUMERIC AS event_penalty,
        COALESCE(p.critical_review_penalty, 0.200)::NUMERIC AS critical_review_penalty,
        COALESCE(p.weak_governance_penalty, 0.080)::NUMERIC AS weak_governance_penalty,
        COALESCE(p.hybrid_bonus, 0.000)::NUMERIC AS hybrid_bonus,
        COALESCE(p.strategic_bonus, 0.000)::NUMERIC AS strategic_bonus,
        COALESCE(p.governed_bonus, 0.000)::NUMERIC AS governed_bonus,
        COALESCE(p.ml_priority_bonus, 0.000)::NUMERIC AS ml_priority_bonus,
        COALESCE(p.volatility_penalty, 0.000)::NUMERIC AS volatility_penalty,
        p.notes AS confidence_policy_notes

    FROM governed gov
    LEFT JOIN rf.semantic_confidence_policy p
        ON p.semantic_code = gov.semantic_code
),

scored AS (
    SELECT
        p.*,

        CASE
            WHEN p.secondary_semantic_code IS NOT NULL
              OR p.tertiary_semantic_code IS NOT NULL
              OR p.hybrid_rule_code IS NOT NULL
                THEN p.hybrid_bonus
            ELSE 0::NUMERIC
        END AS applied_hybrid_bonus,

        CASE
            WHEN p.semantic_governance_status IN ('OK_STRATEGIC', 'OK_MULTI_SEMANTIC')
                THEN p.strategic_bonus
            ELSE 0::NUMERIC
        END AS applied_strategic_bonus,

        CASE
            WHEN p.semantic_governance_status IN ('OK_STRATEGIC', 'OK_HYBRID', 'OK_MULTI_SEMANTIC')
                THEN p.governed_bonus
            ELSE 0::NUMERIC
        END AS applied_governed_bonus,

        CASE
            WHEN p.ml_priority >= 0.800
                THEN p.ml_priority_bonus
            ELSE 0::NUMERIC
        END AS applied_ml_priority_bonus,

        CASE
            WHEN p.semantic_governance_status = 'CRITICAL_SEMANTIC_REVIEW'
                THEN p.critical_review_penalty
            ELSE 0::NUMERIC
        END AS applied_critical_review_penalty,

        CASE
            WHEN p.semantic_code = 'PHYSICAL'
             AND p.semantic_governance_status = 'CRITICAL_SEMANTIC_REVIEW'
                THEN p.physical_penalty
            ELSE 0::NUMERIC
        END AS applied_physical_penalty,

        CASE
            WHEN p.semantic_code = 'EVENT'
                THEN p.event_penalty
            ELSE 0::NUMERIC
        END AS applied_event_penalty,

        CASE
            WHEN p.semantic_governance_status IN ('CRITICAL_SEMANTIC_REVIEW')
              OR p.next_action = 'MANUAL_REVIEW_REQUIRED'
                THEN p.weak_governance_penalty
            ELSE 0::NUMERIC
        END AS applied_weak_governance_penalty,

        CASE
            WHEN p.volatility_class = 'HIGH'
                THEN p.volatility_penalty
            ELSE 0::NUMERIC
        END AS applied_volatility_penalty

    FROM policy_joined p
),

confidence_calc AS (
    SELECT
        s.*,

        ROUND(
            GREATEST(
                s.base_confidence_floor,
                LEAST(
                    s.base_confidence_ceiling,
                    (
                        s.semantic_confidence_base

                      + s.applied_hybrid_bonus
                      + s.applied_strategic_bonus
                      + s.applied_governed_bonus
                      + s.applied_ml_priority_bonus

                      - s.applied_critical_review_penalty
                      - s.applied_physical_penalty
                      - s.applied_event_penalty
                      - s.applied_weak_governance_penalty
                      - s.applied_volatility_penalty
                    )
                )
            )::NUMERIC,
            3
        ) AS semantic_confidence_dynamic

    FROM scored s
),

finalized AS (
    SELECT
        c.*,

        ROUND(
            (
                c.semantic_confidence_dynamic * 0.45
              + c.matrix_trust_level          * 0.20
              + c.matrix_sovereignty_weight   * 0.15
              + c.strategic_priority          * 0.10
              + c.ml_priority                 * 0.10
            )::NUMERIC,
            3
        ) AS semantic_confidence_score,

        CASE
            WHEN c.semantic_governance_status = 'CRITICAL_SEMANTIC_REVIEW'
                THEN 'CONFIDENCE_REVIEW_REQUIRED'

            WHEN c.semantic_confidence_dynamic >= 0.850
                THEN 'HIGH_CONFIDENCE'

            WHEN c.semantic_confidence_dynamic >= 0.700
                THEN 'CONTROLLED_CONFIDENCE'

            WHEN c.semantic_confidence_dynamic >= 0.550
                THEN 'WEAK_BUT_USABLE_CONFIDENCE'

            ELSE 'LOW_CONFIDENCE'
        END AS semantic_confidence_class,

        CASE
            WHEN c.semantic_governance_status = 'CRITICAL_SEMANTIC_REVIEW'
             AND c.semantic_code = 'PHYSICAL'
                THEN 'LOCK_FOR_PHYSICAL_REVIEW'

            WHEN c.semantic_governance_status = 'CRITICAL_SEMANTIC_REVIEW'
                THEN 'REVIEW_BEFORE_OPERATIONAL_USE'

            WHEN c.semantic_confidence_dynamic >= 0.750
                THEN 'READY_FOR_OPERATIONAL_USE'

            WHEN c.semantic_confidence_dynamic >= 0.600
                THEN 'READY_WITH_MONITORING'

            ELSE 'LIMITED_USE_ONLY'
        END AS semantic_confidence_decision,

        CASE
            WHEN c.semantic_code = 'PHYSICAL'
             AND c.semantic_governance_status = 'CRITICAL_SEMANTIC_REVIEW'
                THEN 'PHYSICAL_SIGNAL_REQUIRES_CERTIFIED_SOURCE'

            WHEN c.semantic_source = 'PILLAR_DEFAULT_HEURISTIC'
                THEN 'LOW_SOURCE_SPECIFICITY'

            WHEN c.secondary_semantic_code IS NOT NULL
              OR c.tertiary_semantic_code IS NOT NULL
              OR c.hybrid_rule_code IS NOT NULL
                THEN 'HYBRID_SIGNAL_CONFIDENCE_ADJUSTED'

            WHEN c.semantic_confidence_dynamic < 0.550
                THEN 'LOW_DYNAMIC_CONFIDENCE'

            ELSE 'CONFIDENCE_ACCEPTABLE'
        END AS semantic_confidence_reason

    FROM confidence_calc c
)

SELECT
    indicator_code,
    pillar_code,
    indicator_name,
    nature_code,

    semantic_code,
    secondary_semantic_code,
    tertiary_semantic_code,

    semantic_confidence_base,
    semantic_confidence_dynamic,
    semantic_confidence_score,
    semantic_confidence_class,
    semantic_confidence_decision,
    semantic_confidence_reason,

    semantic_source,
    hybrid_rule_code,
    hybrid_rationale,

    dominance_weight,
    hybrid_weight,
    strategic_criticality,

    matrix_trust_level,
    matrix_sovereignty_weight,
    matrix_forecastability,
    volatility_class,
    imputation_policy,
    ml_priority,
    risk_profile,
    physicality_score,
    dependency_score,
    resilience_score,
    strategic_priority,
    governance_mode,

    p7a_sovereignty_weight,
    p7a_forecastability,

    base_confidence_floor,
    base_confidence_ceiling,
    physical_penalty,
    event_penalty,
    critical_review_penalty,
    weak_governance_penalty,
    hybrid_bonus,
    strategic_bonus,
    governed_bonus,
    ml_priority_bonus,
    volatility_penalty,

    applied_hybrid_bonus,
    applied_strategic_bonus,
    applied_governed_bonus,
    applied_ml_priority_bonus,
    applied_critical_review_penalty,
    applied_physical_penalty,
    applied_event_penalty,
    applied_weak_governance_penalty,
    applied_volatility_penalty,

    p7a2_semantic_code,
    p7a2_semantic_confidence,
    p7a2_status,

    semantic_governance_status,
    next_action,
    confidence_policy_notes

FROM finalized;
