$ErrorActionPreference = "Stop"

$Psql = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
$Db = "osa_db"
$User = "postgres"
$HostName = "localhost"

function Run-SqlFile($file) {
    Write-Host ">>> SQL : $file"
    & $Psql -h $HostName -U $User -d $Db -v ON_ERROR_STOP=1 -f $file
    if ($LASTEXITCODE -ne 0) { throw "Erreur SQL : $file" }
}

Write-Host "========================================="
Write-Host " OSA — RUN P8 OPERATIONALIZATION"
Write-Host "========================================="

Write-Host ">>> Pré-test dépendances P8"
& $Psql -h $HostName -U $User -d $Db -v ON_ERROR_STOP=1 -c @"
WITH deps AS (
    SELECT
        CASE WHEN to_regclass('ma.v_isa_observed_scores_by_country_year') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_country_scores,
        CASE WHEN to_regclass('ma.v_isa_observed_scores_by_pillar') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_pillar_scores,
        CASE WHEN to_regclass('ma.v_isa_swot_signal_engine') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_swot,
        CASE WHEN to_regclass('ma.v_isa_project_opportunity_catalog') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_projects,
        CASE WHEN to_regclass('ma.v_isa_premium_feasibility_triggers') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_premium
),
cols AS (
    SELECT COUNT(*) AS found_cols
    FROM information_schema.columns
    WHERE table_schema = 'ma'
      AND table_name = 'v_isa_observed_scores_by_country_year'
      AND column_name IN (
          'country_iso3',
          'year',
          'publication_status',
          'publication_decision',
          'nb_pillars_observed',
          'data_completeness',
          'isa_observed_score',
          'sovereignty_observed_score',
          'vulnerability_observed_score'
      )
)
SELECT
    d.*,
    CASE WHEN c.found_cols = 9 THEN 'OK' ELSE 'MISSING_COLUMNS' END AS check_required_columns
FROM deps d CROSS JOIN cols c;
"@
if ($LASTEXITCODE -ne 0) { throw "Erreur SQL pré-test P8" }

Run-SqlFile "db/patch_db/patch_p8a_certification_engine.sql"
Run-SqlFile "db/patch_db/patch_p8b_publication_governance.sql"
Run-SqlFile "db/patch_db/patch_p8c_snapshot_freeze.sql"
Run-SqlFile "db/patch_db/patch_p8d_open_data_delivery.sql"
Run-SqlFile "db/patch_db/patch_p8e_premium_delivery.sql"
Run-SqlFile "db/patch_db/patch_p8f_api_registry.sql"
Run-SqlFile "db/patch_db/patch_p8g_eparticipation.sql"

Run-SqlFile "db/views/ma/v_isa_certification_engine.sql"
Run-SqlFile "db/views/ma/v_isa_publication_governance.sql"
Run-SqlFile "db/views/ma/v_isa_snapshot_registry.sql"
Run-SqlFile "db/views/ma/v_isa_open_data_catalog.sql"
Run-SqlFile "db/views/ma/v_isa_premium_catalog.sql"
Run-SqlFile "db/views/ma/v_isa_api_registry.sql"
Run-SqlFile "db/views/ma/v_isa_eparticipation_queue.sql"

Write-Host ">>> Rapport P8"
& $Psql -h $HostName -U $User -d $Db -v ON_ERROR_STOP=1 -f "audit/p8_operationalization_report.sql"
if ($LASTEXITCODE -ne 0) { throw "Erreur rapport P8" }

Write-Host "✅ P8 Operationalization installé"
