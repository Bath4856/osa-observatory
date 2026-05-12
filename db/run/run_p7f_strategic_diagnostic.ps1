Write-Host "========================================="
Write-Host " OSA — RUN P7F STRATEGIC DIAGNOSTIC"
Write-Host "========================================="

$Psql = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
$Db = "osa_db"
$User = "postgres"

function Run-SqlFile($file) {
    Write-Host ">>> SQL : $file"
    & $Psql -U $User -d $Db -v ON_ERROR_STOP=1 -f $file
    if ($LASTEXITCODE -ne 0) { throw "Erreur SQL : $file" }
}

Write-Host ">>> Pré-test dépendances P7F"
& $Psql -U $User -d $Db -v ON_ERROR_STOP=1 -c @"
WITH deps AS (
    SELECT
        to_regclass('ma.v_isa_observed_scores_by_pillar') IS NOT NULL AS has_observed_pillar,
        to_regclass('ma.computed_values') IS NOT NULL AS has_computed_values
), required_observed_cols AS (
    SELECT unnest(ARRAY[
        'country_iso3','year','pillar_code','publication_status','publication_decision',
        'isa_observed_score','sovereignty_observed_score','vulnerability_observed_score',
        'resilience_observed_score','data_completeness','avg_observation_confidence'
    ]) AS column_name
), required_computed_cols AS (
    SELECT unnest(ARRAY['indicator_code','country_iso3','year','value','confidence']) AS column_name
), counts AS (
    SELECT
        (SELECT COUNT(*) FROM required_observed_cols) AS required_observed_cols,
        (SELECT COUNT(*) FROM information_schema.columns c JOIN required_observed_cols r ON r.column_name=c.column_name WHERE c.table_schema='ma' AND c.table_name='v_isa_observed_scores_by_pillar') AS found_observed_cols,
        (SELECT COUNT(*) FROM required_computed_cols) AS required_computed_cols,
        (SELECT COUNT(*) FROM information_schema.columns c JOIN required_computed_cols r ON r.column_name=c.column_name WHERE c.table_schema='ma' AND c.table_name='computed_values') AS found_computed_cols
)
SELECT
    CASE WHEN has_observed_pillar THEN 'OK' ELSE 'KO' END AS check_observed_pillar,
    CASE WHEN has_computed_values THEN 'OK' ELSE 'KO' END AS check_computed_values,
    required_observed_cols,
    found_observed_cols,
    required_computed_cols,
    found_computed_cols,
    CASE
      WHEN has_observed_pillar AND has_computed_values
       AND required_observed_cols = found_observed_cols
       AND required_computed_cols = found_computed_cols THEN 'OK'
      ELSE 'MISSING_COLUMNS'
    END AS check_required_columns
FROM deps, counts;
"@
if ($LASTEXITCODE -ne 0) { throw "Erreur SQL pré-test P7F" }

Run-SqlFile "db/patch_db/patch_p7f_strategic_diagnostic_intelligence.sql"
Run-SqlFile "db/views/ma/v_p7f_computed_swot_source.sql"
Run-SqlFile "db/views/ma/v_p7f_observed_pillar_source.sql"
Run-SqlFile "db/views/ma/v_isa_strategic_diagnostic_engine.sql"
Run-SqlFile "db/views/ma/v_isa_candidate_intervention_catalog.sql"
Run-SqlFile "db/views/ma/v_isa_public_consultation_topics.sql"

Write-Host ">>> Rapport P7F"
& $Psql -U $User -d $Db -v ON_ERROR_STOP=1 -f "audit/p7f_strategic_diagnostic_report.sql"
if ($LASTEXITCODE -ne 0) { throw "Erreur rapport P7F" }

Write-Host "✅ P7F Strategic Diagnostic Intelligence installé"
