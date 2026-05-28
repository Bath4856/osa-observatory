# ============================================================
# OSA Observatory -- restart_v2.ps1
# Lancer depuis G:\osa-observatory en PowerShell
# ============================================================

$ErrorActionPreference = "Stop"
$RepoRoot = "G:\osa-observatory"
$PkgRoot  = "G:\python-packages"
$DbHost   = "127.0.0.1"
$DbPort   = "5432"
$DbName   = "osa_db"
$DbUser   = "postgres"
$PsqlExe  = "psql"
$PyExe    = "py"
$PyVer    = "-3.12"

Set-Location $RepoRoot

# ============================================================
# FONCTIONS
# ============================================================

function Write-Header($title) {
    Write-Host ""
    Write-Host "=======================================" -ForegroundColor Cyan
    Write-Host "  $title" -ForegroundColor Cyan
    Write-Host "=======================================" -ForegroundColor Cyan
}

function Write-Step($num, $total, $label) {
    Write-Host ""
    Write-Host ">>> [$num/$total] $label" -ForegroundColor Yellow
}

function Write-OK($msg)   { Write-Host "    OK : $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "    !! : $msg" -ForegroundColor Magenta }
function Write-Err($msg)  { Write-Host "    XX : $msg" -ForegroundColor Red }

function Start-Postgres {
    $svc = Get-Service -Name "postgresql-x64-17" -ErrorAction SilentlyContinue
    if ($null -eq $svc) { Write-Err "Service postgresql-x64-17 introuvable."; exit 1 }
    if ($svc.Status -ne "Running") {
        Write-Host "    Demarrage PostgreSQL..."
        Start-Service -Name "postgresql-x64-17"
        Start-Sleep -Seconds 3
    }
    $svc = Get-Service -Name "postgresql-x64-17"
    if ($svc.Status -eq "Running") { Write-OK "PostgreSQL Running" }
    else { Write-Err "PostgreSQL ECHEC demarrage"; exit 1 }
}

function Test-DbConnection {
    Write-Host "    Test connexion $DbName..."
    & $PsqlExe -h $DbHost -p $DbPort -U $DbUser -d $DbName `
        -v ON_ERROR_STOP=1 -c "SELECT 'osa_db OK' AS status;" 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Err "Connexion $DbName ECHEC"; exit 1 }
    Write-OK "Base $DbName accessible"
}

function Install-Deps([switch]$Silent) {
    $pipArgs = if ($Silent) { @("-q") } else { @() }
    if (Test-Path "$RepoRoot\requirements.txt") {
        Write-Host "    requirements.txt..."
        & $PyExe $PyVer -m pip install -r requirements.txt --target $PkgRoot @pipArgs
    }
    if (Test-Path "$RepoRoot\api\requirements.txt") {
        Write-Host "    api\requirements.txt..."
        & $PyExe $PyVer -m pip install -r api\requirements.txt --target $PkgRoot @pipArgs
    }
    Write-Host "    uvicorn[standard] fastapi sqlalchemy psycopg2-binary pydantic pydantic-settings python-dotenv..."
    & $PyExe $PyVer -m pip install "uvicorn[standard]" fastapi sqlalchemy `
        psycopg2-binary pydantic pydantic-settings python-dotenv `
        --target $PkgRoot @pipArgs
    Write-OK "Dependances installees dans $PkgRoot"
}

function Run-Psql($file, [switch]$Audit) {
    Write-Host "    psql << $file"
    if ($Audit) {
        & $PsqlExe -h $DbHost -p $DbPort -U $DbUser -d $DbName -f $file
    } else {
        & $PsqlExe -h $DbHost -p $DbPort -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -f $file
        if ($LASTEXITCODE -ne 0) { Write-Err "Erreur SQL : $file"; throw "Arret" }
    }
}

function Run-PsqlInline($sql) {
    & $PsqlExe -h $DbHost -p $DbPort -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -c $sql
    if ($LASTEXITCODE -ne 0) { Write-Err "Erreur SQL inline"; throw "Arret" }
}

# ============================================================
# MENU
# ============================================================

Write-Header "OSA Observatory -- restart_v2"
Write-Host ""
Write-Host "  Choisissez une action :" -ForegroundColor White
Write-Host ""
Write-Host "  [1]  Restart complet  (PostgreSQL + deps + API)" -ForegroundColor White
Write-Host "  [2]  PostgreSQL uniquement" -ForegroundColor White
Write-Host "  [3]  Dependances Python uniquement" -ForegroundColor White
Write-Host "  [4]  API FastAPI uniquement  -- http://localhost:8000" -ForegroundColor White
Write-Host "  [5]  Deployer AMAR v2" -ForegroundColor White
Write-Host "  [6]  Deployer GENECO  (necessite AMAR)" -ForegroundColor White
Write-Host "  [7]  Deployer AMAR v2 + GENECO  (sequence complete)" -ForegroundColor White
Write-Host "  [8]  Dry run  -- etat P7I Core / AMAR / GENECO" -ForegroundColor White
Write-Host "  [9]  Audit colonnes P7I source" -ForegroundColor White
Write-Host "  [A]  Audit pipeline   -- rapport qualite L1/L2/L3 + Excel" -ForegroundColor White
Write-Host "  [HC] Healthcheck auto -- diagnostic pipeline + AMAR + doctrine" -ForegroundColor Cyan
Write-Host "  [R]  Rollback GENECO uniquement" -ForegroundColor Magenta
Write-Host "  [X]  Rollback AMAR + GENECO" -ForegroundColor Red
Write-Host ""
$choice = Read-Host "Votre choix"

# ============================================================
# ACTIONS
# ============================================================

switch ($choice.ToUpper()) {

    "1" {
        Write-Header "Restart complet"
        Write-Step 1 4 "PostgreSQL"
        Start-Postgres
        Write-Step 2 4 "Dependances Python"
        Install-Deps -Silent
        Write-Step 3 4 "Connexion base"
        Test-DbConnection
        Write-Step 4 4 "API FastAPI"
        Write-Host "    http://localhost:8000  |  /docs"
        Write-Host ""
        & $PyExe $PyVer -m uvicorn api.main:app --reload --port 8000
    }

    "2" {
        Write-Header "PostgreSQL"
        Start-Postgres
    }

    "3" {
        Write-Header "Dependances Python"
        Install-Deps
    }

    "4" {
        Write-Header "API FastAPI"
        Test-DbConnection
        Write-Host ""
        Write-Host "    http://localhost:8000  |  http://localhost:8000/docs"
        Write-Host ""
        & $PyExe $PyVer -m uvicorn api.main:app --reload --port 8000
    }

    "5" {
        Write-Header "Deploiement AMAR v2"

        Write-Step 1 3 "Verification P7I Core"
        Run-PsqlInline "SELECT
  CASE WHEN to_regclass('ma.v_p7i_risk_source') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS check_p7i_source,
  CASE WHEN to_regclass('ma.v_isa_early_warning_engine') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS check_p7i_core,
  CASE WHEN to_regclass('ma.v_isa_risk_escalation_engine') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS check_p7i_escalation,
  CASE WHEN to_regclass('ma.v_isa_early_warning_country_year') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS check_p7i_country_year,
  CASE WHEN to_regclass('mg.package_registry') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS check_registry;"

        Write-Step 2 3 "Deploiement SQL"
        Run-Psql "db/patch_db/patch_p7i_amar_extension.sql"
        Run-Psql "db/views/ma/v_p7i_amar_atrocity_precursor_engine.sql"
        Run-Psql "db/views/ma/v_p7i_amar_dashboard.sql"
        Run-Psql "db/views/mg/v_public_p7i_amar_alerts.sql"
        Run-Psql "db/patch_db/patch_p7i_amar_alert_refresh.sql"

        Write-Step 3 3 "Audit"
        Run-Psql "audit/list_p7i_amar_columns.sql" -Audit
        Run-Psql "audit/p7i_amar_report.sql" -Audit

        Write-OK "AMAR v2 deploye"
    }

    "6" {
        Write-Header "Deploiement GENECO"

        Write-Step 1 3 "Verification prerequis"
        Run-PsqlInline "SELECT
  CASE WHEN to_regclass('ma.v_p7i_amar_dashboard') IS NOT NULL THEN 'OK' ELSE 'MISSING -- lancez option 5 avant' END AS check_amar,
  CASE WHEN to_regclass('ma.v_isa_early_warning_engine') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS check_p7i_core;"

        Write-Step 2 3 "Deploiement SQL"
        Run-Psql "db/patch_db/patch_p7i_amar_geneco_registry.sql"
        Run-Psql "db/views/ma/v_p7i_amar_geneco_engine.sql"
        Run-Psql "db/views/ma/v_p7i_amar_geneco_dashboard.sql"
        Run-Psql "db/views/ma/v_p7i_amar_composite_dashboard.sql"
        Run-Psql "db/views/mg/v_public_p7i_amar_geneco_alerts.sql"
        Run-Psql "db/patch_db/patch_p7i_amar_geneco_alert_refresh.sql"

        Write-Step 3 3 "Audit"
        Run-Psql "audit/list_p7i_amar_geneco_columns.sql" -Audit
        Run-Psql "audit/p7i_amar_geneco_report.sql" -Audit

        Write-OK "GENECO deploye"
    }

    "7" {
        Write-Header "Deploiement AMAR v2 + GENECO"

        Write-Step 1 5 "Verification P7I Core"
        Run-PsqlInline "SELECT
  CASE WHEN to_regclass('ma.v_p7i_risk_source') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS check_p7i_source,
  CASE WHEN to_regclass('ma.v_isa_early_warning_engine') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS check_p7i_core,
  CASE WHEN to_regclass('ma.v_isa_risk_escalation_engine') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS check_p7i_escalation,
  CASE WHEN to_regclass('ma.v_isa_early_warning_country_year') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS check_p7i_country_year;"

        Write-Step 2 5 "AMAR -- patch tables + registry"
        Run-Psql "db/patch_db/patch_p7i_amar_extension.sql"

        Write-Step 3 5 "AMAR -- vues + alerts"
        Run-Psql "db/views/ma/v_p7i_amar_atrocity_precursor_engine.sql"
        Run-Psql "db/views/ma/v_p7i_amar_dashboard.sql"
        Run-Psql "db/views/mg/v_public_p7i_amar_alerts.sql"
        Run-Psql "db/patch_db/patch_p7i_amar_alert_refresh.sql"

        Write-Step 4 5 "GENECO -- vues + alerts"
        Run-Psql "db/patch_db/patch_p7i_amar_geneco_registry.sql"
        Run-Psql "db/views/ma/v_p7i_amar_geneco_engine.sql"
        Run-Psql "db/views/ma/v_p7i_amar_geneco_dashboard.sql"
        Run-Psql "db/views/ma/v_p7i_amar_composite_dashboard.sql"
        Run-Psql "db/views/mg/v_public_p7i_amar_geneco_alerts.sql"
        Run-Psql "db/patch_db/patch_p7i_amar_geneco_alert_refresh.sql"

        Write-Step 5 5 "Audit complet"
        Run-Psql "audit/list_p7i_amar_columns.sql" -Audit
        Run-Psql "audit/p7i_amar_report.sql" -Audit
        Run-Psql "audit/list_p7i_amar_geneco_columns.sql" -Audit
        Run-Psql "audit/p7i_amar_geneco_report.sql" -Audit

        Write-OK "AMAR v2 + GENECO deployes"
    }

    "8" {
        Write-Header "Dry run -- etat P7I / AMAR / GENECO"

        Write-Host ""
        Write-Host "  -- P7I Core --" -ForegroundColor Cyan
        Run-PsqlInline "SELECT
  to_regclass('ma.v_p7i_risk_source')               AS p7i_source,
  to_regclass('ma.v_isa_early_warning_engine')       AS p7i_core,
  to_regclass('ma.v_isa_risk_escalation_engine')     AS p7i_escalation,
  to_regclass('ma.v_isa_early_warning_country_year') AS p7i_country_year;"

        Write-Host ""
        Write-Host "  -- AMAR --" -ForegroundColor Cyan
        Run-PsqlInline "SELECT
  to_regclass('ma.v_p7i_amar_atrocity_precursor_engine') AS amar_engine,
  to_regclass('ma.v_p7i_amar_dashboard')                 AS amar_dashboard,
  to_regclass('mg.early_warning_alerts')                 AS alert_table,
  to_regclass('mg.v_public_p7i_amar_alerts')             AS amar_public;"

        Write-Host ""
        Write-Host "  -- GENECO --" -ForegroundColor Cyan
        Run-PsqlInline "SELECT
  to_regclass('ma.v_p7i_amar_geneco_engine')        AS geneco_engine,
  to_regclass('ma.v_p7i_amar_geneco_dashboard')     AS geneco_dashboard,
  to_regclass('ma.v_p7i_amar_composite_dashboard')  AS composite,
  to_regclass('mg.v_public_p7i_amar_geneco_alerts') AS geneco_public;"

        Write-Host ""
        Write-Host "  -- Scores AMAR (si deploye) --" -ForegroundColor Cyan
        & $PsqlExe -h $DbHost -p $DbPort -U $DbUser -d $DbName -c `
            "SELECT year, risk_band, COUNT(*) AS nb, ROUND(AVG(risk_score),3) AS avg_score FROM ma.v_p7i_amar_dashboard GROUP BY year, risk_band ORDER BY year DESC, risk_band;" 2>&1

        Write-Host ""
        Write-Host "  -- Scores GENECO (si deploye) --" -ForegroundColor Cyan
        & $PsqlExe -h $DbHost -p $DbPort -U $DbUser -d $DbName -c `
            "SELECT year, risk_band, COUNT(*) AS nb, ROUND(AVG(risk_score),3) AS avg_score FROM ma.v_p7i_amar_geneco_dashboard GROUP BY year, risk_band ORDER BY year DESC, risk_band;" 2>&1
    }

    "9" {
        Write-Header "Audit colonnes P7I source"
        Run-Psql "audit/list_p7i_source_columns.sql" -Audit
    }

    "S" {
        Write-Header "Audit securite API -- Sprint 17"

        Write-Host ""
        Write-Host "  Cet audit necessite :" -ForegroundColor Yellow
        Write-Host "    - L API OSA en cours (http://localhost:8000)" -ForegroundColor White
        Write-Host "    - Une cle API STANDARD (format osa_...)" -ForegroundColor White
        Write-Host "    - Un code OTP recu par email" -ForegroundColor White
        Write-Host "    - Une cle API EXPERT (format osa_...)" -ForegroundColor White
        Write-Host ""

        $stdKey = Read-Host "    Cle API STANDARD (osa_...)"
        if (-not $stdKey) { Write-Warn "Cle STANDARD requise."; break }

        # Demander un OTP
        Write-Host ""
        Write-Host "    Demande de code OTP en cours..." -ForegroundColor Yellow
        try {
            $otpResp = Invoke-RestMethod "http://localhost:8000/auth/otp/request" `
                -Method POST `
                -Headers @{"X-Api-Key" = $stdKey} `
                -ErrorAction Stop
            Write-OK "Code OTP envoye : $($otpResp.delivery)"
        } catch {
            Write-Warn "Echec demande OTP : $($_.Exception.Message)"
            Write-Host "    Verifiez que l API est demarree (option 4)."
            break
        }

        Write-Host ""
        $stdOtp = Read-Host "    Code OTP recu par email (6 chiffres)"
        if (-not $stdOtp) { Write-Warn "Code OTP requis."; break }

        $expKey = Read-Host "    Cle API EXPERT (osa_...)"
        if (-not $expKey) { Write-Warn "Cle EXPERT requise."; break }

        Write-Host ""
        Write-Host "    Lancement de l audit (63 endpoints)..." -ForegroundColor Yellow
        Write-Host ""

        $env:PYTHONPATH = $RepoRoot
        & $PyExe $PyVer "audit\scripts\osa_security_audit.py" `
            --std-key $stdKey `
            --std-otp $stdOtp `
            --exp-key $expKey

        $auditExit = $LASTEXITCODE
        Write-Host ""
        if ($auditExit -eq 0) {
            Write-OK "Audit securite : PASS -- Zero vulnerabilite critique"
        } else {
            Write-Warn "Audit securite : FAIL -- Voir rapport dans audit\"
        }
    }

    "A" {
        Write-Header "Audit pipeline"
        Write-Step 1 1 "Audit qualite L1/L2/L3"
        & $PyExe $PyVer -m uvicorn api.main:app --reload --port 8000 2>&1 | Out-Null
        Run-Psql "audit/osa_audit_completude_mapping_v2.sql" -Audit
        Write-OK "Audit pipeline termine"
    }

    "HC" {
        Write-Header "Healthcheck automatise"

        Write-Step 1 3 "Execution SQL diagnostic"
        $HcTs  = Get-Date -Format "yyyyMMdd_HHmmss"
        $HcLog = "$RepoRoot\logs\healthcheck\healthcheck_$HcTs.log"
        New-Item -ItemType Directory -Force -Path "$RepoRoot\logs\healthcheck" | Out-Null
        & $PsqlExe -h $DbHost -p $DbPort -U $DbUser -d $DbName `
            -f "$RepoRoot\audit\osa_healthcheck.sql" | Out-File $HcLog -Encoding UTF8
        Write-OK "Log SQL : $HcLog"

        Write-Step 2 3 "Analyse Python"
        $env:PYTHONPATH = $RepoRoot
        & $PyExe $PyVer "$RepoRoot\scripts\analyse\osa_healthcheck.py" --log $HcLog --report
        $HcExit = $LASTEXITCODE

        Write-Step 3 3 "Resultat"
        if ($HcExit -eq 0)     { Write-OK   "Statut GLOBAL : OK -- pipeline sain" }
        elseif ($HcExit -eq 1) { Write-Warn "Statut GLOBAL : ATTENTION -- avertissements detectes" }
        else                   { Write-Err  "Statut GLOBAL : CRITIQUE -- anomalies detectees" }
        Write-Host "    Log  : $HcLog"
        $HcJson = $HcLog -replace "\.log$", ".json"
        Write-Host "    JSON : $HcJson"
    }

    "R" {
        Write-Header "Rollback GENECO"
        Write-Warn "Supprime les vues GENECO et les alertes persistees GENECO."
        $confirm = Read-Host "    Confirmer ? (oui/non)"
        if ($confirm -ne "oui") { Write-Host "    Annule."; exit 0 }
        Run-PsqlInline "BEGIN;
DROP VIEW IF EXISTS mg.v_public_p7i_amar_geneco_alerts;
DROP VIEW IF EXISTS ma.v_p7i_amar_composite_dashboard;
DROP VIEW IF EXISTS ma.v_p7i_amar_geneco_dashboard;
DROP VIEW IF EXISTS ma.v_p7i_amar_geneco_engine;
DELETE FROM mg.early_warning_alerts WHERE source_engine = 'P7I-AMAR-GENECO';
DELETE FROM mg.risk_taxonomy WHERE risk_code = 'CONFLICT_ECONOMY_EXPOSURE';
DELETE FROM mg.package_registry WHERE package_code = 'P7I-AMAR-GENECO';
COMMIT;"
        Write-OK "Rollback GENECO effectue"
    }

    "X" {
        Write-Header "Rollback AMAR + GENECO"
        Write-Warn "Supprime TOUTES les vues AMAR et GENECO. P7I Core non touche."
        $confirm = Read-Host "    Confirmer ? (oui/non)"
        if ($confirm -ne "oui") { Write-Host "    Annule."; exit 0 }

        Write-Host "    Rollback GENECO..."
        Run-PsqlInline "BEGIN;
DROP VIEW IF EXISTS mg.v_public_p7i_amar_geneco_alerts;
DROP VIEW IF EXISTS ma.v_p7i_amar_composite_dashboard;
DROP VIEW IF EXISTS ma.v_p7i_amar_geneco_dashboard;
DROP VIEW IF EXISTS ma.v_p7i_amar_geneco_engine;
DELETE FROM mg.early_warning_alerts WHERE source_engine = 'P7I-AMAR-GENECO';
DELETE FROM mg.risk_taxonomy WHERE risk_code = 'CONFLICT_ECONOMY_EXPOSURE';
DELETE FROM mg.package_registry WHERE package_code = 'P7I-AMAR-GENECO';
COMMIT;"

        Write-Host "    Rollback AMAR..."
        Run-Psql "db/patch_db/rollback_p7i_amar_extension.sql"

        Write-OK "Rollback AMAR + GENECO effectue"
    }

    default {
        Write-Warn "Choix non reconnu : '$choice'"
        exit 1
    }
}

Write-Host ""
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "  Termine." -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""


