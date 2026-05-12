Write-Host "========================================="
Write-Host " OSA — P7G DRY RUN TEST"
Write-Host "========================================="

$Psql = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
$Db = "osa_db"
$User = "postgres"

function Run-Test($sql) {
    Write-Host ""
    Write-Host ">>> Test SQL"
    & $Psql -h 127.0.0.1 -U $User -d $Db -v ON_ERROR_STOP=1 -c $sql
    if ($LASTEXITCODE -ne 0) { throw "Erreur dry-run P7G" }
}

Run-Test @"
SELECT
  CASE WHEN to_regclass('rf.isa_forecast_policy') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_policy,
  CASE WHEN to_regclass('ma.v_p7g_forecast_source') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_source,
  CASE WHEN to_regclass('ma.v_isa_forecast_trend_engine') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_trend,
  CASE WHEN to_regclass('ma.v_isa_forecast_projection_engine') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_projection,
  CASE WHEN to_regclass('ma.v_isa_forecast_country_year') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_country,
  CASE WHEN to_regclass('ma.v_isa_forecast_readiness_p7g') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_readiness;
"@

Run-Test @"
WITH required_cols(col) AS (
  VALUES
    ('country_iso3'), ('pillar_code'), ('last_observed_year'), ('forecast_year'),
    ('horizon_code'), ('horizon_years'), ('forecast_isa_score'), ('forecast_isa_low'),
    ('forecast_isa_high'), ('forecast_confidence'), ('forecast_uncertainty'),
    ('forecast_policy_code'), ('forecast_decision')
),
found_cols AS (
  SELECT COUNT(*) AS n
  FROM required_cols r
  JOIN information_schema.columns c
    ON c.table_schema='ma'
   AND c.table_name='v_isa_forecast_projection_engine'
   AND c.column_name=r.col
)
SELECT
  (SELECT COUNT(*) FROM required_cols) AS required_cols,
  (SELECT n FROM found_cols) AS found_cols,
  CASE WHEN (SELECT n FROM found_cols)=(SELECT COUNT(*) FROM required_cols) THEN 'OK' ELSE 'MISSING_COLUMNS' END AS column_check;
"@

Run-Test "SELECT COUNT(*) AS forecast_policy_rows FROM rf.isa_forecast_policy;"

Run-Test @"
SELECT COUNT(*) AS forecast_source_rows
FROM ma.v_p7g_forecast_source;
"@

Run-Test @"
SELECT COUNT(*) AS trend_rows
FROM ma.v_isa_forecast_trend_engine;
"@

Run-Test @"
SELECT COUNT(*) AS projection_rows
FROM ma.v_isa_forecast_projection_engine;
"@

Run-Test @"
SELECT COUNT(*) AS country_forecast_rows
FROM ma.v_isa_forecast_country_year;
"@

Run-Test @"
SELECT COUNT(*) AS readiness_rows
FROM ma.v_isa_forecast_readiness_p7g;
"@

Run-Test @"
SELECT COUNT(*) AS critical_nulls
FROM ma.v_isa_forecast_projection_engine
WHERE country_iso3 IS NULL
   OR pillar_code IS NULL
   OR forecast_year IS NULL
   OR forecast_isa_score IS NULL
   OR forecast_confidence IS NULL
   OR forecast_decision IS NULL;
"@

Run-Test @"
SELECT COUNT(*) AS out_of_bounds_forecasts
FROM ma.v_isa_forecast_projection_engine
WHERE forecast_isa_score < 0
   OR forecast_isa_score > 1.5
   OR forecast_isa_low < 0
   OR forecast_isa_high > 1.5
   OR forecast_confidence < 0
   OR forecast_confidence > 1
   OR forecast_uncertainty < 0;
"@

Run-Test @"
SELECT COUNT(*) AS invalid_bands
FROM ma.v_isa_forecast_projection_engine
WHERE forecast_isa_low > forecast_isa_score
   OR forecast_isa_score > forecast_isa_high;
"@

Run-Test @"
SELECT COUNT(*) AS zero_or_null_history
FROM ma.v_isa_forecast_trend_engine
WHERE history_years IS NULL
   OR history_years <= 0;
"@

Run-Test @"
SELECT COUNT(DISTINCT country_iso3) AS nb_countries,
       COUNT(DISTINCT pillar_code) AS nb_pillars,
       COUNT(DISTINCT horizon_code) AS nb_horizons
FROM ma.v_isa_forecast_projection_engine;
"@

Run-Test @"
SELECT forecast_decision, COUNT(*) AS nb
FROM ma.v_isa_forecast_projection_engine
GROUP BY forecast_decision
ORDER BY nb DESC;
"@

Write-Host ""
Write-Host "✅ P7G dry-run terminé avec succès"
