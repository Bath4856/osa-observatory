$PSQL = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
$DB   = "osa_db"
$USER = "postgres"

Write-Host "========================================="
Write-Host " OSA — P7B2 DRY RUN TEST"
Write-Host "========================================="

$queries = @(
  "SELECT COUNT(*) AS nb_confidence_policy_rows FROM rf.semantic_confidence_policy;",
  "SELECT COUNT(*) AS nb_confidence_indicators FROM ma.v_semantic_confidence_engine;",
  "SELECT semantic_confidence_class, COUNT(*) AS nb FROM ma.v_semantic_confidence_engine GROUP BY semantic_confidence_class ORDER BY nb DESC;",
  "SELECT semantic_confidence_decision, COUNT(*) AS nb FROM ma.v_semantic_confidence_engine GROUP BY semantic_confidence_decision ORDER BY nb DESC;",
  "SELECT pillar_code, COUNT(*) AS nb, ROUND(AVG(semantic_confidence_dynamic),3) AS avg_dynamic_confidence FROM ma.v_semantic_confidence_engine GROUP BY pillar_code ORDER BY avg_dynamic_confidence;",
  "SELECT COUNT(*) AS locked_review FROM ma.v_semantic_confidence_engine WHERE semantic_confidence_class='CONFIDENCE_LOCKED_REVIEW';"
)

foreach ($q in $queries) {
  Write-Host ""
  Write-Host ">>> Test SQL"
  & $PSQL -U $USER -d $DB -v ON_ERROR_STOP=1 -c $q
  if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Erreur dry-run P7B2"
    exit 1
  }
}

Write-Host ""
Write-Host "✅ P7B2 dry-run terminé avec succès"
