Write-Host "========================================="
Write-Host " OSA — P7B5 DRY RUN TEST"
Write-Host "========================================="

$ErrorActionPreference = "Stop"

$PSQL = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
$DB = "osa_db"
$USER = "postgres"

$tests = @(
@"
SELECT
  CASE WHEN to_regclass('rf.semantic_sovereignty_policy') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS check_policy,
  CASE WHEN to_regclass('ma.v_semantic_sovereignty_engine') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS check_engine,
  CASE WHEN to_regclass('ma.v_isa_sovereignty_readiness') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS check_readiness;
"@,
@"
SELECT COUNT(*) AS nb_sovereignty_policy_rows
FROM rf.semantic_sovereignty_policy;
"@,
@"
SELECT COUNT(*) AS nb_sovereignty_indicators
FROM ma.v_semantic_sovereignty_engine;
"@,
@"
SELECT semantic_sovereignty_class, COUNT(*) AS nb
FROM ma.v_semantic_sovereignty_engine
GROUP BY semantic_sovereignty_class
ORDER BY nb DESC;
"@,
@"
SELECT isa_sovereignty_decision, COUNT(*) AS nb
FROM ma.v_semantic_sovereignty_engine
GROUP BY isa_sovereignty_decision
ORDER BY nb DESC;
"@,
@"
SELECT
    pillar_code,
    COUNT(*) AS nb,
    ROUND(AVG(semantic_sovereignty_score), 3) AS avg_sovereignty,
    ROUND(AVG(semantic_sovereignty_vulnerability), 3) AS avg_vulnerability
FROM ma.v_semantic_sovereignty_engine
GROUP BY pillar_code
ORDER BY avg_sovereignty;
"@,
@"
SELECT COUNT(*) AS locked_sovereignty_gap
FROM ma.v_semantic_sovereignty_engine
WHERE semantic_sovereignty_class = 'SOVEREIGNTY_GAP_LOCKED';
"@,
@"
SELECT COUNT(*) AS readiness_rows
FROM ma.v_isa_sovereignty_readiness;
"@
)

foreach ($sql in $tests) {
    Write-Host ""
    Write-Host ">>> Test SQL"
    & $PSQL -U $USER -d $DB -v ON_ERROR_STOP=1 -c $sql
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Erreur dry-run P7B5"
        exit 1
    }
}

Write-Host ""
Write-Host "✅ P7B5 dry-run terminé avec succès"
