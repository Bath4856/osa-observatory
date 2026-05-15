Write-Host "========================================="
Write-Host " OSA — RUN P7I EARLY WARNING & RISK"
Write-Host "========================================="

$Psql = "psql"
$DbHost = if ($env:OSA_DB_HOST) { $env:OSA_DB_HOST } else { "127.0.0.1" }
$DbPort = if ($env:OSA_DB_PORT) { $env:OSA_DB_PORT } else { "5432" }
$DbName = if ($env:OSA_DB_NAME) { $env:OSA_DB_NAME } else { "osa_db" }
$DbUser = if ($env:OSA_DB_USER) { $env:OSA_DB_USER } else { "postgres" }

function Invoke-SqlFile($file) {
  Write-Host ">>> SQL : $file"
  & $Psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -f $file
  if ($LASTEXITCODE -ne 0) { throw "Erreur SQL : $file" }
}

Write-Host ">>> Pré-test dépendances P7I"
$pretest = @"
WITH deps AS (
  SELECT
    to_regclass('ma.v_isa_strategic_diagnostic_engine') IS NOT NULL AS has_p7f,
    to_regclass('ma.v_isa_forecast_trend_engine') IS NOT NULL AS has_p7g,
    to_regclass('ma.v_isa_scenario_simulation_engine') IS NOT NULL AS has_p7h,
    to_regclass('ma.v_isa_candidate_intervention_catalog') IS NOT NULL AS has_candidates
), p7f_cols AS (
  SELECT COUNT(*) AS found_p7f_cols
  FROM information_schema.columns
  WHERE table_schema='ma' AND table_name='v_isa_strategic_diagnostic_engine'
    AND column_name IN (
      'country_iso3','year','pillar_code','publication_status','publication_decision',
      'isa_observed_score','sovereignty_observed_score','vulnerability_observed_score','resilience_observed_score',
      'data_completeness','observation_confidence','weakness_score','threat_score','strength_score','opportunity_score',
      'strategic_risk_score','strategic_upside_score','diagnostic_priority_score','strategic_diagnostic_role','strategic_attention_class','swot_data_status'
    )
), p7g_cols AS (
  SELECT COUNT(*) AS found_p7g_cols
  FROM information_schema.columns
  WHERE table_schema='ma' AND table_name='v_isa_forecast_trend_engine'
    AND column_name IN (
      'country_iso3','pillar_code','history_years','avg_observation_confidence','isa_trend_slope','isa_volatility',
      'forecast_policy_code','forecast_trend_class','forecast_trend_status','forecast_blocking_reason'
    )
), p7h_cols AS (
  SELECT COUNT(*) AS found_p7h_cols
  FROM information_schema.columns
  WHERE table_schema='ma' AND table_name='v_isa_scenario_simulation_engine'
    AND column_name IN (
      'country_iso3','year','pillar_code','scenario_code','simulated_isa_delta','simulation_confidence','simulation_decision'
    )
)
SELECT
  CASE WHEN has_p7f THEN 'OK' ELSE 'MISSING' END AS check_p7f,
  CASE WHEN has_p7g THEN 'OK' ELSE 'MISSING' END AS check_p7g,
  CASE WHEN has_p7h THEN 'OK' ELSE 'MISSING' END AS check_p7h,
  CASE WHEN has_candidates THEN 'OK' ELSE 'MISSING' END AS check_candidates,
  21 AS required_p7f_cols,
  found_p7f_cols,
  10 AS required_p7g_cols,
  found_p7g_cols,
  7 AS required_p7h_cols,
  found_p7h_cols,
  CASE WHEN has_p7f AND has_p7g AND has_p7h AND has_candidates
         AND found_p7f_cols = 21 AND found_p7g_cols = 10 AND found_p7h_cols = 7
       THEN 'OK' ELSE 'MISSING_COLUMNS' END AS check_required_columns
FROM deps, p7f_cols, p7g_cols, p7h_cols;
"@
& $Psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -c $pretest
if ($LASTEXITCODE -ne 0) { throw "Erreur SQL pré-test P7I" }

Invoke-SqlFile "db/patch_db/patch_p7i_early_warning_risk.sql"

Write-Host ">>> Drop vues P7I avant recréation"
$dropViewsSql = @"
DROP VIEW IF EXISTS ma.v_isa_early_warning_readiness CASCADE;
DROP VIEW IF EXISTS ma.v_isa_early_warning_country_year CASCADE;
DROP VIEW IF EXISTS ma.v_isa_priority_intervention_alerts CASCADE;
DROP VIEW IF EXISTS ma.v_isa_fragility_warning_engine CASCADE;
DROP VIEW IF EXISTS ma.v_isa_risk_escalation_engine CASCADE;
DROP VIEW IF EXISTS ma.v_isa_early_warning_engine CASCADE;
DROP VIEW IF EXISTS ma.v_p7i_risk_source CASCADE;
"@
& $Psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -c $dropViewsSql
if ($LASTEXITCODE -ne 0) { throw "Erreur DROP vues P7I" }

Invoke-SqlFile "db/views/ma/v_p7i_risk_source.sql"
Invoke-SqlFile "db/views/ma/v_isa_early_warning_engine.sql"
Invoke-SqlFile "db/views/ma/v_isa_risk_escalation_engine.sql"
Invoke-SqlFile "db/views/ma/v_isa_fragility_warning_engine.sql"
Invoke-SqlFile "db/views/ma/v_isa_priority_intervention_alerts.sql"
Invoke-SqlFile "db/views/ma/v_isa_early_warning_country_year.sql"
Invoke-SqlFile "db/views/ma/v_isa_early_warning_readiness.sql"

Write-Host ">>> Rapport P7I"
Invoke-SqlFile "audit/p7i_early_warning_risk_report.sql"

Write-Host "✅ P7I Early Warning & Risk Intelligence installé"
