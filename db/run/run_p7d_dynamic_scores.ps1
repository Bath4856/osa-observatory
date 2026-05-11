# ============================================================
# OSA / ISA — RUN P7D DYNAMIC SCORES ENGINE
# ============================================================

$ErrorActionPreference = "Stop"

$Psql = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
if (-not (Test-Path $Psql)) { $Psql = "psql" }

$DbUser = "postgres"
$DbName = "osa_db"
$HostName = "127.0.0.1"

Write-Host "========================================="
Write-Host " OSA — RUN P7D DYNAMIC SCORES ENGINE"
Write-Host "========================================="

Write-Host ">>> Pré-test dépendances P7D"
& $Psql -h $HostName -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -c "
WITH checks AS (
    SELECT
        CASE WHEN EXISTS (
            SELECT 1 FROM information_schema.views
            WHERE table_schema='ma'
              AND table_name='v_semantic_dynamic_aggregation_engine'
        ) THEN 'OK' ELSE 'MISSING' END AS check_aggregation_engine,
        CASE WHEN EXISTS (
            SELECT 1 FROM information_schema.views
            WHERE table_schema='ma'
              AND table_name='v_isa_dynamic_aggregation_readiness'
        ) THEN 'OK' ELSE 'MISSING' END AS check_aggregation_readiness,
        CASE WHEN (
            SELECT COUNT(*)
            FROM information_schema.columns
            WHERE table_schema='ma'
              AND table_name='v_semantic_dynamic_aggregation_engine'
              AND column_name IN (
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
              )
        ) = 20 THEN 'OK' ELSE 'MISSING_COLUMNS' END AS check_required_columns
)
SELECT * FROM checks;
"
if ($LASTEXITCODE -ne 0) { throw "Pré-test P7D échoué" }

$SqlFiles = @(
  "db\patch_db\patch_p7d_dynamic_scores.sql",
  "db\views\ma\v_dynamic_scores_engine.sql",
  "db\views\ma\v_isa_dynamic_scores_readiness.sql"
)

foreach ($file in $SqlFiles) {
    Write-Host ">>> SQL : $file"
    & $Psql -h $HostName -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -f $file
    if ($LASTEXITCODE -ne 0) { throw "Erreur SQL : $file" }
}

Write-Host ">>> Rapport P7D"
& $Psql -h $HostName -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -f "audit\p7d_dynamic_scores_report.sql"
if ($LASTEXITCODE -ne 0) { throw "Erreur rapport P7D" }

Write-Host "✅ P7D Dynamic Scores Engine installé"
