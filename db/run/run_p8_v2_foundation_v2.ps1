param(
  [string]$DbHost = "127.0.0.1",
  [string]$DbPort = "5432",
  [string]$DbName = "osa_db",
  [string]$DbUser = "postgres"
)
$ErrorActionPreference = "Stop"
$Psql = "psql"

Write-Host "========================================="
Write-Host " OSA — RUN P8 V2 FOUNDATION V2"
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

# --- Pré-test dépendances complètes (scores + P7J + P7Z Phase 2)
Run-TestSql @"
SELECT
    -- Scores ISA observés
    mg.fn_check_view('ma','v_isa_observed_scores_by_country_year') AS check_scores_country,
    mg.fn_check_view('ma','v_isa_observed_scores_by_pillar')       AS check_scores_pillar,
    -- P7J v2
    mg.fn_check_view('ma','v_isa_decision_country_year')           AS check_p7j,
    -- P7K V3
    mg.fn_check_matview('ma','mv_isa_executive_master_board')      AS check_p7k_mv,
    -- P7Z Phase 2
    mg.fn_check_matview('ma','mv_isa_p7z_execution_probability')   AS check_p7z_mv,
    mg.fn_check_view('ma','v_isa_p7z_convergence_engine')          AS check_p7z_conv,
    mg.fn_check_view('ma','v_isa_p7z_fragility_engine')            AS check_p7z_frag,
    -- P7K V3 FROZEN
    (SELECT CASE WHEN COUNT(*)>0 THEN 'OK' ELSE 'MISSING' END
     FROM mg.isa_package_freeze_registry
     WHERE package_code='P7K' AND freeze_status='FROZEN')          AS check_p7k_frozen,
    -- P7Z Phase 2 ACTIVE
    (SELECT CASE WHEN COUNT(*)>0 THEN 'OK' ELSE 'MISSING' END
     FROM rf.package_lifecycle
     WHERE package_code='P7Z' AND package_status='ACTIVE')         AS check_p7z_active,
    -- Catalogue interventions
    mg.fn_check_view('ma','v_isa_candidate_intervention_catalog')  AS check_catalog;
"@ "Pré-test dépendances P8 V2"

# --- Patch principal
Run-SQL "db/patch_db/patch_p8_v2_foundation_v2.sql" `
    "SQL : patch_p8_v2_foundation_v2.sql"

# --- Rapport 1 : vues pub.*
Run-TestSql @"
SELECT table_name, obj_description(
    (quote_ident('pub') || '.' || quote_ident(table_name))::regclass, 'pg_class'
) AS description
FROM information_schema.views
WHERE table_schema = 'pub'
ORDER BY table_name;
"@ "Vues pub.* créées"

# --- Rapport 2 : publication registry
Run-TestSql @"
SELECT dataset_code, dataset_family, access_class, publication_status,
       LEFT(public_api_path, 40) AS api_path
FROM mg.publication_registry
WHERE release_code = 'P8V2_2026_CANDIDATE'
ORDER BY dataset_family, dataset_code;
"@ "Publication registry P8 V2"

# --- Rapport 3 : API contracts
Run-TestSql @"
SELECT endpoint_code, http_method, access_class, auth_required,
       LEFT(api_path, 40) AS api_path
FROM mg.api_contract_registry
WHERE release_code = 'P8V2_2026_CANDIDATE'
ORDER BY access_class, endpoint_code;
"@ "API contracts P8 V2"

# --- Rapport 4 : release manifest
Run-TestSql @"
SELECT release_code, release_status, semantic_version,
       data_period_start, data_period_end,
       nb_datasets, nb_endpoints, nb_public_endpoints, nb_expert_endpoints
FROM pub.v_isa_release_manifest;
"@ "Release manifest"

# --- Rapport 5 : country latest sample (5 pays)
Run-TestSql @"
SELECT country_iso3, latest_year, isa_observed_score,
       country_decision_class,
       sovereign_fragility_class,
       ROUND(avg_exec_probability,3) AS avg_exec_prob
FROM pub.v_isa_country_latest
ORDER BY isa_observed_score DESC NULLS LAST
LIMIT 5;
"@ "Top 5 pays pub.v_isa_country_latest"

# --- Rapport 6 : P7Z readiness sample
Run-TestSql @"
SELECT country_iso3, year,
       nb_simulation_ready, avg_execution_probability,
       min_convergence_years, sovereign_fragility_class
FROM pub.v_isa_p7z_country_readiness
WHERE year = (SELECT MAX(year) FROM pub.v_isa_p7z_country_readiness)
ORDER BY avg_execution_probability DESC
LIMIT 10;
"@ "Top pays P7Z readiness (dernière année)"

# --- Checks critiques
Run-TestSql @"
SELECT
    (SELECT COUNT(*) FROM information_schema.views
     WHERE table_schema = 'pub')                        AS pub_views_count,
    (SELECT COUNT(*) FROM mg.publication_registry
     WHERE release_code = 'P8V2_2026_CANDIDATE')        AS pub_datasets,
    (SELECT COUNT(*) FROM mg.api_contract_registry
     WHERE release_code = 'P8V2_2026_CANDIDATE')        AS api_contracts,
    (SELECT COUNT(*) FROM pub.v_isa_country_latest)     AS country_latest_rows,
    (SELECT COUNT(*) FROM pub.v_isa_country_rankings
     WHERE year = 2024)                                 AS rankings_2024,
    (SELECT COUNT(*) FROM pub.v_isa_p7z_country_readiness) AS p7z_readiness_rows,
    (SELECT COUNT(*) FROM pub.v_isa_sovereign_fragility)   AS fragility_rows;
"@ "Checks critiques P8 V2"

Write-Host ""
Write-Host "========================================="
Write-Host " ✅ P8 V2 FOUNDATION V2 COMPLETE"
Write-Host "========================================="
Write-Host ""
Write-Host ">>> Commit suggéré :"
Write-Host @"
git add db/patch_db/patch_p8_v2_foundation_v2.sql ``
        db/run/run_p8_v2_foundation_v2.ps1

git commit -m "fix(p8): P8 V2 foundation V2 — fix orphan SQL, create pub views, integrate P7Z Phase 2"

git push origin main
"@
