Write-Host "========================================="
Write-Host " OSA — TEST P7K FINALIZATION"
Write-Host "========================================="

$DB="osa_db"
$USER="postgres"

# ------------------------------------------------
# MATERIALIZED VIEW
# ------------------------------------------------

psql -U $USER -d $DB -c "
SELECT COUNT(*) AS mv_rows
FROM ma.mv_isa_executive_master_board;
"

# ------------------------------------------------
# READINESS
# ------------------------------------------------

psql -U $USER -d $DB -c "
SELECT COUNT(*) AS predictive_rows
FROM ma.v_isa_predictive_readiness_registry;
"

# ------------------------------------------------
# DISTRIBUTION
# ------------------------------------------------

psql -U $USER -d $DB -c "
SELECT
    executive_master_status,
    COUNT(*)
FROM ma.mv_isa_executive_master_board
GROUP BY executive_master_status
ORDER BY 2 DESC;
"

# ------------------------------------------------
# GOVERNANCE
# ------------------------------------------------

psql -U $USER -d $DB -c "
SELECT
    package_code,
    package_status,
    production_ready,
    freeze_ready
FROM mg.package_governance_registry
WHERE package_code='P7K';
"

Write-Host ""
Write-Host "✅ P7K FINALIZATION TEST COMPLETE"