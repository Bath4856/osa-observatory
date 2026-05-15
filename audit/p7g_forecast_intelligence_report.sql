\echo ''
\echo '========================================================'
\echo ' OSA / ISA — P7G v2 FORECAST INTELLIGENCE REPORT'
\echo '========================================================'

\echo ''
\echo '=== 1. Contrôle PGEO : cause forecast corrigée ==='
SELECT
    pillar_code,
    forecast_policy_code,
    forecast_trend_status,
    forecast_blocking_reason,
    COUNT(*) AS nb,
    ROUND(AVG(avg_observation_confidence), 3) AS avg_confidence,
    MIN(history_years) AS min_history,
    MAX(history_years) AS max_history
FROM ma.v_isa_forecast_trend_engine
WHERE pillar_code = 'PGEO'
GROUP BY pillar_code, forecast_policy_code, forecast_trend_status, forecast_blocking_reason
ORDER BY nb DESC;

\echo ''
\echo '=== 2. Statuts forecast par pilier ==='
SELECT
    pillar_code,
    forecast_policy_code,
    forecast_trend_status,
    forecast_blocking_reason,
    COUNT(*) AS nb
FROM ma.v_isa_forecast_trend_engine
GROUP BY pillar_code, forecast_policy_code, forecast_trend_status, forecast_blocking_reason
ORDER BY pillar_code, forecast_trend_status;

\echo ''
\echo '=== 3. Distribution causes de blocage ==='
SELECT
    forecast_blocking_reason,
    COUNT(*) AS nb
FROM ma.v_isa_forecast_trend_engine
GROUP BY forecast_blocking_reason
ORDER BY nb DESC;

\echo ''
\echo '=== 4. Projection decisions après correction ==='
SELECT
    horizon_code,
    forecast_decision,
    forecast_confidence_class,
    COUNT(*) AS nb
FROM ma.v_isa_forecast_projection_engine
GROUP BY horizon_code, forecast_decision, forecast_confidence_class
ORDER BY horizon_code, forecast_decision, forecast_confidence_class;

\echo ''
\echo '=== 5. Couverture projection par pilier ==='
SELECT
    pillar_code,
    COUNT(*) AS nb_projection_rows,
    COUNT(DISTINCT country_iso3) AS nb_countries,
    COUNT(DISTINCT horizon_code) AS nb_horizons,
    ROUND(AVG(forecast_confidence), 3) AS avg_forecast_confidence
FROM ma.v_isa_forecast_projection_engine
GROUP BY pillar_code
ORDER BY pillar_code;

\echo ''
\echo '=== RAPPORT P7G v2 TERMINÉ ==='
