\echo ''
\echo '========================================================'
\echo ' OSA / ISA — P7B3 SEMANTIC OPERATIONAL POLICIES REPORT'
\echo '========================================================'

\echo ''
\echo '=== 1. Politique opérationnelle sémantique ==='
SELECT
    semantic_code,
    isa_inclusion_policy,
    imputation_operational_policy,
    normalization_policy,
    aggregation_policy,
    min_dynamic_confidence,
    max_imputation_ratio,
    operational_risk_class
FROM rf.semantic_operational_policy
ORDER BY operational_risk_class DESC, semantic_code;

\echo ''
\echo '=== 2. Statuts opérationnels P7B3 ==='
SELECT semantic_operational_status, COUNT(*) AS nb
FROM ma.v_semantic_operational_policy_engine
GROUP BY semantic_operational_status
ORDER BY nb DESC;

\echo ''
\echo '=== 3. Décisions ISA ==='
SELECT isa_operational_decision, COUNT(*) AS nb
FROM ma.v_semantic_operational_policy_engine
GROUP BY isa_operational_decision
ORDER BY nb DESC;

\echo ''
\echo '=== 4. Décisions L2 imputation ==='
SELECT l2_imputation_decision, COUNT(*) AS nb
FROM ma.v_semantic_operational_policy_engine
GROUP BY l2_imputation_decision
ORDER BY nb DESC;

\echo ''
\echo '=== 5. Décisions ML ==='
SELECT ml_operational_decision, COUNT(*) AS nb
FROM ma.v_semantic_operational_policy_engine
GROUP BY ml_operational_decision
ORDER BY nb DESC;

\echo ''
\echo '=== 6. Priorité opérationnelle par pilier/famille ==='
SELECT
    pillar_code,
    semantic_code,
    nb_indicators,
    avg_dynamic_confidence,
    avg_operational_score,
    avg_isa_semantic_weight,
    avg_ml_semantic_weight,
    avg_operational_vulnerability,
    nb_locked_review,
    nb_no_imputation_cert_required,
    nb_ml_forecast_disabled,
    operational_priority_status
FROM ma.v_isa_semantic_operations
ORDER BY
    CASE operational_priority_status
        WHEN 'NEEDS_OPERATIONAL_REVIEW' THEN 1
        WHEN 'OPERATIONALLY_WEAK' THEN 2
        WHEN 'OPERATIONALLY_CONTROLLED' THEN 3
        ELSE 4
    END,
    avg_operational_score ASC,
    pillar_code,
    semantic_code;

\echo ''
\echo '=== 7. Top indicateurs verrouillés / surveillés ==='
SELECT
    indicator_code,
    pillar_code,
    indicator_name,
    semantic_code,
    semantic_confidence_dynamic,
    semantic_operational_score,
    semantic_operational_status,
    isa_operational_decision,
    l2_imputation_decision,
    ml_operational_decision
FROM ma.v_semantic_operational_policy_engine
WHERE semantic_operational_status IN (
    'OPERATION_LOCKED_REVIEW',
    'OPERATION_LIMITED_LOW_CONFIDENCE',
    'OPERATION_MONITOR'
)
   OR l2_imputation_decision = 'NO_IMPUTATION_CERTIFICATION_REQUIRED'
ORDER BY semantic_operational_score ASC, pillar_code, indicator_code
LIMIT 60;

\echo ''
\echo '=== RAPPORT P7B3 TERMINÉ ==='
