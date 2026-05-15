param(
  [string]$DbHost = "127.0.0.1",
  [string]$DbPort = "5432",
  [string]$DbName = "osa_db",
  [string]$DbUser = "postgres"
)
$ErrorActionPreference = "Stop"
$Psql = "psql"

Write-Host "========================================="
Write-Host " OSA — P8 V2 DRY RUN TEST"
Write-Host "========================================="

function Run-TestSql {
    param([string]$Sql, [string]$Label)
    Write-Host ""; Write-Host ">>> Test SQL"
    & $Psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -c $Sql
    if ($LASTEXITCODE -ne 0) { throw "Erreur dry-run P8 V2 : $Label" }
}

# --- Objets MG et pub.*
Run-TestSql @"
SELECT
    mg.fn_check_table('mg','release_registry')          AS check_release_registry,
    mg.fn_check_table('mg','publication_registry')      AS check_pub_registry,
    mg.fn_check_table('mg','api_contract_registry')     AS check_api_registry,
    mg.fn_check_table('mg','asset_registry')            AS check_asset_registry,
    mg.fn_check_table('mg','publication_audit_log')     AS check_audit_log;
"@

# --- Vues pub.* ISA scores
Run-TestSql @"
SELECT
    mg.fn_check_view('pub','v_isa_country_latest')      AS check_country_latest,
    mg.fn_check_view('pub','v_isa_country_history')     AS check_country_history,
    mg.fn_check_view('pub','v_isa_country_rankings')    AS check_country_rankings,
    mg.fn_check_view('pub','v_isa_pillar_breakdown')    AS check_pillar_breakdown,
    mg.fn_check_view('pub','v_isa_opportunity_catalog') AS check_opportunity;
"@

# --- Vues pub.* métadonnées
Run-TestSql @"
SELECT
    mg.fn_check_view('pub','v_isa_release_manifest')    AS check_release_manifest,
    mg.fn_check_view('pub','v_isa_public_methodology')  AS check_methodology;
"@

# --- Vues pub.* P7Z Phase 2
Run-TestSql @"
SELECT
    mg.fn_check_view('pub','v_isa_p7z_country_readiness')  AS check_p7z_readiness,
    mg.fn_check_view('pub','v_isa_p7z_execution_signals')  AS check_p7z_signals,
    mg.fn_check_view('pub','v_isa_sovereign_fragility')    AS check_fragility;
"@

# --- Compteurs pub.* views (doit être >= 9)
Run-TestSql @"
SELECT COUNT(*) AS pub_views_count
FROM information_schema.views
WHERE table_schema = 'pub';
"@

# --- Release registry
Run-TestSql @"
SELECT COUNT(*) AS release_rows
FROM mg.release_registry
WHERE release_family = 'P8V2';
"@

# --- Publication datasets (doit être >= 10)
Run-TestSql @"
SELECT COUNT(*) AS pub_dataset_rows
FROM mg.publication_registry
WHERE release_code = 'P8V2_2026_CANDIDATE';
"@

# --- API contracts (doit être >= 12)
Run-TestSql @"
SELECT COUNT(*) AS api_contract_rows
FROM mg.api_contract_registry
WHERE release_code = 'P8V2_2026_CANDIDATE';
"@

# --- Endpoints P7Z présents (doit être >= 4)
Run-TestSql @"
SELECT COUNT(*) AS p7z_endpoint_rows
FROM mg.api_contract_registry
WHERE release_code = 'P8V2_2026_CANDIDATE'
  AND endpoint_code LIKE 'V2_P7Z%' OR endpoint_code LIKE 'V2_SOVEREIGN%';
"@

# --- Volumétrie country_latest (doit être 54)
Run-TestSql @"
SELECT COUNT(*) AS country_latest_rows
FROM pub.v_isa_country_latest;
"@

# --- Volumétrie country_history
Run-TestSql @"
SELECT COUNT(*) AS country_history_rows
FROM pub.v_isa_country_history;
"@

# --- Volumétrie country_rankings
Run-TestSql @"
SELECT COUNT(*) AS country_rankings_rows
FROM pub.v_isa_country_rankings;
"@

# --- Volumétrie pillar_breakdown
Run-TestSql @"
SELECT COUNT(*) AS pillar_breakdown_rows
FROM pub.v_isa_pillar_breakdown;
"@

# --- Volumétrie P7Z readiness
Run-TestSql @"
SELECT COUNT(*) AS p7z_readiness_rows
FROM pub.v_isa_p7z_country_readiness;
"@

# --- Volumétrie P7Z signals
Run-TestSql @"
SELECT COUNT(*) AS p7z_signals_rows
FROM pub.v_isa_p7z_execution_signals;
"@

# --- Volumétrie sovereign fragility
Run-TestSql @"
SELECT COUNT(*) AS fragility_rows
FROM pub.v_isa_sovereign_fragility;
"@

# --- NULL critiques country_latest
Run-TestSql @"
SELECT COUNT(*) AS null_isa_observed_score
FROM pub.v_isa_country_latest
WHERE isa_observed_score IS NULL;
"@

# --- NULL critiques P7Z readiness
Run-TestSql @"
SELECT COUNT(*) AS null_exec_prob
FROM pub.v_isa_p7z_country_readiness
WHERE avg_execution_probability IS NULL;
"@

# --- Scores hors bornes [0,1]
Run-TestSql @"
SELECT COUNT(*) AS out_of_bounds
FROM pub.v_isa_country_latest
WHERE isa_observed_score NOT BETWEEN 0 AND 1
   OR sovereignty_observed_score NOT BETWEEN 0 AND 1;
"@

# --- Release manifest OK
Run-TestSql @"
SELECT
    release_code, release_status, semantic_version,
    nb_datasets, nb_endpoints,
    nb_public_endpoints, nb_expert_endpoints
FROM pub.v_isa_release_manifest;
"@

# --- Package lifecycle P8V2 et P7Z
Run-TestSql @"
SELECT package_code, package_status
FROM rf.package_lifecycle
WHERE package_code IN ('P8OPS','P8V2','P7K','P7Z')
ORDER BY package_code;
"@

# --- Distribution access_class API contracts
Run-TestSql @"
SELECT access_class, COUNT(*) AS nb
FROM mg.api_contract_registry
WHERE release_code = 'P8V2_2026_CANDIDATE'
GROUP BY access_class
ORDER BY access_class;
"@

# --- Distribution sovereign_fragility_class
Run-TestSql @"
SELECT sovereign_fragility_class, COUNT(*) AS nb
FROM pub.v_isa_sovereign_fragility
GROUP BY sovereign_fragility_class
ORDER BY sovereign_fragility_class;
"@

# --- Distribution execution_probability_class P7Z signals
Run-TestSql @"
SELECT execution_probability_class, COUNT(*) AS nb
FROM pub.v_isa_p7z_execution_signals
GROUP BY execution_probability_class
ORDER BY execution_probability_class;
"@

Write-Host ""
Write-Host "✅ P8 V2 dry-run terminé avec succès"
