param(
  [string]$DbHost = "127.0.0.1",
  [string]$DbPort = "5432",
  [string]$DbName = "osa_db",
  [string]$DbUser = "postgres"
)
$ErrorActionPreference = "Stop"
$Psql = "psql"

Write-Host "========================================="
Write-Host " OSA — MG FREEZE & LINEAGE V1"
Write-Host "========================================="

function Run-TestSql {
    param([string]$Sql, [string]$Label)
    Write-Host ""
    Write-Host ">>> $Label"
    & $Psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -c $Sql
    if ($LASTEXITCODE -ne 0) { throw "Erreur : $Label" }
}

function Run-SQL {
    param([string]$file, [string]$label)
    Write-Host ""
    Write-Host ">>> $label"
    & $Psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -f $file
    if ($LASTEXITCODE -ne 0) { throw "Erreur SQL : $file" }
}

# --- Pré-test dépendances
Run-TestSql @"
SELECT
    (SELECT CASE WHEN COUNT(*)>0 THEN 'OK' ELSE 'MISSING' END
     FROM rf.package_lifecycle
     WHERE package_code='P7K')                          AS check_p7k_lifecycle,
    (SELECT CASE WHEN COUNT(*)>0 THEN 'OK' ELSE 'MISSING' END
     FROM information_schema.tables
     WHERE table_schema='ma'
       AND table_name='mv_isa_executive_master_board')  AS check_mv,
    (SELECT CASE WHEN COUNT(*)>0 THEN 'OK' ELSE 'MISSING' END
     FROM mg.isa_model_governance_policy)               AS check_mg_policy;
"@ "Pré-test dépendances"

# --- Patch principal
Run-SQL "db/patch_db/patch_mg_freeze_lineage_v1.sql" `
    "SQL : patch_mg_freeze_lineage_v1.sql"

# --- Rapport freeze
Run-TestSql @"
SELECT
    package_code, package_version, freeze_status,
    TO_CHAR(freeze_date,'YYYY-MM-DD HH24:MI') AS freeze_date,
    snapshot_rows, snapshot_countries,
    snapshot_years, snapshot_pillars,
    snapshot_audit_status
FROM mg.isa_package_freeze_registry
ORDER BY freeze_date DESC;
"@ "Rapport freeze P7K V3"

# --- Vérification package_lifecycle
Run-TestSql @"
SELECT package_code, package_status, updated_at
FROM rf.package_lifecycle
WHERE package_code = 'P7K';
"@ "Package lifecycle P7K"

# --- Rapport lineage — objets à risque CASCADE
Run-TestSql @"
SELECT
    at_risk_object, target_object_type,
    nb_dependents, dependent_objects
FROM mg.v_lineage_cascade_risk
ORDER BY nb_dependents DESC;
"@ "Lineage — objets à risque CASCADE HIGH"

# --- Rapport lineage — ordre de recréation
Run-TestSql @"
SELECT
    refresh_order, schema_name, object_name,
    object_type, nb_dependencies
FROM mg.v_lineage_refresh_order
ORDER BY refresh_order, schema_name, object_name;
"@ "Lineage — ordre de recréation sûr"

# --- Rapport lineage — chaîne MV complète
Run-TestSql @"
SELECT
    refresh_order, source_object_full,
    dependency_type, cascade_risk,
    target_object_full
FROM mg.v_lineage_dependency_chain
WHERE source_object_full LIKE '%executive_master_board%'
   OR target_object_full LIKE '%executive_master_board%'
ORDER BY refresh_order;
"@ "Lineage — chaîne mv_isa_executive_master_board"

# --- Checks critiques
Run-TestSql @"
SELECT
    (SELECT COUNT(*) FROM mg.isa_package_freeze_registry
     WHERE freeze_status='FROZEN')                      AS frozen_packages,
    (SELECT COUNT(*) FROM mg.isa_view_lineage_registry) AS lineage_rows,
    (SELECT COUNT(DISTINCT target_schema||'.'||target_object)
     FROM mg.isa_view_lineage_registry
     WHERE cascade_risk='HIGH')                         AS high_risk_objects,
    (SELECT CASE WHEN COUNT(*)=3 THEN 'OK' ELSE 'KO' END
     FROM information_schema.views
     WHERE table_schema='mg'
       AND table_name IN (
           'v_lineage_dependency_chain',
           'v_lineage_refresh_order',
           'v_lineage_cascade_risk'))                   AS mg_views_status;
"@ "Checks critiques"

Write-Host ""
Write-Host "========================================="
Write-Host " ✅ MG FREEZE & LINEAGE V1 COMPLETE"
Write-Host "========================================="
Write-Host ""
Write-Host ">>> Commit suggéré :"
Write-Host @"
git add db/patch_db/patch_mg_freeze_lineage_v1.sql ``
        db/run/run_mg_freeze_lineage_v1.ps1 ``
        README_mg_freeze_lineage_v1.md

git commit -m "feat(mg): freeze P7K V3 baseline + view lineage registry with cascade risk and refresh order"

git push origin main
"@
