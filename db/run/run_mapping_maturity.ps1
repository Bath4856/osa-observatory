# ============================================================
# OSA / ISA — INSTALL VIEW + REPORT MAPPING MATURITY
# ============================================================

$BASE = "G:\osa-observatory"
$PSQL = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
$DB   = "osa_db"
$USER = "postgres"

Set-Location "$BASE\db"

Write-Host "========================================="
Write-Host " OSA — INSTALL MAPPING MATURITY VIEW"
Write-Host "========================================="

$view = "$BASE\db\views\ma\v_mapping_maturity.sql"
$report = "$BASE\audit\mapping_maturity_report.sql"

if (!(Test-Path $view)) {
    Write-Host "❌ Vue introuvable : $view"
    exit 1
}

& $PSQL -U $USER -d $DB -f $view -v ON_ERROR_STOP=1

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Erreur installation vue maturité"
    exit 1
}

Write-Host "✅ Vue ma.v_mapping_maturity installée"

if (Test-Path $report) {
    Write-Host ">>> Rapport maturité"
    & $PSQL -U $USER -d $DB -f $report -v ON_ERROR_STOP=1
}
