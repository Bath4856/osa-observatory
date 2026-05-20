# ============================================================
# OSA Observatory — run_full_pipeline.ps1  v3
# Orchestrateur L1 → L2 (imputer MICE) → L3 (normalize)
# Checkpoint par étape, log horodaté par exécution.
# Tous les processus externes via Start-Process (pas de pipe 2>&1).
# ============================================================

$ErrorActionPreference = "Stop"
$RepoRoot       = "G:\osa-observatory"
$DbHost         = "127.0.0.1"
$DbPort         = "5432"
$DbName         = "osa_db"
$DbUser         = "postgres"
$PsqlExe        = "psql"
$PyExe          = "py"
$LogDir         = "$RepoRoot\logs\pipeline"
$CheckpointFile = "$RepoRoot\logs\full_pipeline_checkpoint.json"
$RunId          = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile        = "$LogDir\pipeline_$RunId.log"

Set-Location $RepoRoot
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

# ── Logging ───────────────────────────────────────────────────────────────────

function Log($level, $msg) {
    $ts   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$ts | $($level.PadRight(7)) | $msg"
    Add-Content $LogFile $line
    switch ($level) {
        "OK"    { Write-Host "    $line" -ForegroundColor Green }
        "WARN"  { Write-Host "    $line" -ForegroundColor Magenta }
        "ERROR" { Write-Host "    $line" -ForegroundColor Red }
        "STEP"  { Write-Host ""; Write-Host ">>> $line" -ForegroundColor Yellow }
        "SKIP"  { Write-Host "    $line" -ForegroundColor DarkGray }
        default { Write-Host "    $line" -ForegroundColor White }
    }
}

function Log-Banner($title) {
    $sep = "=" * 72
    $ts  = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content $LogFile ""; Add-Content $LogFile $sep
    Add-Content $LogFile "  $ts | $title"
    Add-Content $LogFile $sep
    Write-Host ""; Write-Host $sep -ForegroundColor Cyan
    Write-Host "  $title" -ForegroundColor Cyan
    Write-Host $sep -ForegroundColor Cyan
}

function Log-Section($title) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content $LogFile ""; Add-Content $LogFile "--- $ts | $title ---"
    Write-Host ""; Write-Host "--- $title ---" -ForegroundColor Cyan
}

# ── Processus externe via Start-Process ──────────────────────────────────────
# Evite 2>&1 | ForEach-Object qui capture NOTICE/INFO comme exceptions.

function Run-Proc($exe, $argList, $label) {
    $tmpOut = "$LogDir\proc_${RunId}_$([System.IO.Path]::GetRandomFileName()).tmp"
    $tmpErr = "$tmpOut.err"

    $proc = Start-Process -FilePath $exe `
        -ArgumentList $argList `
        -RedirectStandardOutput $tmpOut `
        -RedirectStandardError  $tmpErr `
        -NoNewWindow -Wait -PassThru

    # Lire stdout
    if (Test-Path $tmpOut) {
        Get-Content $tmpOut | ForEach-Object {
            $line = "$_"
            if ($line -notmatch "UserWarning|warnings\.warn|sklearn\.utils") {
                Add-Content $LogFile "    $line"
                if ($line -match "(INFO|WARN|ERROR|NOTICE|OK|KO|\d+ valeurs|\d+ lignes)") {
                    Write-Host "    $line" -ForegroundColor Gray
                }
            }
        }
        Remove-Item $tmpOut -ErrorAction SilentlyContinue
    }
    # Lire stderr (NOTICE psql arrive ici)
    if (Test-Path $tmpErr) {
        Get-Content $tmpErr | ForEach-Object {
            $line = "$_"
            if ($line -notmatch "UserWarning|warnings\.warn|sklearn\.utils") {
                Add-Content $LogFile "    $line"
                if ($line -match "(NOTICE|ERROR|FATAL)") {
                    Write-Host "    $line" -ForegroundColor Gray
                }
            }
        }
        Remove-Item $tmpErr -ErrorAction SilentlyContinue
    }

    return $proc.ExitCode
}

