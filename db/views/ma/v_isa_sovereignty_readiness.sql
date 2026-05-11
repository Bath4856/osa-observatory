-- ============================================================
-- OSA / ISA — P7B5
-- View: ma.v_isa_sovereignty_readiness
-- Purpose:
--   Aggregated sovereignty readiness by pillar and semantic family.
-- ============================================================

CREATE OR REPLACE VIEW ma.v_isa_sovereignty_readiness AS

SELECT
    pillar_code,
    semantic_code,

    COUNT(*) AS nb_indicators,

    ROUND(AVG(semantic_sovereignty_score), 3) AS avg_sovereignty_score,
    ROUND(AVG(semantic_sovereignty_vulnerability), 3) AS avg_sovereignty_vulnerability,
    ROUND(AVG(semantic_confidence_dynamic), 3) AS avg_dynamic_confidence,
    ROUND(AVG(semantic_operational_score), 3) AS avg_operational_score,
    ROUND(AVG(semantic_forecastability_score), 3) AS avg_forecastability_score,

    COUNT(*) FILTER (WHERE semantic_sovereignty_class = 'SOVEREIGNTY_STRONG') AS nb_sovereignty_strong,
    COUNT(*) FILTER (WHERE semantic_sovereignty_class = 'SOVEREIGNTY_CONTROLLED') AS nb_sovereignty_controlled,
    COUNT(*) FILTER (WHERE semantic_sovereignty_class = 'SOVEREIGNTY_FRAGILE_BUT_INFORMATIVE') AS nb_sovereignty_fragile,
    COUNT(*) FILTER (WHERE semantic_sovereignty_class = 'SOVEREIGNTY_GAP_LOCKED') AS nb_sovereignty_gap_locked,
    COUNT(*) FILTER (WHERE semantic_sovereignty_class = 'SOVEREIGNTY_WEAK_SIGNAL') AS nb_sovereignty_weak,

    ROUND(AVG(
        CASE
            WHEN isa_sovereignty_decision = 'USE_IN_ISA_WEIGHTED_CORE'
                THEN 1.00
            WHEN isa_sovereignty_decision = 'USE_IN_ISA_WITH_MONITORING'
                THEN 0.75
            WHEN isa_sovereignty_decision = 'USE_AS_STRUCTURAL_GAP'
                THEN 0.45
            ELSE 0.35
        END
    )::NUMERIC, 3) AS isa_sovereignty_readiness_score,

    CASE
        WHEN COUNT(*) FILTER (WHERE semantic_sovereignty_class = 'SOVEREIGNTY_GAP_LOCKED') > 0
            THEN 'NEEDS_SOVEREIGNTY_REVIEW'

        WHEN AVG(semantic_sovereignty_score) >= 0.850
            THEN 'SOVEREIGNTY_READY_STRONG'

        WHEN AVG(semantic_sovereignty_score) >= 0.700
            THEN 'SOVEREIGNTY_READY_CONTROLLED'

        WHEN AVG(semantic_sovereignty_score) >= 0.550
            THEN 'SOVEREIGNTY_CONTEXTUAL'

        ELSE 'SOVEREIGNTY_WEAK'
    END AS sovereignty_readiness_status

FROM ma.v_semantic_sovereignty_engine
GROUP BY
    pillar_code,
    semantic_code;
