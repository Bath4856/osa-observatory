"""
============================================================
OSA Observatory — collectors/fetcher_egdi.py
Sprint 6 — Mai 2026
============================================================
Fetcher EGDI — UN E-Government Development Index
Source : UN DESA

Indicateurs produits :
  PNUM_EGDI_EGOV       — Score global EGDI          [0, 1] → ×100
  PNUM_EGDI_ONLINE_SVC — Online Service Index (OSI) [0, 1] → ×100
  PNUM_EGDI_HUMAN_CAP  — Human Capital Index  (HCI) [0, 1] → ×100

Source :
  URL  : https://publicadministration.un.org/egovkb/Data-Center
  Format : Excel (.xlsx) — téléchargement manuel requis
  Publication : biannuelle (années paires : 2010, 2012, 2014, 2016, 2018, 2020, 2022, 2024)

Structure fichier EGDI attendue (colonnes variables selon édition) :
  Country / Economy / Nation
  ISO3 / Country_Code / Code
  EGDI / EGDI Score / E-Government Development Index
  OSI  / Online Service Index
  TII  / Telecommunication Infrastructure Index  (non utilisé ici)
  HCI  / Human Capital Index

Stratégie :
  L'UN DESA ne dispose pas d'API publique pour ces données.
  Ce fetcher lit des fichiers locaux placés dans data/raw/egdi/.
  Support de plusieurs formats : fichier unique multi-années
  ou fichiers séparés par édition.

Modes de sortie (--output) :
  csv   → data/raw/pnum/{osa_code}_{year_min}_{year_max}.csv
  db    → insertion directe PostgreSQL
  both  → CSV + DB (défaut)

Gestion erreurs :
  Fichier absent → log warning + instructions téléchargement.
  Colonne manquante → log warning + indicateur ignoré.
  Exit code 1 si aucune donnée produite.

Usage :
  python collectors/fetcher_egdi.py --dry-run
  python collectors/fetcher_egdi.py --output both
  python collectors/fetcher_egdi.py --egdi-file data/raw/egdi/egdi_2024.xlsx
  python collectors/fetcher_egdi.py --indicator PNUM_EGDI_EGOV --output db
============================================================
"""

from __future__ import annotations

import argparse
import logging
import os
import sys
from pathlib import Path
from typing import Literal, Optional

import pandas as pd
import psycopg2
from dotenv import load_dotenv
from psycopg2.extras import execute_batch

load_dotenv()

logging.basicConfig(
    level=os.getenv("OSA_LOG_LEVEL", "INFO"),
    format="%(asctime)s | %(levelname)-8s | %(message)s",
)
log = logging.getLogger("fetcher_egdi")

# ── Constantes ────────────────────────────────────────────
LAYER_RAW     = 1
YEAR_MIN      = 2010
YEAR_MAX      = 2024
BATCH_SIZE    = 500

CSV_OUTPUT_BASE = Path(os.getenv("OSA_DATA_DIR", "data/raw"))
EGDI_DATA_DIR   = Path(os.getenv("OSA_EGDI_DIR", "data/raw/egdi"))

# Éditions biannuelles EGDI dans la fenêtre ISA
EGDI_EDITIONS = [2010, 2012, 2014, 2016, 2018, 2020, 2022, 2024]
EGDI_EDITIONS_IN_WINDOW = [y for y in EGDI_EDITIONS if YEAR_MIN <= y <= YEAR_MAX]

# Fichiers attendus par défaut
DEFAULT_EGDI_FILES = [
    EGDI_DATA_DIR / f"egdi_{yr}.xlsx" for yr in EGDI_EDITIONS_IN_WINDOW
]
# Alternative : un seul fichier multi-années
DEFAULT_EGDI_COMBINED = EGDI_DATA_DIR / "egdi_all.xlsx"

