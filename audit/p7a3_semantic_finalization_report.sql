\echo ''
\echo '========================================================'
\echo ' OSA / ISA — P7A3 STRATEGIC SEMANTIC FINALIZATION REPORT'
\echo '========================================================'
\echo ''

\echo '=== 1. Statuts P7A2 / P7A3 ==='
SELECT 'P7A2' AS layer, semantic_governance_status, COUNT(*) AS nb
FROM ma.v_signal_semantic_engine_v2
GROUP BY semantic_governance_status
UNION ALL
SELECT 'P7A3' AS layer, semantic_governance_status, COUNT(*) AS nb
FROM ma.v_signal_semantic_engine_v3
GROUP BY semantic_governance_status
ORDER BY layer, semantic_governance_status;

\echo ''
\echo '=== 2. Répartition finale par famille sémantique ==='
SELECT semantic_code, semantic_source, COUNT(*) AS nb_indicators,
       ROUND(AVG(semantic_confidence),3) AS avg_confidence,
       ROUND(AVG(semantic_sovereignty_weight),3) AS avg_sovereignty_weight,
       ROUND(AVG(semantic_forecastability),3) AS avg_forecastability
FROM ma.v_signal_semantic_engine_v3
GROUP BY semantic_code, semantic_source
ORDER BY semantic_code, semantic_source;

\echo ''
\echo '=== 3. Règles hybrides appliquées ==='
SELECT hybrid_rule_code, semantic_code, secondary_semantic_code, tertiary_semantic_code, COUNT(*) AS nb
FROM ma.v_signal_semantic_engine_v3
WHERE hybrid_rule_code IS NOT NULL
GROUP BY hybrid_rule_code, semantic_code, secondary_semantic_code, tertiary_semantic_code
ORDER BY hybrid_rule_code;

\echo ''
\echo '=== 4. Restes à revue critique ==='
SELECT indicator_code, pillar_code, indicator_name, semantic_code, semantic_confidence,
       semantic_source, semantic_governance_status, next_action
FROM ma.v_signal_semantic_engine_v3
WHERE semantic_governance_status = 'CRITICAL_SEMANTIC_REVIEW'
ORDER BY pillar_code, indicator_code;

\echo ''
\echo '=== 5. Priorité sémantique par pilier ==='
SELECT *
FROM ma.v_semantic_priority_engine
ORDER BY pillar_code, semantic_code;

\echo ''
\echo '=== RAPPORT P7A3 TERMINÉ ==='
