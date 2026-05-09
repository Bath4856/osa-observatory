$BASE = "G:\osa-observatory"

Write-Host "========================================="
Write-Host " OSA — FULL P4 GOVERNANCE"
Write-Host "========================================="

cd $BASE

.\db\run\run_p4_pmin.ps1

python mapping\activation\patch_p4_pmin_industrial.py

cd $BASE\db\run
.\run_mapping_views.ps1
.\run_mapping_maturity.ps1
.\run_mapping_analysis.ps1
