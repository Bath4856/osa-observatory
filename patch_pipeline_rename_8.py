"""
Renomme l'option [8] dans run_full_pipeline.ps1
Alert refresh AMAR + GENECO -> Refresh vues materialisees ISA
"""
from pathlib import Path

PS1 = Path("run_full_pipeline.ps1")
content = PS1.read_text(encoding="utf-8")

fixes = [
    # Menu
    ('Write-Host "  [8]  Alert refresh    — AMAR + GENECO" -ForegroundColor White',
     'Write-Host "  [8]  Refresh vues materialisees ISA (AMAR, GENECO, scores)" -ForegroundColor White'),
    # Banner dans le case
    ('Log-Banner "Alert refresh AMAR + GENECO"',
     'Log-Banner "Refresh vues materialisees ISA"'),
    # Log STEP dans Run-AlertRefresh
    ('Log "STEP" "Refresh alertes AMAR + GENECO"',
     'Log "STEP" "Refresh vues materialisees ISA (AMAR, GENECO, scores piliers)"'),
    # Log OK dans Run-AlertRefresh
    ('Log "OK" "Alert refresh termin',
     'Log "OK" "Refresh vues materialisees termin'),
]

for old, new in fixes:
    if old in content:
        content = content.replace(old, new, 1)
        print(f"OK — {old[:50]}...")
    else:
        print(f"WARN — non trouve : {old[:50]}...")

PS1.write_text(content, encoding="utf-8")
print(f"\nOK — {PS1} sauvegarde")
