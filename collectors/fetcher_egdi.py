"""
OSA Observatory
collectors/fetcher_egdi.py -- Ingestion EGDI (UN E-Government Development Index)

Indicateurs integres :
  PNUM_EGDI_EGOV       <- E-Government Index      [0,1] × 100 → [0,100]
  PNUM_EGDI_ONLINE_SVC <- Online Service Index    [0,1] × 100 → [0,100]
  PNUM_EGDI_HUMAN_CAP  <- Human Capital Index     [0,1] × 100 → [0,100]

Source : UN DESA EGDI (editions biannuelles : 2010, 2012, ..., 2024)
Format fichier : egdi_all.xlsx
  Colonnes : Survey Year | Country Name | iso3 |
             E-Government Index | Online Service Index | Human Capital Index

Valeurs brutes [0,1] stockees en L1 après ×100 → [0,100].
Normalisation finale effectuee par normalize_indicator (pipeline L3).
Les annees non couvertes (2011, 2013...) sont interpolees par imputer_v3.

Usage :
  python collectors/fetcher_egdi.py --dry-run
  python collectors/fetcher_egdi.py --egdi-file data/raw/egdi/egdi_all.xlsx
  python collectors/fetcher_egdi.py --egdi-file data/raw/egdi/egdi_all.xlsx --dry-run
  python collectors/fetcher_egdi.py --indicator PNUM_EGDI_EGOV
"""

import argparse
import logging
import os
import sys
from pathlib import Path

import pandas as pd
import psycopg2
from psycopg2.extras import execute_batch
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(
    level=os.getenv("OSA_LOG_LEVEL", "INFO"),
    format="%(asctime)s | %(levelname)-8s | %(message)s",
)
log = logging.getLogger("fetcher_egdi")

# ── Constantes ────────────────────────────────────────────────────────────────
LAYER_RAW  = 1
YEAR_FROM  = 2010
YEAR_TO    = 2024
BATCH_SIZE = 500

EGDI_DEFAULT_PATH = Path("data/raw/egdi/egdi_all.xlsx")
EGDI_EDITIONS     = [2010, 2012, 2014, 2016, 2018, 2020, 2022, 2024]

# ── Mapping colonnes fichier → codes OSA ─────────────────────────────────────
# Colonnes exactes dans egdi_all.xlsx généré par le pipeline OSA
COL_YEAR    = "Survey Year"
COL_ISO3    = "iso3"
COL_EGOV    = "E-Government Index"
COL_OSI     = "Online Service Index"
COL_HCI     = "Human Capital Index"

INDICATOR_MAP = {
    "PNUM_EGDI_EGOV":       COL_EGOV,
    "PNUM_EGDI_ONLINE_SVC": COL_OSI,
    "PNUM_EGDI_HUMAN_CAP":  COL_HCI,
}

MULTIPLIER = 100.0   # [0,1] → [0,100]


# ── Connexion PostgreSQL ──────────────────────────────────────────────────────
def get_conn():
    return psycopg2.connect(
        host=os.getenv("OSA_DB_HOST", "localhost"),
        port=int(os.getenv("OSA_DB_PORT", 5432)),
        dbname=os.getenv("OSA_DB_NAME", "osa_db"),
        user=os.getenv("OSA_DB_USER", "osa_user"),
        password=os.getenv("OSA_DB_PASS", ""),
    )


def get_method_version(conn) -> int:
    with conn.cursor() as cur:
        cur.execute(
            "SELECT id FROM ma.indicator_method_versions ORDER BY id DESC LIMIT 1"
        )
        row = cur.fetchone()
        return row[0] if row else 1


def get_african_countries(conn) -> set:
    with conn.cursor() as cur:
        cur.execute("SELECT iso3 FROM rf.countries WHERE iso3 IS NOT NULL")
        return {r[0] for r in cur.fetchall()}


