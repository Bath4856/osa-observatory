Write-Host "========================================="
Write-Host " OSA — RUN P7K FINALIZATION"
Write-Host "========================================="

$DB="osa_db"
$USER="postgres"

# ------------------------------------------------
# PATCHES
# ------------------------------------------------

psql -U $USER -d $DB -f db/patch_db/patch_p7k_intervention_family_diversification.sql

psql -U $USER -d $DB -f db/patch_db/patch_p7k_priority_recalibration.sql

psql -U $USER -d $DB -f db/patch_db/patch_p7k_cost_model.sql

psql -U $USER -d $DB -f db/patch_db/patch_p7k_materialized_layer.sql

psql -U $USER -d $DB -f db/patch_db/patch_p7k_master_governance_finalize.sql

# ------------------------------------------------
# VIEWS
# ------------------------------------------------

psql -U $USER -d $DB -f db/views/ma/v_isa_predictive_readiness_registry.sql

# ------------------------------------------------
# REFRESH MV
# ------------------------------------------------

psql -U $USER -d $DB -c "
REFRESH MATERIALIZED VIEW ma.mv_isa_executive_master_board;
"

# ------------------------------------------------
# REPORT
# ------------------------------------------------

psql -U $USER -d $DB -f db/reports/report_p7k_finalize.sql

# ------------------------------------------------
# AUDIT
# ------------------------------------------------

psql -U $USER -d $DB -f audit/audit_p7k_finalize.sql

Write-Host ""
Write-Host "✅ P7K FINALIZATION COMPLETE"
