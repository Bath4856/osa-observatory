-- ============================================================
-- OSA / ISA — P7B2
-- Vue : ma.v_semantic_confidence_priority
-- Rôle : synthèse par pilier/famille pour pilotage.
-- ============================================================

CREATE OR REPLACE VIEW ma.v_semantic_confidence_priority AS
SELECT
    pillar_code,
    semantic_code,
    COUNT(*) AS nb_indicators,
    ROUND(AVG(semantic_confidence_dynamic), 3) AS avg_dynamic_confidence,
    ROUND(AVG(semantic_confidence_base), 3) AS avg_static_confidence,
    ROUND(AVG((semantic_confidence_base - semantic_confidence_dynamic)), 3) AS avg_confidence_delta,
    SUM(CASE WHEN semantic_confidence_class = 'CONFIDENCE_LOCKED_REVIEW' THEN 1 ELSE 0 END) AS nb_locked_review,
    SUM(CASE WHEN semantic_confidence_class = 'DYNAMIC_CONFIDENCE_LOW' THEN 1 ELSE 0 END) AS nb_low_confidence,
    SUM(CASE WHEN semantic_confidence_class = 'DYNAMIC_CONFIDENCE_MEDIUM' THEN 1 ELSE 0 END) AS nb_medium_confidence,
    SUM(CASE WHEN semantic_confidence_class = 'DYNAMIC_CONFIDENCE_HIGH' THEN 1 ELSE 0 END) AS nb_high_confidence,
    CASE
        WHEN SUM(CASE WHEN semantic_confidence_class = 'CONFIDENCE_LOCKED_REVIEW' THEN 1 ELSE 0 END) > 0 THEN 'CONFIDENCE_REVIEW_REQUIRED'
        WHEN AVG(semantic_confidence_dynamic) >= 0.85 THEN 'CONFIDENCE_STRONG'
        WHEN AVG(semantic_confidence_dynamic) >= 0.70 THEN 'CONFIDENCE_ACCEPTABLE'
        ELSE 'CONFIDENCE_WEAK'
    END AS confidence_priority_status
FROM ma.v_semantic_confidence_engine
GROUP BY pillar_code, semantic_code;
