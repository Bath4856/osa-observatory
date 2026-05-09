$PSQL = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
$DB   = "osa_db"
$USER = "postgres"

Write-Host "========================================="
Write-Host " OSA — ANALYSE MAPPING QUALITY"
Write-Host "========================================="
Write-Host ""
Write-Host "Choisissez une option :"
Write-Host "1 - 🔍 Pires indicateurs (CRITIQUE)"
Write-Host "2 - 🔴 Données ORPHELINES (Bloc H)"
Write-Host "3 - 🟡 Indicateurs EXCLUS ISA"
Write-Host "4 - 🟣 Score moyen par pilier"
Write-Host ""

$choice = Read-Host "Votre choix (1-4)"

switch ($choice) {

    "1" {
        $query = @"
SELECT *
FROM ma.v_mapping_quality_score
WHERE quality_class = 'D — CRITIQUE'
ORDER BY mapping_quality_score;
"@
    }

    "2" {
        $query = @"
SELECT *
FROM ma.v_mapping_quality_score
WHERE orphan_flag = 'ORPHELIN';
"@
    }

    "3" {
        $query = @"
SELECT *
FROM ma.v_mapping_quality_score
WHERE isa_status = 'EXCLU ISA';
"@
    }

    "4" {
        $query = @"
SELECT
    pillar_code,
    ROUND(AVG(mapping_quality_score), 3) AS avg_score
FROM ma.v_mapping_quality_score
GROUP BY pillar_code
ORDER BY avg_score;
"@
    }

    default {
        Write-Host "❌ Choix invalide"
        exit 1
    }
}

Write-Host ""
Write-Host ">>> Exécution en cours..."
Write-Host ""

& $PSQL -U $USER -d $DB -c $query

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Erreur lors de l'exécution"
    exit 1
}

Write-Host ""
Write-Host "✅ Analyse terminée"