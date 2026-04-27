"""
patch_wgi_corruption.py
═══════════════════════════════════════════════════════════════════════════
Ajoute l'indicateur PGEO_COR (Contrôle de la corruption) dans
fetcher_wgi_csv.py en mappant GOV_WGI_CC.EST depuis WGICSV.csv.

Pourquoi PGEO_COR est essentiel pour OSA :
  - La corruption mine directement la souveraineté des États africains
  - Détournement des revenus miniers (PMIN)
  - Fuite des capitaux (PECO)
  - Instabilité politique liée aux rentes (PGEO)
  - Source : WGI Control of Corruption [-2.5, +2.5]
    → normalisé [0, 100] par fetcher (0 = très corrompu, 100 = très sain)

Source des données : WGICSV.csv (pas WGI_Data.csv qui ne contient pas CC.EST)
  53/54 pays africains couverts, 1996–2024

Modifications apportées :
  1. Ajoute PGEO_COR dans INDICATOR_MAP de fetcher_wgi_csv.py
  2. Ajoute le support de WGICSV.csv comme source secondaire
  3. Met à jour PILLAR_JOBS pour passer aussi --wgicsv

Usage :
  python patch_wgi_corruption.py --dry-run
  python patch_wgi_corruption.py

Puis lancer :
  python collectors/fetcher_wgi_csv.py \
      --file data/raw/wgi/WGI_Data.csv \
      --wgicsv data/raw/wgi/WGICSV.csv \
      --dry-run
═══════════════════════════════════════════════════════════════════════════
"""

import argparse
import shutil
from datetime import datetime
from pathlib import Path

PROJECT    = Path(__file__).resolve().parent
COLLECTORS = PROJECT / "collectors"
ARCHIVE    = COLLECTORS / "archive"
TARGET     = COLLECTORS / "fetcher_wgi_csv.py"
PIPELINE   = COLLECTORS / "run_pipeline_sprint7.py"


# ── Bloc à insérer dans INDICATOR_MAP ────────────────────────────────────────

PGEO_COR_ENTRY = '''
    # ── Contrôle de la corruption (source : WGICSV.csv) ──────────────────────
    # GOV_WGI_CC.EST absent de WGI_Data.csv → chargé depuis WGICSV.csv
    "GOV_WGI_CC.EST": {
        "osa_code":     "PGEO_COR",
        "name_fr":      "Contrôle de la corruption",
        "pillar":       "PGEO",
        "unit":         "WGI_SCORE",
        "direction":    "+",       # plus élevé = moins de corruption = mieux
        "multiplier":   1.0,
        "bounds":       [-2.5, 2.5],
        "note":         "WGI Control of Corruption. Source : WGICSV.csv. "
                        "Valeurs brutes [-2.5, +2.5] stockées en L1. "
                        "Normalisation [0,100] effectuée par normalize_indicator (L3). "
                        "Essentiel pour mesurer la souveraineté effective des États africains.",
        "source_file":  "wgicsv",  # indique de lire dans WGICSV.csv
    },'''

# ── Bloc à insérer pour le parsing de WGICSV.csv ─────────────────────────────

WGICSV_PARSER = '''

def _parse_wgicsv(wgicsv_path: str, indicator_map: dict, africa_iso3: set,
                  year_from: int, year_to: int) -> list[dict]:
    """
    Parse WGICSV.csv pour extraire les indicateurs marqués source_file=wgicsv.
    Format WGICSV : Country Name, Country Code, Indicator Name, Indicator Code,
                    1996, 1998, 2000, 2002, ... (années en colonnes)
    """
    import csv, logging
    log = logging.getLogger(__name__)

    # Indicateurs à extraire depuis WGICSV
    wgicsv_indicators = {
        k: v for k, v in indicator_map.items()
        if v.get("source_file") == "wgicsv"
    }
    if not wgicsv_indicators:
        return []

    records = []
    try:
        with open(wgicsv_path, encoding="utf-8-sig") as f:
            reader = csv.DictReader(f)
            for row in reader:
                iso3 = row.get("Country Code", "").strip()
                if iso3 not in africa_iso3:
                    continue
                ind_code = row.get("Indicator Code", "").strip()
                if ind_code not in wgicsv_indicators:
                    continue

                cfg = wgicsv_indicators[ind_code]
                for col, val in row.items():
                    # Colonnes années : "2010", "2011", etc.
                    if not col.strip().isdigit():
                        continue
                    year = int(col.strip())
                    if not (year_from <= year <= year_to):
                        continue
                    if not val or val.strip() in ("", "..", "NA"):
                        continue
                    try:
                        raw_value = float(val.strip())
                        records.append({
                            "iso3":          iso3,
                            "year":          year,
                            "indicator_code": cfg["osa_code"],
                            "raw_value":     raw_value,
                            "source":        "WGI_WGICSV",
                        })
                    except ValueError:
                        pass
        log.info(f"WGICSV : {len(records)} observations extraites (PGEO_COR)")
    except Exception as e:
        log.error(f"Erreur lecture WGICSV {wgicsv_path} : {e}")
    return records
'''