# ── Checkpoint ────────────────────────────────────────────────────────────────

function Get-Checkpoint {
    if (Test-Path $CheckpointFile) {
        return Get-Content $CheckpointFile -Raw | ConvertFrom-Json
    }
    return [PSCustomObject]@{}
}

function Set-CheckpointStep($key, $status, $details = "") {
    $cp = Get-Checkpoint
    $cp | Add-Member -NotePropertyName $key -NotePropertyValue ([PSCustomObject]@{
        status   = $status
        done_at  = (Get-Date -Format "o")
        details  = $details
        log_file = [System.IO.Path]::GetFileName($LogFile)
    }) -Force
    $cp | Add-Member -NotePropertyName "updated_at" -NotePropertyValue (Get-Date -Format "o") -Force
    $cp | ConvertTo-Json -Depth 5 | Set-Content $CheckpointFile
}

function Get-StepStatus($key) {
    $entry = (Get-Checkpoint).$key
    if ($null -eq $entry) { return "PENDING" }
    return $entry.status
}

function Show-CheckpointSummary {
    $cp = Get-Checkpoint
    if ($cp.PSObject.Properties.Count -eq 0) {
        Write-Host "  Aucun checkpoint." -ForegroundColor DarkGray; return
    }
    Write-Host ""; Write-Host "  Checkpoint :" -ForegroundColor White
    $cp.PSObject.Properties | Where-Object { $_.Name -ne "updated_at" } | ForEach-Object {
        $s     = $_.Value.status
        $ts    = $_.Value.done_at -replace 'T',' ' -replace '\..+',''
        $det   = $_.Value.details
        $lf    = $_.Value.log_file
        $icon  = if ($s -eq "OK") { "✓" } elseif ($s -eq "KO") { "✗" } else { "~" }
        $color = if ($s -eq "OK") { "Green" } elseif ($s -eq "KO") { "Red" } else { "Yellow" }
        Write-Host ("    {0} {1,-35} {2,-8} {3}  {4}  [{5}]" -f $icon, $_.Name, $s, $ts, $det, $lf) -ForegroundColor $color
    }
}

# ── Piliers ───────────────────────────────────────────────────────────────────

$PILLARS = @("PMIN","PMON","PECO","PGEO","PMIL","PHUM","PENV","PNUM","PRES","PTRA")
$PILLAR_NAMES = @{
    "PMIN"="Souveraineté minière"; "PMON"="Souveraineté monétaire"
    "PECO"="Souveraineté économique"; "PGEO"="Souveraineté géopolitique"
    "PMIL"="Souveraineté militaire"; "PHUM"="Souveraineté humaine"
    "PENV"="Souveraineté environnementale"; "PNUM"="Souveraineté numérique"
    "PRES"="Ressources stratégiques"; "PTRA"="Souveraineté transport"
}

# ── Fonctions pipeline ────────────────────────────────────────────────────────

function Run-L1-Collect($pillar, $dryRun) {
    $key = "L1::$pillar"
    if ((Get-StepStatus $key) -eq "OK" -and -not $dryRun) {
        Log "SKIP" "L1::$pillar déjà complété"; return $true
    }
    Log "STEP" "L1 — Collecte $pillar ($($PILLAR_NAMES[$pillar]))"
    $tStart = Get-Date

    $args = @("-3.12", "collectors\run_pipeline_sprint7.py", "--pillar", $pillar, "--collect")
    if ($dryRun) { $args += "--dry-run" }

    $exit = Run-Proc $PyExe $args "L1::$pillar"
    $elapsed = [math]::Round(((Get-Date) - $tStart).TotalSeconds, 1)

    if ($exit -eq 0) {
        if (-not $dryRun) { Set-CheckpointStep $key "OK" "${elapsed}s" }
        Log "OK" "L1::$pillar terminé en ${elapsed}s"
        return $true
    } else {
        if (-not $dryRun) { Set-CheckpointStep $key "KO" "exit $exit après ${elapsed}s" }
        Log "ERROR" "L1::$pillar ECHEC après ${elapsed}s (exit $exit)"
        return $false
    }
}

