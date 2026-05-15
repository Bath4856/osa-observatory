param(
  [string]$DbHost = "127.0.0.1",
  [string]$DbPort = "5432",
  [string]$DbName = "osa_db",
  [string]$DbUser = "postgres"
)
$ErrorActionPreference = "Stop"
$Psql = "psql"

Write-Host "========================================="
Write-Host " OSA — RUN P7Z PHASE 1 FOUNDATIONS"
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

# --- Pré-test dépendances P7Z (pg_matviews corrigé)
Run-TestSql @"
SELECT
    -- P7K V3 FROZEN obligatoire
    (SELECT CASE WHEN COUNT(*)>0 THEN 'OK' ELSE 'MISSING' END
     FROM mg.isa_package_freeze_registry
     WHERE package_code='P7K'
       AND package_version='V3'
       AND freeze_status='FROZEN')                          AS check_p7k_frozen,

    -- MV P7K opérationnelle (pg_matviews)
    (SELECT CASE WHEN EXISTS (
        SELECT 1 FROM pg_matviews
        WHERE schemaname='ma'
          AND matviewname='mv_isa_executive_master_board'
     ) THEN 'OK' ELSE 'MISSING' END)                       AS check_mv_p7k,

    -- predictive_gap_score présent dans MV
    (SELECT CASE WHEN COUNT(*)>0 THEN 'OK' ELSE 'MISSING' END
     FROM information_schema.columns
     WHERE table_schema='ma'
       AND table_name='mv_isa_executive_master_board'
       AND column_name='predictive_gap_score')              AS check_gap_score,

    -- MG governance policy installée
    (SELECT CASE WHEN COUNT(*)=3 THEN 'OK' ELSE 'MISSING' END
     FROM mg.isa_model_governance_policy)                   AS check_mg_policy,

    -- Lineage installé
    (SELECT CASE WHEN COUNT(*)>0 THEN 'OK' ELSE 'MISSING' END
     FROM mg.isa_view_lineage_registry)                     AS check_lineage;
"@ "Pré-test dépendances P7Z Phase 1"

