-- ============================================================
-- OSA / ISA — P7A3
-- Vue : ma.v_semantic_hybrid_vectors
-- Objet : vecteurs hybrides sémantiques par indicateur
-- ============================================================

CREATE OR REPLACE VIEW ma.v_semantic_hybrid_vectors AS

WITH base AS (
    SELECT
        s.indicator_code,
        s.pillar_code,
        s.indicator_name,
        s.nature_code,
        s.semantic_code AS p7a2_semantic_code,
        s.semantic_confidence AS p7a2_semantic_confidence,
        s.semantic_source AS p7a2_semantic_source,
        s.semantic_governance_status AS p7a2_status,
        s.risk_weight AS base_risk_weight,
        s.strategic_weight AS base_strategic_weight,
        s.volatility_weight AS base_volatility_weight,
        s.ml_importance AS base_ml_importance,
        s.forecastability AS base_forecastability
    FROM ma.v_signal_semantic_engine_v2 s
),
rules AS (
    SELECT *
    FROM ma.semantic_hybrid_rules
    WHERE is_active = TRUE
),
priority AS (
    SELECT * FROM ma.semantic_priority_matrix
)
SELECT
    b.indicator_code,
    b.pillar_code,
    b.indicator_name,
    b.nature_code,

    COALESCE(r.primary_semantic_code, b.p7a2_semantic_code) AS primary_semantic_code,
    r.secondary_semantic_code,
    r.tertiary_semantic_code,

    b.p7a2_semantic_code,
    b.p7a2_semantic_confidence,
    b.p7a2_semantic_source,
    b.p7a2_status,

    r.rule_code AS hybrid_rule_code,
    r.rationale AS hybrid_rationale,

    COALESCE(r.dominance_weight, 0.900) AS dominance_weight,
    COALESCE(r.hybrid_weight, 0.100) AS hybrid_weight,
    COALESCE(r.strategic_criticality, p.sovereignty_weight, 0.500) AS strategic_criticality,

    ROUND(
        LEAST(1.000,
            COALESCE(b.p7a2_semantic_confidence, 0.650)
          + CASE WHEN r.rule_code IS NOT NULL THEN 0.080 ELSE 0 END
        )::NUMERIC,
        3
    ) AS finalized_semantic_confidence,

    ROUND(
        (
            COALESCE(p.sovereignty_weight, b.base_strategic_weight, 0.500) * COALESCE(r.dominance_weight, 0.900)
          + COALESCE(b.base_strategic_weight, 0.500) * COALESCE(r.hybrid_weight, 0.100)
        )::NUMERIC,
        3
    ) AS semantic_sovereignty_weight,

    ROUND(
        LEAST(1.000,
            COALESCE(b.base_forecastability, 0.500)
          + COALESCE(r.forecastability_boost, 0.000)
        )::NUMERIC,
        3
    ) AS semantic_forecastability,

    CASE
        WHEN r.status_override IS NOT NULL THEN r.status_override
        WHEN b.p7a2_status IN ('OK','OK_REFINED') THEN 'OK_STRATEGIC'
        ELSE 'CRITICAL_SEMANTIC_REVIEW'
    END AS strategic_semantic_status

FROM base b
LEFT JOIN rules r ON r.indicator_code = b.indicator_code
LEFT JOIN priority p ON p.semantic_code = COALESCE(r.primary_semantic_code, b.p7a2_semantic_code);
