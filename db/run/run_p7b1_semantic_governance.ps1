$PSQL = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
$DB   = "osa_db"
$USER = "postgres"
$ROOT = "G:\osa-observatory"

Write-Host "========================================="
Write-Host " OSA — RUN P7B1 SEMANTIC GOVERNANCE"
Write-Host "========================================="

$files = @(
  "db\patch_db\patch_p7b1_semantic_governance_matrix.sql",
  "db\views\ma\v_semantic_governance_engine.sql",
  "db\views\ma\v_semantic_governance_priority.sql"
)

foreach ($f in $files) {
  Write-Host ">>> SQL : $f"
  & $PSQL -U $USER -d $DB -v ON_ERROR_STOP=1 -f "$ROOT\$f"
  if ($LASTEXITCODE -ne 0) {
    Write-Host "Erreur SQL : $f"
    exit 1
  }
}

Write-Host ">>> Rapport P7B1"
& $PSQL -U $USER -d $DB -v ON_ERROR_STOP=1 -f "$ROOT\audit\p7b1_semantic_governance_report.sql"
if ($LASTEXITCODE -ne 0) {
  Write-Host "Erreur rapport P7B1"
  exit 1
}

Write-Host "✅ P7B1 Semantic Governance Matrix installé"
