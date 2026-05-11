\echo ''
\echo '========================================================'
\echo ' OSA / ISA — P7B4 SEMANTIC FORECASTABILITY REPORT'
\echo '========================================================'

\echo ''
\echo '=== 1. Politique de forecast sémantique ==='
SELECT
    semantic_code,
    forecast_policy,
    base_forecastability,
    min_forecast_confidence,
    max_forecast_horizon_years,
    event_forecast_allowed,
    physical_forecast_requires_certification
FROM rf.semantic_forecast_policy
ORDER BY
    CASE forecast_policy
        WHEN 'FORECAST_READY' THEN 1
        WHEN 'FORECAST_CERTIFIED' THEN 2
        WHEN 'FORECAST_LIMITED' THEN 3
        WHEN 'FORECAST_COMPONENTS' THEN 4
        WHEN 'CONTEXT_FORECAST' THEN 5
        WHEN 'CONTEXT_ONLY' THEN 6
        WHEN 'FORECAST_DISABLED' THEN 7
        ELSE 9
    END,
    semantic_code;

\echo ''
\echo '=== 2. Statuts forecast P7B4 ==='
SELECT semantic_forecast_status, COUNT(*) AS nb
FROM ma.v_semantic_forecastability_engine
GROUP BY semantic_forecast_status
ORDER BY nb DESC;

\echo ''
\echo '=== 3. Décisions ML forecast ==='
SELECT ml_forecast_decision, COUNT(*) AS nb
FROM ma.v_semantic_forecastability_engine
GROUP BY ml_forecast_decision
ORDER BY nb DESC;

\echo ''
\echo '=== 4. Forecastabilité par pilier ==='
SELECT
    pillar_code,
    COUNT(*) AS nb,
    ROUND(AVG(semantic_forecastability_score), 3) AS avg_forecastability,
    COUNT(*) FILTER (WHERE semantic_forecast_status = 'FORECAST_READY') AS nb_ready,
    COUNT(*) FILTER (WHERE semantic_forecast_status = 'FORECAST_LIMITED') AS nb_limited,
    COUNT(*) FILTER (WHERE semantic_forecast_status LIKE 'FORECAST_DISABLED%') AS nb_disabled
FROM ma.v_semantic_forecastability_engine
GROUP BY pillar_code
ORDER BY avg_forecastability;

\echo ''
\echo '=== 5. Priorité forecast par pilier/famille ==='
SELECT *
FROM ma.v_isa_forecast_readiness
ORDER BY
    CASE forecast_readiness_status
        WHEN 'NEEDS_FORECAST_GOVERNANCE_REVIEW' THEN 1
        WHEN 'FORECAST_WEAK_OR_CONTEXTUAL' THEN 2
        WHEN 'FORECAST_LIMITED_MONITORING' THEN 3
        WHEN 'FORECAST_READY_CONTROLLED' THEN 4
        WHEN 'FORECAST_READY_STRONG' THEN 5
        ELSE 9
    END,
    avg_forecastability_score;

\echo ''
\echo '=== 6. Top signaux non forecastables / à surveiller ==='
SELECT
    indicator_code,
    pillar_code,
    indicator_name,
    semantic_code,
    semantic_confidence_dynamic,
    semantic_operational_status,
    semantic_forecastability_score,
    semantic_forecast_status,
    ml_forecast_decision,
    allowed_forecast_horizon_years,
    forecastability_reason
FROM ma.v_semantic_forecastability_engine
WHERE semantic_forecast_status IN ('FORECAST_DISABLED_REVIEW','FORECAST_DISABLED','CONTEXT_ONLY')
   OR ml_forecast_decision IN ('NO_FORECAST_UNTIL_REVIEW','NO_FORECAST_EVENT_OR_POLICY','USE_AS_CONTEXT_ONLY')
ORDER BY semantic_forecastability_score, pillar_code, indicator_code
LIMIT 40;

\echo ''
\echo '=== RAPPORT P7B4 TERMINÉ ==='
