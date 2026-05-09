"""
inject_imputer_patches.py
Injecte le contenu de imputer_ptra_patch.py et imputer_sprint6_patch.py
dans collectors/imputer_v3.py, juste avant le bloc if __name__ == "__main__".

Usage :
  python inject_imputer_patches.py --dry-run
  python inject_imputer_patches.py
"""

import argparse
import shutil
from datetime import datetime
from pathlib import Path

PROJECT  = Path(__file__).resolve().parent
TARGET   = PROJECT / "collectors" / "imputer_v3.py"
PATCH1   = PROJECT / "collectors" / "imputer_ptra_patch.py"
PATCH2   = PROJECT / "collectors" / "imputer_sprint6_patch.py"
ARCHIVE  = PROJECT / "collectors" / "archive"


def extract_code(patch_path: Path) -> str:
    """Lit le patch et retire les lignes de commentaire d'en-tête (# ==)."""
    lines  = patch_path.read_text(encoding="utf-8").splitlines()
    result = []
    header_done = False
    for line in lines:
        if not header_done and line.startswith("# ="):
            continue
        if not header_done and line.strip() == "":
            continue
        header_done = True
        result.append(line)
    return "\n".join(result)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    for p in (TARGET, PATCH1, PATCH2):
        if not p.exists():
            print(f"ERREUR : introuvable → {p}")
            return

    target_content = TARGET.read_text(encoding="utf-8")

    # Vérifier ce qui est déjà présent
    already = []
    for marker in ["is_ptra_indicator", "step_ptra_imputation",
                   "normalize_score", "LANDLOCKED_AFRICA",
                   "COMPOSITE_SCORE_INDICATORS", "BIANNUAL_INDICATORS"]:
        if marker in target_content:
            already.append(marker)

    if already:
        print(f"Déjà présent dans imputer_v3.py : {already}")
        print("Aucune injection nécessaire.")
        return

    # Construire le bloc à insérer
    bloc = "\n\n"
    bloc += "# " + "=" * 60 + "\n"
    bloc += "# Patch PTRA (imputer_ptra_patch.py — Sprint 5)\n"
    bloc += "# " + "=" * 60 + "\n"
    bloc += extract_code(PATCH1)
    bloc += "\n\n"
    bloc += "# " + "=" * 60 + "\n"
    bloc += "# Patch Sprint 6 (imputer_sprint6_patch.py)\n"
    bloc += "# " + "=" * 60 + "\n"
    bloc += extract_code(PATCH2)
    bloc += "\n"

    # Point d'insertion : juste avant if __name__ == "__main__"
    marker = 'if __name__ == "__main__"'
    if marker in target_content:
        idx = target_content.index(marker)
        new_content = target_content[:idx] + bloc + target_content[idx:]
        insert_point = "avant if __name__"
    else:
        # Fallback : fin de fichier
        new_content = target_content + bloc
        insert_point = "fin de fichier"

    print(f"Injection prévue : {insert_point}")
    print(f"  + {PATCH1.name} ({len(extract_code(PATCH1).splitlines())} lignes)")
    print(f"  + {PATCH2.name} ({len(extract_code(PATCH2).splitlines())} lignes)")
    print(f"  imputer_v3.py : {len(target_content.splitlines())} → "
          f"{len(new_content.splitlines())} lignes")

    if args.dry_run:
        print("\nDRY-RUN — aucune modification.")
        return

    # Backup
    ARCHIVE.mkdir(exist_ok=True)
    ts  = datetime.now().strftime("%Y%m%d_%H%M%S")
    bak = ARCHIVE / f"imputer_v3_before_patch_{ts}.py"
    shutil.copy2(TARGET, bak)
    print(f"Sauvegarde : {bak.name}")

    TARGET.write_text(new_content, encoding="utf-8")
    print(f"OK — imputer_v3.py mis à jour.")


if __name__ == "__main__":
    main()
