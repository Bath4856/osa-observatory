-- ============================================================
-- OSA / ISA — P7B3
-- View: ma.v_semantic_operational_policy_engine
-- Role:
--   Convert P7B2 dynamic confidence into concrete ISA/ML/L2 operations.
--
-- Depends on validated P7B2:
--   ma.v_semantic_confidence_engine
--   rf.semantic_operational_policy
-- ============================================================

CREATE OR REPLACE VIEW ma.v_semantic_operational_policy_engine AS

WITH base AS (
    SELECT
        c.indicator_code,
        c.pillar_code,
        c.indicator_name,
        c.nature_code,

        c.semantic_code,
        c.secondary_semantic_code,
        c.tertiary_semantic_code,

        c.semantic_confidence_base,
        c.semantic_confidence_dynamic,
        c.semantic_confidence_score,
        c.semantic_confidence_class,
        c.semantic_confidence_decision,
        c.semantic_confidence_reason,

        c.semantic_source,
        c.hybrid_rule_code,
        c.hybrid_rationale,

        c.matrix_trust_level,
        c.matrix_sovereignty_weight,
        c.matrix_forecastability,
        c.volatility_class,
        c.imputation_policy AS p7b1_imputation_policy,
        c.ml_priority AS p7b1_ml_priority,
        c.risk_profile,
        c.physicality_score,
        c.dependency_score,
        c.resilience_score,
        c.strategic_priority,
        c.governance_mode,

        c.semantic_governance_status,
        c.next_action

    FROM ma.v_semantic_confidence_engine c
),
policy AS (
    SELECT
        b.*,

        COALESCE(p.isa_inclusion_policy, 'INCLUDE_WITH_CONFIDENCE') AS isa_inclusion_policy,
        COALESCE(p.imputation_operational_policy, 'STANDARD') AS imputation_operational_policy,
        COALESCE(p.normalization_policy, 'STANDARD') AS normalization_policy,
        COALESCE(p.aggregation_policy, 'CONFIDENCE_WEIGHTED') AS aggregation_policy,

        COALESCE(p.min_dynamic_confidence, 0.600)::NUMERIC AS min_dynamic_confidence,
        COALESCE(p.min_governance_score, 0.700)::NUMERIC AS min_governance_score,
        COALESCE(p.max_imputation_ratio, 0.350)::NUMERIC AS max_imputation_ratio,
        COALESCE(p.exclusion_warning_threshold, 0.450)::NUMERIC AS exclusion_warning_threshold,

        COALESCE(p.isa_weight_multiplier, 1.000)::NUMERIC AS isa_weight_multiplier,
        COALESCE(p.ml_weight_multiplier, 1.000)::NUMERIC AS ml_weight_multiplier,
        COALESCE(p.vulnerability_weight, 0.500)::NUMERIC AS vulnerability_weight,

        COALESCE(p.requires_certified_source, FALSE) AS requires_certified_source,
        COALESCE(p.allow_long_gap_imputation, TRUE) AS allow_long_gap_imputation,
        COALESCE(p.allow_ml_forecast, TRUE) AS allow_ml_forecast,
        COALESCE(p.requires_manual_review_if_critical, TRUE) AS requires_manual_review_if_critical,
        COALESCE(p.operational_risk_class, 'MEDIUM') AS operational_risk_class,
        p.notes AS operational_policy_notes

    FROM base b
    LEFT JOIN rf.semantic_operational_policy p
        ON p.semantic_code = b.semantic_code
),
scored AS (
    SELECT
        p.*,

        ROUND(
            LEAST(
                1.000,
                GREATEST(
                    0.000,
                    (
                        p.semantic_confidence_dynamic * 0.35
                      + p.matrix_trust_level          * 0.20
                      + p.matrix_sovereignty_weight   * 0.15
                      + p.strategic_priority          * 0.10
                      + p.p7b1_ml_priority            * 0.10
                      + (1.000 - p.dependency_score)  * 0.05
                      + p.resilience_score            * 0.05
                    )
                )
            )::NUMERIC,
            3
        ) AS semantic_operational_score,

        ROUND(
            LEAST(
                1.500,
                GREATEST(
                    0.000,
                    p.semantic_confidence_dynamic
                    * p.matrix_sovereignty_weight
                    * p.isa_weight_multiplier
                )
            )::NUMERIC,
            3
        ) AS isa_semantic_weight,

        ROUND(
            LEAST(
                1.500,
                GREATEST(
                    0.000,
                    p.semantic_confidence_dynamic
                    * p.p7b1_ml_priority
                    * p.ml_weight_multiplier
                )
            )::NUMERIC,
            3
        ) AS ml_semantic_weight,

        ROUND(
            LEAST(
                1.000,
                GREATEST(
                    0.000,
                    (
                        (1.000 - p.semantic_confidence_dynamic) * 0.40
                      + p.dependency_score * 0.25
                      + p.physicality_score * CASE WHEN p.semantic_governance_status = 'CRITICAL_SEMANTIC_REVIEW' THEN 0.20 ELSE 0.05 END
                      + p.vulnerability_weight * 0.15
                    )
                )
            )::NUMERIC,
            3
        ) AS semantic_operational_vulnerability

    FROM policy p
),
finalized AS (
    SELECT
        s.*,

        CASE
            WHEN s.semantic_governance_status = 'CRITICAL_SEMANTIC_REVIEW'
             AND s.requires_manual_review_if_critical
                THEN 'OPERATION_LOCKED_REVIEW'

            WHEN s.semantic_confidence_dynamic < s.min_dynamic_confidence
                THEN 'OPERATION_LIMITED_LOW_CONFIDENCE'

            WHEN s.semantic_operational_score >= 0.820
                THEN 'OPERATION_READY_STRONG'

            WHEN s.semantic_operational_score >= 0.700
                THEN 'OPERATION_READY_CONTROLLED'

            ELSE 'OPERATION_MONITOR'
        END AS semantic_operational_status,

        CASE
            WHEN s.semantic_governance_status = 'CRITICAL_SEMANTIC_REVIEW'
             AND s.requires_certified_source
                THEN 'ISA_INCLUDE_AS_GAP_LOCKED'

            WHEN s.semantic_confidence_dynamic < s.exclusion_warning_threshold
                THEN 'ISA_INCLUDE_AS_WEAK_SIGNAL'

            WHEN s.isa_inclusion_policy = 'INCLUDE_AS_VULNERABILITY'
                THEN 'ISA_INCLUDE_VULNERABILITY_SIGNAL'

            WHEN s.isa_inclusion_policy = 'INCLUDE_AS_RISK'
                THEN 'ISA_INCLUDE_RISK_SIGNAL'

            WHEN s.isa_inclusion_policy = 'INCLUDE_AS_EVENT_SIGNAL'
                THEN 'ISA_INCLUDE_EVENT_SIGNAL'

            ELSE 'ISA_INCLUDE_CONFIDENCE_WEIGHTED'
        END AS isa_operational_decision,

        CASE
            WHEN s.semantic_governance_status = 'CRITICAL_SEMANTIC_REVIEW'
             AND s.requires_certified_source
                THEN 'NO_IMPUTATION_CERTIFICATION_REQUIRED'

            WHEN s.imputation_operational_policy IN ('VERY_STRICT', 'STRICT_LIMITED')
                THEN 'IMPUTE_ONLY_SHORT_GAPS'

            WHEN s.imputation_operational_policy IN ('STRICT_STABLE', 'CAUTIOUS')
                THEN 'IMPUTE_WITH_STRICT_CONTROLS'

            WHEN s.imputation_operational_policy IN ('CONTROLLED', 'FLEXIBLE_GOVERNED')
                THEN 'IMPUTE_WITH_CONFIDENCE_PENALTY'

            WHEN s.imputation_operational_policy = 'DEPENDENT'
                THEN 'IMPUTE_FROM_COMPONENTS_ONLY'

            ELSE 'STANDARD_IMPUTATION_ALLOWED'
        END AS l2_imputation_decision,

        CASE
            WHEN s.allow_ml_forecast = FALSE
                THEN 'ML_FORECAST_DISABLED'

            WHEN s.semantic_confidence_dynamic < s.min_dynamic_confidence
                THEN 'ML_USE_AS_CONTEXT_ONLY'

            WHEN s.ml_semantic_weight >= 0.850
                THEN 'ML_FEATURE_HIGH_PRIORITY'

            WHEN s.ml_semantic_weight >= 0.650
                THEN 'ML_FEATURE_CONTROLLED'

            ELSE 'ML_FEATURE_LOW_PRIORITY'
        END AS ml_operational_decision

    FROM scored s
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

    semantic_governance_status,
    semantic_source,
    hybrid_rule_code,

    matrix_trust_level,
    matrix_sovereignty_weight,
    matrix_forecastability,
    volatility_class,
    p7b1_imputation_policy,
    p7b1_ml_priority,
    risk_profile,
    physicality_score,
    dependency_score,
    resilience_score,
    strategic_priority,
    governance_mode,

    isa_inclusion_policy,
    imputation_operational_policy,
    normalization_policy,
    aggregation_policy,
    min_dynamic_confidence,
    min_governance_score,
    max_imputation_ratio,
    exclusion_warning_threshold,
    isa_weight_multiplier,
    ml_weight_multiplier,
    vulnerability_weight,
    requires_certified_source,
    allow_long_gap_imputation,
    allow_ml_forecast,
    requires_manual_review_if_critical,
    operational_risk_class,

    semantic_operational_score,
    isa_semantic_weight,
    ml_semantic_weight,
    semantic_operational_vulnerability,

    semantic_operational_status,
    isa_operational_decision,
    l2_imputation_decision,
    ml_operational_decision,

    operational_policy_notes,
    next_action

FROM finalized;
