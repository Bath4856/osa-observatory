"""
============================================================
OSA Observatory — collectors/wb_map_sprint8_patch.py
Sprint 8 — Mai 2026

Patch du WB_MAP de fetcher_wb_pres_pmil_pnum.py
Ajout de 3 nouveaux indicateurs :

  BN.KAC.EOMS.CD  → MON_IFF_PRESSURE  (PMON)
    Erreurs et omissions nettes BoP (USD courants)
    Proxy pression de fuite financière externe
    Direction − | Couverture 52/54 pays africains
    NOTE : valeur brute en USD — conversion % PIB dans le post-traitement
           via NY.GDP.MKTP.CD (ajouté ci-dessous)

  NY.GDP.MKTP.CD  → MON_GDP_CURRENT   (PMON — auxiliaire)
    PIB courant en USD — nécessaire pour conversion MON_IFF_PRESSURE
    Direction + | Déjà utilisé implicitement pour d'autres indicateurs

  GC.REV.XGRT.GD.ZS → ECO_PUBLIC_REV  (PECO)
    Recettes publiques hors dons (% PIB)
    Composante 2 de ECO_PUBLIC_LEAKAGE
    Direction + | Couverture 42/54 pays africains
    NOTE : GC.TAX.TOTL.GD.ZS (ECO_TAX) déjà dans le WB_MAP

Usage :
  python collectors/wb_map_sprint8_patch.py

Ce script applique le patch directement dans
fetcher_wb_pres_pmil_pnum.py par str_replace.
============================================================
"""
import re
from pathlib import Path

FETCHER_PATH = Path("collectors/fetcher_wb_pres_pmil_pnum.py")

# ── Entrées à ajouter dans le WB_MAP ─────────────────────────────────────────

NEW_ENTRIES = '''
    # ══════════════════════════════════════════════════════
    # PMON — Sprint 8 — MON_IFF_PRESSURE + auxiliaire PIB
    # ══════════════════════════════════════════════════════

    "BN.KAC.EOMS.CD": {
        "osa_code":             "MON_IFF_PRESSURE",
        "pillar":               "PMON",
        "name_fr":              "Pression de fuite financière externe (erreurs et omissions BoP % PIB)",
        "unit":                 "PCT_GDP",
        "direction":            "-",
        "multiplier":           1.0,
        # Valeur brute WB en USD courants — le fetcher divise par NY.GDP.MKTP.CD
        # pour obtenir le % PIB avant insertion L1.
        # Proxy comportemental : écart comptable BoP publié par le FMI.
        # Doctrine OSA : fait observable — pas de perception.
        # Publication : libellé "External Financial Leakage Pressure"
        # Couverture : 52/54 pays africains (SOM manquant)
        "imputation_regime":    "STANDARD",
        "has_structural_zeros": False,
        "is_composite_score":   False,
        "min_valid":            -100.0,
        "max_valid":            100.0,
        "requires_gdp_deflator": True,   # flag pour conversion % PIB
    },

    "NY.GDP.MKTP.CD": {
        "osa_code":             "MON_GDP_CURRENT",
        "pillar":               "PMON",
        "name_fr":              "PIB courant (USD) — auxiliaire conversion BoP",
        "unit":                 "USD_M",
        "direction":            "+",
        "multiplier":           1e-6,    # → millions USD
        # Indicateur auxiliaire — sert à convertir BN.KAC.EOMS.CD en % PIB.
        # Stocké en L1 pour traçabilité. Non exposé directement dans l'API.
        "imputation_regime":    "STANDARD",
        "has_structural_zeros": False,
        "is_composite_score":   False,
        "min_valid":            0.0,
        "max_valid":            1e9,
    },

    # ══════════════════════════════════════════════════════
    # PECO — Sprint 8 — ECO_PUBLIC_REV (composante ECO_PUBLIC_LEAKAGE)
    # GC.TAX.TOTL.GD.ZS (ECO_TAX) est déjà dans le WB_MAP
    # ══════════════════════════════════════════════════════

    "GC.REV.XGRT.GD.ZS": {
        "osa_code":             "ECO_PUBLIC_REV",
        "pillar":               "PECO",
        "name_fr":              "Recettes publiques hors dons (% PIB)",
        "unit":                 "PCT_GDP",
        "direction":            "+",
        # Composante 2 de ECO_PUBLIC_LEAKAGE.
        # ECO_TAX (GC.TAX.TOTL.GD.ZS) est déjà collecté.
        # ECO_PUBLIC_LEAKAGE = indicateur COMPUTED calculé en L3
        # depuis ECO_TAX et ECO_PUBLIC_REV.
        # Couverture : 42/54 pays africains (GO confirmé audit 19 mai 2026)
        "multiplier":           1.0,
        "imputation_regime":    "STANDARD",
        "has_structural_zeros": False,
        "is_composite_score":   False,
        "min_valid":            0.0,
        "max_valid":            100.0,
    },
'''

