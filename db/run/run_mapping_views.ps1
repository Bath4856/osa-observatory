$BASE = "G:\osa-observatory\db"
$FILE = "$BASE\install_views.sql"
$PSQL = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
$DB   = "osa_db"
$USER = "postgres"

Write-Host "========================================="
Write-Host " OSA — INSTALLATION DES VUES (ma)"
Write-Host "========================================="

# Se positionner dans le bon dossier
cd $BASE

# Vérification des fichiers
if (!(Test-Path "$BASE\views\ma\v_mapping_quality_score.sql")) {
    Write-Host "❌ Vue mapping introuvable"
    exit 1
}

if (!(Test-Path "$BASE\views\ma\v_indicator_values_final.sql")) {
    Write-Host "❌ Vue indicator_values introuvable"
    exit 1
}

if (!(Test-Path $FILE)) {
    Write-Host "❌ install_views.sql introuvable"
    exit 1
}

Write-Host ">>> Installation en cours..."

# Exécution SQL
& $PSQL `
  -U $USER `
  -d $DB `
  -f $FILE `
  -v ON_ERROR_STOP=1

# Vérification retour
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Erreur lors de l'installation"
    exit 1
}

Write-Host "✅ Installation terminée avec succès"