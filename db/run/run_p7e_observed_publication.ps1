$ErrorActionPreference = "Stop"

Write-Host "========================================="
Write-Host " OSA — RUN P7E OBSERVED PUBLICATION ENGINE"
Write-Host "========================================="

$Psql = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
$DbName = if ($env:OSA_DB_NAME) { $env:OSA_DB_NAME } else { "osa_db" }
$DbUser = if ($env:OSA_DB_USER) { $env:OSA_DB_USER } else { "postgres" }
$DbHost = if ($env:OSA_DB_HOST) { $env:OSA_DB_HOST } else { "127.0.0.1" }
$DbPort = if ($env:OSA_DB_PORT) { $env:OSA_DB_PORT } else { "5432" }

function Invoke-SqlFile($file) {
    Write-Host ">>> SQL : $file"
    & $Psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -f $file
    if ($LASTEXITCODE -ne 0) { throw "Erreur SQL : $file" }
}

Write-Host ">>> Pré-test dépendances P7E"
$precheck = @"
WITH deps AS (
    SELECT
        to_regclass('ma.indicator_values_final') IS NOT NULL AS has_indicator_values_final,
        to_regclass('ma.v_dynamic_scores_engine') IS NOT NULL AS has_dynamic_scores_engine
), required_values_cols AS (
    SELECT unnest(ARRAY[
        'country_iso3','year','indicator_code','processed_value',
        'confidence_score'
    ]) AS column_name
), found_values_cols AS (
    SELECT column_name
    FROM information_schema.columns
    WHERE table_schema = 'ma'
      AND table_name = 'indicator_values_final'
), required_score_cols AS (
    SELECT unnest(ARRAY[
        'indicator_code','pillar_code','semantic_code',
        'dynamic_isa_score_component',
        'dynamic_sovereignty_score_component',
        'dynamic_vulnerability_score_component',
        'dynamic_resilience_score_component',
        'dynamic_forecast_score_component',
        'dynamic_ml_score_component',
        'dynamic_score_class','dynamic_score_decision'
    ]) AS column_name
), found_score_cols AS (
    SELECT column_name
    FROM information_schema.columns
    WHERE table_schema = 'ma'
      AND table_name = 'v_dynamic_scores_engine'
), checks AS (
    SELECT
        (SELECT has_indicator_values_final FROM deps) AS has_indicator_values_final,
        (SELECT has_dynamic_scores_engine FROM deps) AS has_dynamic_scores_engine,
        (SELECT COUNT(*) FROM required_values_cols r JOIN found_values_cols f USING(column_name)) AS found_values_cols,
        (SELECT COUNT(*) FROM required_values_cols) AS required_values_cols,
        (SELECT COUNT(*) FROM required_score_cols r JOIN found_score_cols f USING(column_name)) AS found_score_cols,
        (SELECT COUNT(*) FROM required_score_cols) AS required_score_cols
)
SELECT
    CASE WHEN has_indicator_values_final THEN 'OK' ELSE 'MISSING' END AS check_indicator_values_final,
    CASE WHEN has_dynamic_scores_engine THEN 'OK' ELSE 'MISSING' END AS check_dynamic_scores_engine,
    required_values_cols,
    found_values_cols,
    required_score_cols,
    found_score_cols,
    CASE
        WHEN has_indicator_values_final
         AND has_dynamic_scores_engine
         AND found_values_cols = required_values_cols
         AND found_score_cols = required_score_cols
        THEN 'OK'
        ELSE 'MISSING_COLUMNS'
    END AS check_required_columns
FROM checks;
"@
& $Psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -c $precheck
if ($LASTEXITCODE -ne 0) { throw "Pré-test P7E échoué" }

Invoke-SqlFile "db/patch_db/patch_p7e_observed_publication.sql"
Invoke-SqlFile "db/views/ma/v_isa_observed_publication_engine.sql"
Invoke-SqlFile "db/views/ma/v_isa_observed_scores_by_pillar.sql"
Invoke-SqlFile "db/views/ma/v_isa_observed_scores_by_country_year.sql"
Invoke-SqlFile "db/views/ma/v_isa_observed_scores_by_region_year.sql"
Invoke-SqlFile "db/views/ma/v_isa_observed_publication_readiness.sql"

Write-Host ">>> Rapport P7E"
& $Psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -f "audit/p7e_observed_publication_report.sql"
if ($LASTEXITCODE -ne 0) { throw "Erreur rapport P7E" }

Write-Host "✅ P7E Observed Publication Engine installé"
