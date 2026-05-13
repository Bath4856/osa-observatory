Write-Host "========================================="
Write-Host " OSA — P7H DRY RUN TEST"
Write-Host "========================================="

$DbHost = if ($env:OSA_DB_HOST) { $env:OSA_DB_HOST } else { "127.0.0.1" }
$DbPort = if ($env:OSA_DB_PORT) { $env:OSA_DB_PORT } else { "5432" }
$DbName = if ($env:OSA_DB_NAME) { $env:OSA_DB_NAME } else { "osa_db" }
$DbUser = if ($env:OSA_DB_USER) { $env:OSA_DB_USER } else { "postgres" }
$Psql = if ($env:PSQL_PATH) { $env:PSQL_PATH } else { "psql" }

function Test-Sql($sql) {
  Write-Host "`n>>> Test SQL"
  & $Psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -c $sql
  if ($LASTEXITCODE -ne 0) { throw "Erreur dry-run P7H" }
}

Test-Sql @"
SELECT
  CASE WHEN to_regclass('rf.isa_scenario_policy') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_scenario_policy,
  CASE WHEN to_regclass('rf.isa_scenario_pillar_elasticity') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_elasticity_policy,
  CASE WHEN to_regclass('ma.v_p7h_scenario_source') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_source,
  CASE WHEN to_regclass('ma.v_isa_scenario_simulation_engine') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_sim_engine,
  CASE WHEN to_regclass('ma.v_isa_scenario_country_year') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_country,
  CASE WHEN to_regclass('ma.v_isa_scenario_readiness') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_readiness;
"@

Test-Sql @"
WITH required_cols AS (
  SELECT unnest(ARRAY[
    'country_iso3','year','pillar_code','scenario_code','simulation_confidence',
    'simulated_isa_delta','simulated_sovereignty_delta','simulated_vulnerability_delta','simulated_resilience_delta',
    'simulated_isa_score','simulation_confidence_class','simulation_decision','simulation_scope'
  ]) AS column_name
), found AS (
  SELECT COUNT(*) AS n
  FROM required_cols r
  JOIN information_schema.columns c
    ON c.table_schema='ma' AND c.table_name='v_isa_scenario_simulation_engine' AND c.column_name=r.column_name
)
SELECT 13 AS required_cols, n AS found_cols, CASE WHEN n=13 THEN 'OK' ELSE 'KO' END AS column_check FROM found;
"@

Test-Sql "SELECT COUNT(*) AS scenario_policy_rows FROM rf.isa_scenario_policy;"
Test-Sql "SELECT COUNT(*) AS elasticity_policy_rows FROM rf.isa_scenario_pillar_elasticity;"
Test-Sql "SELECT COUNT(*) AS scenario_source_rows FROM ma.v_p7h_scenario_source;"
Test-Sql "SELECT COUNT(*) AS simulation_rows FROM ma.v_isa_scenario_simulation_engine;"
Test-Sql "SELECT COUNT(*) AS country_scenario_rows FROM ma.v_isa_scenario_country_year;"
Test-Sql "SELECT COUNT(*) AS readiness_rows FROM ma.v_isa_scenario_readiness;"

Test-Sql @"
SELECT COUNT(*) AS critical_nulls
FROM ma.v_isa_scenario_simulation_engine
WHERE country_iso3 IS NULL
   OR year IS NULL
   OR pillar_code IS NULL
   OR scenario_code IS NULL
   OR simulation_confidence IS NULL
   OR simulated_isa_delta IS NULL
   OR simulation_decision IS NULL;
"@

Test-Sql @"
SELECT COUNT(*) AS out_of_bounds_values
FROM ma.v_isa_scenario_simulation_engine
WHERE simulation_confidence < 0 OR simulation_confidence > 1.5
   OR simulated_isa_score < 0 OR simulated_isa_score > 1.5
   OR simulated_sovereignty_score < 0 OR simulated_sovereignty_score > 1.5
   OR simulated_vulnerability_score < 0 OR simulated_vulnerability_score > 1.5
   OR simulated_resilience_score < 0 OR simulated_resilience_score > 1.5;
"@

Test-Sql @"
SELECT COUNT(*) AS forbidden_premium_terms
FROM ma.v_isa_scenario_simulation_engine
WHERE UPPER(simulation_scope) LIKE '%PREMIUM%'
   OR UPPER(simulation_decision) LIKE '%PREMIUM%';
"@

Test-Sql @"
SELECT COUNT(*) AS missing_baseline_nonzero_delta
FROM ma.v_isa_scenario_simulation_engine
WHERE scenario_code='BASELINE'
  AND (simulated_isa_delta <> 0 OR simulated_sovereignty_delta <> 0 OR simulated_vulnerability_delta <> 0 OR simulated_resilience_delta <> 0);
"@

Test-Sql @"
SELECT scenario_code, COUNT(*) AS nb
FROM ma.v_isa_scenario_simulation_engine
GROUP BY scenario_code
ORDER BY scenario_code;
"@

Test-Sql @"
SELECT COUNT(DISTINCT country_iso3) AS nb_countries,
       COUNT(DISTINCT year) AS nb_years,
       COUNT(DISTINCT pillar_code) AS nb_pillars,
       COUNT(DISTINCT scenario_code) AS nb_scenarios
FROM ma.v_isa_scenario_simulation_engine;
"@

Test-Sql @"
SELECT simulation_decision, COUNT(*) AS nb
FROM ma.v_isa_scenario_simulation_engine
GROUP BY simulation_decision
ORDER BY nb DESC;
"@

Write-Host "`n✅ P7H dry-run terminé avec succès"