# ── Chargement du fichier EGDI ────────────────────────────────────────────────
def load_egdi(filepath: Path) -> pd.DataFrame:
    """
    Charge egdi_all.xlsx.
    Colonnes attendues : Survey Year, iso3, E-Government Index,
                         Online Service Index, Human Capital Index
    Retourne DataFrame filtré sur Afrique + 2010-2024.
    """
    if not filepath.exists():
        log.error("Fichier EGDI introuvable : %s", filepath)
        log.error("  Générer avec : python build_egdi_all.py")
        log.error("  Ou télécharger sur : https://publicadministration.un.org/egovkb/Data-Center")
        sys.exit(1)

    log.info("Chargement : %s", filepath)
    df = pd.read_excel(filepath, engine="openpyxl")

    # Vérifier colonnes obligatoires
    required = [COL_YEAR, COL_ISO3, COL_EGOV, COL_OSI, COL_HCI]
    missing  = [c for c in required if c not in df.columns]
    if missing:
        log.error("Colonnes manquantes : %s", missing)
        log.error("Colonnes disponibles : %s", list(df.columns))
        sys.exit(1)

    # Nettoyage
    df[COL_ISO3] = df[COL_ISO3].astype(str).str.strip().str.upper()
    df[COL_YEAR] = pd.to_numeric(df[COL_YEAR], errors="coerce")
    df = df.dropna(subset=[COL_ISO3, COL_YEAR])
    df = df[
        (df[COL_YEAR] >= YEAR_FROM) &
        (df[COL_YEAR] <= YEAR_TO)
    ]

    # Normaliser les scores [0,1] si besoin
    for col in [COL_EGOV, COL_OSI, COL_HCI]:
        df[col] = pd.to_numeric(df[col], errors="coerce")
        if df[col].dropna().max() > 1.5:
            log.info("  %s : valeurs en [0,100] détectées — normalisation ÷100", col)
            df[col] = df[col] / 100.0
        df[col] = df[col].clip(0.0, 1.0)

    log.info(
        "EGDI chargé : %d lignes | %d pays | %d éditions | années : %s",
        len(df),
        df[COL_ISO3].nunique(),
        df[COL_YEAR].nunique(),
        sorted(df[COL_YEAR].unique().tolist()),
    )
    return df


# ── Préparation des enregistrements ──────────────────────────────────────────
def build_records(
    df: pd.DataFrame,
    osa_code: str,
    african_iso3: set,
    method_version: int,
    indicator_filter: str = None,
) -> list:
    """
    Transforme le DataFrame en liste de tuples pour ma.indicator_values.
    Applique le multiplicateur ×100 pour stocker en [0,100].
    """
    if indicator_filter and osa_code != indicator_filter:
        return []

    col = INDICATOR_MAP[osa_code]
    if col not in df.columns:
        log.warning("%s : colonne '%s' absente", osa_code, col)
        return []

    records      = []
    skipped_iso3 = set()

    for _, row in df.iterrows():
        iso3 = str(row[COL_ISO3]).strip()
        year = int(row[COL_YEAR])
        val  = row[col]

        if iso3 not in african_iso3:
            skipped_iso3.add(iso3)
            continue
        if pd.isna(val):
            continue

        scaled = round(float(val) * MULTIPLIER, 4)
        records.append((
            osa_code,       # indicator_code
            iso3,           # country_iso3
            year,           # year
            LAYER_RAW,      # layer_id
            scaled,         # raw_value
            None,           # processed_value
            method_version, # method_version_id
            "OK",           # quality_flag
        ))

    if skipped_iso3:
        log.debug("%s : ISO3 hors référentiel ignorés : %s",
                  osa_code, ", ".join(sorted(skipped_iso3)))

    return records


# ── Insertion batch ───────────────────────────────────────────────────────────
def insert_records(conn, records: list, dry_run: bool = False) -> int:
    if dry_run:
        log.info("[DRY-RUN] %s → %d enregistrements (non insérés)", 
                 records[0][0] if records else "?", len(records))
        return len(records)

    if not records:
        return 0

    sql = """
        INSERT INTO ma.indicator_values
            (indicator_code, country_iso3, year, layer_id,
             raw_value, processed_value, method_version_id, quality_flag)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT DO NOTHING
    """

    osa_code  = records[0][0]
    all_codes = (osa_code,)

    with conn.cursor() as cur:
        cur.execute(
            "SELECT COUNT(*) FROM ma.indicator_values "
            "WHERE indicator_code = %s AND layer_id = %s",
            (osa_code, LAYER_RAW)
        )
        before = cur.fetchone()[0]

    with conn.cursor() as cur:
        execute_batch(cur, sql, records, page_size=BATCH_SIZE)
    conn.commit()

    with conn.cursor() as cur:
        cur.execute(
            "SELECT COUNT(*) FROM ma.indicator_values "
            "WHERE indicator_code = %s AND layer_id = %s",
            (osa_code, LAYER_RAW)
        )
        after = cur.fetchone()[0]

    inserted  = after - before
    conflicts = len(records) - inserted
    log.info("  %-22s → %d insérés | %d conflits ignorés",
             osa_code, inserted, conflicts)
    return inserted


