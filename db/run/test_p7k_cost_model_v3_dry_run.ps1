param(
  [string]$DbHost = "127.0.0.1",
  [string]$DbPort = "5432",
  [string]$DbName = "osa_db",
  [string]$DbUser = "postgres"
)
$ErrorActionPreference = "Stop"
$Psql = "psql"
Write-Host "========================================="
Write-Host " OSA — P7K COST MODEL V3 DRY RUN TEST"
Write-Host "========================================="
function Run-TestSql { param([string]$Sql) Write-Host ""; Write-Host ">>> Test SQL"; & $Psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -c $Sql; if ($LASTEXITCODE -ne 0) { throw "Erreur dry-run P7K cost model V3" } }

# --- RF : cost model
Run-TestSql "SELECT CASE WHEN to_regclass('rf.isa_executive_cost_model') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_cost_model, CASE WHEN to_regclass('rf.isa_cost_model_audit_log') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_audit_log, CASE WHEN to_regclass('mg.isa_model_governance_policy') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_governance_policy, CASE WHEN to_regclass('mg.v_cost_model_review_due') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_review_due_view, CASE WHEN to_regclass('ma.mv_isa_executive_master_board') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_mv;"

# --- RF : lignes cost model
Run-TestSql "SELECT COUNT(*) AS cost_model_rows FROM rf.isa_executive_cost_model;"

# --- RF : tous les piliers couverts (doit être 10)
Run-TestSql "SELECT COUNT(DISTINCT pillar_code) AS nb_pillars_covered FROM rf.isa_executive_cost_model;"

# --- RF : aucune valeur NULL sur colonnes critiques
Run-TestSql "SELECT COUNT(*) AS critical_nulls FROM rf.isa_executive_cost_model WHERE calibration_status IS NULL OR calibration_uncertainty_score IS NULL OR calibration_review_due_date IS NULL OR execution_maturity_score IS NULL;"

# --- RF : scores dans les bornes [0,1]
Run-TestSql "SELECT COUNT(*) AS out_of_bounds FROM rf.isa_executive_cost_model WHERE executive_cost_score NOT BETWEEN 0 AND 1 OR execution_maturity_score NOT BETWEEN 0 AND 1 OR calibration_uncertainty_score NOT BETWEEN 0 AND 1;"

# --- RF : review_due_date toujours après calibration_date
Run-TestSql "SELECT COUNT(*) AS invalid_review_due FROM rf.isa_executive_cost_model WHERE calibration_review_due_date <= calibration_date;"

# --- RF : trigger installé
Run-TestSql "SELECT COUNT(*) AS trigger_installed FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='rf' AND c.relname='isa_executive_cost_model' AND t.tgname='trg_cost_model_audit';"

# --- MG : politique complète (doit être 3)
Run-TestSql "SELECT COUNT(*) AS governance_policy_rows FROM mg.isa_model_governance_policy;"

# --- MG : valeurs predictive_execution_value valides
Run-TestSql "SELECT COUNT(*) AS invalid_predictive_values FROM mg.isa_model_governance_policy WHERE predictive_execution_value NOT IN ('EXEC_READY','EXEC_READY_CAUTION','EXEC_BLOCKED_REVIEW');"

# --- MG : vue review_due retourne des lignes (toutes PROVISIONAL → ON_TRACK au moment du déploiement)
Run-TestSql "SELECT review_status, COUNT(*) AS nb FROM mg.v_cost_model_review_due GROUP BY review_status ORDER BY review_status;"

# --- MA : volumétrie MV
Run-TestSql "SELECT COUNT(*) AS mv_rows, COUNT(DISTINCT country_iso3) AS nb_countries, COUNT(DISTINCT year) AS nb_years, COUNT(DISTINCT pillar_code) AS nb_pillars FROM ma.mv_isa_executive_master_board;"

# --- MA : aucun NULL sur sovereign_execution_pressure
Run-TestSql "SELECT COUNT(*) AS null_pressure FROM ma.mv_isa_executive_master_board WHERE sovereign_execution_pressure IS NULL;"

# --- MA : aucun NULL sur predictive_execution_status
Run-TestSql "SELECT COUNT(*) AS null_predictive_status FROM ma.mv_isa_executive_master_board WHERE predictive_execution_status IS NULL;"

# --- MA : valeurs predictive_execution_status valides
Run-TestSql "SELECT COUNT(*) AS invalid_predictive_status FROM ma.mv_isa_executive_master_board WHERE predictive_execution_status NOT IN ('EXEC_READY','EXEC_READY_CAUTION','EXEC_BLOCKED_REVIEW');"

# --- MA : distribution predictive_execution_status
Run-TestSql "SELECT predictive_execution_status, COUNT(*) AS nb FROM ma.mv_isa_executive_master_board GROUP BY predictive_execution_status ORDER BY predictive_execution_status;"

# --- MA : distribution executive_master_status
Run-TestSql "SELECT executive_master_status, COUNT(*) AS nb FROM ma.mv_isa_executive_master_board GROUP BY executive_master_status ORDER BY executive_master_status;"

# --- MA : distribution cost_model_coverage_flag
Run-TestSql "SELECT cost_model_coverage_flag, COUNT(*) AS nb FROM ma.mv_isa_executive_master_board GROUP BY cost_model_coverage_flag ORDER BY cost_model_coverage_flag;"

# --- MA : distribution review_due_flag
Run-TestSql "SELECT review_due_flag, COUNT(*) AS nb FROM ma.mv_isa_executive_master_board GROUP BY review_due_flag ORDER BY review_due_flag;"

# --- MA : scores hors bornes
Run-TestSql "SELECT COUNT(*) AS out_of_bounds_scores FROM ma.mv_isa_executive_master_board WHERE executive_priority_score NOT BETWEEN 0 AND 1 OR sovereign_execution_pressure NOT BETWEEN 0 AND 1;"

Write-Host ""
Write-Host "✅ P7K cost model V3 dry-run terminé avec succès"
