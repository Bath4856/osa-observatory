$PSQL = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
$DB   = "osa_db"
$USER = "postgres"
$ROOT = "G:\osa-observatory"

Write-Host "========================================="
Write-Host " OSA — RUN P7A3 SEMANTIC FINALIZATION"
Write-Host "========================================="

$files = @(
  "db\patch_db\patch_p7a3_semantic_finalization.sql",
  "db\views\ma\v_semantic_hybrid_vectors.sql",
  "db\views\ma\v_semantic_priority_engine.sql",
  "db\views\ma\v_signal_semantic_engine_v3.sql"
)

foreach ($file in $files) {
    Write-Host ">>> SQL : $file"
    & $PSQL -U $USER -d $DB -v ON_ERROR_STOP=1 -f "$ROOT\$file"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Erreur SQL : $file" -ForegroundColor Red
        exit 1
    }
}

Write-Host ">>> Rapport P7A3"
& $PSQL -U $USER -d $DB -v ON_ERROR_STOP=1 -f "$ROOT\audit\p7a3_semantic_finalization_report.sql"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Erreur rapport P7A3" -ForegroundColor Red
    exit 1
}

Write-Host "✅ P7A3 Semantic Finalization installé" -ForegroundColor Green
