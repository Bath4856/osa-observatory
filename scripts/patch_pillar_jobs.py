"""
patch_pillar_jobs.py
═══════════════════════════════════════════════════════════════════════════
Met à jour PILLAR_JOBS dans run_pipeline_sprint7.py
avec les bons chemins pour les fetchers CSV dont les données
sont déjà présentes dans data/raw/.

Fetchers corrigés (fichiers déjà présents) :
  fetcher_sipri_milex.py   → data/raw/sipri/SIPRI-Milex-data-1949-2024_2.xlsx
  fetcher_imf_bop_csv.py   → data/raw/imf/BOP.csv
  fetcher_imf_dots_csv.py  → data/raw/imf/DOTS.csv
  fetcher_wgi_csv.py       → data/raw/wgi/WGI_Data.csv
  fetcher_fao_csv.py       → data/raw/fao/
  fetcher_undp_csv.py      → data/raw/undp/HDR_2024.csv
  fetcher_usgs_csv.py      → data/raw/pmin/usgs/

Usage :
  python patch_pillar_jobs.py --dry-run
  python patch_pillar_jobs.py
═══════════════════════════════════════════════════════════════════════════
"""

import argparse
import shutil
from datetime import datetime
from pathlib import Path

PROJECT = Path(__file__).resolve().parent
TARGET  = PROJECT / "collectors" / "run_pipeline_sprint7.py"
ARCHIVE = PROJECT / "collectors" / "archive"


# ── Corrections à appliquer ───────────────────────────────────────────────────
# Format : (ancien_tuple_dans_PILLAR_JOBS, nouveau_tuple)