# ── Bilan final ───────────────────────────────────────────────────────────────
def print_summary(conn):
    codes = tuple(INDICATOR_MAP.keys())
    with conn.cursor() as cur:
        cur.execute("""
            SELECT indicator_code,
                   COUNT(*)                                  AS total,
                   COUNT(DISTINCT country_iso3)              AS pays,
                   ROUND(MIN(raw_value)::numeric, 1)         AS vmin,
                   ROUND(MAX(raw_value)::numeric, 1)         AS vmax,
                   ROUND(AVG(raw_value)::numeric, 1)         AS vmoy
            FROM ma.indicator_values
            WHERE layer_id = %s AND indicator_code IN %s
            GROUP BY indicator_code
            ORDER BY indicator_code
        """, (LAYER_RAW, codes))

        rows = cur.fetchall()
        if rows:
            log.info("Bilan final :")
            log.info("  %-22s %8s %6s %8s %8s %8s",
                     "Code", "Lignes", "Pays", "Min", "Max", "Moy")
            for code, total, pays, vmin, vmax, vmoy in rows:
                log.info("  %-22s %8d %6d %8.1f %8.1f %8.1f",
                         code, total, pays,
                         vmin or 0, vmax or 0, vmoy or 0)


# ── Point d'entrée ────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(
        description="OSA -- Fetcher EGDI (PNUM e-gouvernement)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Indicateurs produits :
  PNUM_EGDI_EGOV       E-Government Development Index  [0,100]
  PNUM_EGDI_ONLINE_SVC Online Service Index            [0,100]
  PNUM_EGDI_HUMAN_CAP  Human Capital Index             [0,100]

Editions biannuelles : 2010, 2012, 2014, 2016, 2018, 2020, 2022, 2024
Annees interpolees par imputer_v3 : 2011, 2013, 2015, 2017, 2019, 2021, 2023

Exemples :
  python fetcher_egdi.py --dry-run
  python fetcher_egdi.py --egdi-file data/raw/egdi/egdi_all.xlsx
  python fetcher_egdi.py --indicator PNUM_EGDI_EGOV --dry-run
        """
    )
    parser.add_argument(
        "--egdi-file", dest="egdi_file",
        default=str(EGDI_DEFAULT_PATH),
        help=f"Chemin vers egdi_all.xlsx (défaut: {EGDI_DEFAULT_PATH})"
    )
    parser.add_argument(
        "--indicator",
        choices=list(INDICATOR_MAP.keys()),
        default=None,
        help="Traiter un seul indicateur"
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Simulation sans écriture en base"
    )
    parser.add_argument(
        "--output",
        choices=["csv", "db", "both"],
        default="both",
        help="Mode de sortie (compatibilité orchestrateur)"
    )
    args = parser.parse_args()

    log.info("=" * 55)
    log.info("OSA -- Fetcher EGDI")
    log.info("Fichier    : %s", args.egdi_file)
    log.info("Indicateur : %s", args.indicator or "tous (3)")
    log.info("Dry-run    : %s", args.dry_run)
    log.info("=" * 55)

    # Charger le fichier
    df = load_egdi(Path(args.egdi_file))

    conn = get_conn()
    try:
        african_iso3   = get_african_countries(conn)
        method_version = get_method_version(conn)
        total_inserted = 0

        for osa_code in INDICATOR_MAP:
            if args.indicator and osa_code != args.indicator:
                continue

            records = build_records(
                df, osa_code, african_iso3,
                method_version, args.indicator
            )

            if not records:
                log.warning("%s : aucun enregistrement", osa_code)
                continue

            log.info("[%d/%d] %s — %d enregistrements",
                     list(INDICATOR_MAP.keys()).index(osa_code) + 1,
                     len(INDICATOR_MAP),
                     osa_code, len(records))

            n = insert_records(conn, records, args.dry_run)
            total_inserted += n

        if not args.dry_run:
            print_summary(conn)

        log.info("=" * 55)
        log.info("EGDI terminé | +%d valeurs insérées", total_inserted)
        log.info("=" * 55)

    finally:
        conn.close()


if __name__ == "__main__":
    main()
