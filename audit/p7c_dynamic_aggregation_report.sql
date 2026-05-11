\echo ''
\echo '========================================================'
\echo ' OSA / ISA — P7C DYNAMIC AGGREGATION ENGINE REPORT'
\echo '========================================================'
\echo ''

\echo '=== 1. Politique RF aggregation dynamique ==='
SELECT semantic_code, aggregation_mode, pillar_weight_factor, isa_score_factor,
       vulnerability_factor, resilience_factor, include_in_core_isa
FROM rf.dynamic_aggregation_policy
ORDER BY include_in_core_isa DESC, pillar_weight_factor DESC, semantic_code;

\echo ''
\echo '=== 2. Classes aggregation dynamique ==='
SELECT dynamic_aggregation_class, COUNT(*) AS nb
FROM ma.v_semantic_dynamic_aggregation_engine
GROUP BY dynamic_aggregation_class
ORDER BY nb DESC;

\echo ''
\echo '=== 3. Décisions ISA aggregation ==='
SELECT dynamic_isa_aggregation_decision, COUNT(*) AS nb
FROM ma.v_semantic_dynamic_aggregation_engine
GROUP BY dynamic_isa_aggregation_decision
ORDER BY nb DESC;

\echo ''
\echo '=== 4. Décisions ML / Forecast aggregation ==='
SELECT dynamic_ml_aggregation_decision, COUNT(*) AS nb
FROM ma.v_semantic_dynamic_aggregation_engine
GROUP BY dynamic_ml_aggregation_decision
ORDER BY nb DESC;

SELECT dynamic_forecast_aggregation_decision, COUNT(*) AS nb
FROM ma.v_semantic_dynamic_aggregation_engine
GROUP BY dynamic_forecast_aggregation_decision
ORDER BY nb DESC;

\echo ''
\echo '=== 5. Aggregation dynamique par pilier ==='
SELECT
    pillar_code,
    COUNT(*) AS nb,
    ROUND(AVG(final_isa_aggregation_weight), 3) AS avg_isa_agg_weight,
    ROUND(AVG(final_ml_aggregation_weight), 3) AS avg_ml_agg_weight,
    ROUND(AVG(final_forecast_aggregation_weight), 3) AS avg_forecast_agg_weight,
    ROUND(AVG(final_sovereignty_aggregation_weight), 3) AS avg_sovereignty_agg_weight,
    ROUND(AVG(final_vulnerability_aggregation_weight), 3) AS avg_vulnerability_agg_weight
FROM ma.v_semantic_dynamic_aggregation_engine
GROUP BY pillar_code
ORDER BY avg_isa_agg_weight DESC;

\echo ''
\echo '=== 6. Readiness par pilier/famille ==='
SELECT *
FROM ma.v_isa_dynamic_aggregation_readiness
ORDER BY
    CASE dynamic_aggregation_readiness_status
        WHEN 'AGGREGATION_NEEDS_GAP_REVIEW' THEN 1
        WHEN 'AGGREGATION_VULNERABILITY_DOMINANT' THEN 2
        WHEN 'DYNAMIC_AGGREGATION_RISK_SIGNAL' THEN 3
        WHEN 'DYNAMIC_AGGREGATION_CONTEXTUAL' THEN 4
        WHEN 'DYNAMIC_AGGREGATION_READY_CONTROLLED' THEN 5
        WHEN 'DYNAMIC_AGGREGATION_READY_STRONG' THEN 6
        ELSE 7
    END,
    avg_final_isa_weight DESC;

\echo ''
\echo '=== 7. Top signaux aggregation faible / gap ==='
SELECT
    indicator_code,
    pillar_code,
    indicator_name,
    semantic_code,
    semantic_sovereignty_class,
    final_isa_aggregation_weight,
    final_vulnerability_aggregation_weight,
    dynamic_aggregation_class,
    dynamic_isa_aggregation_decision,
    systemic_vulnerability_class
FROM ma.v_semantic_dynamic_aggregation_engine
WHERE dynamic_aggregation_class IN (
    'AGGREGATION_LOCKED_GAP',
    'AGGREGATION_VULNERABILITY_DOMINANT',
    'AGGREGATION_WEAK_SIGNAL'
)
ORDER BY
    final_vulnerability_aggregation_weight DESC,
    final_isa_aggregation_weight ASC
LIMIT 80;

\echo ''
\echo '=== RAPPORT P7C TERMINÉ ==='