# --- Patch principal
Run-SQL "db/patch_db/patch_p7z_phase1_foundations.sql" `
    "SQL : patch_p7z_phase1_foundations.sql"

# --- Rapport 1 : baseline
Run-TestSql @"
SELECT
    COUNT(*)                                                AS baseline_rows,
    COUNT(DISTINCT country_iso3)                            AS nb_countries,
    COUNT(DISTINCT year)                                    AS nb_years,
    COUNT(DISTINCT pillar_code)                             AS nb_pillars,
    ROUND(AVG(predictive_gap_score),3)                      AS avg_gap,
    ROUND(MIN(predictive_gap_score),3)                      AS min_gap,
    ROUND(MAX(predictive_gap_score),3)                      AS max_gap,
    COUNT(*) FILTER (WHERE predictive_gap_score = 0)        AS gap_zero_count
FROM rf.isa_p7z_baseline_registry;
"@ "Rapport — baseline P7Z"

# --- Rapport 2 : probability model
Run-TestSql @"
SELECT
    pillar_code,
    ROUND(gap_decay_rate,3)                 AS decay_rate,
    ROUND(convergence_horizon_years,1)      AS conv_years,
    ROUND(systemic_fragility_weight,3)      AS fragility_w,
    ROUND(cascade_failure_probability,3)    AS cascade_p,
    ROUND(execution_probability_base,3)     AS exec_prob_base,
    calibration_status,
    ROUND(calibration_uncertainty_score,3)  AS uncertainty
FROM rf.isa_p7z_probability_model
ORDER BY gap_decay_rate DESC;
"@ "Rapport — probability model par pilier"

# --- Rapport 3 : gouvernance P7Z
Run-TestSql @"
SELECT
    eligibility_class,
    max_predictive_gap,
    max_uncertainty,
    min_execution_maturity,
    eligible_convergence_modelling  AS conv,
    eligible_cascade_modelling      AS cascade,
    eligible_fragility_scoring      AS fragility,
    eligible_isa_projection         AS isa_proj,
    eligibility_label
FROM mg.isa_p7z_governance_policy
ORDER BY max_predictive_gap;
"@ "Rapport — gouvernance P7Z"

# --- Rapport 4 : éligibilité par pilier
Run-TestSql @"
SELECT
    pillar_code,
    p7z_eligibility_class,
    COUNT(*)                                            AS nb_rows,
    ROUND(AVG(predictive_gap_score),3)                  AS avg_gap,
    ROUND(MIN(predictive_gap_score),3)                  AS min_gap,
    ROUND(AVG(estimated_execution_probability),3)       AS avg_exec_prob,
    ROUND(AVG(calibration_uncertainty_score),3)         AS avg_uncertainty
FROM mg.v_p7z_simulation_eligibility
GROUP BY pillar_code, p7z_eligibility_class
ORDER BY pillar_code, p7z_eligibility_class;
"@ "Rapport — éligibilité P7Z par pilier"

# --- Rapport 5 : top candidats SIMULATION_READY ou PARTIAL
Run-TestSql @"
SELECT
    country_iso3, year, pillar_code,
    p7z_eligibility_class,
    ROUND(predictive_gap_score,3)               AS gap,
    ROUND(estimated_execution_probability,3)    AS exec_prob,
    ROUND(calibration_uncertainty_score,3)      AS uncertainty,
    eligible_convergence_modelling              AS conv,
    eligible_cascade_modelling                  AS cascade
FROM mg.v_p7z_simulation_eligibility
WHERE p7z_eligibility_class IN ('P7Z_SIMULATION_READY','P7Z_SIMULATION_PARTIAL')
ORDER BY estimated_execution_probability DESC,
         predictive_gap_score ASC
LIMIT 20;
"@ "Top candidats P7Z (READY + PARTIAL)"

# --- Rapport 6 : package lifecycle
Run-TestSql @"
SELECT package_code, package_status, updated_at
FROM rf.package_lifecycle
WHERE package_code IN ('P7K','P7Z')
ORDER BY package_code;
"@ "Package lifecycle P7K + P7Z"

# --- Checks critiques
Run-TestSql @"
SELECT
    (SELECT COUNT(*) FROM rf.isa_p7z_baseline_registry)     AS baseline_rows,
    (SELECT COUNT(*) FROM rf.isa_p7z_probability_model)     AS prob_model_rows,
    (SELECT COUNT(*) FROM mg.isa_p7z_governance_policy)     AS gov_policy_rows,
    (SELECT COUNT(*) FROM mg.v_p7z_simulation_eligibility
     WHERE estimated_execution_probability IS NULL)          AS null_exec_prob,
    (SELECT COUNT(*) FROM mg.v_p7z_simulation_eligibility
     WHERE p7z_eligibility_class IS NULL)                    AS null_eligibility,
    (SELECT COUNT(*) FROM rf.isa_p7z_probability_model
     WHERE calibration_status IS NULL
        OR calibration_uncertainty_score IS NULL)            AS uncalibrated_rows;
"@ "Checks critiques P7Z Phase 1"

Write-Host ""
Write-Host "========================================="
Write-Host " ✅ P7Z PHASE 1 FOUNDATIONS COMPLETE"
Write-Host "========================================="
Write-Host ""
Write-Host ">>> Commit suggéré :"
Write-Host @"
git add db/patch_db/patch_mg_check_helpers.sql ``
        db/patch_db/patch_p7z_phase1_foundations.sql ``
        db/run/run_mg_freeze_lineage_v1.ps1 ``
        db/run/run_p7k_cost_model_v3.ps1 ``
        db/run/run_p7z_phase1_foundations.ps1

git commit -m "feat(p7z): Phase 1 foundations — baseline registry, probability model, governance policy, simulation eligibility + fix pg_matviews checks"

git push origin main
"@
