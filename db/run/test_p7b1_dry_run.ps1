$PSQL = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
$DB   = "osa_db"
$USER = "postgres"

Write-Host "========================================="
Write-Host " OSA — P7B1 DRY RUN TEST"
Write-Host "========================================="

$queries = @(
  "SELECT COUNT(*) AS nb_semantic_governance_rows FROM rf.semantic_governance_matrix;",
  "SELECT COUNT(*) AS nb_governed_indicators FROM ma.v_semantic_governance_engine;",
  "SELECT semantic_governance_class, COUNT(*) AS nb FROM ma.v_semantic_governance_engine GROUP BY semantic_governance_class ORDER BY nb DESC;",
  "SELECT semantic_imputation_decision, COUNT(*) AS nb FROM ma.v_semantic_governance_engine GROUP BY semantic_imputation_decision ORDER BY nb DESC;",
  "SELECT semantic_ml_decision, COUNT(*) AS nb FROM ma.v_semantic_governance_engine GROUP BY semantic_ml_decision ORDER BY nb DESC;",
  "SELECT pillar_code, COUNT(*) AS nb, ROUND(AVG(semantic_governance_score),3) AS avg_governance FROM ma.v_semantic_governance_engine GROUP BY pillar_code ORDER BY avg_governance;"
)

foreach ($q in $queries) {
  Write-Host ""
  Write-Host ">>> Test SQL"
  & $PSQL -U $USER -d $DB -v ON_ERROR_STOP=1 -c $q
  if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Erreur dry-run P7B1"
    exit 1
  }
}

Write-Host ""
Write-Host "✅ P7B1 dry-run terminé avec succès"
