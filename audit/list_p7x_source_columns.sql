\echo '=== Colonnes source P7X — ma.computed_values ==='
SELECT ordinal_position, column_name, data_type
FROM information_schema.columns
WHERE table_schema='ma' AND table_name='computed_values'
ORDER BY ordinal_position;

\echo '=== Colonnes source P7X — ma.v_p7x_computed_swot_source ==='
SELECT ordinal_position, column_name, data_type
FROM information_schema.columns
WHERE table_schema='ma' AND table_name='v_p7x_computed_swot_source'
ORDER BY ordinal_position;

\echo '=== Colonnes source P7X — ma.v_p7x_observed_pillar_source ==='
SELECT ordinal_position, column_name, data_type
FROM information_schema.columns
WHERE table_schema='ma' AND table_name='v_p7x_observed_pillar_source'
ORDER BY ordinal_position;