# ── Métadonnées indicateurs ───────────────────────────────
EGDI_INDICATORS = {
    "PNUM_EGDI_EGOV": {
        "pillar":            "PNUM",
        "name_fr":           "Développement e-gouvernement (EGDI global)",
        "unit":              "SCORE_0_100",
        "direction":         "+",
        "multiplier":        100.0,   # [0,1] → [0,100]
        "imputation_regime": "PHYSICAL",
        "is_composite_score": True,
        "confidence":        1.00,
        "interp_confidence": 0.75,
        "source_col_aliases": [
            "EGDI", "EGDI Score", "E-Government Development Index",
            "egdi", "score_egdi", "E-Gov Development Index",
        ],
    },
    "PNUM_EGDI_ONLINE_SVC": {
        "pillar":            "PNUM",
        "name_fr":           "Services en ligne (OSI — composante EGDI)",
        "unit":              "SCORE_0_100",
        "direction":         "+",
        "multiplier":        100.0,
        "imputation_regime": "PHYSICAL",
        "is_composite_score": True,
        "confidence":        1.00,
        "interp_confidence": 0.75,
        "source_col_aliases": [
            "OSI", "Online Service Index", "osi", "Online Services Index",
            "score_osi", "OSI Score",
        ],
    },
    "PNUM_EGDI_HUMAN_CAP": {
        "pillar":            "PNUM",
        "name_fr":           "Capital humain numérique (HCI — composante EGDI)",
        "unit":              "SCORE_0_100",
        "direction":         "+",
        "multiplier":        100.0,
        "imputation_regime": "PHYSICAL",
        "is_composite_score": True,
        "confidence":        1.00,
        "interp_confidence": 0.75,
        "source_col_aliases": [
            "HCI", "Human Capital Index", "hci", "score_hci",
            "Human Capital Index (HCI)",
        ],
    },
}

# Alias pour colonne pays et ISO3
COUNTRY_ALIASES = ["Country", "Economy", "Nation", "Member State", "country"]
ISO3_ALIASES    = ["ISO3", "iso3", "Country_Code", "Code", "ISO", "iso_code", "ISO Code"]
YEAR_ALIASES    = ["Year", "year", "Année", "annee", "Edition"]


# ── Connexion PostgreSQL ──────────────────────────────────
def get_pg_conn():
    return psycopg2.connect(
        host=os.getenv("OSA_DB_HOST", "localhost"),
        port=int(os.getenv("OSA_DB_PORT", 5432)),
        dbname=os.getenv("OSA_DB_NAME", "osa_db"),
        user=os.getenv("OSA_DB_USER", "osa_user"),
        password=os.getenv("OSA_DB_PASS", ""),
    )


# ── Utilitaire : résolution colonne ──────────────────────
def resolve_col(df: pd.DataFrame, aliases: list) -> Optional[str]:
    for alias in aliases:
        if alias in df.columns:
            return alias
    return None


