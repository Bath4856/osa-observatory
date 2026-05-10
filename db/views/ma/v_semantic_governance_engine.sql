-- ============================================================
-- OSA / ISA — P7B1
-- Vue : ma.v_semantic_governance_engine
-- Rôle : joindre le moteur sémantique final P7A3 avec la matrice
--        de gouvernance sémantique P7B1.
-- ============================================================

CREATE OR REPLACE VIEW ma.v_semantic_governance_engine AS

WITH base AS (
    SELECT
        s.indicator_code,
        s.pillar_code,
        s.indicator_name,
        s.nature_code,
        s.semantic_code,
        s.secondary_semantic_code,
        s.tertiary_semantic_code,
        s.semantic_confidence,
        s.semantic_source,
        s.hybrid_rule_code AS applied_rule_code,
        s.semantic_governance_status,
        s.semantic_sovereignty_weight AS p7a_sovereignty_weight,
        s.semantic_forecastability AS p7a_forecastability
        -- s.sovereignty_weight AS p7a_sovereignty_weight,
        -- s.forecastability    AS p7a_forecastability
    FROM ma.v_signal_semantic_engine_v3 s
), governed AS (
    SELECT
        b.*,
        g.semantic_label,
        g.trust_level,
        g.sovereignty_weight AS matrix_sovereignty_weight,
        g.volatility_class,
        g.forecastability AS matrix_forecastability,
        g.imputation_policy,
        g.ml_priority,
        g.risk_profile,
        g.physicality_score,
        g.dependency_score,
        g.resilience_score,
        g.strategic_priority,
        g.governance_mode,
        g.recommended_action,
        g.description AS semantic_description,

        ROUND(((COALESCE(b.semantic_confidence,0) * 0.35)
             + (COALESCE(g.trust_level,0) * 0.25)
             + (COALESCE(g.strategic_priority,0) * 0.20)
             + (COALESCE(g.ml_priority,0) * 0.10)
             + (COALESCE(g.forecastability,0) * 0.10))::NUMERIC, 3) AS semantic_governance_score,

        ROUND(((COALESCE(b.semantic_confidence,0) * COALESCE(g.trust_level,0))
             * (0.70 + COALESCE(g.strategic_priority,0) * 0.30))::NUMERIC, 3) AS governed_confidence_score

    FROM base b
    LEFT JOIN rf.semantic_governance_matrix g
           ON g.semantic_code = b.semantic_code
)
SELECT
    *,
    CASE
        WHEN semantic_governance_status = 'CRITICAL_SEMANTIC_REVIEW'
            THEN 'CRITICAL_REVIEW_REQUIRED'
        WHEN semantic_governance_score >= 0.85
            THEN 'GOVERNED_STRONG'
        WHEN semantic_governance_score >= 0.70
            THEN 'GOVERNED_ACCEPTABLE'
        WHEN semantic_governance_score >= 0.55
            THEN 'GOVERNED_WEAK'
        ELSE 'GOVERNANCE_GAP'
    END AS semantic_governance_class,

    CASE
        WHEN imputation_policy IN ('STRICT','VERY_STRICT')
             AND semantic_governance_status = 'CRITICAL_SEMANTIC_REVIEW'
            THEN 'LOCK_IMPUTATION_UNTIL_REVIEW'
        WHEN imputation_policy IN ('STRICT','VERY_STRICT')
            THEN 'LIMIT_IMPUTATION'
        WHEN imputation_policy = 'CAUTIOUS'
            THEN 'CONTROLLED_IMPUTATION'
        WHEN imputation_policy = 'MODERATE'
            THEN 'STANDARD_IMPUTATION'
        ELSE 'FLEXIBLE_IMPUTATION'
    END AS semantic_imputation_decision,

    CASE
        WHEN ml_priority >= 0.85 AND semantic_governance_score >= 0.75
            THEN 'ML_HIGH_PRIORITY'
        WHEN ml_priority >= 0.75
            THEN 'ML_MEDIUM_PRIORITY'
        WHEN semantic_governance_status = 'CRITICAL_SEMANTIC_REVIEW'
            THEN 'ML_REVIEW_BEFORE_USE'
        ELSE 'ML_LOW_PRIORITY'
    END AS semantic_ml_decision

FROM governed;
