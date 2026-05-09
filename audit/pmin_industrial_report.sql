\echo ''
\echo '========================================================'
\echo ' OSA / ISA — RAPPORT PMIN INDUSTRIEL'
\echo '========================================================'

\echo ''
\echo '=== 1. Résumé par nature ==='
SELECT nature_code, COUNT(*) AS nb,
       ROUND(AVG(mapping_quality_score), 3) AS avg_mapping_quality,
       ROUND(AVG(mapping_maturity_score), 3) AS avg_maturity
FROM ma.v_pmin_industrial_quality
GROUP BY nature_code
ORDER BY avg_maturity DESC;

\echo ''
\echo '=== 2. Orphelins PMIN restants ==='
SELECT indicator_code, name_fr, nature_code, mapping_quality_score,
       mapping_maturity_score, recommended_action
FROM ma.v_pmin_industrial_quality
WHERE orphan_flag = 'ORPHELIN'
ORDER BY mapping_quality_score;

\echo ''
\echo '=== 3. Risques physiques PMIN ==='
SELECT indicator_code, name_fr, nature_code, confidence_policy,
       mapping_quality_score, exclusion_threshold, pmin_quality_flag
FROM ma.v_pmin_industrial_quality
WHERE pmin_quality_flag IN ('PHYSICAL_RISK', 'ORPHAN', 'NATURE_MISSING')
ORDER BY pmin_quality_flag, mapping_quality_score;

\echo ''
\echo '=== 4. PMIN prêts ISA ==='
SELECT indicator_code, name_fr, nature_code, mapping_quality_score,
       mapping_maturity_score, quality_class, maturity_class
FROM ma.v_pmin_industrial_quality
WHERE pmin_quality_flag = 'OK'
ORDER BY mapping_maturity_score DESC;