function Run-L2-Imputer($pillar, $dryRun) {
    $key = "L2::$pillar"
    if ((Get-StepStatus $key) -eq "OK" -and -not $dryRun) {
        Log "SKIP" "L2::$pillar déjà complété"; return $true
    }
    Log "STEP" "L2 — Imputation MICE $pillar ($($PILLAR_NAMES[$pillar]))"
    $tStart = Get-Date

    $args = @("-3.12", "collectors\imputer_v3.py", "--pillar", $pillar)
    if ($dryRun) { $args += "--dry-run" }

    $exit = Run-Proc $PyExe $args "L2::$pillar"
    $elapsed = [math]::Round(((Get-Date) - $tStart).TotalSeconds, 1)

    if ($exit -eq 0) {
        if (-not $dryRun) { Set-CheckpointStep $key "OK" "${elapsed}s" }
        Log "OK" "L2::$pillar terminé en ${elapsed}s"
        return $true
    } else {
        if (-not $dryRun) { Set-CheckpointStep $key "KO" "exit $exit après ${elapsed}s" }
        Log "ERROR" "L2::$pillar ECHEC après ${elapsed}s (exit $exit)"
        return $false
    }
}

function Run-L3-Normalize($yearFrom, $yearTo, $dryRun) {
    $key = "L3::${yearFrom}_${yearTo}"
    if ((Get-StepStatus $key) -eq "OK" -and -not $dryRun) {
        Log "SKIP" "L3 normalisation $yearFrom-$yearTo déjà complétée"; return $true
    }
    Log "STEP" "L3 — Normalisation + scores piliers + ISA ($yearFrom → $yearTo)"
    $tStart = Get-Date

    if ($dryRun) {
        Log "WARN" "[DRY-RUN] run_pipeline_historical($yearFrom, $yearTo) — non exécuté"
        return $true
    }

    # SQL via fichier temp — evite le decoupage par Start-Process
    $sqlFile = "$LogDir\l3_$RunId.sql"
    "CALL ma.run_pipeline_historical(${yearFrom}::smallint, ${yearTo}::smallint, 1);" | Set-Content $sqlFile -Encoding UTF8
    $args = @("-h", $DbHost, "-p", $DbPort, "-U", $DbUser, "-d", $DbName,
              "-v", "ON_ERROR_STOP=1", "-f", $sqlFile)

    $exit = Run-Proc $PsqlExe $args "L3"
    Remove-Item $sqlFile -ErrorAction SilentlyContinue
    $elapsed = [math]::Round(((Get-Date) - $tStart).TotalSeconds, 1)

    if ($exit -eq 0) {
        Set-CheckpointStep $key "OK" "${elapsed}s"
        Log "OK" "L3 normalisation terminée en ${elapsed}s"
        return $true
    } else {
        Set-CheckpointStep $key "KO" "exit $exit après ${elapsed}s"
        Log "ERROR" "L3 normalisation ECHEC (exit $exit) après ${elapsed}s"
        return $false
    }
}

