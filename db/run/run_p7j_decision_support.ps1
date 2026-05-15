# ============================================================
# OSA — RUN P7J DECISION SUPPORT
# ============================================================

$ErrorActionPreference = "Stop"

$DbHost = if ($env:OSA_DB_HOST) { $env:OSA_DB_HOST } else { "127.0.0.1" }
$DbPort = if ($env:OSA_DB_PORT) { $env:OSA_DB_PORT } else { "5432" }
$DbName = if ($env:OSA_DB_NAME) { $env:OSA_DB_NAME } else { "osa_db" }
$DbUser = if ($env:OSA_DB_USER) { $env:OSA_DB_USER } else { "postgres" }
$Psql = if ($env:PSQL_BIN) { $env:PSQL_BIN } else { "psql" }

Write-Host "========================================="
Write-Host " OSA — RUN P7J DECISION SUPPORT"
Write-Host "========================================="

Write-Host ">>> Pré-test dépendances P7J"
& $Psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -c @"
WITH deps AS (
    SELECT
        to_regclass('ma.v_isa_priority_intervention_alerts') IS NOT NULL AS has_p7i_alerts,
        to_regclass('ma.v_isa_scenario_simulation_engine') IS NOT NULL AS has_p7h_scenarios,
        to_regclass('ma.v_isa_early_warning_engine') IS NOT NULL AS has_p7i_warning
), p7i_cols AS (
    SELECT COUNT(*) AS found_p7i_cols
    FROM information_schema.columns
    WHERE table_schema='ma'
      AND table_name='v_isa_priority_intervention_alerts'
      AND column_name IN (
        'country_iso3','year','pillar_code','intervention_family_code',
        'intervention_family_label','strategic_objective','recommended_action',
        'candidate_intervention_status','sovereign_alert_level','early_warning_score',
        'early_warning_confidence','intervention_alert_priority_score',
        'intervention_priority_class','priority_intervention_action'
      )
), p7h_cols AS (
    SELECT COUNT(*) AS found_p7h_cols
    FROM information_schema.columns
    WHERE table_schema='ma'
      AND table_name='v_isa_scenario_simulation_engine'
      AND column_name IN (
        'country_iso3','year','pillar_code','scenario_code','simulated_isa_delta',
        'simulation_confidence','simulation_decision'
      )
)
SELECT
    CASE WHEN has_p7i_alerts THEN 'OK' ELSE 'KO' END AS check_p7i_alerts,
    CASE WHEN has_p7h_scenarios THEN 'OK' ELSE 'KO' END AS check_p7h_scenarios,
    CASE WHEN has_p7i_warning THEN 'OK' ELSE 'KO' END AS check_p7i_warning,
    14 AS required_p7i_cols,
    found_p7i_cols,
    7 AS required_p7h_cols,
    found_p7h_cols,
    CASE WHEN has_p7i_alerts AND has_p7h_scenarios AND has_p7i_warning AND found_p7i_cols = 14 AND found_p7h_cols = 7
         THEN 'OK' ELSE 'MISSING_COLUMNS' END AS check_required_columns
FROM deps, p7i_cols, p7h_cols;
"@
if ($LASTEXITCODE -ne 0) { throw "Erreur SQL pré-test P7J" }

$SqlFiles = @(
  "db/patch_db/patch_p7j_decision_support.sql"
)

foreach ($file in $SqlFiles) {
  Write-Host ">>> SQL : $file"
  & $Psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -f $file
  if ($LASTEXITCODE -ne 0) { throw "Erreur SQL : $file" }
}

Write-Host ">>> Drop vues P7J avant recréation"
& $Psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -c @"
DROP VIEW IF EXISTS ma.v_isa_decision_readiness CASCADE;
DROP VIEW IF EXISTS ma.v_isa_decision_country_year CASCADE;
DROP VIEW IF EXISTS ma.v_isa_intervention_decision_matrix CASCADE;
DROP VIEW IF EXISTS ma.v_isa_decision_priority_engine CASCADE;
DROP VIEW IF EXISTS ma.v_p7j_decision_source CASCADE;
"@
if ($LASTEXITCODE -ne 0) { throw "Erreur DROP vues P7J" }

$ViewFiles = @(
  "db/views/ma/v_p7j_decision_source.sql",
  "db/views/ma/v_isa_decision_priority_engine.sql",
  "db/views/ma/v_isa_intervention_decision_matrix.sql",
  "db/views/ma/v_isa_decision_country_year.sql",
  "db/views/ma/v_isa_decision_readiness.sql"
)

foreach ($file in $ViewFiles) {
  Write-Host ">>> SQL : $file"
  & $Psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -f $file
  if ($LASTEXITCODE -ne 0) { throw "Erreur SQL : $file" }
}

Write-Host ">>> Rapport P7J"
Write-Host ">>> SQL : audit/p7j_decision_support_report.sql"
& $Psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -f "audit/p7j_decision_support_report.sql"
if ($LASTEXITCODE -ne 0) { throw "Erreur rapport P7J" }

Write-Host "✅ P7J Decision Support installé"
