\echo '=== Colonnes source P8 — ma.v_isa_observed_scores_by_country_year ==='
SELECT ordinal_position, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'ma'
  AND table_name = 'v_isa_observed_scores_by_country_year'
ORDER BY ordinal_position;

\echo ''
\echo '=== Colonnes source P8 — ma.v_isa_observed_scores_by_pillar ==='
SELECT ordinal_position, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'ma'
  AND table_name = 'v_isa_observed_scores_by_pillar'
ORDER BY ordinal_position;

\echo ''
\echo '=== Colonnes source P8 — P7X views ==='
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'ma'
  AND table_name IN (
    'v_isa_swot_signal_engine',
    'v_isa_project_opportunity_catalog',
    'v_isa_premium_feasibility_triggers',
    'v_isa_eparticipation_priorities'
  )
ORDER BY table_name, ordinal_position;