function Run-AlertRefresh($dryRun) {
    if ($dryRun) { Log "WARN" "[DRY-RUN] Alert refresh — non exécuté"; return }
    Log "STEP" "Refresh vues materialisees ISA (AMAR, GENECO, scores piliers)"
    $tStart = Get-Date

    $sql = @"
BEGIN;
INSERT INTO mg.early_warning_alerts
    (country_iso3, year, risk_code, risk_band, risk_score,
     confidence_score, source_engine, public_narrative, created_at, updated_at)
SELECT country_iso3, year, risk_code, risk_band, risk_score,
       confidence_score, 'P7I-AMAR', public_narrative, NOW(), NOW()
FROM ma.v_p7i_amar_dashboard
ON CONFLICT (country_iso3, year, risk_code, source_engine)
DO UPDATE SET risk_band=EXCLUDED.risk_band, risk_score=EXCLUDED.risk_score,
              confidence_score=EXCLUDED.confidence_score,
              public_narrative=EXCLUDED.public_narrative, updated_at=NOW();

INSERT INTO mg.early_warning_alerts
    (country_iso3, year, risk_code, risk_band, risk_score,
     confidence_score, source_engine, public_narrative, created_at, updated_at)
SELECT country_iso3, year, risk_code, risk_band, risk_score,
       confidence_score, 'P7I-AMAR-GENECO',
       CASE WHEN risk_band='BLACK'  THEN 'Urgent conflict-economy exposure review required.'
            WHEN risk_band='RED'    THEN 'High conflict-economy exposure.'
            WHEN risk_band='ORANGE' THEN 'Elevated exposure: reinforced monitoring.'
            WHEN risk_band='YELLOW' THEN 'Watchlist exposure.'
            ELSE 'Low monitored exposure.' END,
       NOW(), NOW()
FROM ma.v_p7i_amar_geneco_dashboard
ON CONFLICT (country_iso3, year, risk_code, source_engine)
DO UPDATE SET risk_band=EXCLUDED.risk_band, risk_score=EXCLUDED.risk_score,
              confidence_score=EXCLUDED.confidence_score,
              public_narrative=EXCLUDED.public_narrative, updated_at=NOW();
COMMIT;
"@
    # SQL via fichier temp
    $sqlFile = "$LogDir\alert_refresh_$RunId.sql"
    $sql | Set-Content $sqlFile -Encoding UTF8
    $args = @("-h", $DbHost, "-p", $DbPort, "-U", $DbUser, "-d", $DbName,
              "-v", "ON_ERROR_STOP=1", "-f", $sqlFile)
    $exit = Run-Proc $PsqlExe $args "ALERT_REFRESH"
    Remove-Item $sqlFile -ErrorAction SilentlyContinue
    $elapsed = [math]::Round(((Get-Date) - $tStart).TotalSeconds, 1)

    if ($exit -eq 0) {
        Set-CheckpointStep "ALERT_REFRESH" "OK" "${elapsed}s"
        Log "OK" "Refresh vues materialisees terminé en ${elapsed}s"
    } else {
        Log "ERROR" "Alert refresh ECHEC (exit $exit)"
    }
}

function Run-Probe {
    Log "STEP" "Probe — couverture L1/L2/L3"
    $args = @("-3.12", "collectors\run_pipeline_sprint7.py", "--probe")
    Run-Proc $PyExe $args "PROBE" | Out-Null

    Log "STEP" "Couverture L1/L2/L3 par pilier"
    $sql = @"
SELECT i.pillar_code,
    COUNT(DISTINCT CASE WHEN v.layer_id=1 THEN v.indicator_code END) AS l1_ind,
    COUNT(DISTINCT CASE WHEN v.layer_id=2 THEN v.indicator_code END) AS l2_ind,
    COUNT(DISTINCT CASE WHEN v.layer_id=3 THEN v.indicator_code END) AS l3_ind,
    COUNT(CASE WHEN v.layer_id=1 THEN 1 END) AS l1_rows,
    COUNT(CASE WHEN v.layer_id=2 THEN 1 END) AS l2_rows,
    COUNT(CASE WHEN v.layer_id=3 THEN 1 END) AS l3_rows
FROM rf.indicators i
LEFT JOIN ma.indicator_values v ON v.indicator_code = i.code
WHERE i.is_active = TRUE
GROUP BY i.pillar_code ORDER BY i.pillar_code;
"@
    $sqlFile2 = "$LogDir\probe_$RunId.sql"
    $sql | Set-Content $sqlFile2 -Encoding UTF8
    $args2 = @("-h", $DbHost, "-p", $DbPort, "-U", $DbUser, "-d", $DbName, "-f", $sqlFile2)
    Run-Proc $PsqlExe $args2 "PROBE_L3" | Out-Null
    Remove-Item $sqlFile2 -ErrorAction SilentlyContinue
}

