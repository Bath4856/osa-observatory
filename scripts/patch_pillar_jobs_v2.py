"""
patch_pillar_jobs_v2.py
Corrige TOUS les fetchers CSV dans PILLAR_JOBS avec les chemins exacts
trouvés dans data/raw/.

Fetchers corrigés :
  DÉJÀ PATCHÉS (v1) :
    fetcher_sipri_milex.py, fetcher_imf_bop_csv.py, fetcher_imf_dots_csv.py
    fetcher_wgi_csv.py (PMIL+PGEO), fetcher_fao_csv.py (PENV+PRES)
    fetcher_undp_csv.py, fetcher_usgs_csv.py, fetcher_eiti_csv.py

  NOUVEAUX (v2) :
    fetcher_sipri_csv.py      → data/raw/sipri/
    fetcher_acled_csv.py      → data/raw/pgeo/country_level_data.csv
    fetcher_unpk_csv.py       → data/raw/pgeo/country_level_data.csv
    fetcher_unctad_csv.py     → data/raw/ptra/lsci_2010_2024.csv

Usage :
  python patch_pillar_jobs_v2.py --dry-run
  python patch_pillar_jobs_v2.py
"""

import argparse
import shutil
from datetime import datetime
from pathlib import Path

PROJECT = Path(__file__).resolve().parent
TARGET  = PROJECT / "collectors" / "run_pipeline_sprint7.py"
ARCHIVE = PROJECT / "collectors" / "archive"

PATCHES = [
    # ── PMIL ──────────────────────────────────────────────────────────────
    (
        '("fetcher_sipri_csv.py",         []),           # PMIL_ARMS CSV',
        '("fetcher_sipri_csv.py",         ["--dir", "data/raw/sipri"]),  # PMIL_ARMS CSV',
    ),
    (
        '("fetcher_acled_csv.py",         []),           # PMIL conflits ACLED CSV',
        '("fetcher_acled_csv.py",         ["--file", "data/raw/pgeo/country_level_data.csv"]),  # PMIL conflits ACLED CSV',
    ),
    # ── PGEO ──────────────────────────────────────────────────────────────
    (
        '("fetcher_acled_csv.py",         []),           # GEO conflits ACLED CSV',
        '("fetcher_acled_csv.py",         ["--file", "data/raw/pgeo/country_level_data.csv"]),  # GEO conflits ACLED CSV',
    ),
    (
        '("fetcher_unpk_csv.py",          []),           # GEO_PEA UNPK CSV',
        '("fetcher_unpk_csv.py",          ["--file", "data/raw/pgeo/country_level_data.csv"]),  # GEO_PEA UNPK CSV',
    ),
    # ── PECO ──────────────────────────────────────────────────────────────
    (
        '("fetcher_unctad_csv.py",         []),          # ECO_FDI/IMP UNCTAD CSV',
        '("fetcher_unctad_csv.py",         ["--file", "data/raw/ptra/lsci_2010_2024.csv"]),  # ECO_FDI/IMP UNCTAD CSV',
    ),
    # ── PMIN ──────────────────────────────────────────────────────────────
    (
        '("fetcher_unctad_csv.py",         []),          # MIN export UNCTAD CSV',
        '("fetcher_unctad_csv.py",         ["--file", "data/raw/ptra/lsci_2010_2024.csv"]),  # MIN export UNCTAD CSV',
    ),
]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    if not TARGET.exists():
        print(f"ERREUR : {TARGET} introuvable.")
        return

    content = TARGET.read_text(encoding="utf-8")
    applied, skipped = [], []

    for old, new in PATCHES:
        if old in content:
            content = content.replace(old, new, 1)
            applied.append(old.split('"')[1])
        else:
            skipped.append(old.split('"')[1] + " (introuvable ou déjà patché)")

    print(f"Patches : {len(PATCHES)} | Appliqués : {len(applied)} | Ignorés : {len(skipped)}")
    for f in applied:  print(f"  ✓ {f}")
    for f in skipped:  print(f"  · {f}")

    if args.dry_run:
        print("\nDRY-RUN — aucune modification.")
        return

    if not applied:
        print("\nRien à modifier.")
        return

    ARCHIVE.mkdir(exist_ok=True)
    ts  = datetime.now().strftime("%Y%m%d_%H%M%S")
    bak = ARCHIVE / f"run_pipeline_sprint7_before_jobsv2_{ts}.py"
    shutil.copy2(TARGET, bak)
    print(f"\nSauvegarde : {bak.name}")
    TARGET.write_text(content, encoding="utf-8")
    print("OK — run_pipeline_sprint7.py mis à jour.")
    print("\nRelancez :")
    print("  python launch_pipeline.py --mode dry-run")

if __name__ == "__main__":
    main()
