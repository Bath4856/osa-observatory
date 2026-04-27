"""
patch_add_output_arg.py
═══════════════════════════════════════════════════════════════════════════
Ajoute l'argument --output aux fetchers qui ne l'ont pas
mais qui reçoivent --output both de l'orchestrateur.

Fetchers corrigés :
  fetcher_itu.py
  fetcher_who.py
  fetcher_acled_csv.py
  fetcher_unpk_csv.py
  fetcher_sipri_csv.py
  fetcher_unctad_csv.py
  fetcher_comtrade_api.py
  fetcher_imf.py

Stratégie : ajouter parser.add_argument("--output", ...) juste après
la ligne parser.add_argument("--dry-run", ...) dans chaque fetcher.
L'argument est accepté mais ignoré — le fetcher gère déjà son propre
mode de sortie via sa logique interne.

Usage :
  python patch_add_output_arg.py --dry-run
  python patch_add_output_arg.py
═══════════════════════════════════════════════════════════════════════════
"""

import argparse
import re
import shutil
from datetime import datetime
from pathlib import Path

PROJECT    = Path(__file__).resolve().parent
COLLECTORS = PROJECT / "collectors"
ARCHIVE    = COLLECTORS / "archive"

# Fetchers à corriger
TARGETS = [
    "fetcher_itu.py",
    "fetcher_who.py",
    "fetcher_acled_csv.py",
    "fetcher_unpk_csv.py",
    "fetcher_sipri_csv.py",
    "fetcher_unctad_csv.py",
    "fetcher_comtrade_api.py",
    "fetcher_imf.py",
    "fetcher_imf_bop_csv.py",
    "fetcher_imf_dots_csv.py",
    "fetcher_undp_csv.py",
    "fetcher_fao_csv.py",
    "fetcher_usgs_csv.py",
    "fetcher_wgi_csv.py",
    "fetcher_sipri_milex.py",
    "fetcher_eiti_csv.py",
]

# Ligne à insérer après --dry-run
OUTPUT_ARG = '    parser.add_argument("--output", choices=["csv", "db", "both"], default="both", help="Mode de sortie (ignoré — compatibilité orchestrateur)")\n'

# Patterns pour trouver la ligne --dry-run dans argparse
DRY_RUN_PATTERNS = [
    r'parser\.add_argument\(["\']--dry-run["\'].*\)\n',
    r'parser\.add_argument\(["\']--dry.run["\'].*\)\n',
]


def patch_file(path: Path, dry_run: bool) -> str:
    """
    Ajoute --output après --dry-run dans le fichier.
    Retourne le statut : 'PATCHED' | 'ALREADY' | 'NOT_FOUND' | 'NO_ARGPARSE'
    """
    content = path.read_text(encoding="utf-8", errors="ignore")

    # Déjà patché
    if '"--output"' in content or "'--output'" in content:
        return "ALREADY"

    # Pas d'argparse
    if "argparse" not in content:
        return "NO_ARGPARSE"

    # Chercher la ligne --dry-run
    for pattern in DRY_RUN_PATTERNS:
        match = re.search(pattern, content)
        if match:
            insert_pos  = match.end()
            new_content = content[:insert_pos] + OUTPUT_ARG + content[insert_pos:]

            if not dry_run:
                ARCHIVE.mkdir(exist_ok=True)
                ts  = datetime.now().strftime("%Y%m%d_%H%M%S")
                bak = ARCHIVE / f"{path.stem}_before_output_{ts}{path.suffix}"
                shutil.copy2(path, bak)
                path.write_text(new_content, encoding="utf-8")

            return "PATCHED"

    return "NOT_FOUND"


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Ajoute --output aux fetchers sans cet argument"
    )
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    print("=" * 55)
    print(f"  Patch --output | Mode : {'DRY-RUN' if args.dry_run else 'RÉEL'}")
    print("=" * 55)

    patched    = []
    already    = []
    not_found  = []
    absent     = []

    for name in TARGETS:
        path = COLLECTORS / name
        if not path.exists():
            absent.append(name)
            continue

        status = patch_file(path, args.dry_run)

        if status == "PATCHED":
            patched.append(name)
            print(f"  ✓ PATCHÉ  : {name}")
        elif status == "ALREADY":
            already.append(name)
            print(f"  · DÉJÀ    : {name}")
        elif status == "NOT_FOUND":
            not_found.append(name)
            print(f"  ? PAS TROUVÉ (--dry-run absent ?) : {name}")
        elif status == "NO_ARGPARSE":
            not_found.append(name)
            print(f"  ? PAS ARGPARSE : {name}")

    for name in absent:
        print(f"  - ABSENT  : {name}")

    print("=" * 55)
    print(f"  Patchés    : {len(patched)}")
    print(f"  Déjà OK    : {len(already)}")
    print(f"  Non trouvé : {len(not_found)}")
    print(f"  Absents    : {len(absent)}")

    if args.dry_run:
        print("\n  DRY-RUN — aucune modification.")
        print("  Relancez sans --dry-run pour appliquer.")
    else:
        print("\n  Relancez le pipeline :")
        print("  python launch_pipeline.py --mode dry-run")


if __name__ == "__main__":
    main()
