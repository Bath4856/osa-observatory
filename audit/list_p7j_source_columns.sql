\echo '=== Colonnes source P7J — ma.v_isa_priority_intervention_alerts ==='
SELECT ordinal_position, column_name, data_type
FROM information_schema.columns
WHERE table_schema='ma' AND table_name='v_isa_priority_intervention_alerts'
ORDER BY ordinal_position;

\echo ''
\echo '=== Colonnes source P7J — ma.v_isa_scenario_simulation_engine ==='
SELECT ordinal_position, column_name, data_type
FROM information_schema.columns
WHERE table_schema='ma' AND table_name='v_isa_scenario_simulation_engine'
ORDER BY ordinal_position;

\echo ''
\echo '=== Colonnes P7J — vues générées ==='
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema='ma'
  AND table_name IN (
      'v_p7j_decision_source',
      'v_isa_decision_priority_engine',
      'v_isa_intervention_decision_matrix',
      'v_isa_decision_country_year',
      'v_isa_decision_readiness'
  )
ORDER BY table_name, ordinal_position;
