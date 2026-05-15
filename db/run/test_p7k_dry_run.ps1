param(
  [string]$DbHost = "127.0.0.1",
  [string]$DbPort = "5432",
  [string]$DbName = "osa_db",
  [string]$DbUser = "postgres"
)
$ErrorActionPreference = "Stop"
$Psql = "psql"
Write-Host "========================================="
Write-Host " OSA — P7K DRY RUN TEST"
Write-Host "========================================="
function Run-TestSql { param([string]$Sql) Write-Host ""; Write-Host ">>> Test SQL"; & $Psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -c $Sql; if ($LASTEXITCODE -ne 0) { throw "Erreur dry-run P7K" } }
Run-TestSql "SELECT CASE WHEN to_regclass('rf.isa_executive_governance_policy') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_governance_policy, CASE WHEN to_regclass('rf.isa_executive_budget_band_policy') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_budget_policy, CASE WHEN to_regclass('rf.isa_executive_escalation_policy') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_escalation_policy, CASE WHEN to_regclass('ma.v_p7k_executive_source') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_source, CASE WHEN to_regclass('ma.v_isa_executive_priority_portfolio') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_portfolio, CASE WHEN to_regclass('ma.v_isa_budget_arbitration_matrix') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_budget, CASE WHEN to_regclass('ma.v_isa_board_decision_pack') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_board, CASE WHEN to_regclass('ma.v_isa_national_escalation_queue') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_escalation;"
Run-TestSql "SELECT COUNT(*) AS executive_source_rows FROM ma.v_p7k_executive_source;"
Run-TestSql "SELECT COUNT(*) AS executive_portfolio_rows FROM ma.v_isa_executive_priority_portfolio;"
Run-TestSql "SELECT COUNT(*) AS budget_arbitration_rows FROM ma.v_isa_budget_arbitration_matrix;"
Run-TestSql "SELECT COUNT(*) AS board_pack_rows FROM ma.v_isa_board_decision_pack;"
Run-TestSql "SELECT COUNT(*) AS heatmap_rows FROM ma.v_isa_governance_heatmap;"
Run-TestSql "SELECT COUNT(*) AS watchlist_rows FROM ma.v_isa_executive_watchlist;"
Run-TestSql "SELECT COUNT(*) AS escalation_rows FROM ma.v_isa_national_escalation_queue;"
Run-TestSql "SELECT COUNT(*) AS readiness_rows FROM ma.v_isa_executive_governance_readiness;"
Run-TestSql "SELECT COUNT(*) AS critical_nulls FROM ma.v_isa_executive_priority_portfolio WHERE country_iso3 IS NULL OR year IS NULL OR pillar_code IS NULL OR executive_priority_score IS NULL OR budget_pressure_score IS NULL OR governance_risk_score IS NULL OR executive_decision_class IS NULL OR executive_action_code IS NULL;"
Run-TestSql "SELECT COUNT(*) AS out_of_bounds_scores FROM ma.v_isa_executive_priority_portfolio WHERE executive_priority_score < 0 OR executive_priority_score > 1 OR budget_pressure_score < 0 OR budget_pressure_score > 1 OR governance_risk_score < 0 OR governance_risk_score > 1;"
Run-TestSql "SELECT COUNT(*) AS invalid_executive_classes FROM ma.v_isa_executive_priority_portfolio WHERE executive_decision_class NOT IN ('EXEC_BOARD_PREPARED','EXEC_FAST_TRACK_CANDIDATE','EXEC_PROGRAMME_CANDIDATE','EXEC_WATCHLIST');"
Run-TestSql "SELECT COUNT(*) AS invalid_budget_bands FROM ma.v_isa_budget_arbitration_matrix WHERE budget_band_code NOT IN ('LOW_BUDGET_PRESSURE','MEDIUM_BUDGET_PRESSURE','HIGH_BUDGET_PRESSURE','CRITICAL_BUDGET_PRESSURE');"
Run-TestSql "SELECT COUNT(DISTINCT country_iso3) AS nb_countries, COUNT(DISTINCT year) AS nb_years, COUNT(DISTINCT pillar_code) AS nb_pillars FROM ma.v_isa_executive_priority_portfolio;"
Run-TestSql "SELECT executive_decision_class, COUNT(*) AS nb FROM ma.v_isa_executive_priority_portfolio GROUP BY executive_decision_class ORDER BY executive_decision_class;"
Run-TestSql "SELECT national_escalation_status, COUNT(*) AS nb FROM ma.v_isa_national_escalation_queue GROUP BY national_escalation_status ORDER BY national_escalation_status;"
Run-TestSql "SELECT board_pack_section, COUNT(*) AS nb FROM ma.v_isa_board_decision_pack GROUP BY board_pack_section ORDER BY board_pack_section;"
Write-Host ""
Write-Host "✅ P7K dry-run terminé avec succès"
