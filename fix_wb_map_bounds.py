"""Corrige les bornes min_valid/max_valid pour MON_IFF_PRESSURE et MON_GDP_CURRENT."""
from pathlib import Path

path = Path("collectors/fetcher_wb_pres_pmil_pnum.py")
content = path.read_text(encoding="utf-8")

# Fix 1 : MON_IFF_PRESSURE — bornes USD bruts (valeurs peuvent atteindre ±100 milliards)
old1 = '        "min_valid":            -100.0,\n        "max_valid":            100.0,\n        "requires_gdp_deflator": True,   # flag pour conversion % PIB'
new1 = '        "min_valid":            -5e12,\n        "max_valid":            5e12,\n        "requires_gdp_deflator": True,   # flag pour conversion % PIB'

# Fix 2 : MON_GDP_CURRENT — PIB Nigeria seul ~400 milliards, ZAF ~400 milliards
old2 = '        "min_valid":            0.0,\n        "max_valid":            1e9,'
new2 = '        "min_valid":            0.0,\n        "max_valid":            1e15,'

if old1 in content:
    content = content.replace(old1, new1, 1)
    print("OK — Fix 1 MON_IFF_PRESSURE bornes corrigées : -5e12 / +5e12")
else:
    print("WARN — Fix 1 pattern non trouvé")

# Fix 2 : cibler uniquement MON_GDP_CURRENT (max_valid=1e9 est unique à cet indicateur)
if old2 in content:
    content = content.replace(old2, new2, 1)
    print("OK — Fix 2 MON_GDP_CURRENT max_valid corrigée : 1e9 → 1e15")
else:
    print("WARN — Fix 2 pattern non trouvé")

path.write_text(content, encoding="utf-8")
print("Fichier sauvegardé.")
