$PSQL = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
$DB   = "osa_db"
$USER = "postgres"

Write-Host "========================================="
Write-Host " OSA — P7A1 DRY RUN TEST"
Write-Host "========================================="

$queries = @(
  "SELECT COUNT(*) AS nb_semantic_indicators FROM ma.v_signal_semantic_engine;",
  "SELECT semantic_code, COUNT(*) AS nb FROM ma.v_signal_semantic_engine GROUP BY semantic_code ORDER BY nb DESC;",
  "SELECT semantic_governance_status, COUNT(*) AS nb FROM ma.v_signal_semantic_engine GROUP BY semantic_governance_status ORDER BY nb DESC;",
  "SELECT * FROM ma.v_signal_semantic_engine LIMIT 10;"
)

foreach ($q in $queries) {
    Write-Host ""
    Write-Host ">>> Test SQL"
    & $PSQL -U $USER -d $DB -v ON_ERROR_STOP=1 -c $q
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Erreur dry-run P7A1"
        exit 1
    }
}

Write-Host ""
Write-Host "✅ P7A1 dry-run terminé avec succès"
