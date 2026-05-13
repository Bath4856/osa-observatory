\echo '========================================================'
\echo ' OSA / ISA — P7G v2 FORECAST STATUS FIX REPORT'
\echo '========================================================'
\echo ''
\echo '=== 1. PGEO status attendu : LOW_CONFIDENCE ==='
SELECT
    pillar_code,
    forecast_policy_code,
    forecast_blocking_reason,
    forecast_trend_status,
    COUNT(*) AS nb,
    ROUND(AVG(avg_observation_confidence), 3) AS avg_confidence,
    MIN(history_years) AS min_history,
    MAX(history_years) AS max_history
FROM ma.v_isa_forecast_trend_engine
WHERE pillar_code = 'PGEO'
GROUP BY pillar_code, forecast_policy_code, forecast_blocking_reason, forecast_trend_status
ORDER BY nb DESC;

\echo ''
\echo '=== 2. Tous les statuts forecast ==='
SELECT forecast_trend_status, COUNT(*) AS nb
FROM ma.v_isa_forecast_trend_engine
GROUP BY forecast_trend_status
ORDER BY nb DESC;

\echo ''
\echo '=== 3. Piliers disponibles trend ==='
SELECT COUNT(DISTINCT pillar_code) AS nb_pillars
FROM ma.v_isa_forecast_trend_engine;

\echo ''
\echo '=== RAPPORT P7G v2 TERMINÉ ==='