def patch_indicator_map(content: str) -> tuple[str, bool]:
    """Insère PGEO_COR dans INDICATOR_MAP."""
    # Chercher la fin de INDICATOR_MAP (avant la dernière })
    # On insère avant la ligne qui ferme le dict principal
    marker = '"GOV_WGI_GE.EST"'
    if "PGEO_COR" in content:
        return content, False  # déjà présent
    if marker not in content:
        return content, False

    # Trouver la position après la dernière entrée connue du dict
    idx = content.rfind('"GOV_WGI_GE.EST"')
    # Trouver la fin du bloc de cette entrée (la } qui ferme le dict de cet indicateur)
    block_end = content.find('},', idx)
    if block_end == -1:
        return content, False

    insert_pos = block_end + 2  # après "},\n"
    new_content = content[:insert_pos] + PGEO_COR_ENTRY + content[insert_pos:]
    return new_content, True


def patch_wgicsv_support(content: str) -> tuple[str, bool]:
    """
    Ajoute :
    1. Le paramètre --wgicsv dans argparse
    2. La fonction _parse_wgicsv()
    3. L'appel à _parse_wgicsv() dans main()
    """
    if "_parse_wgicsv" in content:
        return content, False

    # 1. Ajouter --wgicsv dans argparse après --file
    old_arg = 'parser.add_argument("--file"'
    if old_arg not in content:
        return content, False

    # Trouver la fin de l'argument --file
    idx = content.find(old_arg)
    end = content.find('\n', idx)
    # Chercher la fin du bloc add_argument (peut être multi-lignes)
    paren_count = 0
    pos = idx
    while pos < len(content):
        if content[pos] == '(':
            paren_count += 1
        elif content[pos] == ')':
            paren_count -= 1
            if paren_count == 0:
                break
        pos += 1

    insert_after = pos + 1  # après la )
    wgicsv_arg = '\n    parser.add_argument("--wgicsv", default=None, ' \
                 'help="Chemin vers WGICSV.csv (pour PGEO_COR / GOV_WGI_CC.EST)")'
    content = content[:insert_after] + wgicsv_arg + content[insert_after:]

    # 2. Ajouter la fonction _parse_wgicsv avant if __name__
    if 'if __name__ == "__main__"' in content:
        idx = content.index('if __name__ == "__main__"')
        content = content[:idx] + WGICSV_PARSER + content[idx:]
    else:
        content += WGICSV_PARSER

    # 3. Ajouter l'appel dans main() — après le parsing principal
    # Chercher une ligne type "records = parse_wgi(...)" ou équivalent
    call_marker = "args.wgicsv"
    if call_marker not in content:
        # Insérer après une ligne contenant "records"
        wgicsv_call = '''
    # ── WGICSV.csv : indicateurs additionnels (PGEO_COR) ─────────────────
    if args.wgicsv:
        extra = _parse_wgicsv(
            args.wgicsv, INDICATOR_MAP, AFRICA_ISO3,
            args.from_year if hasattr(args, "from_year") else 2010,
            args.to_year   if hasattr(args, "to_year")   else 2024,
        )
        records.extend(extra)
'''
        # Chercher "records.extend" ou "insert_records" dans main
        for marker in ["records.extend", "insert_records(", "ingest(records"]:
            if marker in content:
                idx = content.rindex(marker)
                line_end = content.find('\n', idx)
                content = content[:line_end + 1] + wgicsv_call + content[line_end + 1:]
                break

    return content, True


