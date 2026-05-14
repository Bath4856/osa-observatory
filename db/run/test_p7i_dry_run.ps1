Write-Host "========================================="
Write-Host " OSA — P7I DRY RUN TEST"
Write-Host "========================================="

$Psql = "psql"
$DbHost = if ($env:OSA_DB_HOST) { $env:OSA_DB_HOST } else { "127.0.0.1" }
$DbPort = if ($env:OSA_DB_PORT) { $env:OSA_DB_PORT } else { "5432" }
$DbName = if ($env:OSA_DB_NAME) { $env:OSA_DB_NAME } else { "osa_db" }
$DbUser = if ($env:OSA_DB_USER) { $env:OSA_DB_USER } else { "postgres" }

function Invoke-TestSql($sql) {
  Write-Host ""
  Write-Host ">>> Test SQL"
  & $Psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -c $sql
  if ($LASTEXITCODE -ne 0) { throw "Erreur dry-run P7I" }
}

Invoke-TestSql @"
SELECT
  CASE WHEN to_regclass('rf.isa_early_warning_policy') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS check_warning_policy,
  CASE WHEN to_regclass('rf.isa_early_warning_pillar_weight') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS check_weight_policy,
  CASE WHEN to_regclass('ma.v_p7i_risk_source') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS check_source,
  CASE WHEN to_regclass('ma.v_isa_early_warning_engine') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS check_warning_engine,
  CASE WHEN to_regclass('ma.v_isa_risk_escalation_engine') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS check_escalation,
  CASE WHEN to_regclass('ma.v_isa_priority_intervention_alerts') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS check_priority_alerts,
  CASE WHEN to_regclass('ma.v_isa_early_warning_country_year') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS check_country_warning;
"@

Invoke-TestSql @"
WITH required AS (
  SELECT unnest(ARRAY[
    'country_iso3','year','pillar_code','sovereign_alert_level','early_warning_score','early_warning_confidence',
    'sovereign_risk_score','fragility_warning_score','stress_propagation_score','early_warning_decision','early_warning_class'
  ]) AS column_name
), found AS (
  SELECT column_name
  FROM information_schema.columns
  WHERE table_schema='ma' AND table_name='v_isa_early_warning_engine'
)
SELECT
  (SELECT COUNT(*) FROM required) AS required_cols,
  COUNT(f.column_name) AS found_cols,
  CASE WHEN COUNT(f.column_name) = (SELECT COUNT(*) FROM required) THEN 'OK' ELSE 'KO' END AS column_check
FROM required r
LEFT JOIN found f USING (column_name);
"@

Invoke-TestSql "SELECT COUNT(*) AS warning_policy_rows FROM rf.isa_early_warning_policy;"
Invoke-TestSql "SELECT COUNT(*) AS pillar_weight_rows FROM rf.isa_early_warning_pillar_weight;"
Invoke-TestSql "SELECT COUNT(*) AS risk_source_rows FROM ma.v_p7i_risk_source;"
Invoke-TestSql "SELECT COUNT(*) AS early_warning_rows FROM ma.v_isa_early_warning_engine;"
Invoke-TestSql "SELECT COUNT(*) AS escalation_rows FROM ma.v_isa_risk_escalation_engine;"
Invoke-TestSql "SELECT COUNT(*) AS fragility_rows FROM ma.v_isa_fragility_warning_engine;"
Invoke-TestSql "SELECT COUNT(*) AS priority_alert_rows FROM ma.v_isa_priority_intervention_alerts;"
Invoke-TestSql "SELECT COUNT(*) AS country_warning_rows FROM ma.v_isa_early_warning_country_year;"
Invoke-TestSql "SELECT COUNT(*) AS readiness_rows FROM ma.v_isa_early_warning_readiness;"

Invoke-TestSql @"
SELECT COUNT(*) AS critical_nulls
FROM ma.v_isa_early_warning_engine
WHERE country_iso3 IS NULL
   OR year IS NULL
   OR pillar_code IS NULL
   OR sovereign_alert_level IS NULL
   OR early_warning_score IS NULL
   OR early_warning_confidence IS NULL
   OR early_warning_decision IS NULL;
"@

Invoke-TestSql @"
SELECT COUNT(*) AS out_of_bounds_scores
FROM ma.v_isa_early_warning_engine
WHERE early_warning_score < 0 OR early_warning_score > 1
   OR early_warning_confidence < 0 OR early_warning_confidence > 1
   OR sovereign_risk_score < 0 OR sovereign_risk_score > 1
   OR fragility_warning_score < 0 OR fragility_warning_score > 1
   OR stress_propagation_score < 0 OR stress_propagation_score > 1;
"@

Invoke-TestSql @"
SELECT COUNT(*) AS invalid_alert_levels
FROM ma.v_isa_early_warning_engine
WHERE sovereign_alert_level NOT IN ('GREEN','YELLOW','ORANGE','RED');
"@

Invoke-TestSql @"
SELECT nb_countries, nb_years, nb_pillars
FROM (
  SELECT COUNT(DISTINCT country_iso3) AS nb_countries,
         COUNT(DISTINCT year) AS nb_years,
         COUNT(DISTINCT pillar_code) AS nb_pillars
  FROM ma.v_isa_early_warning_engine
) x;
"@

Invoke-TestSql @"
SELECT sovereign_alert_level, COUNT(*) AS nb
FROM ma.v_isa_early_warning_engine
GROUP BY sovereign_alert_level
ORDER BY sovereign_alert_level;
"@

Invoke-TestSql @"
SELECT risk_escalation_class, COUNT(*) AS nb
FROM ma.v_isa_risk_escalation_engine
GROUP BY risk_escalation_class
ORDER BY risk_escalation_class;
"@

Invoke-TestSql @"
SELECT COUNT(*) AS missing_intervention_priority
FROM ma.v_isa_priority_intervention_alerts
WHERE intervention_priority_class IS NULL
   OR priority_intervention_alert_status IS NULL;
"@

Write-Host ""
Write-Host "✅ P7I dry-run terminé avec succès"
