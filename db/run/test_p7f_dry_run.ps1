Write-Host "========================================="
Write-Host " OSA — P7F DRY RUN TEST"
Write-Host "========================================="

$Psql = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
$Db = "osa_db"
$User = "postgres"

function Test-Sql($sql) {
    Write-Host ""
    Write-Host ">>> Test SQL"
    & $Psql -U $User -d $Db -v ON_ERROR_STOP=1 -c $sql
    if ($LASTEXITCODE -ne 0) { throw "Erreur dry-run P7F" }
}

Test-Sql @"
SELECT
  CASE WHEN to_regclass('rf.isa_strategic_diagnostic_policy') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_diag_policy,
  CASE WHEN to_regclass('rf.isa_candidate_intervention_family') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_family_policy,
  CASE WHEN to_regclass('ma.v_p7f_computed_swot_source') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_swot_source,
  CASE WHEN to_regclass('ma.v_isa_strategic_diagnostic_engine') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_diag_engine,
  CASE WHEN to_regclass('ma.v_isa_candidate_intervention_catalog') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_candidate_catalog,
  CASE WHEN to_regclass('ma.v_isa_public_consultation_topics') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_consultation;
"@

Test-Sql @"
SELECT
  COUNT(*) FILTER (WHERE swot_type='WKN') AS wkn_rows,
  COUNT(*) FILTER (WHERE swot_type='THR') AS thr_rows,
  COUNT(*) FILTER (WHERE swot_type='STR') AS str_rows_tolerated,
  COUNT(*) FILTER (WHERE swot_type='OPP') AS opp_rows_tolerated,
  CASE WHEN COUNT(*) FILTER (WHERE swot_type='WKN') > 0 THEN 'OK' ELSE 'KO' END AS check_wkn,
  CASE WHEN COUNT(*) FILTER (WHERE swot_type='THR') > 0 THEN 'OK' ELSE 'KO' END AS check_thr
FROM ma.v_p7f_computed_swot_source;
"@

Test-Sql "SELECT COUNT(*) AS diagnostic_rows FROM ma.v_isa_strategic_diagnostic_engine;"
Test-Sql "SELECT COUNT(*) AS candidate_intervention_rows FROM ma.v_isa_candidate_intervention_catalog;"
Test-Sql "SELECT COUNT(*) AS public_consultation_rows FROM ma.v_isa_public_consultation_topics;"

Test-Sql @"
SELECT COUNT(*) AS critical_nulls
FROM ma.v_isa_strategic_diagnostic_engine
WHERE country_iso3 IS NULL
   OR year IS NULL
   OR pillar_code IS NULL
   OR strategic_diagnostic_role IS NULL
   OR strategic_attention_class IS NULL
   OR diagnostic_priority_score IS NULL;
"@

Test-Sql @"
SELECT COUNT(*) AS out_of_bounds_scores
FROM ma.v_isa_strategic_diagnostic_engine
WHERE weakness_score < 0 OR weakness_score > 1
   OR threat_score < 0 OR threat_score > 1
   OR strength_score < 0 OR strength_score > 1
   OR opportunity_score < 0 OR opportunity_score > 1
   OR strategic_risk_score < 0 OR strategic_risk_score > 1
   OR strategic_upside_score < 0 OR strategic_upside_score > 1
   OR diagnostic_priority_score < 0 OR diagnostic_priority_score > 1;
"@

Test-Sql @"
SELECT COUNT(*) AS forbidden_premium_terms
FROM ma.v_isa_candidate_intervention_catalog
WHERE validation_scope ILIKE '%PREMIUM%'
   OR validation_scope ILIKE '%FEASIBILITY%'
   OR validation_scope ILIKE '%FORECAST_VALIDATED%' AND validation_scope <> 'P7F_DIAGNOSTIC_ONLY_NOT_FORECAST_VALIDATED';
"@

Test-Sql @"
SELECT COUNT(DISTINCT country_iso3) AS nb_countries,
       COUNT(DISTINCT year) AS nb_years,
       COUNT(DISTINCT pillar_code) AS nb_pillars
FROM ma.v_isa_strategic_diagnostic_engine;
"@

Test-Sql @"
SELECT strategic_diagnostic_role, COUNT(*) AS nb
FROM ma.v_isa_strategic_diagnostic_engine
GROUP BY strategic_diagnostic_role
ORDER BY nb DESC;
"@

Test-Sql @"
SELECT package_code, package_status, replacement_package
FROM mg.package_lifecycle
WHERE package_code IN ('P7X','P7F')
ORDER BY package_code;
"@

Write-Host ""
Write-Host "✅ P7F dry-run terminé avec succès"
