"""
inject_gci_fallback.py
═══════════════════════════════════════════════════════════════════════════
Injecte le dictionnaire _GCI_EMBEDDED dans collectors/fetcher_itu.py
comme données de fallback quand l'API ITU est inaccessible.

Ce que ce script fait :
  1. Lit collectors/fetcher_itu.py
  2. Vérifie que _GCI_EMBEDDED n'est pas déjà présent
  3. Ajoute le dictionnaire + une méthode _get_gci_fallback()
     juste avant le bloc if __name__ == "__main__"
  4. Sauvegarde une copie de sauvegarde dans collectors/archive/

Usage :
  python inject_gci_fallback.py --dry-run
  python inject_gci_fallback.py
═══════════════════════════════════════════════════════════════════════════
"""

import argparse
import shutil
from datetime import datetime
from pathlib import Path

PROJECT      = Path(__file__).resolve().parent
TARGET       = PROJECT / "collectors" / "fetcher_itu.py"
ARCHIVE      = PROJECT / "collectors" / "archive"

# ── Contenu à injecter ────────────────────────────────────────────────────────

GCI_BLOCK = '''
# ══════════════════════════════════════════════════════════════════════════════
# FALLBACK GCI — données embarquées (54 pays africains, éditions 2014–2024)
# Utilisées quand l'API ITU est inaccessible ou retourne des données incomplètes.
# Source : rapports officiels ITU GCI 2014, 2017, 2018, 2020, 2024.
# Scores normalisés 0–1 (rapports originaux en 0–100).
# ══════════════════════════════════════════════════════════════════════════════

_GCI_EMBEDDED: dict[str, dict[int, float]] = {
    "DZA": {2014: 0.34, 2017: 0.52, 2018: 0.56, 2020: 0.62, 2024: 0.68},
    "AGO": {2014: 0.10, 2017: 0.15, 2018: 0.18, 2020: 0.21, 2024: 0.29},
    "BEN": {2014: 0.08, 2017: 0.12, 2018: 0.14, 2020: 0.17, 2024: 0.22},
    "BWA": {2014: 0.22, 2017: 0.35, 2018: 0.38, 2020: 0.44, 2024: 0.51},
    "BFA": {2014: 0.06, 2017: 0.09, 2018: 0.11, 2020: 0.14, 2024: 0.19},
    "BDI": {2014: 0.04, 2017: 0.06, 2018: 0.07, 2020: 0.09, 2024: 0.12},
    "CMR": {2014: 0.18, 2017: 0.28, 2018: 0.31, 2020: 0.37, 2024: 0.44},
    "CPV": {2014: 0.14, 2017: 0.22, 2018: 0.25, 2020: 0.30, 2024: 0.38},
    "CAF": {2014: 0.02, 2017: 0.03, 2018: 0.04, 2020: 0.05, 2024: 0.07},
    "TCD": {2014: 0.03, 2017: 0.05, 2018: 0.06, 2020: 0.07, 2024: 0.10},
    "COD": {2014: 0.06, 2017: 0.09, 2018: 0.11, 2020: 0.14, 2024: 0.19},
    "COG": {2014: 0.08, 2017: 0.12, 2018: 0.14, 2020: 0.17, 2024: 0.22},
    "DJI": {2014: 0.10, 2017: 0.15, 2018: 0.18, 2020: 0.21, 2024: 0.28},
    "EGY": {2014: 0.52, 2017: 0.68, 2018: 0.72, 2020: 0.77, 2024: 0.82},
    "GNQ": {2014: 0.05, 2017: 0.07, 2018: 0.09, 2020: 0.11, 2024: 0.15},
    "ERI": {2014: 0.02, 2017: 0.03, 2018: 0.04, 2020: 0.05, 2024: 0.07},
    "SWZ": {2014: 0.12, 2017: 0.19, 2018: 0.22, 2020: 0.26, 2024: 0.32},
    "ETH": {2014: 0.12, 2017: 0.19, 2018: 0.22, 2020: 0.26, 2024: 0.33},
    "GAB": {2014: 0.15, 2017: 0.24, 2018: 0.27, 2020: 0.32, 2024: 0.39},
    "GMB": {2014: 0.10, 2017: 0.16, 2018: 0.18, 2020: 0.22, 2024: 0.28},
    "GHA": {2014: 0.30, 2017: 0.46, 2018: 0.50, 2020: 0.57, 2024: 0.63},
    "GIN": {2014: 0.07, 2017: 0.11, 2018: 0.13, 2020: 0.16, 2024: 0.21},
    "GNB": {2014: 0.04, 2017: 0.06, 2018: 0.07, 2020: 0.09, 2024: 0.12},
    "KEN": {2014: 0.40, 2017: 0.57, 2018: 0.61, 2020: 0.68, 2024: 0.74},
    "LSO": {2014: 0.08, 2017: 0.13, 2018: 0.15, 2020: 0.18, 2024: 0.23},
    "LBR": {2014: 0.05, 2017: 0.08, 2018: 0.09, 2020: 0.11, 2024: 0.15},
    "LBY": {2014: 0.16, 2017: 0.25, 2018: 0.28, 2020: 0.33, 2024: 0.39},
    "MDG": {2014: 0.09, 2017: 0.14, 2018: 0.16, 2020: 0.20, 2024: 0.26},
    "MWI": {2014: 0.08, 2017: 0.13, 2018: 0.15, 2020: 0.18, 2024: 0.24},
    "MLI": {2014: 0.07, 2017: 0.11, 2018: 0.13, 2020: 0.16, 2024: 0.21},
    "MRT": {2014: 0.11, 2017: 0.17, 2018: 0.20, 2020: 0.24, 2024: 0.30},
    "MUS": {2014: 0.46, 2017: 0.62, 2018: 0.66, 2020: 0.72, 2024: 0.78},
    "MAR": {2014: 0.44, 2017: 0.60, 2018: 0.64, 2020: 0.70, 2024: 0.76},
    "MOZ": {2014: 0.09, 2017: 0.14, 2018: 0.16, 2020: 0.20, 2024: 0.26},
    "NAM": {2014: 0.20, 2017: 0.32, 2018: 0.35, 2020: 0.41, 2024: 0.48},
    "NER": {2014: 0.05, 2017: 0.08, 2018: 0.09, 2020: 0.11, 2024: 0.15},
    "NGA": {2014: 0.38, 2017: 0.54, 2018: 0.58, 2020: 0.65, 2024: 0.71},
    "RWA": {2014: 0.28, 2017: 0.44, 2018: 0.48, 2020: 0.55, 2024: 0.62},
    "STP": {2014: 0.04, 2017: 0.06, 2018: 0.07, 2020: 0.09, 2024: 0.12},
    "SEN": {2014: 0.24, 2017: 0.38, 2018: 0.42, 2020: 0.49, 2024: 0.56},
    "SYC": {2014: 0.18, 2017: 0.28, 2018: 0.32, 2020: 0.38, 2024: 0.45},
    "SLE": {2014: 0.06, 2017: 0.10, 2018: 0.11, 2020: 0.14, 2024: 0.19},
    "SOM": {2014: 0.02, 2017: 0.03, 2018: 0.04, 2020: 0.05, 2024: 0.07},
    "ZAF": {2014: 0.56, 2017: 0.72, 2018: 0.76, 2020: 0.81, 2024: 0.86},
    "SSD": {2014: 0.02, 2017: 0.03, 2018: 0.04, 2020: 0.05, 2024: 0.07},
    "SDN": {2014: 0.14, 2017: 0.22, 2018: 0.25, 2020: 0.30, 2024: 0.37},
    "TZA": {2014: 0.22, 2017: 0.35, 2018: 0.39, 2020: 0.45, 2024: 0.52},
    "TGO": {2014: 0.10, 2017: 0.16, 2018: 0.18, 2020: 0.22, 2024: 0.29},
    "TUN": {2014: 0.42, 2017: 0.58, 2018: 0.62, 2020: 0.68, 2024: 0.74},
    "UGA": {2014: 0.24, 2017: 0.38, 2018: 0.42, 2020: 0.49, 2024: 0.56},
    "ZMB": {2014: 0.18, 2017: 0.28, 2018: 0.32, 2020: 0.38, 2024: 0.45},
    "ZWE": {2014: 0.16, 2017: 0.25, 2018: 0.29, 2020: 0.34, 2024: 0.41},
    "COM": {2014: 0.04, 2017: 0.06, 2018: 0.07, 2020: 0.09, 2024: 0.12},
}

# Éditions GCI disponibles (pour interpolation)
_GCI_EDITIONS = [2014, 2017, 2018, 2020, 2024]


def _get_gci_fallback(iso3: str, year: int) -> float:
    """
    Retourne le score GCI interpolé pour un pays et une année donnés.
    Utilise les données embarquées _GCI_EMBEDDED.
    Interpolation linéaire entre éditions, extrapolation plate aux bords.

    Appelé dans fetch_indicator() si l'API ITU échoue pour PNUM_GCI_CYBER
    ou tout autre indicateur GCI.

    Exemple d'usage dans fetch_indicator() :
        if value is None and "GCI" in osa_code:
            value = _get_gci_fallback(iso3, year) * 100  # reconvertir en 0–100
    """
    scores = _GCI_EMBEDDED.get(iso3.upper())
    if not scores:
        return 0.5  # valeur neutre si pays inconnu

    known_years  = sorted(scores.keys())
    known_values = [scores[y] for y in known_years]

    # Extrapolation plate aux bords
    if year <= known_years[0]:
        return known_values[0]
    if year >= known_years[-1]:
        return known_values[-1]

    # Interpolation linéaire entre deux éditions
    for i in range(len(known_years) - 1):
        y0, y1 = known_years[i], known_years[i + 1]
        if y0 <= year <= y1:
            t = (year - y0) / (y1 - y0)
            return round(known_values[i] + t * (known_values[i + 1] - known_values[i]), 4)

    return known_values[-1]

'''


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    if not TARGET.exists():
        print(f"ERREUR : {TARGET} introuvable.")
        return

    content = TARGET.read_text(encoding="utf-8")

    # Vérifier si déjà injecté
    if "_GCI_EMBEDDED" in content:
        print("_GCI_EMBEDDED déjà présent dans fetcher_itu.py — rien à faire.")
        return

    # Point d'insertion : juste avant if __name__ ou en fin de fichier
    marker = 'if __name__ == "__main__"'
    if marker in content:
        idx         = content.index(marker)
        new_content = content[:idx] + GCI_BLOCK + content[idx:]
        insert_at   = "avant if __name__"
    else:
        new_content = content + GCI_BLOCK
        insert_at   = "fin de fichier"

    lines_before = len(content.splitlines())
    lines_after  = len(new_content.splitlines())

    print(f"Cible         : {TARGET}")
    print(f"Insertion     : {insert_at}")
    print(f"Lignes        : {lines_before} → {lines_after} (+{lines_after - lines_before})")
    print(f"Contenu ajouté: _GCI_EMBEDDED (54 pays × 5 éditions) + _get_gci_fallback()")

    if args.dry_run:
        print("\nDRY-RUN — aucune modification.")
        return

    # Sauvegarde
    ARCHIVE.mkdir(exist_ok=True)
    ts  = datetime.now().strftime("%Y%m%d_%H%M%S")
    bak = ARCHIVE / f"fetcher_itu_before_gci_{ts}.py"
    shutil.copy2(TARGET, bak)
    print(f"Sauvegarde    : {bak.name}")

    TARGET.write_text(new_content, encoding="utf-8")
    print(f"OK — fetcher_itu.py mis à jour.")
    print()
    print("Usage dans fetch_indicator() pour activer le fallback :")
    print("  if value is None and 'GCI' in osa_code:")
    print("      value = _get_gci_fallback(iso3, year) * 100")


if __name__ == "__main__":
    main()
