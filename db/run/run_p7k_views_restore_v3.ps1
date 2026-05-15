param(
  [string]$DbHost = "127.0.0.1",
  [string]$DbPort = "5432",
  [string]$DbName = "osa_db",
  [string]$DbUser = "postgres"
)
$ErrorActionPreference = "Stop"
$Psql = "psql"

Write-Host "========================================="
Write-Host " OSA — P7K VIEWS RESTORE V3"
Write-Host "========================================="

function Run-SQL {
    param([string]$file, [string]$label)
    Write-Host ""
    Write-Host ">>> $label"
    & $Psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -f $file
    if ($LASTEXITCODE -ne 0) { throw "Erreur SQL : $file" }
}

# --- Patch restore
Run-SQL "db/patch_db/patch_p7k_views_restore_v3.sql" `
    "SQL : patch_p7k_views_restore_v3.sql"

# --- Contrôle rapide
Write-Host ""
Write-Host ">>> Contrôle post-restore"
& $Psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -c @"
SELECT
    (SELECT COUNT(*) FROM ma.mv_isa_executive_master_board)         AS mv_rows,
    (SELECT COUNT(*) FROM ma.mv_isa_executive_master_board
     WHERE predictive_gap_score IS NULL)                            AS gap_nulls,
    (SELECT COUNT(*) FROM ma.v_isa_executive_cost_projection
     LIMIT 1)                                                       AS cp_accessible,
    (SELECT COUNT(*) FROM ma.v_isa_executive_master_board
     LIMIT 1)                                                       AS mb_accessible,
    (SELECT COUNT(*) FROM ma.v_isa_predictive_readiness_registry)   AS prr_rows,
    (SELECT ROUND(AVG(predictive_gap_score),3)
     FROM ma.mv_isa_executive_master_board)                         AS avg_gap,
    (SELECT ROUND(MIN(predictive_gap_score),3)
     FROM ma.mv_isa_executive_master_board)                         AS min_gap;
"@
if ($LASTEXITCODE -ne 0) { throw "Contrôle post-restore échoué" }

# --- Rapport predictive_gap par pilier
Write-Host ""
Write-Host ">>> Predictive gap par pilier (top 5 les plus proches du seuil)"
& $Psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -c @"
SELECT pillar_code, nb_rows, avg_priority, avg_pressure,
       avg_predictive_gap, min_predictive_gap,
       nb_predictive_ready, nb_predictive_caution, nb_predictive_blocked
FROM ma.v_isa_predictive_readiness_registry
ORDER BY min_predictive_gap ASC
LIMIT 5;
"@
if ($LASTEXITCODE -ne 0) { throw "Rapport predictive gap échoué" }

Write-Host ""
Write-Host "========================================="
Write-Host " ✅ P7K VIEWS RESTORE V3 COMPLETE"
Write-Host "========================================="
Write-Host ""
Write-Host ">>> Commit suggéré :"
Write-Host @"
git add db/patch_db/patch_p7k_views_restore_v3.sql ``
        db/patch_db/patch_p7k_materialized_layer_v3.sql ``
        db/views/ma/v_isa_executive_cost_projection.sql ``
        db/views/ma/v_isa_executive_master_board.sql ``
        db/views/ma/v_isa_predictive_readiness_registry.sql ``
        db/run/run_p7k_views_restore_v3.ps1 ``
        README_p7k_cost_model_v3.md

git commit -m "fix(p7k): restore cascaded views, add predictive_gap_score and sovereign_dependency_score to MV V3"

git push origin main
"@
