\echo '=== Colonnes P7I-AMAR — vues générées ==='
SELECT table_schema, table_name, ordinal_position, column_name, data_type
FROM information_schema.columns
WHERE (table_schema, table_name) IN (
    ('ma', 'v_p7i_amar_atrocity_precursor_engine'),
    ('ma', 'v_p7i_amar_dashboard'),
    ('mg', 'v_public_p7i_amar_alerts')
)
ORDER BY table_schema, table_name, ordinal_position;

\echo ''
\echo '=== Objets P7I-AMAR ==='
SELECT
    to_regclass('ma.v_p7i_amar_atrocity_precursor_engine') AS amar_engine,
    to_regclass('ma.v_p7i_amar_dashboard') AS amar_dashboard,
    to_regclass('mg.v_public_p7i_amar_alerts') AS public_amar_alerts,
    to_regclass('mg.risk_taxonomy') AS risk_taxonomy,
    to_regclass('mg.early_warning_alerts') AS early_warning_alerts;