# ── Lecture d'un fichier EGDI ────────────────────────────
def parse_egdi_file(filepath: Path, edition_year: Optional[int] = None) -> pd.DataFrame:
    """
    Lit un fichier EGDI (Excel ou CSV).
    Supporte deux formats :
      - Fichier par édition (avec ou sans colonne Year)
      - Fichier combiné multi-années (avec colonne Year)

    Retourne DataFrame(country_iso3, year, EGDI, OSI, HCI)
    tous en [0, 1] (normalisation si nécessaire).
    """
    if not filepath.exists():
        return pd.DataFrame()

    log.info("  Lecture EGDI : %s (édition %s)", filepath,
             str(edition_year) if edition_year else "auto")

    try:
        if filepath.suffix.lower() in (".xlsx", ".xls"):
            # Certains fichiers EGDI ont plusieurs feuilles
            xl = pd.ExcelFile(filepath, engine="openpyxl")
            # Prendre la première feuille contenant "EGDI" ou la première tout court
            sheet = xl.sheet_names[0]
            for s in xl.sheet_names:
                if "egdi" in s.lower() or "country" in s.lower():
                    sheet = s
                    break
            df = pd.read_excel(filepath, sheet_name=sheet, engine="openpyxl")
        else:
            df = pd.read_csv(filepath)
    except Exception as e:
        log.warning("  Erreur lecture %s : %s", filepath, e)
        return pd.DataFrame()

    # Supprimer les lignes vides
    df = df.dropna(how="all")

    # Résoudre colonne ISO3
    iso3_col = resolve_col(df, ISO3_ALIASES)
    if not iso3_col:
        # Essayer d'extraire ISO3 depuis la colonne pays
        country_col = resolve_col(df, COUNTRY_ALIASES)
        if not country_col:
            log.warning("  Aucune colonne pays / ISO3 trouvée. Colonnes : %s",
                        list(df.columns)[:10])
            return pd.DataFrame()
        log.warning("  Pas de colonne ISO3 — utilisation de '%s' brut", country_col)
        df["country_iso3"] = df[country_col].astype(str).str.strip()
    else:
        df["country_iso3"] = df[iso3_col].astype(str).str.upper().str.strip()

    # Résoudre colonne année
    year_col = resolve_col(df, YEAR_ALIASES)
    if year_col:
        df["year"] = pd.to_numeric(df[year_col], errors="coerce").astype("Int64")
    elif edition_year:
        df["year"] = edition_year
    else:
        log.warning("  Impossible de déterminer l'année — fichier ignoré")
        return pd.DataFrame()

    # Résoudre les colonnes scores
    result_cols = ["country_iso3", "year"]
    for osa_code, meta in EGDI_INDICATORS.items():
        col = resolve_col(df, meta["source_col_aliases"])
        if col:
            df[osa_code] = pd.to_numeric(df[col], errors="coerce")
            # Normaliser vers [0, 1] si les valeurs semblent être en [0, 100]
            if df[osa_code].dropna().max() > 1.5:
                log.info("    [%s] Valeurs en [0,100] détectées — normalisation ÷100",
                         osa_code)
                df[osa_code] = df[osa_code] / 100.0
            df[osa_code] = df[osa_code].clip(0.0, 1.0)
            result_cols.append(osa_code)
        else:
            log.warning("  [%s] Colonne non trouvée dans %s", osa_code, filepath.name)

    if len(result_cols) <= 2:
        log.warning("  Aucune colonne score EGDI trouvée")
        return pd.DataFrame()

    df_out = df[result_cols].copy()
    df_out = df_out[df_out["country_iso3"].str.len() >= 2]
    df_out = df_out.dropna(subset=["year"])

    # Filtrer sur la fenêtre ISA
    df_out = df_out[
        (df_out["year"] >= YEAR_MIN) &
        (df_out["year"] <= YEAR_MAX)
    ]

    log.info("  → %d lignes · %d pays · %d–%d · indicateurs : %s",
             len(df_out),
             df_out["country_iso3"].nunique(),
             int(df_out["year"].min()) if not df_out.empty else 0,
             int(df_out["year"].max()) if not df_out.empty else 0,
             [c for c in result_cols if c not in ["country_iso3", "year"]])

    return df_out


# ── Export CSV ────────────────────────────────────────────
def export_csv(df: pd.DataFrame, osa_code: str, year_min: int, year_max: int) -> Path:
    out_dir = CSV_OUTPUT_BASE / "pnum"
    out_dir.mkdir(parents=True, exist_ok=True)
    path = out_dir / f"{osa_code.lower()}_{year_min}_{year_max}.csv"

    value_col = osa_code   # colonne dans le DF consolidé
    if value_col not in df.columns:
        log.warning("  [%s] Colonne absente du DataFrame", osa_code)
        return path

    df_export = df[["country_iso3", "year", value_col]].copy()
    df_export.columns = ["country_iso3", "year", "raw_value"]
    df_export.insert(0, "indicator_code", osa_code)
    df_export.sort_values(["country_iso3", "year"]).to_csv(path, index=False)
    log.info("  [%s] CSV → %s (%d lignes)", osa_code, path, len(df_export))
    return path