PATCHES = [

    # ── PMIL ──────────────────────────────────────────────────────────────────

    # fetcher_sipri_milex.py : --file requis
    (
        '("fetcher_sipri_milex.py",       []),          # PMIL_DEF_BUDGET SIPRI',
        '("fetcher_sipri_milex.py",       ["--file", "data/raw/sipri/SIPRI-Milex-data-1949-2024_2.xlsx"]),  # PMIL_DEF_BUDGET SIPRI',
    ),

    # fetcher_wgi_csv.py dans PMIL : --file requis
    (
        '("fetcher_wgi_csv.py",           []),           # PMIL_STABILITY_WGI natif',
        '("fetcher_wgi_csv.py",           ["--file", "data/raw/wgi/WGI_Data.csv"]),  # PMIL_STABILITY_WGI natif',
    ),

    # ── PGEO ──────────────────────────────────────────────────────────────────

    # fetcher_wgi_csv.py dans PGEO : --file requis
    (
        '("fetcher_wgi_csv.py",           []),           # GEO_RSK/STAB WGI natif CSV',
        '("fetcher_wgi_csv.py",           ["--file", "data/raw/wgi/WGI_Data.csv"]),  # GEO_RSK/STAB WGI natif CSV',
    ),

    # ── PMON ──────────────────────────────────────────────────────────────────

    # fetcher_imf_bop_csv.py : --file requis
    (
        '("fetcher_imf_bop_csv.py",       []),           # MON_PAY BOP CSV',
        '("fetcher_imf_bop_csv.py",       ["--file", "data/raw/imf/BOP.csv"]),  # MON_PAY BOP CSV',
    ),

    # ── PECO ──────────────────────────────────────────────────────────────────

    # fetcher_imf_dots_csv.py : --file requis
    (
        '("fetcher_imf_dots_csv.py",       []),          # ECO_IMP/EXP DOTS CSV',
        '("fetcher_imf_dots_csv.py",       ["--file", "data/raw/imf/DOTS.csv"]),  # ECO_IMP/EXP DOTS CSV',
    ),

    # ── PENV ──────────────────────────────────────────────────────────────────

    # fetcher_fao_csv.py dans PENV : --dir requis
    (
        '("fetcher_fao_csv.py",           []),           # ENV_FOR/WATER FAO CSV',
        '("fetcher_fao_csv.py",           ["--dir", "data/raw/fao"]),  # ENV_FOR/WATER FAO CSV',
    ),

    # ── PRES ──────────────────────────────────────────────────────────────────

    # fetcher_fao_csv.py dans PRES : --dir requis
    (
        '("fetcher_fao_csv.py",           []),           # PRES_WATER FAO CSV',
        '("fetcher_fao_csv.py",           ["--dir", "data/raw/fao"]),  # PRES_WATER FAO CSV',
    ),

    # ── PHUM ──────────────────────────────────────────────────────────────────

    # fetcher_undp_csv.py : --file requis
    (
        '("fetcher_undp_csv.py",          []),           # HUM_POV UNDP CSV',
        '("fetcher_undp_csv.py",          ["--file", "data/raw/undp/HDR_2024.csv"]),  # HUM_POV UNDP CSV',
    ),

    # ── PMIN ──────────────────────────────────────────────────────────────────

    # fetcher_usgs_csv.py : --dir requis
    (
        '("fetcher_usgs_csv.py",           []),          # MIN production USGS CSV',
        '("fetcher_usgs_csv.py",           ["--dir", "data/raw/pmin/usgs"]),  # MIN production USGS CSV',
    ),

    # fetcher_eiti_csv.py : --dir requis (données à déposer manuellement)
    (
        '("fetcher_eiti_csv.py",           []),          # MIN_GOV/TAX EITI CSV',
        '("fetcher_eiti_csv.py",           ["--dir", "data/manual/eiti"]),  # MIN_GOV/TAX EITI CSV',
    ),
]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    if not TARGET.exists():
        print(f"ERREUR : {TARGET} introuvable.")
        return

    content = TARGET.read_text(encoding="utf-8")
    applied = []
    skipped = []

    for old, new in PATCHES:
        if old in content:
            content = content.replace(old, new, 1)
            applied.append(new.split('"')[1])   # nom du fetcher
        else:
            # Peut-être déjà patché
            fetcher = old.split('"')[1]
            if fetcher in content:
                skipped.append(fetcher + " (déjà patché ou ligne modifiée)")
            else:
                skipped.append(fetcher + " (introuvable)")

    print(f"Patches à appliquer : {len(PATCHES)}")
    print(f"  Appliqués  : {len(applied)}")
    print(f"  Ignorés    : {len(skipped)}")

    if applied:
        print("\nFetchers mis à jour :")
        for f in applied:
            print(f"  ✓ {f}")

    if skipped:
        print("\nIgnorés :")
        for f in skipped:
            print(f"  · {f}")

    if args.dry_run:
        print("\nDRY-RUN — aucune modification.")
        return

    if not applied:
        print("\nRien à modifier.")
        return

    # Sauvegarde
    ARCHIVE.mkdir(exist_ok=True)
    ts  = datetime.now().strftime("%Y%m%d_%H%M%S")
    bak = ARCHIVE / f"run_pipeline_sprint7_before_jobs_{ts}.py"
    shutil.copy2(TARGET, bak)
    print(f"\nSauvegarde : {bak.name}")

    TARGET.write_text(content, encoding="utf-8")
    print("OK — run_pipeline_sprint7.py mis à jour.")

    print("\nFetchers encore KO (données manquantes à déposer manuellement) :")
    print("  fetcher_comtrade_api.py   → token Comtrade requis")
    print("  fetcher_unctad_csv.py     → CSV UNCTAD à télécharger")
    print("  fetcher_imf.py            → token IMF requis")
    print("  fetcher_acled_csv.py      → CSV ACLED à exporter")
    print("  fetcher_unpk_csv.py       → CSV UNPK à télécharger")
    print("  fetcher_sipri_csv.py      → dossier SIPRI CSV à préparer")
    print("  fetcher_itu.py            → token ITU requis")
    print("  fetcher_egdi.py           → token EGDI requis")
    print("  fetcher_who.py            → token WHO requis")
    print("  fetcher_eiti_csv.py       → déposer CSV dans data/manual/eiti/")

    print("\nRelancez le pipeline :")
    print("  python launch_pipeline.py --mode dry-run")
    print("  python launch_pipeline.py")


if __name__ == "__main__":
    main()
