Write-Host "========================================="
Write-Host " OSA — RUN P7G v2 FORECAST STATUS FIX"
Write-Host "========================================="

$ErrorActionPreference = "Stop"
$PSQL = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
$DB = "osa_db"
$USER = "postgres"

Write-Host ">>> Pré-test dépendances P7G v2"
& $PSQL -h 127.0.0.1 -U $USER -d $DB -v ON_ERROR_STOP=1 -c @"
SELECT
  CASE WHEN to_regclass('ma.v_p7g_forecast_source') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_source,
  CASE WHEN to_regclass('rf.isa_forecast_policy') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_policy,
  CASE WHEN to_regclass('ma.v_isa_forecast_projection_engine') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_projection;
"@
if ($LASTEXITCODE -ne 0) { throw "Erreur SQL pré-test P7G v2" }

$files = @(
  "db/views/ma/v_isa_forecast_trend_engine.sql"
)

foreach ($file in $files) {
  Write-Host ">>> SQL : $file"
  & $PSQL -h 127.0.0.1 -U $USER -d $DB -v ON_ERROR_STOP=1 -f $file
  if ($LASTEXITCODE -ne 0) { throw "Erreur SQL : $file" }
}

Write-Host ">>> Rapport P7G v2"
& $PSQL -h 127.0.0.1 -U $USER -d $DB -v ON_ERROR_STOP=1 -f "audit/p7g_v2_forecast_status_fix_report.sql"
if ($LASTEXITCODE -ne 0) { throw "Erreur rapport P7G v2" }

Write-Host "✅ P7G v2 Forecast Status Fix installé"
