\echo ''
\echo '========================================================'
\echo ' OSA / ISA — P7K EXECUTIVE GOVERNANCE REPORT'
\echo '========================================================'
\echo ''

\echo '=== 0. Colonnes sources P7K ==='
\i audit/list_p7k_source_columns.sql

\echo ''
\echo '=== 1. Package lifecycle ==='
SELECT package_code, package_status, replacement_package, notes
FROM rf.package_lifecycle
WHERE package_code = 'P7K';

\echo ''
\echo '=== 2. Executive governance policies ==='
SELECT executive_decision_class, min_executive_score, max_executive_score, executive_rank, executive_action_code, executive_track
FROM rf.isa_executive_governance_policy
ORDER BY executive_rank DESC;

\echo ''
\echo '=== 3. Source P7K volumétrie ==='
SELECT COUNT(*) AS source_rows, COUNT(DISTINCT country_iso3) AS nb_countries, COUNT(DISTINCT year) AS nb_years, COUNT(DISTINCT pillar_code) AS nb_pillars
FROM ma.v_p7k_executive_source;

\echo ''
\echo '=== 4. Executive portfolio distribution ==='
SELECT executive_decision_class, executive_track, COUNT(*) AS nb, ROUND(AVG(executive_priority_score), 3) AS avg_priority, ROUND(AVG(budget_pressure_score), 3) AS avg_budget, ROUND(AVG(governance_risk_score), 3) AS avg_governance
FROM ma.v_isa_executive_priority_portfolio
GROUP BY executive_decision_class, executive_track
ORDER BY CASE executive_decision_class WHEN 'EXEC_BOARD_PREPARED' THEN 4 WHEN 'EXEC_FAST_TRACK_CANDIDATE' THEN 3 WHEN 'EXEC_PROGRAMME_CANDIDATE' THEN 2 ELSE 1 END DESC, nb DESC;

\echo ''
\echo '=== 5. Budget arbitration ==='
SELECT budget_band_code, budget_arbitration_decision, COUNT(*) AS nb, ROUND(AVG(budget_pressure_score), 3) AS avg_budget, ROUND(AVG(executive_priority_score), 3) AS avg_priority
FROM ma.v_isa_budget_arbitration_matrix
GROUP BY budget_band_code, budget_arbitration_decision
ORDER BY avg_budget DESC, nb DESC;

\echo ''
\echo '=== 6. Board pack sections ==='
SELECT board_pack_section, executive_decision_class, COUNT(*) AS nb, ROUND(AVG(executive_priority_score), 3) AS avg_priority
FROM ma.v_isa_board_decision_pack
GROUP BY board_pack_section, executive_decision_class
ORDER BY CASE board_pack_section WHEN 'BOARD_TOP_5' THEN 1 WHEN 'BOARD_TOP_10' THEN 2 ELSE 3 END, avg_priority DESC;

\echo ''
\echo '=== 7. Governance heatmap ==='
SELECT governance_heatmap_class, COUNT(*) AS nb, ROUND(AVG(avg_executive_priority_score), 3) AS avg_priority, ROUND(AVG(avg_governance_risk_score), 3) AS avg_governance
FROM ma.v_isa_governance_heatmap
GROUP BY governance_heatmap_class
ORDER BY avg_priority DESC;

\echo ''
\echo '=== 8. Executive watchlist ==='
SELECT watchlist_reason, COUNT(*) AS nb, ROUND(AVG(executive_priority_score), 3) AS avg_priority, ROUND(AVG(governance_risk_score), 3) AS avg_governance
FROM ma.v_isa_executive_watchlist
GROUP BY watchlist_reason
ORDER BY nb DESC;

\echo ''
\echo '=== 9. National escalation queue ==='
SELECT escalation_level_code, national_escalation_status, COUNT(*) AS nb, ROUND(AVG(national_escalation_score), 3) AS avg_escalation
FROM ma.v_isa_national_escalation_queue
GROUP BY escalation_level_code, national_escalation_status
ORDER BY avg_escalation DESC, nb DESC;

\echo ''
\echo '=== 10. Executive readiness ==='
SELECT *
FROM ma.v_isa_executive_governance_readiness
ORDER BY CASE executive_decision_class WHEN 'EXEC_BOARD_PREPARED' THEN 4 WHEN 'EXEC_FAST_TRACK_CANDIDATE' THEN 3 WHEN 'EXEC_PROGRAMME_CANDIDATE' THEN 2 ELSE 1 END DESC, avg_executive_priority_score DESC;

\echo ''
\echo '=== 11. Top board items ==='
SELECT country_iso3, year, board_item_rank, pillar_code, intervention_family_code, executive_decision_class, executive_priority_score, budget_pressure_score, governance_risk_score, executive_action_code, board_pack_section, board_recommended_decision
FROM ma.v_isa_board_decision_pack
WHERE board_pack_section IN ('BOARD_TOP_5','BOARD_TOP_10')
ORDER BY executive_priority_score DESC, governance_risk_score DESC
LIMIT 60;

\echo ''
\echo '=== RAPPORT P7K TERMINÉ ==='
