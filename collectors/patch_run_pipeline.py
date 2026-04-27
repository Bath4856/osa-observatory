"""
patch_run_pipeline.py
═══════════════════════════════════════════════════════════════════════════
Corrige run_pipeline_sprint7.py :

  Problème : l'orchestrateur passe --output both à TOUS les fetchers.
  Les fetchers qui n'ont pas cet argument échouent avec :
    "error: unrecognized arguments: --output both"

  Solution : ne passer --output que aux fetchers qui l'acceptent.
  La liste est définie dans FETCHERS_WITH_OUTPUT ci-dessous.

Usage :
  python patch_run_pipeline.py --dry-run
  python patch_run_pipeline.py
═══════════════════════════════════════════════════════════════════════════
"""

import argparse
import shutil
from datetime import datetime
from pathlib import Path

PROJECT    = Path(__file__).resolve().parent
TARGET     = PROJECT / "collectors" / "run_pipeline_sprint7.py"
ARCHIVE    = PROJECT / "collectors" / "archive"

# Fetchers qui acceptent --output (vérifiés par Select-String add_argument.*output)
FETCHERS_WITH_OUTPUT = {
    "fetcher_wb_pres_pmil_pnum.py",
    "fetcher_egdi.py",
    "fetcher_wb_ptra.py",
    "fetcher_lpi.py",
    "fetcher_unctad.py",
}

# Ancien code à remplacer
OLD_CODE = '''    cmd = [PYTHON, str(script)] + extra_args + ["--output", output]
    if mode == "dry-run":
        cmd.append("--dry-run")'''

# Nouveau code : --output uniquement si le fetcher le supporte
NEW_CODE = '''    # N'envoyer --output que aux fetchers qui acceptent cet argument
    _fetchers_with_output = {
        "fetcher_wb_pres_pmil_pnum.py",
        "fetcher_egdi.py",
        "fetcher_wb_ptra.py",
        "fetcher_lpi.py",
        "fetcher_unctad.py",
    }
    cmd = [PYTHON, str(script)] + extra_args
    if fetcher in _fetchers_with_output:
        cmd += ["--output", output]
    if mode == "dry-run":
        cmd.append("--dry-run")'''


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    if not TARGET.exists():
        print(f"ERREUR : {TARGET} introuvable.")
        return

    content = TARGET.read_text(encoding="utf-8")

    # Vérifier si déjà patché
    if "_fetchers_with_output" in content:
        print("Patch déjà appliqué — rien à faire.")
        return

    # Vérifier que l'ancien code est bien présent
    if OLD_CODE not in content:
        print("ERREUR : pattern à remplacer introuvable dans run_pipeline_sprint7.py")
        print("Le fichier a peut-être déjà été modifié manuellement.")
        print("\nPattern cherché :")
        print(OLD_CODE)
        return

    new_content = content.replace(OLD_CODE, NEW_CODE, 1)

    print(f"Cible  : {TARGET}")
    print(f"Avant  : --output envoyé à TOUS les fetchers")
    print(f"Après  : --output envoyé uniquement à {len(FETCHERS_WITH_OUTPUT)} fetchers")
    print(f"  {', '.join(sorted(FETCHERS_WITH_OUTPUT))}")

    if args.dry_run:
        print("\nDRY-RUN — aucune modification.")
        return

    # Sauvegarde
    ARCHIVE.mkdir(exist_ok=True)
    ts  = datetime.now().strftime("%Y%m%d_%H%M%S")
    bak = ARCHIVE / f"run_pipeline_sprint7_before_patch_{ts}.py"
    shutil.copy2(TARGET, bak)
    print(f"Sauvegarde : {bak.name}")

    TARGET.write_text(new_content, encoding="utf-8")
    print("OK — run_pipeline_sprint7.py patché.")
    print("\nRelancez le probe pour vérifier :")
    print("  python collectors\\run_pipeline_sprint7.py --probe --dry-run")


if __name__ == "__main__":
    main()
