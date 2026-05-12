Write-Host "========================================="
Write-Host " OSA — RUN P7G FORECAST INTELLIGENCE"
Write-Host "========================================="

$Psql = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
$Db = "osa_db"
$User = "postgres"

function Run-SqlFile($file) {
    Write-Host ">>> SQL : $file"
    & $Psql -h 127.0.0.1 -U $User -d $Db -v ON_ERROR_STOP=1 -f $file
    if ($LASTEXITCODE -ne 0) { throw "Erreur SQL : $file" }
}

Write-Host ">>> Pré-test dépendances P7G"
$pretest = @"
WITH deps AS (
    SELECT
        to_regclass('ma.v_isa_observed_scores_by_pillar') IS NOT NULL AS has_observed_pillar,
        to_regclass('ma.v_isa_strategic_diagnostic_engine') IS NOT NULL AS has_p7f_diag
),
required_observed(col) AS (
    VALUES
      ('country_iso3'), ('year'), ('pillar_code'),
      ('publication_status'), ('publication_decision'), ('methodology_version'),
      ('data_completeness'), ('avg_observation_confidence'),
      ('isa_observed_score'), ('sovereignty_observed_score'),
      ('vulnerability_observed_score'), ('resilience_observed_score'),
      ('forecast_readiness_score'), ('ml_readiness_score')
),
required_diag(col) AS (
    VALUES
      ('country_iso3'), ('year'), ('pillar_code'),
      ('strategic_diagnostic_role'), ('strategic_attention_class'),
      ('diagnostic_priority_score'), ('strategic_risk_score'),
      ('strategic_upside_score'), ('weakness_score'), ('threat_score'),
      ('strength_score'), ('opportunity_score'), ('swot_data_status')
),
found_observed AS (
    SELECT COUNT(*) AS n
    FROM required_observed r
    JOIN information_schema.columns c
      ON c.table_schema='ma'
     AND c.table_name='v_isa_observed_scores_by_pillar'
     AND c.column_name=r.col
),
found_diag AS (
    SELECT COUNT(*) AS n
    FROM required_diag r
    JOIN information_schema.columns c
      ON c.table_schema='ma'
     AND c.table_name='v_isa_strategic_diagnostic_engine'
     AND c.column_name=r.col
)
SELECT
    CASE WHEN has_observed_pillar THEN 'OK' ELSE 'KO' END AS check_observed_pillar,
    CASE WHEN has_p7f_diag THEN 'OK' ELSE 'KO' END AS check_p7f_diagnostic,
    (SELECT COUNT(*) FROM required_observed) AS required_observed_cols,
    (SELECT n FROM found_observed) AS found_observed_cols,
    (SELECT COUNT(*) FROM required_diag) AS required_diag_cols,
    (SELECT n FROM found_diag) AS found_diag_cols,
    CASE
      WHEN has_observed_pillar
       AND has_p7f_diag
       AND (SELECT n FROM found_observed) = (SELECT COUNT(*) FROM required_observed)
       AND (SELECT n FROM found_diag) = (SELECT COUNT(*) FROM required_diag)
      THEN 'OK' ELSE 'MISSING_COLUMNS' END AS check_required_columns
FROM deps;
"@

& $Psql -h 127.0.0.1 -U $User -d $Db -v ON_ERROR_STOP=1 -c $pretest
if ($LASTEXITCODE -ne 0) { throw "Erreur SQL pré-test P7G" }

Run-SqlFile "db/patch_db/patch_p7g_forecast_intelligence.sql"
Run-SqlFile "db/views/ma/v_p7g_forecast_source.sql"
Run-SqlFile "db/views/ma/v_isa_forecast_trend_engine.sql"
Run-SqlFile "db/views/ma/v_isa_forecast_projection_engine.sql"
Run-SqlFile "db/views/ma/v_isa_forecast_country_year.sql"
Run-SqlFile "db/views/ma/v_isa_forecast_readiness_p7g.sql"

Write-Host ">>> Rapport P7G"
& $Psql -h 127.0.0.1 -U $User -d $Db -v ON_ERROR_STOP=1 -f "audit/p7g_forecast_intelligence_report.sql"
if ($LASTEXITCODE -ne 0) { throw "Erreur rapport P7G" }

Write-Host "✅ P7G Forecast Intelligence installé"
