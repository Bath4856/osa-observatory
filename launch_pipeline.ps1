# ============================================================
# OSA Observatory — launch_pipeline.ps1
# Lance run_pipeline_sprint7.py en arrière-plan
# avec suivi en temps réel via fichier log.
#
# Usage :
#   .\launch_pipeline.ps1 -Mode probe
#   .\launch_pipeline.ps1 -Mode dry-run
#   .\launch_pipeline.ps1 -Mode collect
#   .\launch_pipeline.ps1 -Mode collect -Pillar PECO
#   .\launch_pipeline.ps1 -Mode resume
#   .\launch_pipeline.ps1 -Follow
#   .\launch_pipeline.ps1 -Status
#   .\launch_pipeline.ps1 -CheckpointStatus
#   .\launch_pipeline.ps1 -Stop
#   .\launch_pipeline.ps1 -Reset
# ============================================================

param(
    [ValidateSet("probe","dry-run","collect","resume","")]
    [string]$Mode = "",
    [string]$Pillar = "",
    [switch]$Follow,
    [switch]$Status,
    [switch]$CheckpointStatus,
    [switch]$Stop,
    [switch]$Reset
)

$ProjectDir = "G:\osa-observatory"
$LogDir     = "$ProjectDir\logs"
$LogFile    = "$LogDir\pipeline_sprint7.log"
$ErrFile    = "$LogDir\pipeline_sprint7_err.log"
$PidFile    = "$LogDir\pipeline_sprint7.pid"
$Python     = "python"
$Script     = "$ProjectDir\collectors\run_pipeline_sprint7.py"

if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir | Out-Null
}

# ── Status job en cours ───────────────────────────────────
if ($Status) {
    if (Test-Path $PidFile) {
        $pid_val = Get-Content $PidFile
        $proc = Get-Process -Id $pid_val -ErrorAction SilentlyContinue
        if ($proc) {
            Write-Host "✓ Pipeline en cours (PID $pid_val) — CPU: $($proc.CPU)s" -ForegroundColor Green
            Write-Host "  Log : $LogFile`n"
            Write-Host "Dernières lignes :" -ForegroundColor Cyan
            Get-Content $LogFile -Tail 15
        } else {
            Write-Host "✗ Pipeline terminé (PID $pid_val introuvable)" -ForegroundColor Yellow
            Remove-Item $PidFile -ErrorAction SilentlyContinue
            Write-Host "`nDernières lignes du log :" -ForegroundColor Cyan
            Get-Content $LogFile -Tail 10
        }
    } else {
        Write-Host "Aucun pipeline en cours." -ForegroundColor Gray
    }
    exit
}

# ── Checkpoint status ─────────────────────────────────────
if ($CheckpointStatus) {
    & $Python $Script --status
    exit
}

# ── Reset checkpoint ──────────────────────────────────────
if ($Reset) {
    & $Python $Script --reset
    exit
}

# ── Stop ──────────────────────────────────────────────────
if ($Stop) {
    if (Test-Path $PidFile) {
        $pid_val = Get-Content $PidFile
        $proc = Get-Process -Id $pid_val -ErrorAction SilentlyContinue
        if ($proc) {
            Stop-Process -Id $pid_val -Force
            Write-Host "✓ Pipeline arrêté (PID $pid_val)" -ForegroundColor Yellow
            Write-Host "  Pour reprendre : .\launch_pipeline.ps1 -Mode resume"
        } else {
            Write-Host "Pipeline déjà terminé." -ForegroundColor Gray
        }
        Remove-Item $PidFile -ErrorAction SilentlyContinue
    } else {
        Write-Host "Aucun pipeline en cours." -ForegroundColor Gray
    }
    exit
}

# ── Follow log ────────────────────────────────────────────
if ($Follow) {
    if (-not (Test-Path $LogFile)) {
        Write-Host "Aucun log trouvé : $LogFile" -ForegroundColor Yellow
        exit
    }
    Write-Host "Suivi temps réel — Ctrl+C pour arrêter" -ForegroundColor Cyan
    Write-Host "Log : $LogFile`n" -ForegroundColor Gray
    Get-Content $LogFile -Wait -Tail 20
    exit
}

