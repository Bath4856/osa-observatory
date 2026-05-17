Write-Host "OSA — RUN P7I-AMAR MERGE PACK v2"

$ErrorActionPreference = "Stop"

$Psql = "psql"
$HostDb = "127.0.0.1"
$Port = "5432"
$Db = "osa_db"
$User = "postgres"

function Run-SqlFile($file) {
    Write-Host ">>> Running $file"
    & $Psql -h $HostDb -p $Port -U $User -d $Db -v ON_ERROR_STOP=1 -f $file
    if ($LASTEXITCODE -ne 0) {
        throw "Erreur SQL : $file"
    }
}

Write-Host ">>> Pré-test dépendances P7I-AMAR"
& $Psql -h $HostDb -p $Port -U $User -d $Db -v ON_ERROR_STOP=1 -c "
SELECT
  CASE WHEN to_regclass('ma.v_p7i_risk_source') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS check_p7i_source,
  CASE WHEN to_regclass('ma.v_isa_early_warning_engine') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS check_p7i_core,
  CASE WHEN to_regclass('ma.v_isa_risk_escalation_engine') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS check_p7i_escalation,
  CASE WHEN to_regclass('ma.v_isa_early_warning_country_year') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS check_p7i_country_year,
  CASE WHEN to_regclass('mg.package_registry') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS check_registry;
"
if ($LASTEXITCODE -ne 0) { throw "Erreur pré-test P7I-AMAR" }

Run-SqlFile "db/patch_db/patch_p7i_amar_extension.sql"
Run-SqlFile "db/views/ma/v_p7i_amar_atrocity_precursor_engine.sql"
Run-SqlFile "db/views/ma/v_p7i_amar_dashboard.sql"
Run-SqlFile "db/views/mg/v_public_p7i_amar_alerts.sql"
Run-SqlFile "db/patch_db/patch_p7i_amar_alert_refresh.sql"

Write-Host ">>> Colonnes P7I-AMAR"
Run-SqlFile "audit/list_p7i_amar_columns.sql"

Write-Host ">>> Rapport P7I-AMAR"
Run-SqlFile "audit/p7i_amar_report.sql"

Write-Host "✅ P7I-AMAR v2 installé avec succès"
