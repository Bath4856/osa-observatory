\echo '=== Colonnes source P7F — ma.v_isa_observed_scores_by_pillar ==='
SELECT ordinal_position, column_name, data_type
FROM information_schema.columns
WHERE table_schema='ma'
  AND table_name='v_isa_observed_scores_by_pillar'
ORDER BY ordinal_position;

\echo ''
\echo '=== Colonnes source P7F — ma.computed_values ==='
SELECT ordinal_position, column_name, data_type
FROM information_schema.columns
WHERE table_schema='ma'
  AND table_name='computed_values'
ORDER BY ordinal_position;

\echo ''
\echo '=== Colonnes P7F — vues générées ==='
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema='ma'
  AND table_name IN (
    'v_p7f_computed_swot_source',
    'v_p7f_observed_pillar_source',
    'v_isa_strategic_diagnostic_engine',
    'v_isa_candidate_intervention_catalog',
    'v_isa_public_consultation_topics'
  )
ORDER BY table_name, ordinal_position;
