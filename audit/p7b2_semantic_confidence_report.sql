\echo ''
\echo '========================================================'
\echo ' OSA / ISA — P7B2 SEMANTIC CONFIDENCE ENGINE REPORT'
\echo '========================================================'
\echo ''

\echo '=== 1. Politique de confiance sémantique ==='
SELECT semantic_code, base_confidence_floor, base_confidence_ceiling,
       critical_review_penalty, weak_governance_penalty, volatility_penalty
FROM rf.semantic_confidence_policy
ORDER BY semantic_code;

\echo ''
\echo '=== 2. Statuts de confiance dynamique ==='
SELECT semantic_confidence_class, COUNT(*) AS nb
FROM ma.v_semantic_confidence_engine
GROUP BY semantic_confidence_class
ORDER BY nb DESC;

\echo ''
\echo '=== 3. Confiance dynamique par pilier ==='
SELECT pillar_code,
       COUNT(*) AS nb,
       ROUND(AVG(semantic_confidence_dynamic),3) AS avg_dynamic_confidence,
       ROUND(AVG(semantic_confidence_base),3) AS avg_static_confidence,
       ROUND(AVG(ROUND(AVG(semantic_confidence_base - semantic_confidence_dynamic), 3) AS avg_confidence_delta),3) AS avg_delta,
       SUM(CASE WHEN semantic_confidence_class='CONFIDENCE_LOCKED_REVIEW' THEN 1 ELSE 0 END) AS locked_review
FROM ma.v_semantic_confidence_engine
GROUP BY pillar_code
ORDER BY avg_dynamic_confidence;

\echo ''
\echo '=== 4. Priorité confiance par pilier/famille ==='
SELECT *
FROM ma.v_semantic_confidence_priority
ORDER BY confidence_priority_status DESC, avg_dynamic_confidence ASC, pillar_code, semantic_code;

\echo ''
\echo '=== 5. Top indicateurs à revue confiance ==='
SELECT indicator_code, pillar_code, indicator_name, semantic_code,
       semantic_confidence_base, semantic_confidence_dynamic,
       ROUND(AVG(semantic_confidence_base - semantic_confidence_dynamic), 3) AS avg_confidence_delta, semantic_confidence_class,
       semantic_confidence_decision, semantic_governance_status
FROM ma.v_semantic_confidence_engine
WHERE semantic_confidence_class IN ('CONFIDENCE_REVIEW_REQUIRED','LOW_CONFIDENCE','WEAK_BUT_USABLE_CONFIDENCE')
ORDER BY semantic_confidence_dynamic ASC, pillar_code, indicator_code
LIMIT 50;

\echo ''
\echo '=== RAPPORT P7B2 TERMINÉ ==='

