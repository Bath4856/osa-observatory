\echo ''
\echo '========================================================'
\echo ' OSA / ISA — P7A1 SEMANTIC TAXONOMY REPORT'
\echo '========================================================'
\echo ''

\echo '=== 1. Répartition par semantic_code ==='
SELECT
    semantic_code,
    semantic_source,
    COUNT(*) AS nb_indicators,
    ROUND(AVG(semantic_confidence), 3) AS avg_semantic_confidence
FROM ma.v_signal_semantic_engine
GROUP BY semantic_code, semantic_source
ORDER BY nb_indicators DESC;

\echo ''
\echo '=== 2. UNCLASSIFIED restants ==='
SELECT
    indicator_code,
    pillar_code,
    indicator_name,
    nature_code,
    semantic_source,
    semantic_governance_status
FROM ma.v_signal_semantic_engine
WHERE semantic_code = 'UNCLASSIFIED'
ORDER BY pillar_code, indicator_code;

\echo ''
\echo '=== 3. Classification par pilier ==='
SELECT
    pillar_code,
    semantic_code,
    COUNT(*) AS nb
FROM ma.v_signal_semantic_engine
GROUP BY pillar_code, semantic_code
ORDER BY pillar_code, nb DESC;

\echo ''
\echo '=== 4. Indicateurs à revoir ==='
SELECT
    indicator_code,
    pillar_code,
    nature_code,
    semantic_code,
    semantic_confidence,
    semantic_source,
    fallback_reason,
    semantic_governance_status
FROM ma.v_signal_semantic_engine
WHERE semantic_governance_status <> 'OK'
ORDER BY semantic_confidence ASC, pillar_code, indicator_code
LIMIT 100;

\echo ''
\echo '=== RAPPORT P7A1 TERMINÉ ==='
