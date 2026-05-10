\echo ''
\echo '========================================================'
\echo ' OSA / ISA — P7B1 SEMANTIC GOVERNANCE MATRIX REPORT'
\echo '========================================================'
\echo ''

\echo '=== 1. Matrice de gouvernance sémantique ==='
SELECT semantic_code, trust_level, sovereignty_weight, volatility_class,
       forecastability, imputation_policy, ml_priority, risk_profile,
       governance_mode
FROM rf.semantic_governance_matrix
ORDER BY sovereignty_weight DESC, semantic_code;

\echo ''
\echo '=== 2. Classes de gouvernance P7B1 ==='
SELECT semantic_governance_class, COUNT(*) AS nb
FROM ma.v_semantic_governance_engine
GROUP BY semantic_governance_class
ORDER BY nb DESC;

\echo ''
\echo '=== 3. Décisions imputation sémantique ==='
SELECT semantic_imputation_decision, COUNT(*) AS nb
FROM ma.v_semantic_governance_engine
GROUP BY semantic_imputation_decision
ORDER BY nb DESC;

\echo ''
\echo '=== 4. Décisions ML sémantique ==='
SELECT semantic_ml_decision, COUNT(*) AS nb
FROM ma.v_semantic_governance_engine
GROUP BY semantic_ml_decision
ORDER BY nb DESC;

\echo ''
\echo '=== 5. Priorité de gouvernance par pilier/famille ==='
SELECT pillar_code, semantic_code, nb_indicators, avg_governance_score,
       avg_governed_confidence, avg_sovereignty_weight, avg_forecastability,
       nb_critical_review, governance_priority_status
FROM ma.v_semantic_governance_priority
ORDER BY nb_critical_review DESC, avg_governance_score ASC, pillar_code, semantic_code
LIMIT 80;

\echo ''
\echo '=== 6. Top indicateurs nécessitant revue de gouvernance ==='
SELECT indicator_code, pillar_code, indicator_name, semantic_code,
       semantic_governance_status, semantic_governance_score,
       semantic_governance_class, imputation_policy, semantic_imputation_decision,
       semantic_ml_decision
FROM ma.v_semantic_governance_engine
WHERE semantic_governance_class IN ('CRITICAL_REVIEW_REQUIRED','GOVERNANCE_GAP','GOVERNED_WEAK')
ORDER BY semantic_governance_class, semantic_governance_score ASC
LIMIT 60;

\echo ''
\echo '=== RAPPORT P7B1 TERMINÉ ==='
