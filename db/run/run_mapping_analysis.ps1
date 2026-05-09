Write-Host ">>> SCRIPT LANCÉ"

$PSQL = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
$DB   = "osa_db"
$USER = "postgres"

Write-Host "========================================="
Write-Host " OSA — ANALYSE MAPPING QUALITY"
Write-Host "========================================="

$choice = Read-Host "Choix (1-4)"

if (-not $choice) {
    Write-Host "❌ Aucun choix saisi"
    exit
}

switch ($choice) {

    "1" {
        $query = "SELECT * FROM ma.v_mapping_quality_score WHERE quality_class = 'D — CRITIQUE' ORDER BY mapping_quality_score;"
    }

    "2" {
        $query = "SELECT * FROM ma.v_mapping_quality_score WHERE orphan_flag = 'ORPHELIN';"
    }

    "3" {
        $query = "SELECT * FROM ma.v_mapping_quality_score WHERE isa_status = 'EXCLU ISA';"
    }

    "4" {
        $query = "SELECT pillar_code, ROUND(AVG(mapping_quality_score),3) FROM ma.v_mapping_quality_score GROUP BY pillar_code ORDER BY 2;"
    }

    default {
        Write-Host "❌ Choix invalide"
        exit
    }
}

Write-Host ">>> Requête envoyée..."

& $PSQL -U $USER -d $DB -c $query

Write-Host ">>> FIN"