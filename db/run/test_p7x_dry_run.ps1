$ErrorActionPreference = "Stop"

Write-Host "========================================="
Write-Host " OSA — P7X DRY RUN TEST"
Write-Host "========================================="

$Psql = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
$Db = "osa_db"
$User = "postgres"

function Run-Test($sql) {
    Write-Host ""
    Write-Host ">>> Test SQL"
    & $Psql -h 127.0.0.1 -U $User -d $Db -v ON_ERROR_STOP=1 -c $sql
    if ($LASTEXITCODE -ne 0) { throw "Erreur dry-run P7X" }
}

Run-Test "
SELECT
  CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='rf' AND table_name='swot_signal_policy') THEN 'OK' ELSE 'MISSING' END AS check_policy,
  CASE WHEN EXISTS (SELECT 1 FROM information_schema.views WHERE table_schema='ma' AND table_name='v_p7x_computed_swot_source') THEN 'OK' ELSE 'MISSING' END AS check_swot_compat,
  CASE WHEN EXISTS (SELECT 1 FROM information_schema.views WHERE table_schema='ma' AND table_name='v_isa_swot_signal_engine') THEN 'OK' ELSE 'MISSING' END AS check_signal_engine,
  CASE WHEN EXISTS (SELECT 1 FROM information_schema.views WHERE table_schema='ma' AND table_name='v_isa_project_opportunity_catalog') THEN 'OK' ELSE 'MISSING' END AS check_project_catalog,
  CASE WHEN EXISTS (SELECT 1 FROM information_schema.views WHERE table_schema='ma' AND table_name='v_isa_premium_feasibility_triggers') THEN 'OK' ELSE 'MISSING' END AS check_premium_triggers;
"

Run-Test "
SELECT
  SUM(CASE WHEN swot_type='WKN' THEN 1 ELSE 0 END) AS wkn_rows,
  SUM(CASE WHEN swot_type='THR' THEN 1 ELSE 0 END) AS thr_rows,
  SUM(CASE WHEN swot_type='STR' THEN 1 ELSE 0 END) AS str_rows_tolerated,
  SUM(CASE WHEN swot_type='OPP' THEN 1 ELSE 0 END) AS opp_rows_tolerated,
  CASE WHEN SUM(CASE WHEN swot_type='WKN' THEN 1 ELSE 0 END) > 0 THEN 'OK' ELSE 'MISSING_WKN' END AS check_wkn,
  CASE WHEN SUM(CASE WHEN swot_type='THR' THEN 1 ELSE 0 END) > 0 THEN 'OK' ELSE 'MISSING_THR' END AS check_thr
FROM ma.v_p7x_computed_swot_source;
"

Run-Test "
SELECT COUNT(*) AS swot_signal_rows FROM ma.v_isa_swot_signal_engine;
"

Run-Test "
SELECT COUNT(*) AS critical_nulls
FROM ma.v_isa_swot_signal_engine
WHERE country_iso3 IS NULL OR year IS NULL OR pillar_code IS NULL
   OR swot_strategic_role IS NULL OR strategic_risk_score IS NULL;
"

Run-Test "
SELECT COUNT(*) AS recommendation_rows FROM ma.v_isa_strategic_recommendation_engine;
"

Run-Test "
SELECT COUNT(*) AS project_rows FROM ma.v_isa_project_opportunity_catalog;
"

Run-Test "
SELECT COUNT(*) AS premium_trigger_rows FROM ma.v_isa_premium_feasibility_triggers;
"

Run-Test "
SELECT COUNT(*) AS eparticipation_rows FROM ma.v_isa_eparticipation_priorities;
"

Run-Test "
SELECT COUNT(*) AS out_of_bounds_priority
FROM ma.v_isa_strategic_recommendation_engine
WHERE strategic_priority_score < 0 OR strategic_priority_score > 1.5;
"

Run-Test "
SELECT
  COUNT(DISTINCT country_iso3) AS nb_countries,
  COUNT(DISTINCT year) AS nb_years,
  COUNT(DISTINCT pillar_code) AS nb_pillars
FROM ma.v_isa_swot_signal_engine;
"

Run-Test "
SELECT premium_feasibility_trigger, COUNT(*) AS nb
FROM ma.v_isa_premium_feasibility_triggers
GROUP BY premium_feasibility_trigger
ORDER BY nb DESC;
"

Write-Host ""
Write-Host "✅ P7X dry-run terminé avec succès"
