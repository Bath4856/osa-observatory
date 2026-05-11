$PSQL = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
$DB   = "osa_db"
$USER = "postgres"
$ROOT = "G:\osa-observatory"

Write-Host "========================================="
Write-Host " OSA — RUN P7B2 SEMANTIC CONFIDENCE"
Write-Host "========================================="

$files = @(
  "db\patch_db\patch_p7b2_semantic_confidence_engine.sql",
  "db\views\ma\v_semantic_confidence_engine.sql",
  "db\views\ma\v_semantic_confidence_priority.sql"
)

foreach ($file in $files) {
  Write-Host ">>> SQL : $file"
  & $PSQL -U $USER -d $DB -v ON_ERROR_STOP=1 -f "$ROOT\$file"
  if ($LASTEXITCODE -ne 0) {
    Write-Host "Erreur SQL : $file"
    exit 1
  }
}

Write-Host ">>> Rapport P7B2"
& $PSQL -U $USER -d $DB -v ON_ERROR_STOP=1 -f "$ROOT\audit\p7b2_semantic_confidence_report.sql"
if ($LASTEXITCODE -ne 0) {
  Write-Host "Erreur rapport P7B2"
  exit 1
}

Write-Host "✅ P7B2 Semantic Confidence Engine installé"
