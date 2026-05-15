\echo ''
\echo '========================================================'
\echo ' OSA / ISA — P8 OPS INVENTORY'
\echo '========================================================'
\echo ''

\echo '=== 1. P8-related package lifecycle ==='
SELECT package_code, package_label, package_status, replacement_package, notes, updated_at
FROM rf.package_lifecycle
WHERE package_code ILIKE 'P8%' OR package_code IN ('P8OPS','P8V2')
ORDER BY package_code;

\echo ''
\echo '=== 2. P8 OPS tables ==='
SELECT schemaname, tablename
FROM pg_tables
WHERE schemaname IN ('rf','mg','ma')
  AND (
       tablename ILIKE '%p8%'
    OR tablename ILIKE '%publication%'
    OR tablename ILIKE '%premium%'
    OR tablename ILIKE '%certification%'
    OR tablename ILIKE '%api%'
    OR tablename ILIKE '%open_data%'
  )
ORDER BY schemaname, tablename;

\echo ''
\echo '=== 3. P8 OPS views ==='
SELECT schemaname, viewname
FROM pg_views
WHERE schemaname IN ('ma','mg','rf','pub','archive')
  AND (
       viewname ILIKE '%p8%'
    OR viewname ILIKE '%publication%'
    OR viewname ILIKE '%premium%'
    OR viewname ILIKE '%certification%'
    OR viewname ILIKE '%api%'
    OR viewname ILIKE '%open_data%'
    OR viewname IN (
        'v_isa_certification_engine',
        'v_isa_publication_governance',
        'v_isa_snapshot_registry',
        'v_isa_open_data_catalog',
        'v_isa_premium_catalog',
        'v_isa_api_registry',
        'v_isa_eparticipation_queue'
    )
  )
ORDER BY schemaname, viewname;

\echo ''
\echo '=== 4. P8 OPS view columns ==='
SELECT table_schema, table_name, ordinal_position, column_name, data_type
FROM information_schema.columns
WHERE table_schema IN ('ma','mg','rf','pub','archive')
  AND table_name IN (
        'v_isa_certification_engine',
        'v_isa_publication_governance',
        'v_isa_snapshot_registry',
        'v_isa_open_data_catalog',
        'v_isa_premium_catalog',
        'v_isa_api_registry',
        'v_isa_eparticipation_queue'
  )
ORDER BY table_schema, table_name, ordinal_position;

\echo ''
\echo '=== 5. Current source views required by P8 V2 candidate ==='
SELECT table_schema, table_name, COUNT(*) AS nb_columns
FROM information_schema.columns
WHERE table_schema = 'ma'
  AND table_name IN (
        'v_isa_observed_scores_by_country_year',
        'v_isa_observed_scores_by_pillar',
        'v_isa_strategic_diagnostic_engine',
        'v_isa_candidate_intervention_catalog',
        'v_isa_public_consultation_topics',
        'v_isa_forecast_country_year',
        'v_isa_scenario_country_year',
        'v_isa_early_warning_country_year',
        'v_isa_decision_country_year'
  )
GROUP BY table_schema, table_name
ORDER BY table_name;

\echo ''
\echo '=== 6. Core public coverage candidates ==='
SELECT 'country_year_observed' AS dataset, COUNT(*) AS rows, COUNT(DISTINCT country_iso3) AS countries, COUNT(DISTINCT year) AS years
FROM ma.v_isa_observed_scores_by_country_year
UNION ALL
SELECT 'pillar_observed', COUNT(*), COUNT(DISTINCT country_iso3), COUNT(DISTINCT year)
FROM ma.v_isa_observed_scores_by_pillar
UNION ALL
SELECT 'strategic_diagnostic', COUNT(*), COUNT(DISTINCT country_iso3), COUNT(DISTINCT year)
FROM ma.v_isa_strategic_diagnostic_engine
UNION ALL
SELECT 'candidate_interventions', COUNT(*), COUNT(DISTINCT country_iso3), COUNT(DISTINCT year)
FROM ma.v_isa_candidate_intervention_catalog;

\echo ''
\echo '=== P8 OPS INVENTORY TERMINÉ ==='
