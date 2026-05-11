# ============================================================
# OSA / ISA — RUN P7B3 SEMANTIC OPERATIONAL POLICIES
# ============================================================

$ErrorActionPreference = "Stop"

$ROOT = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$PSQL = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
$DB = "osa_db"
$USER = "postgres"

function Run-SqlFile($file) {
    Write-Host ">>> SQL : $file"
    & $PSQL -U $USER -d $DB -v ON_ERROR_STOP=1 -f (Join-Path $ROOT $file)
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Erreur SQL : $file" -ForegroundColor Red
        exit 1
    }
}

Write-Host "========================================="
Write-Host " OSA — RUN P7B3 SEMANTIC OPERATIONAL"
Write-Host "========================================="

# Dependency checks: fail early with explicit messages
$check = @"
SELECT
  CASE WHEN to_regclass('ma.v_semantic_confidence_engine') IS NULL THEN 'MISSING ma.v_semantic_confidence_engine' ELSE 'OK' END AS check_confidence,
  CASE WHEN to_regclass('rf.semantic_governance_matrix') IS NULL THEN 'MISSING rf.semantic_governance_matrix' ELSE 'OK' END AS check_governance,
  CASE WHEN to_regclass('rf.semantic_confidence_policy') IS NULL THEN 'MISSING rf.semantic_confidence_policy' ELSE 'OK' END AS check_conf_policy;
"@
& $PSQL -U $USER -d $DB -v ON_ERROR_STOP=1 -c $check
if ($LASTEXITCODE -ne 0) { exit 1 }

Run-SqlFile "db\patch_db\patch_p7b3_semantic_operational_policies.sql"
Run-SqlFile "db\views\ma\v_semantic_operational_policy_engine.sql"
Run-SqlFile "db\views\ma\v_isa_semantic_operations.sql"

Write-Host ">>> Rapport P7B3"
& $PSQL -U $USER -d $DB -v ON_ERROR_STOP=1 -f (Join-Path $ROOT "audit\p7b3_semantic_operational_report.sql")
if ($LASTEXITCODE -ne 0) {
    Write-Host "Erreur rapport P7B3" -ForegroundColor Red
    exit 1
}

Write-Host "✅ P7B3 Semantic Operational Policies installé" -ForegroundColor Green
