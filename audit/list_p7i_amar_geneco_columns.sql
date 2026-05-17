\echo '============================================================'
\echo ' OSA / ISA — P7I-AMAR-GENECO COLUMN CHECK'
\echo '============================================================'

SELECT table_schema, table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema IN ('ma','mg')
  AND table_name IN (
      'v_p7i_amar_geneco_engine',
      'v_p7i_amar_geneco_dashboard',
      'v_p7i_amar_composite_dashboard',
      'v_public_p7i_amar_geneco_alerts'
  )
ORDER BY table_schema, table_name, ordinal_position;