function Pick-Pillar {
    Write-Host ""; Write-Host "  Piliers :" -ForegroundColor White
    for ($i = 0; $i -lt $PILLARS.Count; $i++) {
        $p  = $PILLARS[$i]
        $l1 = Get-StepStatus "L1::$p"
        $l2 = Get-StepStatus "L2::$p"
        $ic = if ($l1 -eq "OK" -and $l2 -eq "OK") { "✓" } elseif ($l1 -eq "OK") { "~" } else { " " }
        Write-Host ("  [{0,2}]  {1} {2,-6}  {3,-35}  L1:{4,-8} L2:{5}" -f ($i+1),$ic,$p,$PILLAR_NAMES[$p],$l1,$l2)
    }
    Write-Host ""
    $idx = Read-Host "Numéro du pilier"
    return $PILLARS[[int]$idx - 1]
}

# ── MENU ─────────────────────────────────────────────────────────────────────

Log-Banner "OSA Observatory — run_full_pipeline.ps1 v3 | RunID: $RunId"
Log "INFO" "Log : $LogFile"

Write-Host ""
Write-Host "  Pipeline : L1 → L2 (MICE) → L3 (normalisation)" -ForegroundColor White
Write-Host "  Log      : $LogFile" -ForegroundColor DarkGray

Show-CheckpointSummary

Write-Host ""
Write-Host "  Actions :" -ForegroundColor White
Write-Host ""
Write-Host "  [1]  Pipeline complet — tous piliers  (L1 + L2 + L3 + alert refresh)" -ForegroundColor White
Write-Host "  [2]  Pipeline complet — pilier unique (L1 + L2 + L3)" -ForegroundColor White
Write-Host "  [3]  L1 collecte      — tous piliers" -ForegroundColor White
Write-Host "  [4]  L1 collecte      — pilier unique" -ForegroundColor White
Write-Host "  [5]  L2 imputation    — tous piliers" -ForegroundColor White
Write-Host "  [6]  L2 imputation    — pilier unique" -ForegroundColor White
Write-Host "  [7]  L3 mise a jour annuelle — 2021 a annee courante (usage normal)" -ForegroundColor White
Write-Host "  [8]  Refresh vues materialisees ISA (AMAR, GENECO, scores)" -ForegroundColor White
Write-Host "  [9]  Probe            — couverture L1/L2/L3" -ForegroundColor White
Write-Host "  [D]  Dry-run complet  — tous piliers (aucune ecriture)" -ForegroundColor White
Write-Host "  [H]  L3 historique complet — 2010 a 2024 (recalibration exceptionnelle)" -ForegroundColor Yellow
Write-Host "  [A]  Audit pipeline    — rapport qualite L1/L2/L3 + Excel" -ForegroundColor Cyan
Write-Host "  [R]  Reset checkpoint" -ForegroundColor Magenta
Write-Host ""
$choice = Read-Host "Votre choix"
Log "INFO" "Choix : $choice"

