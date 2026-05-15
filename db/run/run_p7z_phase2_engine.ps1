param(
  [string]$DbHost = "127.0.0.1",
  [string]$DbPort = "5432",
  [string]$DbName = "osa_db",
  [string]$DbUser = "postgres"
)
$ErrorActionPreference = "Stop"
$Psql = "psql"

Write-Host "========================================="
Write-Host " OSA — RUN P7Z PHASE 2 ENGINE"
Write-Host "========================================="

function Run-TestSql {
    param([string]$Sql, [string]$Label)
    Write-Host ""; Write-Host ">>> $Label"
    & $Psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -c $Sql
    if ($LASTEXITCODE -ne 0) { throw "Erreur : $Label" }
}
function Run-SQL {
    param([string]$file, [string]$label)
    Write-Host ""; Write-Host ">>> $label"
    & $Psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -f $file
    if ($LASTEXITCODE -ne 0) { throw "Erreur SQL : $file" }
}

# --- Pré-test dépendances P7Z Phase 2
Run-TestSql @"
SELECT
    -- P7Z Phase 1 installée
    (SELECT CASE WHEN COUNT(*)>0 THEN 'OK' ELSE 'MISSING' END
     FROM rf.isa_p7z_baseline_registry)                 AS check_p7z_baseline,

    (SELECT CASE WHEN COUNT(*)=10 THEN 'OK' ELSE 'MISSING' END
     FROM rf.isa_p7z_probability_model)                 AS check_prob_model,

    (SELECT CASE WHEN COUNT(*)=3 THEN 'OK' ELSE 'MISSING' END
     FROM mg.isa_p7z_governance_policy)                 AS check_p7z_policy,

    -- P7K V3 FROZEN
    (SELECT CASE WHEN COUNT(*)>0 THEN 'OK' ELSE 'MISSING' END
     FROM mg.isa_package_freeze_registry
     WHERE package_code='P7K' AND freeze_status='FROZEN') AS check_p7k_frozen,

    -- MV P7K (pg_matviews)
    (SELECT CASE WHEN EXISTS (
        SELECT 1 FROM pg_matviews
        WHERE schemaname='ma'
          AND matviewname='mv_isa_executive_master_board'
     ) THEN 'OK' ELSE 'MISSING' END)                   AS check_mv_p7k,

    -- P7H scénarios
    (SELECT CASE WHEN COUNT(*)>0 THEN 'OK' ELSE 'MISSING' END
     FROM information_schema.views
     WHERE table_schema='ma'
       AND table_name='v_isa_scenario_simulation_engine') AS check_p7h,

    -- P7J décisions
    (SELECT CASE WHEN COUNT(*)>0 THEN 'OK' ELSE 'MISSING' END
     FROM information_schema.views
     WHERE table_schema='ma'
       AND table_name='v_isa_decision_priority_engine')  AS check_p7j;
"@ "Pré-test dépendances P7Z Phase 2"

