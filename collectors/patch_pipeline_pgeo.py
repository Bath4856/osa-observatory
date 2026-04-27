"""
patch_pipeline_pgeo.py
═══════════════════════════════════════════════════════════════════════════
Applique deux corrections à run_pipeline_sprint7.py :

  1. Ajoute fetcher_pgeo_wikipedia.py au pilier PGEO dans PILLAR_JOBS
     avec le flag --skip-if-populated (ne re-scrape pas si déjà peuplé)

  2. Ajoute fetcher_pgeo_wikipedia.py à la liste FETCHERS_WITH_OUTPUT
     (si patch_run_pipeline.py a déjà été appliqué)

Prérequis :
  - pmin_schema.sql doit avoir été exécuté sur la base
  - fetcher_pgeo_wikipedia.py doit être présent dans collectors/

Usage :
  python patch_pipeline_pgeo.py --dry-run
  python patch_pipeline_pgeo.py
═══════════════════════════════════════════════════════════════════════════
"""

import argparse
import shutil
from datetime import datetime
from pathlib import Path

PROJECT = Path(__file__).resolve().parent
TARGET  = PROJECT / "collectors" / "run_pipeline_sprint7.py"
ARCHIVE = PROJECT / "collectors" / "archive"

# ── Patch 1 : ajouter fetcher_pgeo_wikipedia.py au pilier PGEO ───────────────

OLD_PGEO = '''    "PGEO": [
        ("fetcher_wb_pres_pmil_pnum.py", ["--pillar", "PGEO"]),
        ("fetcher_wgi_csv.py",           []),           # GEO_RSK/STAB WGI natif CSV
        ("fetcher_acled_csv.py",         []),           # GEO conflits ACLED CSV
        ("fetcher_unpk_csv.py",          []),           # GEO_PEA UNPK CSV
    ],'''

NEW_PGEO = '''    "PGEO": [
        ("fetcher_wb_pres_pmil_pnum.py", ["--pillar", "PGEO"]),
        ("fetcher_wgi_csv.py",           []),           # GEO_RSK/STAB WGI natif CSV
        ("fetcher_acled_csv.py",         []),           # GEO conflits ACLED CSV
        ("fetcher_unpk_csv.py",          []),           # GEO_PEA UNPK CSV
        ("fetcher_pgeo_wikipedia.py",    ["--skip-if-populated"]),  # sites miniers Wikipedia
    ],'''

# ── Patch 2 : ajouter pgeo_wikipedia à _fetchers_with_output ────────────────
# (seulement si patch_run_pipeline.py a déjà été appliqué)

OLD_OUTPUT_SET = '''    _fetchers_with_output = {
        "fetcher_wb_pres_pmil_pnum.py",
        "fetcher_egdi.py",
        "fetcher_wb_ptra.py",
        "fetcher_lpi.py",
        "fetcher_unctad.py",
    }'''

NEW_OUTPUT_SET = '''    _fetchers_with_output = {
        "fetcher_wb_pres_pmil_pnum.py",
        "fetcher_egdi.py",
        "fetcher_wb_ptra.py",
        "fetcher_lpi.py",
        "fetcher_unctad.py",
        "fetcher_pgeo_wikipedia.py",
    }'''


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    if not TARGET.exists():
        print(f"ERREUR : {TARGET} introuvable.")
        return

    # Vérifier que fetcher_pgeo_wikipedia.py est présent
    pgeo_fetcher = PROJECT / "collectors" / "fetcher_pgeo_wikipedia.py"
    if not pgeo_fetcher.exists():
        print(f"ERREUR : fetcher_pgeo_wikipedia.py absent dans collectors/")
        print("  → Copiez-le d'abord dans collectors/ puis relancez.")
        return

    content = TARGET.read_text(encoding="utf-8")

    # Vérifier si déjà patché
    if "fetcher_pgeo_wikipedia.py" in content:
        print("fetcher_pgeo_wikipedia.py déjà présent dans PILLAR_JOBS — rien à faire.")
        return

    # Appliquer patch 1 : PGEO jobs
    if OLD_PGEO not in content:
        print("ERREUR : bloc PGEO introuvable dans PILLAR_JOBS.")
        print("Le fichier a peut-être été modifié. Vérifiez manuellement.")
        return

    new_content = content.replace(OLD_PGEO, NEW_PGEO, 1)
    print("Patch 1 : fetcher_pgeo_wikipedia.py ajouté au pilier PGEO")

    # Appliquer patch 2 : _fetchers_with_output (si patch_run_pipeline déjà appliqué)
    if OLD_OUTPUT_SET in new_content:
        new_content = new_content.replace(OLD_OUTPUT_SET, NEW_OUTPUT_SET, 1)
        print("Patch 2 : fetcher_pgeo_wikipedia.py ajouté à _fetchers_with_output")
    elif "_fetchers_with_output" not in new_content:
        print("Info : patch_run_pipeline.py pas encore appliqué.")
        print("  → Appliquez patch_run_pipeline.py d'abord, puis relancez ce script.")

    if args.dry_run:
        print("\nDRY-RUN — aucune modification.")
        return

    # Sauvegarde
    ARCHIVE.mkdir(exist_ok=True)
    ts  = datetime.now().strftime("%Y%m%d_%H%M%S")
    bak = ARCHIVE / f"run_pipeline_sprint7_before_pgeo_{ts}.py"
    shutil.copy2(TARGET, bak)
    print(f"Sauvegarde : {bak.name}")

    TARGET.write_text(new_content, encoding="utf-8")
    print("OK — run_pipeline_sprint7.py mis à jour.")
    print()
    print("Ordre d'exécution recommandé :")
    print("  1. psql -U postgres -d osa_db -f pmin_schema.sql")
    print("  2. python patch_run_pipeline.py")
    print("  3. python inject_gci_fallback.py")
    print("  4. python collectors\\run_pipeline_sprint7.py --collect --pillar PGEO")
    print("  5. python collectors\\detect_min_pmin.py")


if __name__ == "__main__":
    main()
