-- ============================================================
-- OSA / ISA — P7D
-- Utility: list all columns available in P7D source view.
-- ============================================================

SELECT
    ordinal_position,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'ma'
  AND table_name = 'v_semantic_dynamic_aggregation_engine'
ORDER BY ordinal_position;
