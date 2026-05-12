$ErrorActionPreference = "Stop"

Write-Host "========================================="
Write-Host " OSA — RUN P7X SWOT STRATEGIC INTELLIGENCE"
Write-Host "========================================="

$Psql = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
$Db = "osa_db"
$User = "postgres"

function Run-SqlFile($file) {
    Write-Host ">>> SQL : $file"
    & $Psql -h 127.0.0.1 -U $User -d $Db -v ON_ERROR_STOP=1 -f $file
    if ($LASTEXITCODE -ne 0) { throw "Erreur SQL : $file" }
}

Write-Host ">>> Pré-test dépendances P7X"
& $Psql -h 127.0.0.1 -U $User -d $Db -v ON_ERROR_STOP=1 -c "
WITH deps AS (
    SELECT
      EXISTS (SELECT 1 FROM information_schema.views WHERE table_schema='ma' AND table_name='v_isa_observed_scores_by_pillar') AS has_p7e_pillar,
      EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='ma' AND table_name='computed_values') AS has_computed_values
), cols AS (
    SELECT
      SUM(CASE WHEN table_schema='ma' AND table_name='computed_values' AND column_name IN ('computed_code','indicator_code','code','metric_code','signal_code','name') THEN 1 ELSE 0 END) AS code_cols,
      SUM(CASE WHEN table_schema='ma' AND table_name='computed_values' AND column_name IN ('country_iso3','iso3','country_code') THEN 1 ELSE 0 END) AS country_cols,
      SUM(CASE WHEN table_schema='ma' AND table_name='computed_values' AND column_name IN ('year','annee') THEN 1 ELSE 0 END) AS year_cols,
      SUM(CASE WHEN table_schema='ma' AND table_name='computed_values' AND column_name IN ('computed_value','value','processed_value','score','raw_value') THEN 1 ELSE 0 END) AS value_cols
    FROM information_schema.columns
)
SELECT
  CASE WHEN has_p7e_pillar THEN 'OK' ELSE 'MISSING' END AS check_p7e_pillar,
  CASE WHEN has_computed_values THEN 'OK' ELSE 'MISSING' END AS check_computed_values,
  code_cols, country_cols, year_cols, value_cols,
  CASE WHEN has_p7e_pillar AND has_computed_values AND code_cols>0 AND country_cols>0 AND year_cols>0 AND value_cols>0
       THEN 'OK' ELSE 'COMPATIBILITY_VIEW_WILL_BE_EMPTY_OR_LIMITED' END AS check_required_columns
FROM deps, cols;
"
if ($LASTEXITCODE -ne 0) { throw "Erreur SQL pré-test P7X" }

Run-SqlFile "db/patch_db/patch_p7x_swot_strategic_intelligence.sql"
Run-SqlFile "db/views/ma/v_isa_swot_signal_engine.sql"
Run-SqlFile "db/views/ma/v_isa_strategic_recommendation_engine.sql"
Run-SqlFile "db/views/ma/v_isa_project_opportunity_catalog.sql"
Run-SqlFile "db/views/ma/v_isa_premium_feasibility_triggers.sql"
Run-SqlFile "db/views/ma/v_isa_eparticipation_priorities.sql"

Write-Host ">>> Rapport P7X"
& $Psql -h 127.0.0.1 -U $User -d $Db -v ON_ERROR_STOP=1 -f "audit/p7x_swot_strategic_intelligence_report.sql"
if ($LASTEXITCODE -ne 0) { throw "Erreur rapport P7X" }

Write-Host "✅ P7X SWOT Strategic Intelligence installé"
