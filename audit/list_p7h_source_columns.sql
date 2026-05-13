\echo '=== Colonnes source P7H — ma.v_isa_strategic_diagnostic_engine ==='
SELECT ordinal_position, column_name, data_type
FROM information_schema.columns
WHERE table_schema='ma' AND table_name='v_isa_strategic_diagnostic_engine'
ORDER BY ordinal_position;

\echo '=== Colonnes source P7H — ma.v_isa_forecast_trend_engine ==='
SELECT ordinal_position, column_name, data_type
FROM information_schema.columns
WHERE table_schema='ma' AND table_name='v_isa_forecast_trend_engine'
ORDER BY ordinal_position;

\echo '=== Colonnes P7H — vues générées ==='
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema='ma'
  AND table_name IN (
    'v_p7h_scenario_source',
    'v_isa_scenario_policy_engine',
    'v_isa_scenario_simulation_engine',
    'v_isa_scenario_country_year',
    'v_isa_scenario_readiness'
  )
ORDER BY table_name, ordinal_position;