# ── method_version_id ────────────────────────────────────
def get_method_version_id(conn, osa_code: str) -> int:
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT id FROM rf.method_versions
                WHERE indicator_code = %s
                ORDER BY created_at DESC LIMIT 1
            """, (osa_code,))
            row = cur.fetchone()
            return int(row[0]) if row else 1
    except Exception:
        return 1


# ── Insertion batch ───────────────────────────────────────
def insert_indicator(
    conn,
    df: pd.DataFrame,
    osa_code: str,
    dry_run: bool = False,
) -> int:
    """
    Insère un indicateur EGDI. Le DataFrame doit avoir une colonne
    nommée osa_code contenant les scores en [0,1].
    """
    if df.empty or osa_code not in df.columns:
        return 0

    meta       = EGDI_INDICATORS[osa_code]
    multiplier = meta["multiplier"]    # 100.0 → [0,1] → [0,100]
    confidence = meta["confidence"]

    df_ind = df[["country_iso3", "year", osa_code]].dropna().copy()
    if df_ind.empty:
        return 0

    if dry_run:
        log.info("  [DRY-RUN] [%s] %d lignes prêtes (moy=%.3f → ×%.0f → %.1f)",
                 osa_code, len(df_ind),
                 float(df_ind[osa_code].mean()),
                 multiplier,
                 float(df_ind[osa_code].mean()) * multiplier)
        return len(df_ind)

    with conn.cursor() as cur:
        cur.execute("""
            SELECT column_name FROM information_schema.columns
            WHERE table_schema = 'ma' AND table_name = 'indicator_values'
        """)
        db_cols = {r[0] for r in cur.fetchall()}

    has_confidence = "confidence_score" in db_cols
    has_status     = "value_status"     in db_cols
    mvid           = get_method_version_id(conn, osa_code)

    batch_data = []
    for _, row in df_ind.iterrows():
        iso3   = str(row["country_iso3"])
        year   = int(row["year"])
        scaled = round(float(row[osa_code]) * multiplier, 4)

        if has_confidence and has_status:
            batch_data.append((
                osa_code, iso3, year, LAYER_RAW,
                scaled, None, mvid, "OK", confidence, "OBSERVED"
            ))
        elif has_confidence:
            batch_data.append((
                osa_code, iso3, year, LAYER_RAW,
                scaled, None, mvid, "OK", confidence
            ))
        else:
            batch_data.append((
                osa_code, iso3, year, LAYER_RAW,
                scaled, None, mvid, "OK"
            ))

    if has_confidence and has_status:
        sql = """
            INSERT INTO ma.indicator_values
                (indicator_code, country_iso3, year, layer_id,
                 raw_value, processed_value, method_version_id,
                 quality_flag, confidence_score, value_status)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT DO NOTHING
        """
    elif has_confidence:
        sql = """
            INSERT INTO ma.indicator_values
                (indicator_code, country_iso3, year, layer_id,
                 raw_value, processed_value, method_version_id,
                 quality_flag, confidence_score)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT DO NOTHING
        """
    else:
        sql = """
            INSERT INTO ma.indicator_values
                (indicator_code, country_iso3, year, layer_id,
                 raw_value, processed_value, method_version_id, quality_flag)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT DO NOTHING
        """

    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT COUNT(*) FROM ma.indicator_values "
                "WHERE indicator_code = %s AND layer_id = %s",
                (osa_code, LAYER_RAW)
            )
            before = cur.fetchone()[0]

        with conn.cursor() as cur:
            execute_batch(cur, sql, batch_data, page_size=BATCH_SIZE)
        conn.commit()

        with conn.cursor() as cur:
            cur.execute(
                "SELECT COUNT(*) FROM ma.indicator_values "
                "WHERE indicator_code = %s AND layer_id = %s",
                (osa_code, LAYER_RAW)
            )
            after = cur.fetchone()[0]

        inserted = after - before
        log.info("  [%s] %d insérés (préparés=%d)", osa_code, inserted, len(batch_data))
        return inserted

    except Exception as e:
        log.error("  [%s] Erreur insertion : %s", osa_code, e)
        conn.rollback()
        return 0


# ── Rapport ───────────────────────────────────────────────
def print_report(results: dict, dry_run: bool, output_mode: str) -> None:
    print("\n" + "=" * 65)
    print("RAPPORT FETCHER EGDI — UN E-Government Development Index")
    print("=" * 65)

    print(f"\nMode sortie  : {output_mode.upper()}")
    total = sum(results.values())
    label = "[DRY-RUN prévu]" if dry_run else "Total lignes"
    print(f"{label:<21} : {total:>6}")

    print(f"\n  {'Indicateur':<28} {'Lignes':>7}  Statut")
    print(f"  {'-'*50}")
    for osa_code, n in results.items():
        if n > 0:
            status = "[DRY-RUN]" if dry_run else "OK"
        else:
            status = "VIDE — fichier absent"
        print(f"  {osa_code:<28} {n:>7}  {status}")

    gap_years = [y for y in range(YEAR_MIN, YEAR_MAX + 1)
                 if y not in EGDI_EDITIONS_IN_WINDOW]

    if any(n == 0 for n in results.values()):
        print(f"\n  Fichiers attendus dans : {EGDI_DATA_DIR}/")
        for yr in EGDI_EDITIONS_IN_WINDOW:
            print(f"    egdi_{yr}.xlsx  (ou egdi_all.xlsx pour toutes les éditions)")
        print(f"\n  Téléchargement : https://publicadministration.un.org/egovkb/Data-Center")
        print(f"\n  Après téléchargement :")
        print(f"    python fetcher_egdi.py --egdi-file data/raw/egdi/egdi_2024.xlsx --output both")

    print(f"\n  Éditions dans fenêtre ISA : {EGDI_EDITIONS_IN_WINDOW}")
    print(f"  Années sans édition (à interpoler) : {gap_years}")
    print(f"  → imputer_v3 : PNUM_PHYSICAL conf 0.75")
    print("=" * 65)


# ── Orchestrateur ─────────────────────────────────────────
def run(
    egdi_files:       Optional[list] = None,
    indicator_filter: Optional[str]  = None,
    dry_run:          bool = False,
    year_min:         int  = YEAR_MIN,
    year_max:         int  = YEAR_MAX,
    output_mode:      Literal["csv", "db", "both"] = "both",
) -> int:
    log.info("=" * 65)
    log.info("OSA Fetcher EGDI — PNUM e-gouvernement | Output : %s",
             output_mode.upper())
    if dry_run:
        log.info("MODE DRY-RUN — aucune écriture")

    # Résoudre les fichiers à lire
    if egdi_files:
        files_to_read = [(Path(f), None) for f in egdi_files]
    else:
        # Chercher fichier combiné d'abord
        files_to_read = []
        if DEFAULT_EGDI_COMBINED.exists():
            files_to_read = [(DEFAULT_EGDI_COMBINED, None)]
            log.info("Fichier combiné trouvé : %s", DEFAULT_EGDI_COMBINED)
        else:
            for yr in EGDI_EDITIONS_IN_WINDOW:
                p = EGDI_DATA_DIR / f"egdi_{yr}.xlsx"
                if p.exists():
                    files_to_read.append((p, yr))
            if not files_to_read:
                log.warning(
                    "Aucun fichier EGDI trouvé dans %s\n"
                    "  Télécharger depuis : "
                    "https://publicadministration.un.org/egovkb/Data-Center",
                    EGDI_DATA_DIR
                )

    # Lire et consolider tous les fichiers
    all_frames = []
    for fpath, yr in files_to_read:
        df = parse_egdi_file(fpath, edition_year=yr)
        if not df.empty:
            all_frames.append(df)

    results: dict[str, int] = {code: 0 for code in EGDI_INDICATORS}

    if not all_frames:
        print_report(results, dry_run=True, output_mode=output_mode)
        return -1

    df_all = pd.concat(all_frames, ignore_index=True)
    # Déduplication : garder la valeur la plus récente par (country, year)
    df_all = df_all.sort_values("year").drop_duplicates(
        subset=["country_iso3", "year"], keep="last"
    )

    conn = get_pg_conn()
    try:
        for osa_code in EGDI_INDICATORS:
            if indicator_filter and osa_code != indicator_filter:
                continue
            if osa_code not in df_all.columns:
                log.warning("[%s] Absent des données consolidées — skip", osa_code)
                continue

            if not dry_run and output_mode in ("csv", "both"):
                export_csv(df_all, osa_code, year_min, year_max)

            n = insert_indicator(conn, df_all, osa_code, dry_run=dry_run)
            if output_mode == "csv" and not dry_run:
                n = int(df_all[osa_code].notna().sum())
            results[osa_code] = n

    finally:
        conn.close()

    print_report(results, dry_run=dry_run, output_mode=output_mode)

    all_zero = all(n == 0 for n in results.values())
    return -1 if all_zero else sum(results.values())


# ── CLI ───────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(
        description="OSA — Fetcher EGDI UN (PNUM e-gouvernement)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=f"""
