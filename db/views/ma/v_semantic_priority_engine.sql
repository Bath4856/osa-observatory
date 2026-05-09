-- ============================================================
-- OSA / ISA — P7A3
-- Vue : ma.v_semantic_priority_engine
-- Objet : priorité stratégique par pilier et famille sémantique
-- ============================================================

CREATE OR REPLACE VIEW ma.v_semantic_priority_engine AS

SELECT
    h.pillar_code,
    h.primary_semantic_code AS semantic_code,
    COUNT(*) AS nb_indicators,
    ROUND(AVG(h.finalized_semantic_confidence), 3) AS avg_semantic_confidence,
    ROUND(AVG(h.semantic_sovereignty_weight), 3) AS avg_sovereignty_weight,
    ROUND(AVG(h.semantic_forecastability), 3) AS avg_forecastability,
    COUNT(*) FILTER (WHERE h.strategic_semantic_status = 'OK_STRATEGIC') AS nb_ok_strategic,
    COUNT(*) FILTER (WHERE h.strategic_semantic_status = 'OK_HYBRID') AS nb_ok_hybrid,
    COUNT(*) FILTER (WHERE h.strategic_semantic_status = 'OK_MULTI_SEMANTIC') AS nb_ok_multi_semantic,
    COUNT(*) FILTER (WHERE h.strategic_semantic_status = 'CRITICAL_SEMANTIC_REVIEW') AS nb_critical_review,
    CASE
        WHEN COUNT(*) FILTER (WHERE h.strategic_semantic_status = 'CRITICAL_SEMANTIC_REVIEW') = 0
            THEN 'SEMANTICALLY_GOVERNED'
        WHEN ROUND(AVG(h.finalized_semantic_confidence),3) >= 0.800
            THEN 'MOSTLY_GOVERNED'
        ELSE 'NEEDS_SEMANTIC_GOVERNANCE'
    END AS semantic_priority_status
FROM ma.v_semantic_hybrid_vectors h
GROUP BY h.pillar_code, h.primary_semantic_code;
