\echo '=== Colonnes source P7G — ma.v_isa_observed_scores_by_pillar ==='
SELECT ordinal_position, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'ma'
  AND table_name = 'v_isa_observed_scores_by_pillar'
ORDER BY ordinal_position;

\echo ''
\echo '=== Colonnes source P7G — ma.v_isa_strategic_diagnostic_engine ==='
SELECT ordinal_position, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'ma'
  AND table_name = 'v_isa_strategic_diagnostic_engine'
ORDER BY ordinal_position;

\echo ''
\echo '=== Colonnes P7G — vues générées ==='
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'ma'
  AND table_name IN (
      'v_p7g_forecast_source',
      'v_isa_forecast_trend_engine',
      'v_isa_forecast_projection_engine',
      'v_isa_forecast_country_year',
      'v_isa_forecast_readiness_p7g'
  )
ORDER BY table_name, ordinal_position;
