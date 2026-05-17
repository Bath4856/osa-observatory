Write-Host "OSA — ROLLBACK P7I-AMAR EXTENSION"

$ErrorActionPreference = "Stop"

$Psql = "psql"
$HostDb = "127.0.0.1"
$Port = "5432"
$Db = "osa_db"
$User = "postgres"

& $Psql -h $HostDb -p $Port -U $User -d $Db -v ON_ERROR_STOP=1 -f "db/patch_db/rollback_p7i_amar_extension.sql"

if ($LASTEXITCODE -ne 0) {
    throw "Erreur rollback P7I-AMAR"
}

Write-Host "✅ Rollback P7I-AMAR terminé"
