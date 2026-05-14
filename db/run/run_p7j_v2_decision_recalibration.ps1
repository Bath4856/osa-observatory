param([string]$DbHost="127.0.0.1",[string]$DbPort="5432",[string]$DbName="osa_db",[string]$DbUser="postgres")
$ErrorActionPreference="Stop"; $Psql="psql"
Write-Host "========================================="
Write-Host " OSA — RUN P7J v2 DECISION RECALIBRATION"
Write-Host "========================================="
Write-Host ">>> Pré-test dépendances P7J v2"
$precheck=@"
WITH checks AS (
 SELECT to_regclass('ma.v_isa_priority_intervention_alerts') IS NOT NULL has_alerts,
        to_regclass('ma.v_isa_scenario_simulation_engine') IS NOT NULL has_scenarios,
        to_regclass('rf.isa_decision_priority_policy') IS NOT NULL has_priority_policy,
        to_regclass('rf.isa_decision_timing_policy') IS NOT NULL has_timing_policy
), cols AS (
 SELECT COUNT(*) FILTER (WHERE table_schema='ma' AND table_name='v_isa_priority_intervention_alerts' AND column_name IN ('country_iso3','year','pillar_code','intervention_family_code','intervention_family_label','strategic_objective','recommended_action','candidate_intervention_status','sovereign_alert_level','early_warning_class','early_warning_score','early_warning_confidence','intervention_alert_priority_score','intervention_priority_class')) found_p7i_cols,
        COUNT(*) FILTER (WHERE table_schema='ma' AND table_name='v_isa_scenario_simulation_engine' AND column_name IN ('country_iso3','year','pillar_code','scenario_code','simulated_isa_delta','simulation_decision','simulation_confidence')) found_p7h_cols
 FROM information_schema.columns
)
SELECT CASE WHEN has_alerts THEN 'OK' ELSE 'KO' END check_p7i_alerts,
       CASE WHEN has_scenarios THEN 'OK' ELSE 'KO' END check_p7h_scenarios,
       CASE WHEN has_priority_policy THEN 'OK' ELSE 'KO' END check_priority_policy,
       CASE WHEN has_timing_policy THEN 'OK' ELSE 'KO' END check_timing_policy,
       14 required_p7i_cols, found_p7i_cols, 7 required_p7h_cols, found_p7h_cols,
       CASE WHEN has_alerts AND has_scenarios AND has_priority_policy AND has_timing_policy AND found_p7i_cols=14 AND found_p7h_cols=7 THEN 'OK' ELSE 'MISSING_DEPENDENCY_OR_COLUMNS' END check_required_columns
FROM checks, cols;
"@
& $Psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -c $precheck
if($LASTEXITCODE -ne 0){throw "Erreur SQL pré-test P7J v2"}
Write-Host ">>> SQL : db/patch_db/patch_p7j_v2_decision_recalibration.sql"
& $Psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -f "db/patch_db/patch_p7j_v2_decision_recalibration.sql"
if($LASTEXITCODE -ne 0){throw "Erreur SQL patch P7J v2"}
Write-Host ">>> Drop vues P7J dépendantes avant recréation"
$dropSql=@"
DROP VIEW IF EXISTS ma.v_isa_decision_readiness CASCADE;
DROP VIEW IF EXISTS ma.v_isa_decision_country_year CASCADE;
DROP VIEW IF EXISTS ma.v_isa_intervention_decision_matrix CASCADE;
DROP VIEW IF EXISTS ma.v_isa_decision_priority_engine CASCADE;
"@
& $Psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -c $dropSql
if($LASTEXITCODE -ne 0){throw "Erreur DROP vues P7J v2"}
$files=@("db/views/ma/v_isa_decision_priority_engine.sql","db/views/ma/v_isa_intervention_decision_matrix.sql","db/views/ma/v_isa_decision_country_year.sql","db/views/ma/v_isa_decision_readiness.sql")
foreach($file in $files){Write-Host ">>> SQL : $file"; & $Psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -f $file; if($LASTEXITCODE -ne 0){throw "Erreur SQL : $file"}}
Write-Host ">>> Rapport P7J v2"
& $Psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -f "audit/p7j_v2_decision_recalibration_report.sql"
if($LASTEXITCODE -ne 0){throw "Erreur rapport P7J v2"}
Write-Host "✅ P7J v2 recalibration installé"
