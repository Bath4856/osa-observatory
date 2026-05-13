Write-Host "========================================="
Write-Host " OSA — P7G v2 FORECAST STATUS FIX DRY RUN"
Write-Host "========================================="

$ErrorActionPreference = "Stop"
$PSQL = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
$DB = "osa_db"
$USER = "postgres"

function Run-Sql($sql) {
  Write-Host ""
  Write-Host ">>> Test SQL"
  & $PSQL -h 127.0.0.1 -U $USER -d $DB -v ON_ERROR_STOP=1 -c $sql
  if ($LASTEXITCODE -ne 0) { throw "Erreur dry-run P7G v2" }
}

Run-Sql "SELECT CASE WHEN to_regclass('ma.v_isa_forecast_trend_engine') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_trend;"

Run-Sql @"
SELECT
  COUNT(*) FILTER (WHERE pillar_code='PGEO') AS pgeo_rows,
  COUNT(*) FILTER (WHERE pillar_code='PGEO' AND forecast_trend_status='FORECAST_DISABLED_LOW_CONFIDENCE') AS pgeo_low_confidence_rows,
  CASE
    WHEN COUNT(*) FILTER (WHERE pillar_code='PGEO') = COUNT(*) FILTER (WHERE pillar_code='PGEO' AND forecast_trend_status='FORECAST_DISABLED_LOW_CONFIDENCE')
    THEN 'OK' ELSE 'KO'
  END AS pgeo_status_check
FROM ma.v_isa_forecast_trend_engine;
"@

Run-Sql @"
SELECT
  COUNT(*) FILTER (WHERE forecast_trend_status IS NULL OR forecast_blocking_reason IS NULL) AS critical_nulls
FROM ma.v_isa_forecast_trend_engine;
"@

Run-Sql @"
SELECT COUNT(DISTINCT pillar_code) AS nb_pillars
FROM ma.v_isa_forecast_trend_engine;
"@

Run-Sql @"
SELECT forecast_trend_status, COUNT(*) AS nb
FROM ma.v_isa_forecast_trend_engine
GROUP BY forecast_trend_status
ORDER BY nb DESC;
"@

Write-Host ""
Write-Host "✅ P7G v2 forecast status fix dry-run terminé avec succès"
