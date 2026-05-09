# ============================================================
# OSA / ISA — FULL MAPPING GOVERNANCE WORKFLOW
# ============================================================

$BASE = "G:\osa-observatory"
Set-Location $BASE

Write-Host "========================================="
Write-Host " OSA — FULL MAPPING GOVERNANCE"
Write-Host "========================================="

Write-Host ">>> 1. Patch P3"
& "$BASE\db\run\run_p3_mapping.ps1"
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host ">>> 2. Installation vues mapping existantes"
& "$BASE\db\run\run_mapping_views.ps1"
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host ">>> 3. Installation vue maturité"
& "$BASE\db\run\run_mapping_maturity.ps1"
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host ">>> 4. Export mapping analysis"
python "$BASE\audit\scripts\export_mapping_analysis_v3.py"
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host ">>> 5. Export mapping maturity"
python "$BASE\audit\scripts\export_mapping_maturity.py"
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host "✅ Workflow complet terminé"