# ── Ancre d'insertion — juste avant la fermeture du WB_MAP ───────────────────
# On insère avant la ligne "# fin du WB_MAP" ou avant le "}"
# qui ferme le dictionnaire principal

ANCHOR = '    "FB.BNK.CAPA.ZS": {'

def apply_patch():
    content = FETCHER_PATH.read_text(encoding="utf-8")

    if "MON_IFF_PRESSURE" in content:
        print("⚠  Patch déjà appliqué — MON_IFF_PRESSURE déjà présent dans le WB_MAP.")
        return False

    if ANCHOR not in content:
        print(f"❌ Ancre non trouvée : {ANCHOR!r}")
        print("   Vérifiez que fetcher_wb_pres_pmil_pnum.py contient FB.BNK.CAPA.ZS")
        return False

    # Insérer les nouvelles entrées juste avant l'ancre FB.BNK.CAPA.ZS
    new_content = content.replace(ANCHOR, NEW_ENTRIES + "    " + '"FB.BNK.CAPA.ZS": {', 1)

    FETCHER_PATH.write_text(new_content, encoding="utf-8")
    print("✓  Patch appliqué dans fetcher_wb_pres_pmil_pnum.py")
    print("   Indicateurs ajoutés :")
    print("     BN.KAC.EOMS.CD  → MON_IFF_PRESSURE  (PMON)")
    print("     NY.GDP.MKTP.CD  → MON_GDP_CURRENT   (PMON — auxiliaire)")
    print("     GC.REV.XGRT.GD.ZS → ECO_PUBLIC_REV (PECO)")
    return True


def verify_patch():
    """Vérifie que les nouveaux indicateurs sont bien dans le WB_MAP."""
    content = FETCHER_PATH.read_text(encoding="utf-8")
    checks = [
        ("MON_IFF_PRESSURE",  "BN.KAC.EOMS.CD"),
        ("MON_GDP_CURRENT",   "NY.GDP.MKTP.CD"),
        ("ECO_PUBLIC_REV",    "GC.REV.XGRT.GD.ZS"),
    ]
    all_ok = True
    for osa_code, wb_code in checks:
        ok_osa = osa_code in content
        ok_wb  = wb_code in content
        status = "✓" if ok_osa and ok_wb else "✗"
        print(f"  {status}  {wb_code:30s} → {osa_code}")
        if not (ok_osa and ok_wb):
            all_ok = False
    return all_ok


if __name__ == "__main__":
    print("=" * 60)
    print("OSA Sprint 8 — WB_MAP patch")
    print("=" * 60)
    success = apply_patch()
    print()
    print("Vérification :")
    ok = verify_patch()
    if ok:
        print()
        print("Prochaine étape — dry-run :")
        print("  python collectors\\fetcher_wb_pres_pmil_pnum.py --pillar PMON --dry-run")
        print("  python collectors\\fetcher_wb_pres_pmil_pnum.py --pillar PECO --dry-run")
    else:
        print("❌ Vérification échouée — inspecter fetcher_wb_pres_pmil_pnum.py")