switch ($choice.ToUpper()) {

    "1" {
        Log-Banner "Pipeline complet — tous piliers"
        foreach ($pillar in $PILLARS) {
            Log-Section "$pillar — $($PILLAR_NAMES[$pillar])"
            Run-L1-Collect $pillar $false | Out-Null
            Run-L2-Imputer $pillar $false | Out-Null
        }
        $currentYear = (Get-Date).Year
        Run-L3-Normalize 2021 $currentYear $false | Out-Null
        Run-AlertRefresh $false
        Run-Probe
        Log "OK" "Pipeline complet terminé"
    }

    "2" {
        $pillar = Pick-Pillar
        Log-Banner "Pipeline complet — $pillar"
        Run-L1-Collect $pillar $false | Out-Null
        Run-L2-Imputer $pillar $false | Out-Null
        Run-L3-Normalize 2010 2024 $false | Out-Null
        Log "OK" "Pipeline $pillar terminé"
    }

    "3" {
        Log-Banner "L1 collecte — tous piliers"
        foreach ($pillar in $PILLARS) { Run-L1-Collect $pillar $false | Out-Null }
        Log "OK" "L1 tous piliers terminé"
    }

    "4" {
        $pillar = Pick-Pillar
        Log-Banner "L1 collecte — $pillar"
        Run-L1-Collect $pillar $false | Out-Null
    }

    "5" {
        Log-Banner "L2 imputation — tous piliers"
        foreach ($pillar in $PILLARS) { Run-L2-Imputer $pillar $false | Out-Null }
        Log "OK" "L2 tous piliers terminé"
    }

    "6" {
        $pillar = Pick-Pillar
        Log-Banner "L2 imputation — $pillar"
        Run-L2-Imputer $pillar $false | Out-Null
    }

    "7" {
        # Mise a jour annuelle — 2021 a annee courante
        # Les bornes 2010-2020 sont gelees dans rf.normalization_bounds v1_2026
        # Les annees 2010-2020 ne sont PAS recalculees
        $currentYear = (Get-Date).Year
        Log-Banner "L3 mise a jour annuelle (2021 -> $currentYear)"
        Log "INFO" "Bornes de reference : rf.normalization_bounds v1_2026 (gel 2010-2020)"
        Log "INFO" "Les annees 2010-2020 ne sont PAS recalculees (periode de reference stable)"
        Run-L3-Normalize 2021 $currentYear $false | Out-Null
    }

    "H" {
        # Recalibration historique complete — usage exceptionnel uniquement
        # A n'utiliser qu'en cas de changement de bornes ou de correction structurelle
        Log-Banner "L3 historique complet (2010 -> 2024) — EXCEPTIONNEL"
        Write-Host "  ATTENTION : Cette option recalcule toute la periode historique." -ForegroundColor Yellow
        Write-Host "  A utiliser uniquement pour une recalibration officielle." -ForegroundColor Yellow
        Write-Host "  Les scores 2010-2020 seront recalcules sur les bornes figees." -ForegroundColor Yellow
        Write-Host ""
        $confirm = Read-Host "Confirmer recalcul historique complet ? (oui/non)"
        if ($confirm -eq "oui") {
            $yearFrom = Read-Host "Annee debut (defaut 2010)"
            $yearTo   = Read-Host "Annee fin   (defaut 2024)"
            if (-not $yearFrom) { $yearFrom = 2010 }
            if (-not $yearTo)   { $yearTo   = 2024 }
            Log "INFO" "Recalcul historique $yearFrom -> $yearTo confirme"
            Run-L3-Normalize $yearFrom $yearTo $false | Out-Null
        } else {
            Log "INFO" "Recalibration historique annulee"
        }
    }

    "8" {
        Log-Banner "Refresh vues materialisees ISA"
        Run-AlertRefresh $false
    }

    "9" { Run-Probe }

    "D" {
        Log-Banner "Dry-run complet — tous piliers"
        Log "WARN" "Aucune écriture en base ni checkpoint"
        foreach ($pillar in $PILLARS) {
            Log-Section "$pillar"
            Run-L1-Collect $pillar $true | Out-Null
            Run-L2-Imputer $pillar $true | Out-Null
        }
        Run-L3-Normalize 2010 2024 $true | Out-Null
        Log "OK" "Dry-run terminé"
    }

    "R" {
        $confirm = Read-Host "Confirmer reset checkpoint ? (oui/non)"
        if ($confirm -eq "oui") {
            if (Test-Path $CheckpointFile) { Remove-Item $CheckpointFile }
            Log "OK" "Checkpoint réinitialisé"
        } else { Log "INFO" "Annulé" }
    }

    "A" {
        Log-Banner "Audit pipeline — qualite L1/L2/L3"
        $auditDate = Get-Date -Format "yyyyMMdd_HHmm"
        $auditExcel = "logs\audit_pipeline_$auditDate.xlsx"
        Log "STEP" "Audit pipeline en cours..."
        $auditArgs = @("-3.12", "collectors\audit_pipeline.py", "--detail", "--excel", $auditExcel)
        $exit = Run-Proc $PyExe $auditArgs "AUDIT"
        if (Test-Path $auditExcel) {
            Log "OK" "Rapport Excel : $auditExcel"
        }
    }

    default { Log "WARN" "Choix non reconnu : '$choice'" }
}

Log-Banner "Terminé | RunID: $RunId | Log : $LogFile"
Write-Host "  Log complet : $LogFile" -ForegroundColor DarkGray
Write-Host ""
