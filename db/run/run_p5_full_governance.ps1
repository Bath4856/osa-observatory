$BASE = "G:\osa-observatory"

Write-Host "========================================="
Write-Host " OSA — RUN P5 FULL GOVERNANCE"
Write-Host "========================================="

cd $BASE
.\db\run\run_p5_zero_orphans.ps1

python mapping\activation\patch_p5_zero_orphans.py

cd "$BASE\db\run"
.\run_mapping_views.ps1
.\run_mapping_maturity.ps1

Write-Host "✅ P5 full governance terminé"
