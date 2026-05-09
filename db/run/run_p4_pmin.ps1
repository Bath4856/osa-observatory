$BASE = "G:\osa-observatory"
$PSQL = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
$DB   = "osa_db"
$USER = "postgres"

Write-Host "========================================="
Write-Host " OSA — RUN P4 PMIN INDUSTRIAL"
Write-Host "========================================="

cd $BASE

$patches = @(
  "db\patch_db\patch_p4a_pmin_usgs_physical.sql",
  "db\patch_db\patch_p4b_pmin_reserves.sql",
  "db\patch_db\patch_p4c_pmin_criticality.sql",
  "db\patch_db\patch_p4d_pmin_extractives_sovereignty.sql"
)

foreach ($patch in $patches) {
    Write-Host ">>> Patch : $patch"
    & $PSQL -U $USER -d $DB -f "$BASE\$patch" -v ON_ERROR_STOP=1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Erreur patch : $patch"
        exit 1
    }
}

Write-Host ">>> Installation vue PMIN industrial quality"
& $PSQL -U $USER -d $DB -f "$BASE\db\views\ma\v_pmin_industrial_quality.sql" -v ON_ERROR_STOP=1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Erreur vue PMIN"
    exit 1
}

Write-Host ">>> Rapport PMIN industriel"
& $PSQL -U $USER -d $DB -f "$BASE\audit\pmin_industrial_report.sql" -v ON_ERROR_STOP=1

Write-Host "✅ P4 PMIN terminé"
