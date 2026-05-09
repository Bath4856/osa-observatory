# ============================================================
# OSA / ISA — RUN P3 PHYSICAL MAPPING
# ============================================================

$BASE = "G:\osa-observatory"
$PSQL = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
$DB   = "osa_db"
$USER = "postgres"

Set-Location $BASE

Write-Host "========================================="
Write-Host " OSA — RUN P3 PHYSICAL MAPPING"
Write-Host "========================================="

$patch = "$BASE\db\patch_db\patch_p3_physical_mapping.sql"

if (!(Test-Path $patch)) {
    Write-Host "❌ Patch introuvable : $patch"
    exit 1
}

& $PSQL -U $USER -d $DB -f $patch -v ON_ERROR_STOP=1

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Erreur patch P3"
    exit 1
}

Write-Host "✅ Patch P3 appliqué"