# ── Aide ──────────────────────────────────────────────────
if ($Mode -eq "") {
    Write-Host @"
OSA Observatory — Pipeline Sprint 7

LANCER :
  .\launch_pipeline.ps1 -Mode probe                  Sonde la couverture L1
  .\launch_pipeline.ps1 -Mode dry-run                Simulation sans ecriture
  .\launch_pipeline.ps1 -Mode collect                Collecte complete (arriere-plan)
  .\launch_pipeline.ps1 -Mode collect -Pillar PECO   Un seul pilier
  .\launch_pipeline.ps1 -Mode resume                 Reprend depuis checkpoint

SUIVRE :
  .\launch_pipeline.ps1 -Follow              Log temps reel (Ctrl+C pour quitter)
  .\launch_pipeline.ps1 -Status              Etat du job en cours
  .\launch_pipeline.ps1 -CheckpointStatus    Avancement detaille par fetcher

CONTRÔLER :
  .\launch_pipeline.ps1 -Stop                Arreter le pipeline
  .\launch_pipeline.ps1 -Reset               Effacer checkpoint (repartir de zero)
"@
    exit
}

# ── Verifier si pipeline tourne ───────────────────────────
if (Test-Path $PidFile) {
    $pid_val = Get-Content $PidFile
    $proc = Get-Process -Id $pid_val -ErrorAction SilentlyContinue
    if ($proc) {
        Write-Host "⚠ Un pipeline tourne deja (PID $pid_val)." -ForegroundColor Yellow
        Write-Host "  -Status | -Stop | -Mode resume"
        exit 1
    }
    Remove-Item $PidFile -ErrorAction SilentlyContinue
}

# ── Construire args Python ────────────────────────────────
$PyArgs = @($Script)
switch ($Mode) {
    "probe"   { $PyArgs += "--probe" }
    "dry-run" { $PyArgs += "--dry-run" }
    "collect" { $PyArgs += "--collect" }
    "resume"  { $PyArgs += "--resume" }
}
if ($Pillar -ne "") {
    $PyArgs += "--pillar"
    $PyArgs += $Pillar
}

# ── Timestamp dans log ────────────────────────────────────
$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
"" | Out-File $LogFile -Append
"============================================================" | Out-File $LogFile -Append
"OSA Pipeline Sprint 7 — $Timestamp" | Out-File $LogFile -Append
"Mode : $Mode$(if ($Pillar) { ' | Pilier : ' + $Pillar })" | Out-File $LogFile -Append
"============================================================" | Out-File $LogFile -Append

# ── Lancer en arriere-plan ────────────────────────────────
Write-Host "Lancement pipeline en arriere-plan..." -ForegroundColor Cyan
Write-Host "  Mode : $Mode$(if ($Pillar) { ' | Pilier : ' + $Pillar })"
Write-Host "  Log  : $LogFile`n"

$proc = Start-Process `
    -FilePath $Python `
    -ArgumentList $PyArgs `
    -WorkingDirectory $ProjectDir `
    -RedirectStandardOutput $LogFile `
    -RedirectStandardError $ErrFile `
    -WindowStyle Hidden `
    -PassThru

$proc.Id | Out-File $PidFile

Write-Host "✓ Pipeline lance (PID $($proc.Id))" -ForegroundColor Green
Write-Host ""
Write-Host "Commandes :" -ForegroundColor Cyan
Write-Host "  .\launch_pipeline.ps1 -Follow              log temps reel"
Write-Host "  .\launch_pipeline.ps1 -Status              etat du job"
Write-Host "  .\launch_pipeline.ps1 -CheckpointStatus    avancement par fetcher"
Write-Host "  .\launch_pipeline.ps1 -Stop                arreter"
Write-Host "  .\launch_pipeline.ps1 -Mode resume         reprendre apres arret"