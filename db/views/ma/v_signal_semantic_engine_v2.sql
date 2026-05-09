-- ============================================================
-- OSA / ISA — P7A2
-- Vue : ma.v_signal_semantic_engine_v2
-- Rôle : appliquer les règles explicites P7A2 au-dessus de P7A1.
-- P7A1 reste la fondation ; P7A2 affine les heuristiques faibles.
-- ============================================================

CREATE OR REPLACE VIEW ma.v_signal_semantic_engine_v2 AS

WITH base AS (
    SELECT
        s.*
    FROM ma.v_signal_semantic_engine s
),

rule_candidates AS (
    SELECT
        b.indicator_code,
        r.rule_code,
        r.semantic_code,
        r.semantic_confidence,
        r.refinement_reason,
        r.rule_priority,
        ROW_NUMBER() OVER (
            PARTITION BY b.indicator_code
            ORDER BY r.rule_priority ASC, r.semantic_confidence DESC, r.rule_id ASC
        ) AS rn
    FROM base b
    JOIN ma.signal_semantic_refinement_rules r
      ON r.is_active = TRUE
     AND (
            (r.indicator_code IS NOT NULL AND r.indicator_code = b.indicator_code)
         OR (r.indicator_code IS NULL AND r.pillar_code IS NOT NULL AND r.pillar_code = b.pillar_code)
         OR (r.indicator_code IS NULL AND r.code_pattern IS NOT NULL AND b.indicator_code LIKE r.code_pattern)
         OR (r.indicator_code IS NULL AND r.name_pattern IS NOT NULL AND b.indicator_name ILIKE r.name_pattern)
     )
),

best_rule AS (
    SELECT *
    FROM rule_candidates
    WHERE rn = 1
)

SELECT
    b.indicator_code,
    b.pillar_code,
    b.indicator_name,
    b.nature_code,
    b.confidence_policy,
    b.physical_weight,
    b.imputation_allowed,
    b.governance_threshold,

    COALESCE(br.semantic_code, b.semantic_code) AS semantic_code,
    p.semantic_label,

    CASE
        WHEN br.semantic_code IS NOT NULL THEN br.semantic_confidence
        ELSE b.semantic_confidence
    END AS semantic_confidence,

    CASE
        WHEN br.semantic_code IS NOT NULL THEN 'P7A2_REFINEMENT_RULE'
        ELSE b.semantic_source
    END AS semantic_source,

    CASE
        WHEN br.semantic_code IS NOT NULL THEN br.refinement_reason
        ELSE b.fallback_reason
    END AS fallback_reason,

    p.risk_weight,
    p.strategic_weight,
    p.volatility_weight,
    p.ml_importance,
    p.physicality,
    p.dependency_factor,
    p.resilience_factor,
    p.forecastability,

    CASE
        WHEN br.semantic_code IS NOT NULL THEN 'OK_REFINED'
        WHEN b.semantic_governance_status = 'OK' THEN 'OK'
        WHEN b.semantic_confidence >= 0.80 THEN 'OK'
        ELSE 'REVIEW_RECOMMENDED'
    END AS semantic_governance_status,

    br.rule_code AS applied_rule_code

FROM base b
LEFT JOIN best_rule br
    ON br.indicator_code = b.indicator_code
LEFT JOIN ma.signal_semantic_policy p
    ON p.semantic_code = COALESCE(br.semantic_code, b.semantic_code);
