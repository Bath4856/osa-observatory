$PSQL = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
$DB   = "osa_db"
$USER = "postgres"

Write-Host "========================================="
Write-Host " OSA — P7A2 DRY RUN TEST"
Write-Host "========================================="

$queries = @(
    "SELECT COUNT(*) AS nb_semantic_indicators FROM ma.v_signal_semantic_engine_v2;",
    "SELECT semantic_governance_status, COUNT(*) AS nb FROM ma.v_signal_semantic_engine_v2 GROUP BY semantic_governance_status ORDER BY nb DESC;",
    "SELECT semantic_code, COUNT(*) AS nb FROM ma.v_signal_semantic_engine_v2 GROUP BY semantic_code ORDER BY nb DESC;",
    "SELECT COUNT(*) AS review_remaining FROM ma.v_signal_semantic_engine_v2 WHERE semantic_governance_status='REVIEW_RECOMMENDED';",
    "SELECT indicator_code, pillar_code, semantic_code, semantic_confidence, semantic_source, applied_rule_code FROM ma.v_signal_semantic_engine_v2 WHERE applied_rule_code IS NOT NULL LIMIT 20;"
)

foreach ($q in $queries) {
    Write-Host ""
    Write-Host ">>> Test SQL"
    & $PSQL -U $USER -d $DB -v ON_ERROR_STOP=1 -c $q
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Erreur dry-run P7A2"
        exit 1
    }
}

Write-Host ""
Write-Host "✅ P7A2 dry-run terminé avec succès"
