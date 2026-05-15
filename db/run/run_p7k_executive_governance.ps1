param(
  [string]$DbHost = "127.0.0.1",
  [string]$DbPort = "5432",
  [string]$DbName = "osa_db",
  [string]$DbUser = "postgres"
)

$ErrorActionPreference = "Stop"
$Psql = "psql"

Write-Host "========================================="
Write-Host " OSA — RUN P7K EXECUTIVE GOVERNANCE"
Write-Host "========================================="

Write-Host ">>> Pré-test dépendances P7K"
$precheck = @"
WITH checks AS (
    SELECT
        to_regclass('ma.v_isa_intervention_decision_matrix') IS NOT NULL AS has_decision_matrix,
        to_regclass('ma.v_isa_decision_country_year') IS NOT NULL AS has_country_decision,
        to_regclass('ma.v_isa_decision_priority_engine') IS NOT NULL AS has_decision_engine
),
cols AS (
    SELECT
        COUNT(*) FILTER (WHERE table_schema='ma' AND table_name='v_isa_intervention_decision_matrix' AND column_name IN ('country_iso3','year','pillar_code','intervention_family_code','intervention_family_label','strategic_objective','recommended_action','sovereign_alert_level','decision_priority_class','decision_priority_score','decision_confidence_score','governance_track','public_decision_scope','decision_timing_code','decision_timing_label','decision_max_months','central_isa_delta','ambitious_isa_delta','stress_isa_delta','decision_matrix_action','decision_readiness_class','decision_support_status')) AS found_matrix_cols,
        COUNT(*) FILTER (WHERE table_schema='ma' AND table_name='v_isa_decision_country_year' AND column_name IN ('country_iso3','year','nb_decision_items','nb_pillars_with_decisions','nb_critical_decisions','nb_high_decisions','nb_standard_decisions','nb_monitor_decisions','country_decision_priority_score','country_max_decision_priority_score','country_decision_confidence_score','country_decision_class','country_decision_status')) AS found_country_cols
    FROM information_schema.columns
)
SELECT
    CASE WHEN has_decision_matrix THEN 'OK' ELSE 'KO' END AS check_decision_matrix,
    CASE WHEN has_country_decision THEN 'OK' ELSE 'KO' END AS check_country_decision,
    CASE WHEN has_decision_engine THEN 'OK' ELSE 'KO' END AS check_decision_engine,
    22 AS required_matrix_cols,
    found_matrix_cols,
    13 AS required_country_cols,
    found_country_cols,
    CASE WHEN has_decision_matrix AND has_country_decision AND has_decision_engine AND found_matrix_cols = 22 AND found_country_cols = 13 THEN 'OK' ELSE 'MISSING_DEPENDENCY_OR_COLUMNS' END AS check_required_columns
FROM checks, cols;
"@
& $Psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -c $precheck
if ($LASTEXITCODE -ne 0) { throw "Erreur SQL pré-test P7K" }

Write-Host ">>> SQL : db/patch_db/patch_p7k_executive_governance.sql"
& $Psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -f "db/patch_db/patch_p7k_executive_governance.sql"
if ($LASTEXITCODE -ne 0) { throw "Erreur SQL patch P7K" }

Write-Host ">>> Drop vues P7K avant recréation"
$dropSql = @"
DROP VIEW IF EXISTS ma.v_isa_executive_governance_readiness CASCADE;
DROP VIEW IF EXISTS ma.v_isa_national_escalation_queue CASCADE;
DROP VIEW IF EXISTS ma.v_isa_executive_watchlist CASCADE;
DROP VIEW IF EXISTS ma.v_isa_governance_heatmap CASCADE;
DROP VIEW IF EXISTS ma.v_isa_board_decision_pack CASCADE;
DROP VIEW IF EXISTS ma.v_isa_budget_arbitration_matrix CASCADE;
DROP VIEW IF EXISTS ma.v_isa_executive_priority_portfolio CASCADE;
DROP VIEW IF EXISTS ma.v_p7k_executive_source CASCADE;
"@
& $Psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -c $dropSql
if ($LASTEXITCODE -ne 0) { throw "Erreur DROP vues P7K" }

$files = @(
  "db/views/ma/v_p7k_executive_source.sql",
  "db/views/ma/v_isa_executive_priority_portfolio.sql",
  "db/views/ma/v_isa_budget_arbitration_matrix.sql",
  "db/views/ma/v_isa_board_decision_pack.sql",
  "db/views/ma/v_isa_governance_heatmap.sql",
  "db/views/ma/v_isa_executive_watchlist.sql",
  "db/views/ma/v_isa_national_escalation_queue.sql",
  "db/views/ma/v_isa_executive_governance_readiness.sql"
)
foreach ($file in $files) {
  Write-Host ">>> SQL : $file"
  & $Psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -f $file
  if ($LASTEXITCODE -ne 0) { throw "Erreur SQL : $file" }
}

Write-Host ">>> Rapport P7K"
& $Psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -f "audit/p7k_executive_governance_report.sql"
if ($LASTEXITCODE -ne 0) { throw "Erreur rapport P7K" }

Write-Host "✅ P7K Executive Pre-Governance installé"
