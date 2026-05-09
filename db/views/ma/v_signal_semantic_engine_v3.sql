-- ============================================================
-- OSA / ISA — P7A3
-- Vue : ma.v_signal_semantic_engine_v3
-- Objet : couche finale de gouvernance sémantique ISA
-- ============================================================

CREATE OR REPLACE VIEW ma.v_signal_semantic_engine_v3 AS

SELECT
    h.indicator_code,
    h.pillar_code,
    h.indicator_name,
    h.nature_code,

    h.primary_semantic_code AS semantic_code,
    h.secondary_semantic_code,
    h.tertiary_semantic_code,

    h.finalized_semantic_confidence AS semantic_confidence,
    CASE
        WHEN h.hybrid_rule_code IS NOT NULL THEN 'P7A3_STRATEGIC_FINALIZATION'
        ELSE h.p7a2_semantic_source
    END AS semantic_source,

    h.hybrid_rule_code,
    h.hybrid_rationale,
    h.dominance_weight,
    h.hybrid_weight,
    h.strategic_criticality,
    h.semantic_sovereignty_weight,
    h.semantic_forecastability,

    h.p7a2_semantic_code,
    h.p7a2_semantic_confidence,
    h.p7a2_status,

    h.strategic_semantic_status AS semantic_governance_status,

    CASE
        WHEN h.strategic_semantic_status IN ('OK_STRATEGIC','OK_HYBRID','OK_MULTI_SEMANTIC') THEN 'READY_FOR_P7B'
        ELSE 'MANUAL_REVIEW_REQUIRED'
    END AS next_action

FROM ma.v_semantic_hybrid_vectors h;
