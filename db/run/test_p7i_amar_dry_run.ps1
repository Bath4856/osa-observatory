Write-Host "OSA — P7I-AMAR DRY RUN TEST v2"

$ErrorActionPreference = "Stop"

$Psql = "psql"
$HostDb = "127.0.0.1"
$Port = "5432"
$Db = "osa_db"
$User = "postgres"

& $Psql -h $HostDb -p $Port -U $User -d $Db -v ON_ERROR_STOP=1 -c "
SELECT
  to_regclass('ma.v_p7i_risk_source') AS p7i_source,
  to_regclass('ma.v_p7i_amar_atrocity_precursor_engine') AS amar_engine,
  to_regclass('ma.v_p7i_amar_dashboard') AS amar_dashboard,
  to_regclass('mg.early_warning_alerts') AS alert_table,
  to_regclass('mg.v_public_p7i_amar_alerts') AS public_view;
"

& $Psql -h $HostDb -p $Port -U $User -d $Db -v ON_ERROR_STOP=1 -c "
SELECT
  MIN(risk_score) AS min_risk_score,
  MAX(risk_score) AS max_risk_score,
  ROUND(AVG(risk_score), 3) AS avg_risk_score,
  COUNT(*) AS nb_rows
FROM ma.v_p7i_amar_dashboard;
"

& $Psql -h $HostDb -p $Port -U $User -d $Db -v ON_ERROR_STOP=1 -c "
SELECT year, risk_band, COUNT(*) AS nb
FROM ma.v_p7i_amar_dashboard
GROUP BY year, risk_band
ORDER BY year DESC, risk_band;
"

& $Psql -h $HostDb -p $Port -U $User -d $Db -v ON_ERROR_STOP=1 -c "
SELECT country_iso3, year, risk_band, risk_score, confidence_score, recommended_action
FROM ma.v_p7i_amar_dashboard
ORDER BY year DESC, risk_score DESC
LIMIT 20;
"

Write-Host "✅ P7I-AMAR dry-run terminé"
