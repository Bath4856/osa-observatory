# ============================================================
# OSA / ISA — P7D DRY RUN TEST
# ============================================================

$ErrorActionPreference = "Stop"

$Psql = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
if (-not (Test-Path $Psql)) { $Psql = "psql" }

$DbUser = "postgres"
$DbName = "osa_db"
$HostName = "127.0.0.1"

Write-Host "========================================="
Write-Host " OSA — P7D DRY RUN TEST"
Write-Host "========================================="

function Run-TestSql($Sql) {
    Write-Host ""
    Write-Host ">>> Test SQL"
    & $Psql -h $HostName -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -c $Sql
    if ($LASTEXITCODE -ne 0) { throw "❌ Erreur dry-run P7D" }
}

Run-TestSql "
SELECT
    CASE WHEN EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema='rf' AND table_name='dynamic_score_policy'
    ) THEN 'OK' ELSE 'MISSING' END AS check_policy,
    CASE WHEN EXISTS (
        SELECT 1 FROM information_schema.views
        WHERE table_schema='ma' AND table_name='v_dynamic_scores_engine'
    ) THEN 'OK' ELSE 'MISSING' END AS check_engine,
    CASE WHEN EXISTS (
        SELECT 1 FROM information_schema.views
        WHERE table_schema='ma' AND table_name='v_isa_dynamic_scores_readiness'
    ) THEN 'OK' ELSE 'MISSING' END AS check_readiness;
"

Run-TestSql "
WITH required AS (
    SELECT unnest(ARRAY[
        'indicator_code',
        'pillar_code',
        'indicator_name',
        'semantic_code',
        'semantic_confidence_dynamic',
        'semantic_operational_score',
        'semantic_forecastability_score',
        'semantic_sovereignty_score',
        'semantic_sovereignty_vulnerability',
        'final_isa_aggregation_weight',
        'final_ml_aggregation_weight',
        'final_forecast_aggregation_weight',
        'final_sovereignty_aggregation_weight',
        'final_vulnerability_aggregation_weight',
        'dynamic_aggregation_class',
        'dynamic_isa_aggregation_decision',
        'dynamic_ml_aggregation_decision',
        'dynamic_forecast_aggregation_decision',
        'systemic_vulnerability_class',
        'semantic_sovereignty_class'
    ]) AS column_name
), found AS (
    SELECT column_name
    FROM information_schema.columns
    WHERE table_schema='ma'
      AND table_name='v_semantic_dynamic_aggregation_engine'
)
SELECT
    (SELECT COUNT(*) FROM required) AS required_cols,
    (SELECT COUNT(*) FROM required r JOIN found f USING(column_name)) AS found_cols,
    CASE WHEN (SELECT COUNT(*) FROM required r JOIN found f USING(column_name)) = (SELECT COUNT(*) FROM required)
         THEN 'OK' ELSE 'MISSING_COLUMNS' END AS column_check;
"

Run-TestSql "SELECT COUNT(*) AS nb_dynamic_score_policy_rows FROM rf.dynamic_score_policy;"
Run-TestSql "SELECT COUNT(*) AS nb_dynamic_score_indicators FROM ma.v_dynamic_scores_engine;"

Run-TestSql "
SELECT COUNT(*) AS critical_nulls
FROM ma.v_dynamic_scores_engine
WHERE indicator_code IS NULL
   OR pillar_code IS NULL
   OR semantic_code IS NULL
   OR dynamic_isa_score_component IS NULL
   OR dynamic_sovereignty_score_component IS NULL
   OR dynamic_vulnerability_score_component IS NULL
   OR dynamic_resilience_score_component IS NULL
   OR dynamic_score_class IS NULL
   OR dynamic_score_decision IS NULL;
"

Run-TestSql "
SELECT COUNT(*) AS out_of_bounds_scores
FROM ma.v_dynamic_scores_engine
WHERE dynamic_isa_score_component < 0 OR dynamic_isa_score_component > 1.5
   OR dynamic_sovereignty_score_component < 0 OR dynamic_sovereignty_score_component > 1.5
   OR dynamic_vulnerability_score_component < 0 OR dynamic_vulnerability_score_component > 1.5
   OR dynamic_resilience_score_component < 0 OR dynamic_resilience_score_component > 1.5
   OR dynamic_forecast_score_component < 0 OR dynamic_forecast_score_component > 1.5
   OR dynamic_ml_score_component < 0 OR dynamic_ml_score_component > 1.5;
"

Run-TestSql "
SELECT dynamic_score_class, COUNT(*) AS nb
FROM ma.v_dynamic_scores_engine
GROUP BY dynamic_score_class
ORDER BY nb DESC;
"

Run-TestSql "
SELECT dynamic_score_decision, COUNT(*) AS nb
FROM ma.v_dynamic_scores_engine
GROUP BY dynamic_score_decision
ORDER BY nb DESC;
"

Run-TestSql "
SELECT
    pillar_code,
    COUNT(*) AS nb,
    ROUND(AVG(dynamic_isa_score_component), 3) AS avg_isa_score,
    ROUND(AVG(dynamic_vulnerability_score_component), 3) AS avg_vulnerability_score
FROM ma.v_dynamic_scores_engine
GROUP BY pillar_code
ORDER BY avg_isa_score DESC;
"

Run-TestSql "SELECT COUNT(*) AS readiness_rows FROM ma.v_isa_dynamic_scores_readiness;"

Run-TestSql "
SELECT COUNT(*) AS locked_gap_scores
FROM ma.v_dynamic_scores_engine
WHERE dynamic_score_class = 'DYNAMIC_SCORE_LOCKED_GAP';
"

Write-Host ""
Write-Host "✅ P7D dry-run terminé avec succès"
