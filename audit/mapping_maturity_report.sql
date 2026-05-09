-- ============================================================
-- OSA / ISA — MAPPING MATURITY REPORT
-- ============================================================
\echo ''
\echo '========================================================'
\echo ' OSA / ISA — RAPPORT MATURITÉ MAPPING'
\echo '========================================================'

\echo ''
\echo '=== 1. Score moyen de maturité par pilier ==='
SELECT pillar_code, COUNT(*) AS nb_indicators, ROUND(AVG(mapping_maturity_score), 3) AS avg_maturity,
       MIN(mapping_maturity_score) AS min_maturity, MAX(mapping_maturity_score) AS max_maturity
FROM ma.v_mapping_maturity
GROUP BY pillar_code
ORDER BY avg_maturity;

\echo ''
\echo '=== 2. Répartition par classe de maturité ==='
SELECT maturity_class, COUNT(*) AS nb_indicators
FROM ma.v_mapping_maturity
GROUP BY maturity_class
ORDER BY maturity_class;

\echo ''
\echo '=== 3. Répartition par nature ==='
SELECT nature_code, COUNT(*) AS nb_indicators, ROUND(AVG(mapping_maturity_score), 3) AS avg_maturity
FROM ma.v_mapping_maturity
GROUP BY nature_code
ORDER BY avg_maturity;

\echo ''
\echo '=== 4. Actions recommandées ==='
SELECT recommended_action, COUNT(*) AS nb_indicators
FROM ma.v_mapping_maturity
GROUP BY recommended_action
ORDER BY nb_indicators DESC;

\echo ''
\echo '=== 5. Top 30 indicateurs les plus critiques ==='
SELECT pillar_code, indicator_code, nature_code, confidence_policy, mapping_maturity_score, maturity_class, orphan_flag, recommended_action
FROM ma.v_mapping_maturity
WHERE maturity_class IN ('D — FRAGILE', 'E — CRITIQUE')
ORDER BY mapping_maturity_score, pillar_code, indicator_code
LIMIT 30;

\echo ''
\echo '=== 6. Risque physique : PHYSICAL non maîtrisés ==='
SELECT pillar_code, indicator_code, mapping_maturity_score, maturity_class, imputation_allowed, exclusion_threshold, recommended_action
FROM ma.v_mapping_maturity
WHERE nature_code = 'PHYSICAL'
ORDER BY mapping_maturity_score, indicator_code;

\echo ''
\echo '=== RAPPORT TERMINÉ ==='
