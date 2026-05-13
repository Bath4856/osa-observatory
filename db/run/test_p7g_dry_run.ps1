Write-Host "========================================="
Write-Host " OSA — P7G v2 DRY RUN TEST"
Write-Host "========================================="

$Psql = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
$Db = "osa_db"
$User = "postgres"
$HostName = "127.0.0.1"

function Invoke-TestSql($Sql) {
  Write-Host "`n>>> Test SQL"
  & $Psql -h $HostName -U $User -d $Db -v ON_ERROR_STOP=1 -c $Sql
  if ($LASTEXITCODE -ne 0) { throw "Erreur dry-run P7G v2" }
}

Invoke-TestSql @"
SELECT
  CASE WHEN to_regclass('ma.v_isa_forecast_trend_engine') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_trend,
  CASE WHEN to_regclass('ma.v_isa_forecast_trend_engine') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_projection,
  CASE WHEN to_regclass('rf.isa_forecast_policy') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_policy;
"@

Invoke-TestSql @"
WITH required(col) AS (
  VALUES
    ('forecast_trend_status'),
    ('forecast_blocking_reason'),
    ('avg_observation_confidence'),
    ('history_years'),
    ('avg_data_completeness'),
    ('forecast_policy_code')
), found AS (
  SELECT column_name
  FROM information_schema.columns
  WHERE table_schema = 'ma'
    AND table_name = 'v_isa_forecast_trend_engine'
)
SELECT
  COUNT(*) AS required_cols,
  SUM(CASE WHEN f.column_name IS NOT NULL THEN 1 ELSE 0 END) AS found_cols,
  CASE WHEN COUNT(*) = SUM(CASE WHEN f.column_name IS NOT NULL THEN 1 ELSE 0 END) THEN 'OK' ELSE 'MISSING_COLUMNS' END AS column_check
FROM required r
LEFT JOIN found f ON f.column_name = r.col;
"@

Invoke-TestSql @"
SELECT
  pillar_code,
  forecast_trend_status,
  forecast_blocking_reason,
  COUNT(*) AS nb
FROM ma.v_isa_forecast_trend_engine
WHERE pillar_code = 'PGEO'
GROUP BY pillar_code, forecast_trend_status, forecast_blocking_reason;
"@

Invoke-TestSql @"
SELECT COUNT(*) AS pgeo_wrong_status
FROM ma.v_isa_forecast_trend_engine
WHERE pillar_code = 'PGEO'
  AND forecast_trend_status = 'FORECAST_DISABLED_INSUFFICIENT_HISTORY'
  AND history_years >= min_history_years
  AND avg_observation_confidence < min_observation_confidence;
"@

Invoke-TestSql @"
SELECT COUNT(*) AS pgeo_low_confidence_status
FROM ma.v_isa_forecast_trend_engine
WHERE pillar_code = 'PGEO'
  AND forecast_trend_status = 'FORECAST_DISABLED_LOW_CONFIDENCE'
  AND forecast_blocking_reason = 'LOW_CONFIDENCE';
"@

Invoke-TestSql @"
SELECT COUNT(*) AS critical_nulls
FROM ma.v_isa_forecast_trend_engine
WHERE country_iso3 IS NULL
   OR pillar_code IS NULL
   OR forecast_policy_code IS NULL
   OR forecast_trend_status IS NULL
   OR forecast_blocking_reason IS NULL;
"@

Invoke-TestSql @"
SELECT COUNT(*) AS invalid_policy_status
FROM ma.v_isa_forecast_trend_engine
WHERE forecast_policy_code = 'NO_FORECAST'
  AND forecast_blocking_reason = 'FORECAST_POLICY_OK';
"@

Invoke-TestSql @"
SELECT
  COUNT(DISTINCT pillar_code) AS trend_pillars,
  COUNT(*) AS trend_rows
FROM ma.v_isa_forecast_trend_engine;
"@

Invoke-TestSql @"
SELECT
  COUNT(DISTINCT pillar_code) AS projected_pillars,
  COUNT(*) AS projection_rows
FROM ma.v_isa_forecast_trend_engine;
"@

Invoke-TestSql @"
SELECT
  forecast_blocking_reason,
  COUNT(*) AS nb
FROM ma.v_isa_forecast_trend_engine
GROUP BY forecast_blocking_reason
ORDER BY nb DESC;
"@

Write-Host "`n✅ P7G v2 dry-run terminé avec succès"
