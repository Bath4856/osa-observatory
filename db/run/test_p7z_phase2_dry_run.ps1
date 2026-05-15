param(
  [string]$DbHost = "127.0.0.1",
  [string]$DbPort = "5432",
  [string]$DbName = "osa_db",
  [string]$DbUser = "postgres"
)
$ErrorActionPreference = "Stop"
$Psql = "psql"

Write-Host "========================================="
Write-Host " OSA — P7Z PHASE 2 DRY RUN TEST"
Write-Host "========================================="

function Run-TestSql {
    param([string]$Sql, [string]$Label)
    Write-Host ""; Write-Host ">>> Test : $Label"
    & $Psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -c $Sql
    if ($LASTEXITCODE -ne 0) { throw "Erreur dry-run : $Label" }
}

# Objets existants
Run-TestSql "SELECT
    (SELECT CASE WHEN EXISTS (SELECT 1 FROM pg_matviews WHERE schemaname='ma' AND matviewname='mv_isa_p7z_execution_probability') THEN 'OK' ELSE 'MISSING' END) AS check_mv,
    mg.fn_check_view('ma','v_isa_p7z_convergence_engine')    AS check_convergence,
    mg.fn_check_view('ma','v_isa_p7z_cascade_propagation')   AS check_cascade,
    mg.fn_check_view('ma','v_isa_p7z_fragility_engine')      AS check_fragility,
    mg.fn_check_view('mg','v_p7z_phase2_readiness')          AS check_readiness;" "Objets P7Z Phase 2"

# Volumétrie MV
Run-TestSql "SELECT COUNT(*) AS mv_rows, COUNT(DISTINCT country_iso3) AS nb_countries, COUNT(DISTINCT year) AS nb_years, COUNT(DISTINCT pillar_code) AS nb_pillars FROM ma.mv_isa_p7z_execution_probability;" "Volumétrie MV"

# Nulls critiques
Run-TestSql "SELECT COUNT(*) AS null_exec_prob FROM ma.mv_isa_p7z_execution_probability WHERE execution_probability IS NULL;" "Nulls execution_probability"

# Bornes [0,1]
Run-TestSql "SELECT COUNT(*) AS out_of_bounds FROM ma.mv_isa_p7z_execution_probability WHERE execution_probability NOT BETWEEN 0 AND 1;" "Bornes [0,1]"

# Classes valides
Run-TestSql "SELECT COUNT(*) AS invalid_classes FROM ma.mv_isa_p7z_execution_probability WHERE execution_probability_class NOT IN ('HIGH_PROBABILITY','MEDIUM_PROBABILITY','LOW_PROBABILITY','VERY_LOW_PROBABILITY');" "Classes valides"

# Éligibilité valide
Run-TestSql "SELECT COUNT(*) AS invalid_eligibility FROM ma.mv_isa_p7z_execution_probability WHERE p7z_eligibility_class NOT IN ('P7Z_SIMULATION_READY','P7Z_SIMULATION_PARTIAL','P7Z_MONITORING_ONLY');" "Éligibilité valide"

# Convergence
Run-TestSql "SELECT COUNT(*) AS convergence_rows, COUNT(DISTINCT country_iso3) AS nb_countries FROM ma.v_isa_p7z_convergence_engine;" "Volumétrie convergence"

# Cascade
Run-TestSql "SELECT COUNT(*) AS cascade_rows, COUNT(*) FILTER (WHERE cascade_risk_class='CASCADE_CRITICAL') AS nb_critical FROM ma.v_isa_p7z_cascade_propagation;" "Volumétrie cascade"

# Fragilité
Run-TestSql "SELECT COUNT(*) AS fragility_rows, COUNT(*) FILTER (WHERE sovereign_fragility_class='SOVEREIGN_FRAGILE') AS nb_fragile FROM ma.v_isa_p7z_fragility_engine;" "Volumétrie fragilité"

# Lineage P7Z
Run-TestSql "SELECT COUNT(*) AS p7z_lineage_rows FROM mg.isa_view_lineage_registry WHERE package_code='P7Z';" "Lineage P7Z"

# Phase 2 status
Run-TestSql "SELECT p7z_phase2_status, mv_rows, nb_fragile_countries, nb_cascade_critical, avg_execution_probability FROM mg.v_p7z_phase2_readiness;" "Phase 2 status"

# Package lifecycle
Run-TestSql "SELECT package_code, package_status FROM rf.package_lifecycle WHERE package_code='P7Z';" "Package lifecycle P7Z"

Write-Host ""
Write-Host "✅ P7Z Phase 2 dry-run terminé avec succès"
