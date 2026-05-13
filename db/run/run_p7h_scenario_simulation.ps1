Write-Host "========================================="
Write-Host " OSA — RUN P7H SCENARIO SIMULATION"
Write-Host "========================================="

$DbHost = if ($env:OSA_DB_HOST) { $env:OSA_DB_HOST } else { "127.0.0.1" }
$DbPort = if ($env:OSA_DB_PORT) { $env:OSA_DB_PORT } else { "5432" }
$DbName = if ($env:OSA_DB_NAME) { $env:OSA_DB_NAME } else { "osa_db" }
$DbUser = if ($env:OSA_DB_USER) { $env:OSA_DB_USER } else { "postgres" }
$Psql = if ($env:PSQL_PATH) { $env:PSQL_PATH } else { "psql" }

function Invoke-SqlFile($file) {
  Write-Host ">>> SQL : $file"
  & $Psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -f $file
  if ($LASTEXITCODE -ne 0) { throw "Erreur SQL : $file" }
}

Write-Host ">>> Pré-test dépendances P7H"
$precheck = @"
WITH deps AS (
  SELECT
    to_regclass('ma.v_isa_strategic_diagnostic_engine') IS NOT NULL AS has_p7f,
    to_regclass('ma.v_isa_forecast_trend_engine') IS NOT NULL AS has_p7g
), required_diag_cols AS (
  SELECT unnest(ARRAY[
    'country_iso3','year','pillar_code','publication_status','publication_decision',
    'isa_observed_score','sovereignty_observed_score','vulnerability_observed_score','resilience_observed_score',
    'data_completeness','observation_confidence','weakness_score','threat_score','strength_score','opportunity_score',
    'strategic_risk_score','strategic_upside_score','diagnostic_priority_score','strategic_diagnostic_role','strategic_attention_class'
  ]) AS column_name
), required_g_cols AS (
  SELECT unnest(ARRAY[
    'country_iso3','pillar_code','forecast_policy_code','forecast_trend_status','forecast_blocking_reason',
    'forecast_trend_class','isa_trend_slope','isa_volatility','avg_forecast_readiness_score','avg_ml_readiness_score'
  ]) AS column_name
), found_diag AS (
  SELECT COUNT(*) AS n
  FROM required_diag_cols r
  JOIN information_schema.columns c
    ON c.table_schema='ma' AND c.table_name='v_isa_strategic_diagnostic_engine' AND c.column_name=r.column_name
), found_g AS (
  SELECT COUNT(*) AS n
  FROM required_g_cols r
  JOIN information_schema.columns c
    ON c.table_schema='ma' AND c.table_name='v_isa_forecast_trend_engine' AND c.column_name=r.column_name
)
SELECT
  CASE WHEN has_p7f THEN 'OK' ELSE 'KO' END AS check_p7f,
  CASE WHEN has_p7g THEN 'OK' ELSE 'KO' END AS check_p7g,
  20 AS required_p7f_cols,
  (SELECT n FROM found_diag) AS found_p7f_cols,
  10 AS required_p7g_cols,
  (SELECT n FROM found_g) AS found_p7g_cols,
  CASE WHEN has_p7f AND has_p7g AND (SELECT n FROM found_diag)=20 AND (SELECT n FROM found_g)=10 THEN 'OK' ELSE 'MISSING_COLUMNS' END AS check_required_columns
FROM deps;
"@

& $Psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -c $precheck
if ($LASTEXITCODE -ne 0) { throw "Erreur SQL pré-test P7H" }

Invoke-SqlFile "db/patch_db/patch_p7h_scenario_simulation.sql"
Invoke-SqlFile "db/views/ma/v_p7h_scenario_source.sql"
Invoke-SqlFile "db/views/ma/v_isa_scenario_policy_engine.sql"
Invoke-SqlFile "db/views/ma/v_isa_scenario_simulation_engine.sql"
Invoke-SqlFile "db/views/ma/v_isa_scenario_country_year.sql"
Invoke-SqlFile "db/views/ma/v_isa_scenario_readiness.sql"

Write-Host ">>> Rapport P7H"
& $Psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -f "audit/p7h_scenario_simulation_report.sql"
if ($LASTEXITCODE -ne 0) { throw "Erreur rapport P7H" }

Write-Host "✅ P7H Scenario Simulation installé"
