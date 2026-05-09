$PSQL = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
$DB   = "osa_db"
$USER = "postgres"
$ROOT = "G:\osa-observatory"

Write-Host "========================================="
Write-Host " OSA — RUN P7A1 SEMANTIC ENGINE"
Write-Host "========================================="

$files = @(
  "db\patch_db\patch_p7a1_semantic_taxonomy.sql",
  "db\views\ma\v_signal_semantic_engine.sql"
)

foreach ($file in $files) {
    Write-Host ">>> SQL : $file"
    & $PSQL -U $USER -d $DB -v ON_ERROR_STOP=1 -f "$ROOT\$file"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Erreur SQL : $file"
        exit 1
    }
}

Write-Host ">>> Rapport P7A1"
& $PSQL -U $USER -d $DB -v ON_ERROR_STOP=1 -f "$ROOT\audit\p7a1_semantic_report.sql"
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Erreur rapport P7A1"
    exit 1
}

Write-Host "✅ P7A1 Semantic Engine installé"
