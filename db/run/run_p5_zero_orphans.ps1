$BASE = "G:\osa-observatory"
$PSQL = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
$DB   = "osa_db"
$USER = "postgres"

Write-Host "========================================="
Write-Host " OSA — RUN P5 ZERO ORPHANS"
Write-Host "========================================="

$patches = @(
  "db\patch_db\patch_p5a_pmil_security.sql",
  "db\patch_db\patch_p5b_phum_structural.sql",
  "db\patch_db\patch_p5c_hybrids_final.sql"
)

cd $BASE

foreach ($p in $patches) {
  $file = Join-Path $BASE $p
  if (!(Test-Path $file)) {
    Write-Host "❌ Patch introuvable : $file"
    exit 1
  }
  Write-Host ">>> Patch : $p"
  & $PSQL -U $USER -d $DB -f $file -v ON_ERROR_STOP=1
  if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Erreur patch : $p"
    exit 1
  }
}

Write-Host ">>> Installation vue orphan resolution"
& $PSQL -U $USER -d $DB -f "$BASE\db\views\ma\v_orphan_resolution_status.sql" -v ON_ERROR_STOP=1
if ($LASTEXITCODE -ne 0) {
  Write-Host "❌ Erreur installation vue orphan resolution"
  exit 1
}

Write-Host "✅ P5 zero orphans terminé"
