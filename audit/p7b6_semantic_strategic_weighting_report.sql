\echo ''
\echo '========================================================'
\echo ' OSA / ISA — P7B6 SEMANTIC STRATEGIC WEIGHTING REPORT'
\echo '========================================================'
\echo ''

\echo '=== 1. Politique de pondération stratégique ==='
SELECT
    semantic_code,
    isa_base_weight,
    ml_base_weight,
    forecast_base_weight,
    sovereignty_base_weight,
    vulnerability_base_weight,
    weighting_mode
FROM rf.semantic_weighting_policy
ORDER BY isa_base_weight DESC, semantic_code;

\echo ''
\echo '=== 2. Classes de pondération stratégique ==='
SELECT
    strategic_weighting_class,
    COUNT(*) AS nb
FROM ma.v_semantic_strategic_weighting_engine
GROUP BY strategic_weighting_class
ORDER BY nb DESC;

\echo ''
\echo '=== 3. Décisions ISA dynamiques ==='
SELECT
    isa_weighting_decision,
    COUNT(*) AS nb
FROM ma.v_semantic_strategic_weighting_engine
GROUP BY isa_weighting_decision
ORDER BY nb DESC;

\echo ''
\echo '=== 4. Décisions ML dynamiques ==='
SELECT
    ml_weighting_decision,
    COUNT(*) AS nb
FROM ma.v_semantic_strategic_weighting_engine
GROUP BY ml_weighting_decision
ORDER BY nb DESC;

\echo ''
\echo '=== 5. Décisions forecast dynamiques ==='
SELECT
    forecast_weighting_decision,
    COUNT(*) AS nb
FROM ma.v_semantic_strategic_weighting_engine
GROUP BY forecast_weighting_decision
ORDER BY nb DESC;

\echo ''
\echo '=== 6. Pondération dynamique par pilier ==='
SELECT
    pillar_code,
    COUNT(*) AS nb,
    ROUND(AVG(isa_dynamic_weight), 3) AS avg_isa_weight,
    ROUND(AVG(ml_dynamic_weight), 3) AS avg_ml_weight,
    ROUND(AVG(forecast_dynamic_weight), 3) AS avg_forecast_weight,
    ROUND(AVG(sovereignty_dynamic_weight), 3) AS avg_sovereignty_weight,
    ROUND(AVG(systemic_vulnerability_weight), 3) AS avg_vulnerability_weight
FROM ma.v_semantic_strategic_weighting_engine
GROUP BY pillar_code
ORDER BY avg_isa_weight DESC;

\echo ''
\echo '=== 7. Priorité par pilier/famille ==='
SELECT
    pillar_code,
    semantic_code,
    nb_indicators,
    avg_isa_dynamic_weight,
    avg_ml_dynamic_weight,
    avg_forecast_dynamic_weight,
    avg_sovereignty_dynamic_weight,
    avg_systemic_vulnerability_weight,
    nb_weight_core_strong,
    nb_weight_locked_gap,
    nb_no_forecast_weight,
    dynamic_weighting_readiness_status
FROM ma.v_isa_dynamic_weighting_readiness
ORDER BY
    CASE WHEN dynamic_weighting_readiness_status = 'NEEDS_WEIGHTING_REVIEW' THEN 0 ELSE 1 END,
    avg_isa_dynamic_weight DESC,
    pillar_code,
    semantic_code;

\echo ''
\echo '=== 8. Top signaux faibles / gaps de pondération ==='
SELECT
    indicator_code,
    pillar_code,
    indicator_name,
    semantic_code,
    semantic_sovereignty_class,
    isa_dynamic_weight,
    ml_dynamic_weight,
    forecast_dynamic_weight,
    sovereignty_dynamic_weight,
    systemic_vulnerability_weight,
    strategic_weighting_class,
    isa_weighting_decision
FROM ma.v_semantic_strategic_weighting_engine
WHERE strategic_weighting_class IN (
    'WEIGHT_LOCKED_GAP',
    'WEIGHT_VULNERABILITY_SIGNAL',
    'WEIGHT_CONTEXTUAL'
)
   OR forecast_weighting_decision = 'NO_FORECAST_WEIGHT'
ORDER BY
    systemic_vulnerability_weight DESC,
    isa_dynamic_weight ASC,
    pillar_code,
    indicator_code
LIMIT 60;

\echo ''
\echo '=== RAPPORT P7B6 TERMINÉ ==='
