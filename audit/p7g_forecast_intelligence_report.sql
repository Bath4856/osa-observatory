\echo ''
\echo '========================================================'
\echo ' OSA / ISA — P7G FORECAST INTELLIGENCE REPORT'
\echo '========================================================'
\echo ''

\echo '=== 0. Colonnes sources P7G ==='
\i audit/list_p7g_source_columns.sql

\echo ''
\echo '=== 1. Package lifecycle ==='
SELECT package_code, package_status, replacement_package, notes
FROM mg.package_lifecycle
WHERE package_code IN ('P7G')
ORDER BY package_code;

\echo ''
\echo '=== 2. Politiques forecast ==='
SELECT forecast_policy_code, min_history_years, min_data_completeness,
       min_observation_confidence, min_forecast_confidence,
       short_horizon_years, medium_horizon_years, long_horizon_years
FROM rf.isa_forecast_policy
ORDER BY min_history_years;

\echo ''
\echo '=== 3. Source P7G volumétrie ==='
SELECT COUNT(*) AS source_rows,
       COUNT(DISTINCT country_iso3) AS nb_countries,
       COUNT(DISTINCT year) AS nb_years,
       COUNT(DISTINCT pillar_code) AS nb_pillars
FROM ma.v_p7g_forecast_source;

\echo ''
\echo '=== 4. Trend status ==='
SELECT forecast_policy_code, forecast_trend_class, forecast_trend_status, COUNT(*) AS nb
FROM ma.v_isa_forecast_trend_engine
GROUP BY forecast_policy_code, forecast_trend_class, forecast_trend_status
ORDER BY forecast_policy_code, forecast_trend_class;

\echo ''
\echo '=== 5. Projection decisions ==='
SELECT horizon_code, forecast_decision, forecast_confidence_class, COUNT(*) AS nb
FROM ma.v_isa_forecast_projection_engine
GROUP BY horizon_code, forecast_decision, forecast_confidence_class
ORDER BY horizon_code, forecast_decision, forecast_confidence_class;

\echo ''
\echo '=== 6. Forecast par pilier ==='
SELECT pillar_code,
       COUNT(*) AS nb,
       ROUND(AVG(forecast_isa_score),3) AS avg_forecast_isa,
       ROUND(AVG(forecast_confidence),3) AS avg_forecast_confidence,
       ROUND(AVG(forecast_uncertainty),3) AS avg_uncertainty
FROM ma.v_isa_forecast_projection_engine
GROUP BY pillar_code
ORDER BY avg_forecast_confidence DESC, pillar_code;

\echo ''
\echo '=== 7. Country forecast status ==='
SELECT horizon_code, country_forecast_status, country_forecast_publication_scope, COUNT(*) AS nb
FROM ma.v_isa_forecast_country_year
GROUP BY horizon_code, country_forecast_status, country_forecast_publication_scope
ORDER BY horizon_code, country_forecast_status;

\echo ''
\echo '=== 8. Readiness P7G ==='
SELECT *
FROM ma.v_isa_forecast_readiness_p7g
ORDER BY horizon_years, pillar_code;

\echo ''
\echo '=== 9. Top forecast variations ==='
SELECT country_iso3, pillar_code, last_observed_year, forecast_year, horizon_code,
       last_isa_observed_score, isa_trend_slope, forecast_isa_score,
       forecast_isa_low, forecast_isa_high,
       forecast_confidence, forecast_decision
FROM ma.v_isa_forecast_projection_engine
ORDER BY ABS(forecast_isa_score - last_isa_observed_score) DESC, forecast_confidence DESC
LIMIT 50;

\echo ''
\echo '=== RAPPORT P7G TERMINÉ ==='
