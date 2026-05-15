\echo '=== Colonnes source P7I — ma.v_isa_strategic_diagnostic_engine ==='
SELECT ordinal_position, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'ma'
  AND table_name = 'v_isa_strategic_diagnostic_engine'
ORDER BY ordinal_position;

\echo ''
\echo '=== Colonnes source P7I — ma.v_isa_forecast_trend_engine ==='
SELECT ordinal_position, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'ma'
  AND table_name = 'v_isa_forecast_trend_engine'
ORDER BY ordinal_position;

\echo ''
\echo '=== Colonnes source P7I — ma.v_isa_scenario_simulation_engine ==='
SELECT ordinal_position, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'ma'
  AND table_name = 'v_isa_scenario_simulation_engine'
ORDER BY ordinal_position;

\echo ''
\echo '=== Colonnes P7I — vues générées ==='
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'ma'
  AND table_name IN (
      'v_p7i_risk_source',
      'v_isa_early_warning_engine',
      'v_isa_risk_escalation_engine',
      'v_isa_fragility_warning_engine',
      'v_isa_priority_intervention_alerts',
      'v_isa_early_warning_country_year',
      'v_isa_early_warning_readiness'
  )
ORDER BY table_name, ordinal_position;
