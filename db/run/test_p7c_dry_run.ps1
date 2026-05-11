$ErrorActionPreference = "Stop"

Write-Host "========================================="
Write-Host " OSA — P7C DRY RUN TEST"
Write-Host "========================================="

$PSQL = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
$DB = "osa_db"
$USER = "postgres"

function Run-Test($Sql) {
    Write-Host ""
    Write-Host ">>> Test SQL"
    & $PSQL -U $USER -d $DB -v ON_ERROR_STOP=1 -c $Sql
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Erreur dry-run P7C" -ForegroundColor Red
        exit 1
    }
}

# 1. Dépendances objet
Run-Test "
SELECT
    CASE WHEN to_regclass('rf.dynamic_aggregation_policy') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS check_policy,
    CASE WHEN to_regclass('ma.v_semantic_dynamic_aggregation_engine') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS check_engine,
    CASE WHEN to_regclass('ma.v_isa_dynamic_aggregation_readiness') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS check_readiness;
"

# 2. Dépendances colonnes via information_schema
Run-Test "
WITH required(col) AS (
    VALUES
    ('indicator_code'),('pillar_code'),('semantic_code'),('final_isa_aggregation_weight'),
    ('final_ml_aggregation_weight'),('final_forecast_aggregation_weight'),
    ('final_sovereignty_aggregation_weight'),('final_vulnerability_aggregation_weight'),
    ('dynamic_aggregation_class'),('dynamic_isa_aggregation_decision'),
    ('dynamic_ml_aggregation_decision'),('dynamic_forecast_aggregation_decision'),
    ('systemic_vulnerability_class')
), found AS (
    SELECT column_name
    FROM information_schema.columns
    WHERE table_schema='ma'
      AND table_name='v_semantic_dynamic_aggregation_engine'
)
SELECT COUNT(*) AS required_cols,
       COUNT(f.column_name) AS found_cols,
       CASE WHEN COUNT(*) = COUNT(f.column_name) THEN 'OK' ELSE 'MISSING_COLUMNS' END AS column_check
FROM required r
LEFT JOIN found f ON f.column_name = r.col;
"

# 3. Cardinalité politique RF
Run-Test "SELECT COUNT(*) AS nb_dynamic_aggregation_policy_rows FROM rf.dynamic_aggregation_policy;"

# 4. Couverture 228 indicateurs
Run-Test "SELECT COUNT(*) AS nb_dynamic_aggregation_indicators FROM ma.v_semantic_dynamic_aggregation_engine;"

# 5. Anti-NULL sur colonnes critiques
Run-Test "
SELECT COUNT(*) AS critical_nulls
FROM ma.v_semantic_dynamic_aggregation_engine
WHERE indicator_code IS NULL
   OR pillar_code IS NULL
   OR semantic_code IS NULL
   OR final_isa_aggregation_weight IS NULL
   OR final_vulnerability_aggregation_weight IS NULL
   OR dynamic_aggregation_class IS NULL
   OR dynamic_isa_aggregation_decision IS NULL;
"

# 6. Anti division zéro potentiel : aucune famille avec somme poids ISA négative ou NULL
Run-Test "
SELECT COUNT(*) AS zero_or_null_weight_groups
FROM (
    SELECT pillar_code, semantic_code, SUM(final_isa_aggregation_weight) AS sum_isa_weight
    FROM ma.v_semantic_dynamic_aggregation_engine
    GROUP BY pillar_code, semantic_code
) x
WHERE sum_isa_weight IS NULL OR sum_isa_weight < 0;
"

# 7. Contrôle classes
Run-Test "
SELECT dynamic_aggregation_class, COUNT(*) AS nb
FROM ma.v_semantic_dynamic_aggregation_engine
GROUP BY dynamic_aggregation_class
ORDER BY nb DESC;
"

# 8. Contrôle décisions ISA
Run-Test "
SELECT dynamic_isa_aggregation_decision, COUNT(*) AS nb
FROM ma.v_semantic_dynamic_aggregation_engine
GROUP BY dynamic_isa_aggregation_decision
ORDER BY nb DESC;
"

# 9. Readiness cardinalité
Run-Test "SELECT COUNT(*) AS readiness_rows FROM ma.v_isa_dynamic_aggregation_readiness;"

# 10. Locked gaps conservés
Run-Test "
SELECT COUNT(*) AS locked_gap_aggregation
FROM ma.v_semantic_dynamic_aggregation_engine
WHERE dynamic_aggregation_class = 'AGGREGATION_LOCKED_GAP';
"

Write-Host ""
Write-Host "✅ P7C dry-run terminé avec succès" -ForegroundColor Green
