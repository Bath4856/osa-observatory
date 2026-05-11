\echo ''
\echo '========================================================'
\echo ' OSA / ISA — P7D DYNAMIC SCORES ENGINE REPORT'
\echo '========================================================'
\echo ''

\echo '=== 0. Colonnes disponibles dans la vue source P7D ==='
SELECT ordinal_position, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'ma'
  AND table_name = 'v_semantic_dynamic_aggregation_engine'
ORDER BY ordinal_position;

\echo ''
\echo '=== 1. Politique RF dynamic score ==='
SELECT
    semantic_code,
    scoring_mode,
    performance_factor,
    sovereignty_factor,
    vulnerability_factor,
    resilience_factor,
    forecast_factor,
    include_in_dynamic_score
FROM rf.dynamic_score_policy
ORDER BY include_in_dynamic_score DESC, performance_factor DESC, semantic_code;

\echo ''
\echo '=== 2. Classes score dynamique ==='
SELECT dynamic_score_class, COUNT(*) AS nb
FROM ma.v_dynamic_scores_engine
GROUP BY dynamic_score_class
ORDER BY nb DESC;

\echo ''
\echo '=== 3. Décisions score dynamique ==='
SELECT dynamic_score_decision, COUNT(*) AS nb
FROM ma.v_dynamic_scores_engine
GROUP BY dynamic_score_decision
ORDER BY nb DESC;

\echo ''
\echo '=== 4. Score components par pilier ==='
SELECT
    pillar_code,
    COUNT(*) AS nb,
    ROUND(AVG(dynamic_isa_score_component), 3) AS avg_isa_score_component,
    ROUND(AVG(dynamic_sovereignty_score_component), 3) AS avg_sovereignty_score_component,
    ROUND(AVG(dynamic_vulnerability_score_component), 3) AS avg_vulnerability_score_component,
    ROUND(AVG(dynamic_resilience_score_component), 3) AS avg_resilience_score_component,
    ROUND(AVG(dynamic_forecast_score_component), 3) AS avg_forecast_score_component,
    ROUND(AVG(dynamic_ml_score_component), 3) AS avg_ml_score_component
FROM ma.v_dynamic_scores_engine
GROUP BY pillar_code
ORDER BY avg_isa_score_component DESC;

\echo ''
\echo '=== 5. Readiness score par pilier/famille ==='
SELECT *
FROM ma.v_isa_dynamic_scores_readiness
ORDER BY
    CASE dynamic_scores_readiness_status
        WHEN 'DYNAMIC_SCORE_NEEDS_GAP_REVIEW' THEN 1
        WHEN 'DYNAMIC_SCORE_VULNERABILITY_DOMINANT' THEN 2
        WHEN 'DYNAMIC_SCORE_RISK_SIGNAL' THEN 3
        WHEN 'DYNAMIC_SCORE_READY_STRONG' THEN 4
        WHEN 'DYNAMIC_SCORE_READY_CONTROLLED' THEN 5
        ELSE 6
    END,
    avg_dynamic_isa_score DESC;

\echo ''
\echo '=== 6. Top signaux faibles / vulnérabilité score ==='
SELECT
    indicator_code,
    pillar_code,
    indicator_name,
    semantic_code,
    semantic_sovereignty_class,
    dynamic_isa_score_component,
    dynamic_sovereignty_score_component,
    dynamic_vulnerability_score_component,
    dynamic_score_class,
    dynamic_score_decision,
    dynamic_score_vulnerability_class
FROM ma.v_dynamic_scores_engine
WHERE dynamic_score_class IN (
    'DYNAMIC_SCORE_LOCKED_GAP',
    'DYNAMIC_SCORE_VULNERABILITY_SIGNAL',
    'DYNAMIC_SCORE_CONTEXT_ONLY'
)
   OR dynamic_vulnerability_score_component >= 0.550
ORDER BY dynamic_vulnerability_score_component DESC, dynamic_isa_score_component ASC
LIMIT 80;

\echo ''
\echo '=== RAPPORT P7D TERMINÉ ==='