Indicateurs produits :
  PNUM_EGDI_EGOV       → Score global EGDI  [0,1] × 100
  PNUM_EGDI_ONLINE_SVC → OSI (services en ligne) [0,1] × 100
  PNUM_EGDI_HUMAN_CAP  → HCI (capital humain)    [0,1] × 100

Éditions biannuelles dans fenêtre ISA : {EGDI_EDITIONS_IN_WINDOW}

Fichiers attendus dans {EGDI_DATA_DIR}/ :
  egdi_all.xlsx  (fichier combiné — préféré)
  ou egdi_{{2010|2012|...|2024}}.xlsx (un par édition)

Téléchargement : https://publicadministration.un.org/egovkb/Data-Center

Modes de sortie :
  --output csv   → data/raw/pnum/
  --output db    → ma.indicator_values
  --output both  → CSV + DB (défaut)
  --dry-run      → rapport seul, aucune écriture

Exemples :
  python fetcher_egdi.py --dry-run
  python fetcher_egdi.py --output both
  python fetcher_egdi.py --egdi-file data/raw/egdi/egdi_2024.xlsx --output both
  python fetcher_egdi.py --indicator PNUM_EGDI_EGOV --output db
        """
    )
    parser.add_argument("--dry-run",     action="store_true",
                        help="Rapport sans écriture")
    parser.add_argument("--output",      choices=["csv", "db", "both"], default="both")
    parser.add_argument("--egdi-file",   action="append", dest="egdi_files",
                        type=Path, default=None,
                        help="Fichier EGDI Excel (répéter pour plusieurs éditions)")
    parser.add_argument("--indicator",   choices=list(EGDI_INDICATORS.keys()),
                        default=None)
    parser.add_argument("--year-min",    type=int, default=YEAR_MIN)
    parser.add_argument("--year-max",    type=int, default=YEAR_MAX)

    args = parser.parse_args()
    result = run(
        egdi_files=args.egdi_files,
        indicator_filter=args.indicator,
        dry_run=args.dry_run,
        year_min=args.year_min,
        year_max=args.year_max,
        output_mode=args.output,
    )
    sys.exit(0 if result >= 0 else 1)


if __name__ == "__main__":
    main()
