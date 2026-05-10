-- ============================================================
-- OSA / ISA — P7B1
-- Vue : ma.v_semantic_governance_priority
-- Rôle : synthèse par pilier/famille sémantique pour pilotage ISA.
-- ============================================================

CREATE OR REPLACE VIEW ma.v_semantic_governance_priority AS

SELECT
    pillar_code,
    semantic_code,
    COUNT(*) AS nb_indicators,
    ROUND(AVG(semantic_confidence), 3) AS avg_semantic_confidence,
    ROUND(AVG(semantic_governance_score), 3) AS avg_governance_score,
    ROUND(AVG(governed_confidence_score), 3) AS avg_governed_confidence,
    ROUND(AVG(matrix_sovereignty_weight), 3) AS avg_sovereignty_weight,
    ROUND(AVG(matrix_forecastability), 3) AS avg_forecastability,
    ROUND(AVG(ml_priority), 3) AS avg_ml_priority,
    ROUND(AVG(dependency_score), 3) AS avg_dependency_score,
    ROUND(AVG(resilience_score), 3) AS avg_resilience_score,

    COUNT(*) FILTER (WHERE semantic_governance_class = 'GOVERNED_STRONG') AS nb_governed_strong,
    COUNT(*) FILTER (WHERE semantic_governance_class = 'GOVERNED_ACCEPTABLE') AS nb_governed_acceptable,
    COUNT(*) FILTER (WHERE semantic_governance_class = 'GOVERNED_WEAK') AS nb_governed_weak,
    COUNT(*) FILTER (WHERE semantic_governance_class = 'GOVERNANCE_GAP') AS nb_governance_gap,
    COUNT(*) FILTER (WHERE semantic_governance_class = 'CRITICAL_REVIEW_REQUIRED') AS nb_critical_review,

    CASE
        WHEN COUNT(*) FILTER (WHERE semantic_governance_class = 'CRITICAL_REVIEW_REQUIRED') > 0
            THEN 'NEEDS_GOVERNANCE_REVIEW'
        WHEN AVG(semantic_governance_score) >= 0.85
            THEN 'SEMANTIC_GOVERNANCE_STRONG'
        WHEN AVG(semantic_governance_score) >= 0.70
            THEN 'SEMANTIC_GOVERNANCE_ACCEPTABLE'
        ELSE 'SEMANTIC_GOVERNANCE_WEAK'
    END AS governance_priority_status

FROM ma.v_semantic_governance_engine
GROUP BY pillar_code, semantic_code;
