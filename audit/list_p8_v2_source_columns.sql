\echo ''
\echo '========================================================'
\echo ' OSA / ISA — P8 V2 SOURCE COLUMNS'
\echo '========================================================'
\echo ''

\echo '=== Source — ma.v_isa_observed_scores_by_country_year ==='
SELECT ordinal_position, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'ma' AND table_name = 'v_isa_observed_scores_by_country_year'
ORDER BY ordinal_position;

\echo ''
\echo '=== Source — ma.v_isa_observed_scores_by_pillar ==='
SELECT ordinal_position, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'ma' AND table_name = 'v_isa_observed_scores_by_pillar'
ORDER BY ordinal_position;

\echo ''
\echo '=== Source — ma.v_isa_strategic_diagnostic_engine ==='
SELECT ordinal_position, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'ma' AND table_name = 'v_isa_strategic_diagnostic_engine'
ORDER BY ordinal_position;

\echo ''
\echo '=== Source — ma.v_isa_candidate_intervention_catalog ==='
SELECT ordinal_position, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'ma' AND table_name = 'v_isa_candidate_intervention_catalog'
ORDER BY ordinal_position;

\echo ''
\echo '=== Source — optional predictive/decision/publication views ==='
SELECT table_name, ordinal_position, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'ma'
  AND table_name IN (
        'v_isa_forecast_country_year',
        'v_isa_scenario_country_year',
        'v_isa_early_warning_country_year',
        'v_isa_decision_country_year',
        'v_isa_open_data_catalog',
        'v_isa_premium_catalog',
        'v_isa_api_registry'
  )
ORDER BY table_name, ordinal_position;
