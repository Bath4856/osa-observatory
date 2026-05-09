\echo ''
\echo '========================================================'
\echo ' OSA / ISA — RAPPORT RESOLUTION ORPHELINS P5'
\echo '========================================================'

\echo ''
\echo '=== 1. Orphelins restants ==='
SELECT *
FROM ma.v_orphan_resolution_status
WHERE orphan_flag = 'ORPHELIN'
ORDER BY pillar_code, indicator_code;

\echo ''
\echo '=== 2. Statut resolution par pilier ==='
SELECT
    pillar_code,
    resolution_status,
    COUNT(*) AS nb
FROM ma.v_orphan_resolution_status
GROUP BY pillar_code, resolution_status
ORDER BY pillar_code, resolution_status;

\echo ''
\echo '=== 3. Indicateurs faibles hors orphelins ==='
SELECT
    pillar_code,
    indicator_code,
    name_fr,
    nature_code,
    mapping_quality_score,
    quality_class,
    isa_status,
    resolution_status
FROM ma.v_orphan_resolution_status
WHERE orphan_flag IS NULL
  AND mapping_quality_score < 0.50
ORDER BY mapping_quality_score, pillar_code, indicator_code
LIMIT 50;

\echo ''
\echo '=== RAPPORT TERMINÉ ==='
