\echo ''
\echo '========================================================'
\echo ' OSA / ISA — P7E SOURCE COLUMNS'
\echo '========================================================'
\echo ''

\echo '=== A. ma.indicator_values_final columns ==='
SELECT ordinal_position, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'ma'
  AND table_name = 'indicator_values_final'
ORDER BY ordinal_position;

\echo ''
\echo '=== B. ma.v_dynamic_scores_engine columns ==='
SELECT ordinal_position, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'ma'
  AND table_name = 'v_dynamic_scores_engine'
ORDER BY ordinal_position;