# --- Patch principal
Run-SQL "db/patch_db/patch_p7z_phase2_engine.sql" `
    "SQL : patch_p7z_phase2_engine.sql"

# --- Rapport 1 : MV exécution probabilité
Run-TestSql @"
SELECT
    COUNT(*)                                            AS mv_rows,
    COUNT(DISTINCT country_iso3)                        AS nb_countries,
    COUNT(DISTINCT pillar_code)                         AS nb_pillars,
    ROUND(AVG(execution_probability),       3)          AS avg_exec_prob,
    ROUND(MIN(execution_probability),       3)          AS min_exec_prob,
    ROUND(MAX(execution_probability),       3)          AS max_exec_prob,
    ROUND(AVG(probability_confidence_interval),3)       AS avg_ci,
    COUNT(*) FILTER (WHERE execution_probability IS NULL) AS null_probs
FROM ma.mv_isa_p7z_execution_probability;
"@ "Rapport — MV execution probability"

# --- Rapport 2 : distribution probabilité
Run-TestSql @"
SELECT
    execution_probability_class,
    p7z_eligibility_class,
    COUNT(*)                                            AS nb,
    ROUND(AVG(execution_probability),       3)          AS avg_prob,
    ROUND(AVG(predictive_gap_score),        3)          AS avg_gap,
    ROUND(AVG(estimated_convergence_years), 1)          AS avg_conv_years
FROM ma.mv_isa_p7z_execution_probability
GROUP BY execution_probability_class, p7z_eligibility_class
ORDER BY avg_prob DESC;
"@ "Rapport — distribution probabilité"

# --- Rapport 3 : convergence par pilier
Run-TestSql @"
SELECT
    pillar_code,
    convergence_class,
    scenario_trend,
    COUNT(*)                                            AS nb_country_years,
    ROUND(AVG(min_conv_years_r),            1)          AS avg_min_conv_years,
    ROUND(AVG(max_exec_prob_r),             3)          AS avg_max_prob,
    SUM(nb_ready)                                       AS total_ready
FROM ma.v_isa_p7z_convergence_engine
GROUP BY pillar_code, convergence_class, scenario_trend
ORDER BY pillar_code, avg_min_conv_years;
"@ "Rapport — convergence par pilier"

# --- Rapport 4 : cascade par pilier
Run-TestSql @"
SELECT
    pillar_code,
    cascade_risk_class,
    COUNT(*)                                            AS nb_country_years,
    ROUND(AVG(cascade_impact_score),        3)          AS avg_cascade_impact,
    ROUND(AVG(failure_probability),         3)          AS avg_failure_prob,
    ROUND(AVG(pillar_resilience_score),     3)          AS avg_resilience
FROM ma.v_isa_p7z_cascade_propagation
GROUP BY pillar_code, cascade_risk_class
ORDER BY pillar_code, avg_cascade_impact DESC;
"@ "Rapport — cascade par pilier"

# --- Rapport 5 : top pays fragiles
Run-TestSql @"
SELECT
    country_iso3, year,
    sovereign_fragility_class,
    p7z_national_status,
    ROUND(sovereign_fragility_index,        3)          AS fragility_idx,
    ROUND(sovereign_resilience_index,       3)          AS resilience_idx,
    ROUND(avg_national_exec_probability,    3)          AS avg_exec_prob,
    most_fragile_pillar,
    most_resilient_pillar,
    nb_high_cascade_pillars,
    total_ready_interventions
FROM ma.v_isa_p7z_fragility_engine
WHERE sovereign_fragility_class IN ('SOVEREIGN_FRAGILE','SOVEREIGN_VULNERABLE')
ORDER BY sovereign_fragility_index DESC, year DESC
LIMIT 20;
"@ "Top pays fragiles / vulnérables"

# --- Rapport 6 : readiness Phase 2
Run-TestSql @"
SELECT * FROM mg.v_p7z_phase2_readiness;
"@ "Rapport — P7Z Phase 2 readiness"

# --- Rapport 7 : package lifecycle
Run-TestSql @"
SELECT package_code, package_status, LEFT(notes,80) AS notes_short, updated_at
FROM rf.package_lifecycle
WHERE package_code IN ('P7K','P7Z')
ORDER BY package_code;
"@ "Package lifecycle"

# --- Checks critiques
Run-TestSql @"
SELECT
    (SELECT COUNT(*) FROM ma.mv_isa_p7z_execution_probability
     WHERE execution_probability IS NULL)               AS null_exec_prob,
    (SELECT COUNT(*) FROM ma.mv_isa_p7z_execution_probability
     WHERE execution_probability NOT BETWEEN 0 AND 1)  AS out_of_bounds,
    (SELECT COUNT(*) FROM ma.v_isa_p7z_convergence_engine) AS convergence_rows,
    (SELECT COUNT(*) FROM ma.v_isa_p7z_cascade_propagation) AS cascade_rows,
    (SELECT COUNT(*) FROM ma.v_isa_p7z_fragility_engine)   AS fragility_rows,
    (SELECT p7z_phase2_status FROM mg.v_p7z_phase2_readiness) AS phase2_status;
"@ "Checks critiques P7Z Phase 2"

Write-Host ""
Write-Host "========================================="
Write-Host " ✅ P7Z PHASE 2 ENGINE COMPLETE"
Write-Host "========================================="
Write-Host ""
Write-Host ">>> Commit suggéré :"
Write-Host @"
git add db/patch_db/patch_p7z_phase2_engine.sql ``
        db/run/run_p7z_phase2_engine.ps1 ``
        db/run/test_p7z_phase2_dry_run.ps1 ``
        README_p7z_phase2_engine.md

git commit -m "feat(p7z): Phase 2 engine — execution probability MV, convergence, cascade propagation, fragility engine"

git push origin main
"@
