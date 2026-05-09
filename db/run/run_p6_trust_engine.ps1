$BASE = "G:\osa-observatory"
$PSQL = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
$DB   = "osa_db"
$USER = "postgres"

Write-Host "========================================="
Write-Host " OSA — RUN P6 TRUST & VULNERABILITY ENGINE"
Write-Host "========================================="

cd $BASE

$files = @(
  "db\patch_db\patch_p6_trust_vulnerability_schema.sql",
  "db\views\ma\v_swot_vectors.sql",
  "db\views\ma\v_signal_trust_engine.sql",
  "db\views\ma\v_structural_gap_engine.sql",
  "db\views\ma\v_ai_ml_sovereignty_vector.sql"
)

foreach ($file in $files) {
    Write-Host ">>> SQL : $file"
    & $PSQL -U $USER -d $DB -f "$BASE\$file" -v ON_ERROR_STOP=1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Erreur SQL : $file"
        exit 1
    }
}

Write-Host ">>> Rapport P6"
& $PSQL -U $USER -d $DB -f "$BASE\audit\p6_trust_vulnerability_report.sql" -v ON_ERROR_STOP=1

if ($LASTEXITCODE -ne 0) {
    Write-Host "Erreur rapport P6"
    exit 1
}

Write-Host "P6 Trust & Vulnerability Engine installé"
