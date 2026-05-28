# =============================================================================
# OSA Observatory -- Patch restart_v2.ps1
# Ajoute l'option [S] Audit securite API
# Executer depuis G:\osa-observatory
# =============================================================================

$RepoRoot = "G:\osa-observatory"
$Target   = "$RepoRoot\restart_v2.ps1"

$content = Get-Content $Target -Raw

# -- 1. Ajouter [S] dans le menu ---------------------------------------------
$menuOld = '  Write-Host "  [9]  Audit colonnes P7I source" -ForegroundColor White'
$menuNew = '  Write-Host "  [9]  Audit colonnes P7I source" -ForegroundColor White
  Write-Host "  [S]  Audit securite API         -- 63 endpoints JWT" -ForegroundColor Cyan'

if ($content -notmatch '\[S\]') {
    $content = $content.Replace($menuOld, $menuNew)
    Write-Host "OK : [S] ajoute dans le menu" -ForegroundColor Green
} else {
    Write-Host "INFO : [S] deja present dans le menu" -ForegroundColor Yellow
}

# -- 2. Ajouter le case "S" apres le case "9" --------------------------------
$caseOld = @'
    "9" {
        Write-Header "Audit colonnes P7I source"
        Run-Psql "audit/list_p7i_source_columns.sql" -Audit
    }
'@

$caseNew = @'
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
'@

if ($content -notmatch '"S"') {
    $content = $content.Replace($caseOld, $caseNew)
    Write-Host "OK : case S ajoute dans le switch" -ForegroundColor Green
} else {
    Write-Host "INFO : case S deja present dans le switch" -ForegroundColor Yellow
}

# -- 3. Sauvegarder ----------------------------------------------------------
Set-Content $Target $content -Encoding UTF8
Write-Host ""
Write-Host "restart_v2.ps1 mis a jour." -ForegroundColor Green
Write-Host "Option [S] disponible au prochain lancement."
