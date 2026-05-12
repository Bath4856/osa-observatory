$ErrorActionPreference = "Stop"

Write-Host "========================================="
Write-Host " OSA — P7E DRY RUN TEST"
Write-Host "========================================="

$Psql = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
$DbName = if ($env:OSA_DB_NAME) { $env:OSA_DB_NAME } else { "osa_db" }
$DbUser = if ($env:OSA_DB_USER) { $env:OSA_DB_USER } else { "postgres" }
$DbHost = if ($env:OSA_DB_HOST) { $env:OSA_DB_HOST } else { "127.0.0.1" }
$DbPort = if ($env:OSA_DB_PORT) { $env:OSA_DB_PORT } else { "5432" }

function Test-Sql($sql) {
    Write-Host ""
    Write-Host ">>> Test SQL"
    & $Psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -c $sql
    if ($LASTEXITCODE -ne 0) { throw "Erreur dry-run P7E" }
}

Test-Sql "
SELECT
    CASE WHEN to_regclass('rf.isa_publication_policy') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS check_policy,
    CASE WHEN to_regclass('ma.v_isa_observed_publication_engine') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS check_engine,
    CASE WHEN to_regclass('ma.v_isa_observed_scores_by_pillar') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS check_pillar_scores,
    CASE WHEN to_regclass('ma.v_isa_observed_scores_by_country_year') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS check_country_scores,
    CASE WHEN to_regclass('ma.v_isa_observed_publication_readiness') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS check_readiness;
"

Test-Sql "
WITH required_values_cols AS (
    SELECT unnest(ARRAY['country_iso3','year','indicator_code','processed_value','confidence_score']) AS column_name
), found_values_cols AS (
    SELECT column_name FROM information_schema.columns WHERE table_schema='ma' AND table_name='indicator_values_final'
), required_score_cols AS (
    SELECT unnest(ARRAY['indicator_code','pillar_code','semantic_code','dynamic_isa_score_component','dynamic_sovereignty_score_component','dynamic_vulnerability_score_component','dynamic_resilience_score_component','dynamic_forecast_score_component','dynamic_ml_score_component','dynamic_score_class','dynamic_score_decision']) AS column_name
), found_score_cols AS (
    SELECT column_name FROM information_schema.columns WHERE table_schema='ma' AND table_name='v_dynamic_scores_engine'
)
SELECT
    (SELECT COUNT(*) FROM required_values_cols) AS required_values_cols,
    (SELECT COUNT(*) FROM required_values_cols r JOIN found_values_cols f USING(column_name)) AS found_values_cols,
    (SELECT COUNT(*) FROM required_score_cols) AS required_score_cols,
    (SELECT COUNT(*) FROM required_score_cols r JOIN found_score_cols f USING(column_name)) AS found_score_cols,
    CASE
        WHEN (SELECT COUNT(*) FROM required_values_cols) = (SELECT COUNT(*) FROM required_values_cols r JOIN found_values_cols f USING(column_name))
         AND (SELECT COUNT(*) FROM required_score_cols) = (SELECT COUNT(*) FROM required_score_cols r JOIN found_score_cols f USING(column_name))
        THEN 'OK'
        ELSE 'MISSING_COLUMNS'
    END AS column_check;
"

Test-Sql "SELECT COUNT(*) AS nb_publication_policy_rows FROM rf.isa_publication_policy;"
Test-Sql "SELECT COUNT(*) AS nb_observed_publication_rows FROM ma.v_isa_observed_publication_engine;"
Test-Sql "SELECT COUNT(DISTINCT indicator_code) AS nb_dynamic_score_indicators_joined FROM ma.v_isa_observed_publication_engine;"
Test-Sql "SELECT COUNT(*) AS critical_nulls FROM ma.v_isa_observed_publication_engine WHERE country_iso3 IS NULL OR year IS NULL OR pillar_code IS NULL OR indicator_code IS NULL OR publication_status IS NULL;"
Test-Sql "SELECT COUNT(*) AS out_of_bounds_scores FROM ma.v_isa_observed_publication_engine WHERE observed_isa_component < 0 OR observed_isa_component > 1.5 OR observed_sovereignty_component < 0 OR observed_sovereignty_component > 1.5 OR observed_vulnerability_component < 0 OR observed_vulnerability_component > 1.5;"
Test-Sql "SELECT COUNT(*) AS zero_denominator_groups FROM ma.v_isa_observed_scores_by_pillar WHERE nb_indicators_observed IS NULL OR nb_indicators_observed = 0;"
Test-Sql "SELECT publication_status, COUNT(*) AS nb FROM ma.v_isa_observed_publication_engine GROUP BY publication_status ORDER BY publication_status;"
Test-Sql "SELECT COUNT(*) AS country_year_rows FROM ma.v_isa_observed_scores_by_country_year;"
Test-Sql "SELECT COUNT(*) AS pillar_rows FROM ma.v_isa_observed_scores_by_pillar;"
Test-Sql "SELECT COUNT(*) AS readiness_rows FROM ma.v_isa_observed_publication_readiness;"

Write-Host ""
Write-Host "✅ P7E dry-run terminé avec succès"
