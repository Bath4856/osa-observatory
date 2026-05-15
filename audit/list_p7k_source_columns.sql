\echo '=== Colonnes source P7K — ma.v_isa_intervention_decision_matrix ==='
SELECT ordinal_position, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'ma'
  AND table_name = 'v_isa_intervention_decision_matrix'
ORDER BY ordinal_position;

\echo ''
\echo '=== Colonnes source P7K — ma.v_isa_decision_country_year ==='
SELECT ordinal_position, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'ma'
  AND table_name = 'v_isa_decision_country_year'
ORDER BY ordinal_position;

\echo ''
\echo '=== Colonnes source P7K — vues générées ==='
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'ma'
  AND table_name IN (
    'v_p7k_executive_source',
    'v_isa_executive_priority_portfolio',
    'v_isa_budget_arbitration_matrix',
    'v_isa_board_decision_pack',
    'v_isa_governance_heatmap',
    'v_isa_executive_watchlist',
    'v_isa_national_escalation_queue',
    'v_isa_executive_governance_readiness'
  )
ORDER BY table_name, ordinal_position;