def patch_pipeline(content: str) -> tuple[str, bool]:
    """Ajoute --wgicsv aux appels de fetcher_wgi_csv dans PILLAR_JOBS."""
    if "WGICSV.csv" in content:
        return content, False

    old_pgeo = '"--file", "data/raw/wgi/WGI_Data.csv"]),  # GEO_RSK/STAB WGI natif CSV'
    new_pgeo = '"--file", "data/raw/wgi/WGI_Data.csv", "--wgicsv", "data/raw/wgi/WGICSV.csv"]),  # GEO_RSK/STAB + PGEO_COR'

    old_pmil = '"--file", "data/raw/wgi/WGI_Data.csv"]),  # PMIL_STABILITY_WGI natif'
    new_pmil = '"--file", "data/raw/wgi/WGI_Data.csv", "--wgicsv", "data/raw/wgi/WGICSV.csv"]),  # PMIL_STABILITY_WGI + PGEO_COR'

    modified = False
    if old_pgeo in content:
        content = content.replace(old_pgeo, new_pgeo)
        modified = True
    if old_pmil in content:
        content = content.replace(old_pmil, new_pmil)
        modified = True
    return content, modified


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    print("=" * 60)
    print(f"  Patch PGEO_COR | Mode : {'DRY-RUN' if args.dry_run else 'RÉEL'}")
    print("=" * 60)

    # ── Vérifications préalables ──────────────────────────────────────────────
    if not TARGET.exists():
        print(f"ERREUR : {TARGET} introuvable.")
        return

    wgicsv = PROJECT / "data" / "raw" / "wgi" / "WGICSV.csv"
    if not wgicsv.exists():
        print(f"ATTENTION : WGICSV.csv absent de {wgicsv}")
        print(f"  → Copiez WGICSV.csv dans data/raw/wgi/")
        if not args.dry_run:
            resp = input("Continuer quand même ? [o/N] : ").strip().lower()
            if resp not in ("o", "oui", "y"):
                return

    # ── Patch fetcher_wgi_csv.py ──────────────────────────────────────────────
    content = TARGET.read_text(encoding="utf-8", errors="ignore")

    content, p1 = patch_indicator_map(content)
    print(f"  {'✓' if p1 else '·'} INDICATOR_MAP : {'PGEO_COR ajouté' if p1 else 'déjà présent'}")

    content, p2 = patch_wgicsv_support(content)
    print(f"  {'✓' if p2 else '·'} Support WGICSV : {'ajouté' if p2 else 'déjà présent'}")

    # ── Patch run_pipeline_sprint7.py ─────────────────────────────────────────
    pipe_patched = False
    if PIPELINE.exists():
        pipe_content = PIPELINE.read_text(encoding="utf-8", errors="ignore")
        pipe_content, pipe_patched = patch_pipeline(pipe_content)
        print(f"  {'✓' if pipe_patched else '·'} PILLAR_JOBS : {'--wgicsv ajouté' if pipe_patched else 'déjà présent ou non trouvé'}")

    if args.dry_run:
        print("\n  DRY-RUN — aucune modification.")
        return

    if not (p1 or p2 or pipe_patched):
        print("\n  Rien à modifier.")
        return

    # Sauvegardes
    ARCHIVE.mkdir(exist_ok=True)
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")

    if p1 or p2:
        bak = ARCHIVE / f"fetcher_wgi_csv_before_pgeo_cor_{ts}.py"
        shutil.copy2(TARGET, bak)
        TARGET.write_text(content, encoding="utf-8")
        print(f"\n  Sauvegarde : {bak.name}")
        print(f"  OK — fetcher_wgi_csv.py mis à jour")

    if pipe_patched:
        bak2 = ARCHIVE / f"run_pipeline_sprint7_before_pgeo_cor_{ts}.py"
        shutil.copy2(PIPELINE, bak2)
        PIPELINE.write_text(pipe_content, encoding="utf-8")
        print(f"  OK — run_pipeline_sprint7.py mis à jour")

    print("""
Copier WGICSV.csv dans data/raw/wgi/ si pas encore fait :
  Copy-Item $env:USERPROFILE\\Downloads\\WGICSV.csv data\\raw\\wgi\\

Tester :
  python collectors\\fetcher_wgi_csv.py \\
      --file data\\raw\\wgi\\WGI_Data.csv \\
      --wgicsv data\\raw\\wgi\\WGICSV.csv \\
      --dry-run

Vérifier en base :
  SELECT * FROM rf.indicators WHERE code = 'PGEO_COR';
  SELECT COUNT(*) FROM ma.indicator_values WHERE indicator_code = 'PGEO_COR';
""")


if __name__ == "__main__":
    main()
