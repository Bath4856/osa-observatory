"""
OSA Observatory — patch_pipeline_v4.py
Modifie run_full_pipeline.ps1 pour séparer :
  [7]  L3 mise à jour annuelle — 2021 → année courante (usage normal)
  [H]  L3 historique complet  — 2010 → 2024 (recalibration exceptionnelle)
"""
from pathlib import Path

PS1 = Path("run_full_pipeline.ps1")
content = PS1.read_text(encoding="utf-8")

# ── 1. Menu : remplacer [7] et ajouter [H] ───────────────────────────────────

OLD_MENU = '''Write-Host "  [7]  L3 normalisation — run_pipeline_historical" -ForegroundColor White
Write-Host "  [8]  Alert refresh    — AMAR + GENECO" -ForegroundColor White
Write-Host "  [9]  Probe            — couverture L1/L2/L3" -ForegroundColor White
Write-Host "  [D]  Dry-run complet  — tous piliers (aucune écriture)" -ForegroundColor White
Write-Host "  [R]  Reset checkpoint" -ForegroundColor Magenta'''

NEW_MENU = '''Write-Host "  [7]  L3 mise a jour annuelle — 2021 a annee courante (usage normal)" -ForegroundColor White
Write-Host "  [8]  Alert refresh    — AMAR + GENECO" -ForegroundColor White
Write-Host "  [9]  Probe            — couverture L1/L2/L3" -ForegroundColor White
Write-Host "  [D]  Dry-run complet  — tous piliers (aucune ecriture)" -ForegroundColor White
Write-Host "  [H]  L3 historique complet — 2010 a 2024 (recalibration exceptionnelle)" -ForegroundColor Yellow
Write-Host "  [R]  Reset checkpoint" -ForegroundColor Magenta'''

# ── 2. Switch case [7] : remplacer par mise à jour annuelle ──────────────────

OLD_CASE_7 = '''    "7" {
        Log-Banner "L3 normalisation"
        $yearFrom = Read-Host "Année début (défaut 2010)"
        $yearTo   = Read-Host "Année fin   (défaut 2024)"
        if (-not $yearFrom) { $yearFrom = 2010 }
        if (-not $yearTo)   { $yearTo   = 2024 }
        Run-L3-Normalize $yearFrom $yearTo $false | Out-Null
    }'''

NEW_CASE_7 = '''    "7" {
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
    }'''

# ── 3. Option [1] pipeline complet : utiliser mise à jour annuelle ───────────

OLD_CASE_1_L3 = '        Run-L3-Normalize 2010 2024 $false | Out-Null\n        Run-AlertRefresh $false'
NEW_CASE_1_L3 = '        $currentYear = (Get-Date).Year\n        Run-L3-Normalize 2021 $currentYear $false | Out-Null\n        Run-AlertRefresh $false'

OLD_CASE_2_L3 = '        Run-L3-Normalize 2010 2024 $false | Out-Null\n        Log "OK" "Pipeline $pillar termine"'
NEW_CASE_2_L3 = '        $currentYear = (Get-Date).Year\n        Run-L3-Normalize 2021 $currentYear $false | Out-Null\n        Log "OK" "Pipeline $pillar termine"'

OLD_DRYRUN_L3 = '        Run-L3-Normalize 2010 2024 $true | Out-Null\n        Log "OK" "Dry-run termine"'
NEW_DRYRUN_L3 = '        $currentYear = (Get-Date).Year\n        Run-L3-Normalize 2021 $currentYear $true | Out-Null\n        Log "OK" "Dry-run termine"'

# Appliquer les corrections
fixes = [
    (OLD_MENU,      NEW_MENU,      "Menu [7]+[H]"),
    (OLD_CASE_7,    NEW_CASE_7,    "Switch case [7]+[H]"),
    (OLD_CASE_1_L3, NEW_CASE_1_L3, "Case [1] L3 annuelle"),
    (OLD_CASE_2_L3, NEW_CASE_2_L3, "Case [2] L3 annuelle"),
    (OLD_DRYRUN_L3, NEW_DRYRUN_L3, "Case [D] L3 annuelle"),
]

for old, new, label in fixes:
    if old in content:
        content = content.replace(old, new, 1)
        print(f"OK — {label}")
    else:
        print(f"WARN — {label} : pattern non trouve")

PS1.write_text(content, encoding="utf-8")
print(f"\nOK — {PS1} sauvegarde (v4)")
print()
print("Doctrine OSA implementee :")
print("  [7] L3 mise a jour annuelle : 2021 -> annee courante (usage normal)")
print("  [H] L3 historique complet   : 2010 -> 2024 (recalibration exceptionnelle, confirmation requise)")
print("  [1][2][D] utilisent desormais L3 annuelle par defaut")
