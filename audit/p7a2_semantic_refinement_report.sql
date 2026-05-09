\echo ''
\echo '========================================================'
\echo ' OSA / ISA — P7A2 SEMANTIC REFINEMENT REPORT'
\echo '========================================================'
\echo ''

\echo '=== 1. Statuts avant/après P7A2 ==='
SELECT 'P7A1_BASE' AS layer, semantic_governance_status, COUNT(*) AS nb
FROM ma.v_signal_semantic_engine
GROUP BY semantic_governance_status
UNION ALL
SELECT 'P7A2_REFINED' AS layer, semantic_governance_status, COUNT(*) AS nb
FROM ma.v_signal_semantic_engine_v2
GROUP BY semantic_governance_status
ORDER BY layer, semantic_governance_status;

\echo ''
\echo '=== 2. Répartition sémantique P7A2 ==='
SELECT semantic_code, semantic_source, COUNT(*) AS nb_indicators,
       ROUND(AVG(semantic_confidence), 3) AS avg_semantic_confidence
FROM ma.v_signal_semantic_engine_v2
GROUP BY semantic_code, semantic_source
ORDER BY semantic_code, semantic_source;

\echo ''
\echo '=== 3. Règles P7A2 appliquées ==='
SELECT applied_rule_code, semantic_code, COUNT(*) AS nb
FROM ma.v_signal_semantic_engine_v2
WHERE applied_rule_code IS NOT NULL
GROUP BY applied_rule_code, semantic_code
ORDER BY nb DESC, applied_rule_code
LIMIT 80;

\echo ''
\echo '=== 4. REVIEW_RECOMMENDED restants ==='
SELECT indicator_code, pillar_code, indicator_name, nature_code,
       semantic_code, semantic_confidence, semantic_source,
       fallback_reason, semantic_governance_status
FROM ma.v_signal_semantic_engine_v2
WHERE semantic_governance_status = 'REVIEW_RECOMMENDED'
ORDER BY pillar_code, indicator_code
LIMIT 120;

\echo ''
\echo '=== 5. Classification par pilier après P7A2 ==='
SELECT pillar_code, semantic_code, COUNT(*) AS nb
FROM ma.v_signal_semantic_engine_v2
GROUP BY pillar_code, semantic_code
ORDER BY pillar_code, nb DESC, semantic_code;

\echo ''
\echo '=== RAPPORT P7A2 TERMINÉ ==='
