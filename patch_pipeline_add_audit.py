"""
OSA Observatory — patch_pipeline_add_audit.py
Ajoute l'option [A] Audit pipeline dans run_full_pipeline.ps1
"""
from pathlib import Path

PS1 = Path("run_full_pipeline.ps1")
content = PS1.read_text(encoding="utf-8")

# 1. Menu — ajouter [A] avant [R]
OLD_MENU = 'Write-Host "  [R]  Reset checkpoint" -ForegroundColor Magenta'
NEW_MENU = '''Write-Host "  [A]  Audit pipeline    — rapport qualite L1/L2/L3 + Excel" -ForegroundColor Cyan
Write-Host "  [R]  Reset checkpoint" -ForegroundColor Magenta'''

# 2. Switch — ajouter case [A] avant default
OLD_CASE = '    default { Log "WARN" "Choix non reconnu : \'$choice\'" }'
NEW_CASE = '''    "A" {
        Log-Banner "Audit pipeline — qualite L1/L2/L3"
        $auditDate = Get-Date -Format "yyyyMMdd_HHmm"
        $auditExcel = "logs\\audit_pipeline_$auditDate.xlsx"
        Log "STEP" "Audit pipeline en cours..."
        $auditArgs = @("-3.12", "collectors\\audit_pipeline.py", "--detail", "--excel", $auditExcel)
        $exit = Run-Proc $PyExe $auditArgs "AUDIT"
        if (Test-Path $auditExcel) {
            Log "OK" "Rapport Excel : $auditExcel"
        }
    }

    default { Log "WARN" "Choix non reconnu : '$choice'" }'''

ok1 = OLD_MENU in content
ok2 = OLD_CASE in content

if ok1:
    content = content.replace(OLD_MENU, NEW_MENU, 1)
    print("OK — menu [A] ajouté")
else:
    print("WARN — menu pattern non trouvé")

if ok2:
    content = content.replace(OLD_CASE, NEW_CASE, 1)
    print("OK — switch case [A] ajouté")
else:
    print("WARN — switch case pattern non trouvé")
    # Diagnostic
    idx = content.find("default { Log")
    print(repr(content[idx:idx+60]))

if ok1 or ok2:
    PS1.write_text(content, encoding="utf-8")
    print(f"OK — {PS1} sauvegardé (v4 + audit)")
