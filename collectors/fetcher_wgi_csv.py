"""
OSA Observatory
collectors/fetcher_wgi_csv.py -- Ingestion WGI (Worldwide Governance Indicators)

Indicateurs integres :
  GOV_WGI_PV.EST -> GEO_STAB   Political Stability and Absence of Violence
  GOV_WGI_RL.EST -> GEO_RSK    Rule of Law
  GOV_WGI_GE.EST -> NUM_GOV    Government Effectiveness
  GOV_WGI_CC.EST -> PGEO_COR   Control of Corruption (source : WGICSV.csv)

Valeurs brutes WGI : echelle [-2.5, +2.5]
La normalisation [0,1] est effectuee par normalize_indicator (pipeline L3).

PGEO_COR — Pourquoi essentiel pour OSA :
  La corruption mine la souverainete effective des Etats africains.
  Elle affecte PMIN (revenus miniers detournes), PECO (fuite des capitaux),
  PGEO (instabilite liee aux rentes). Source : WGICSV.csv (53/54 pays africains).

Sources :
  WGI_Data.csv : export DataBank WB (PV, RL, GE)
    https://databank.worldbank.org/source/worldwide-governance-indicators
  WGICSV.csv   : export complet WGI (tous indicateurs dont CC.EST)
    https://databank.worldbank.org/source/worldwide-governance-indicators

Usage :
  python collectors/fetcher_wgi_csv.py --file data/raw/wgi/WGI_Data.csv --dry-run
  python collectors/fetcher_wgi_csv.py --file data/raw/wgi/WGI_Data.csv
  python collectors/fetcher_wgi_csv.py --file data/raw/wgi/WGI_Data.csv --indicator GEO_STAB
  python collectors/fetcher_wgi_csv.py \
      --file data/raw/wgi/WGI_Data.csv \
      --wgicsv data/raw/wgi/WGICSV.csv \
      --dry-run
"""

import argparse
import logging
import os
import sys
from collections import Counter

import pandas as pd
import psycopg2
from psycopg2.extras import execute_batch
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(
    level=os.getenv("OSA_LOG_LEVEL", "INFO"),
    format="%(asctime)s | %(levelname)-8s | %(message)s",
)
log = logging.getLogger("fetcher_wgi")

# ── Mapping WGI_Data.csv -> OSA ───────────────────────────────────────────────
# Source : export DataBank WB (format Country Name / Country Code / Series Code)
WGI_MAPPING = {
    "GOV_WGI_PV.EST": "GEO_STAB",   # Political Stability and Absence of Violence
    "GOV_WGI_RL.EST": "GEO_RSK",    # Rule of Law
    "GOV_WGI_GE.EST": "NUM_GOV",    # Government Effectiveness
}

# ── Mapping WGICSV.csv -> OSA ─────────────────────────────────────────────────
# Source : export complet WGI (format Country Name / Country Code / Indicator Code)
WGICSV_MAPPING = {
    "GOV_WGI_CC.EST": "PGEO_COR",   # Control of Corruption
}

# ── Constantes ────────────────────────────────────────────────────────────────
YEAR_FROM  = 2010
YEAR_TO    = 2024
LAYER_RAW  = 1
BATCH_SIZE = 500
WGI_MIN    = -2.5
WGI_MAX    =  2.5


# ── Connexion PostgreSQL ──────────────────────────────────────────────────────
def get_conn():
    return psycopg2.connect(
        host=os.getenv("OSA_DB_HOST", "localhost"),
        port=int(os.getenv("OSA_DB_PORT", 5432)),
        dbname=os.getenv("OSA_DB_NAME", "osa_db"),
        user=os.getenv("OSA_DB_USER", "osa_user"),
        password=os.getenv("OSA_DB_PASS", ""),
    )


# ── Pays africains du referentiel OSA ────────────────────────────────────────
def get_african_countries(conn):
    with conn.cursor() as cur:
        cur.execute("SELECT iso3 FROM rf.countries WHERE iso3 IS NOT NULL")
        return {r[0] for r in cur.fetchall()}


# ── Version methode ───────────────────────────────────────────────────────────
def get_method_version(conn):
    with conn.cursor() as cur:
        cur.execute(
            "SELECT id FROM ma.indicator_method_versions ORDER BY id DESC LIMIT 1"
        )
        row = cur.fetchone()
        return row[0] if row else 1


# ── Chargement WGI_Data.csv (format DataBank) ─────────────────────────────────
def load_wgi_data(filepath):
    """
    Charge WGI_Data.csv.
    Format : Country Name, Country Code, Series Name, Series Code,
             2005 [YR2005], 2006 [YR2006], ...
    """
    df = pd.read_csv(filepath)

    required = ["Country Code", "Series Code"]
    for col in required:
        if col not in df.columns:
            log.error("Colonne manquante : %s", col)
            sys.exit(1)

    df = df[df["Series Code"].isin(WGI_MAPPING.keys())].copy()

    if df.empty:
        log.error("Aucune serie WGI connue. Attendues : %s", list(WGI_MAPPING.keys()))
        sys.exit(1)

    log.info("WGI_Data.csv : %d lignes | %d pays | %d series",
             len(df), df["Country Code"].nunique(), df["Series Code"].nunique())
    return df


# ── Preparation des enregistrements depuis WGI_Data.csv ──────────────────────
def prepare_records(df, african_iso3, method_version, indicator_filter=None):
    """
    Transforme le DataFrame large en liste de tuples prets a inserer.
    Controle plage WGI [-2.5, +2.5].
    """
    year_cols = [
        c for c in df.columns
        if c[:4].isdigit() and YEAR_FROM <= int(c[:4]) <= YEAR_TO
    ]

    records         = []
    skipped_country = set()
    skipped_range   = 0
    pays_dans_csv   = set()

    for _, row in df.iterrows():
        iso3     = str(row["Country Code"]).strip()
        wgi_code = str(row["Series Code"]).strip()
        osa_code = WGI_MAPPING.get(wgi_code)

        if not osa_code:
            continue
        if indicator_filter and osa_code != indicator_filter:
            continue
        if iso3 not in african_iso3:
            skipped_country.add(iso3)
            continue

        pays_dans_csv.add(iso3)

        for col in year_cols:
            year = int(col[:4])
            raw  = row[col]

            if pd.isna(raw) or str(raw).strip() in ("", "..", "NA", "N/A"):
                continue
            try:
                val = float(raw)
            except (ValueError, TypeError):
                continue

            if val < WGI_MIN or val > WGI_MAX:
                log.warning("Hors plage [%.1f, %.1f] : %s %s %d -> %.4f -- ignore",
                            WGI_MIN, WGI_MAX, osa_code, iso3, year, val)
                skipped_range += 1
                continue

            records.append((
                osa_code, iso3, year, LAYER_RAW,
                val, None, method_version, "OK",
            ))

    log.info("WGI_Data : %d enregistrements prepares", len(records))
    if skipped_range:
        log.warning("Valeurs ignorees (hors plage) : %d", skipped_range)
    if skipped_country:
        log.info("Pays hors referentiel : %s", ", ".join(sorted(skipped_country)))

    manquants = african_iso3 - pays_dans_csv
    if manquants:
        log.warning("Pays africains absents du CSV (%d) : %s",
                    len(manquants), ", ".join(sorted(manquants)))

    return records


# ── Chargement WGICSV.csv (format complet WGI) ───────────────────────────────
def load_wgicsv(filepath, african_iso3, method_version, indicator_filter=None):
    """
    Charge WGICSV.csv pour extraire PGEO_COR (GOV_WGI_CC.EST).
    Format : Country Name, Country Code, Indicator Name, Indicator Code,
             1996, 1998, 2000, 2002, 2003, 2004, 2005, ... (annees en colonnes)
    Retourne une liste de tuples prets a inserer.
    """
    if not os.path.exists(filepath):
        log.warning("WGICSV.csv introuvable : %s -- PGEO_COR ignore", filepath)
        return []

    try:
        df = pd.read_csv(filepath)
    except Exception as e:
        log.error("Erreur lecture WGICSV.csv : %s", e)
        return []

    required = ["Country Code", "Indicator Code"]
    for col in required:
        if col not in df.columns:
            log.error("WGICSV.csv : colonne manquante : %s", col)
            return []

    df = df[df["Indicator Code"].isin(WGICSV_MAPPING.keys())].copy()
    if df.empty:
        log.warning("WGICSV.csv : aucun indicateur CC.EST trouve")
        return []

    # Colonnes annees (format entier ou "YYYY")
    year_cols = [
        c for c in df.columns
        if str(c).strip().isdigit() and YEAR_FROM <= int(str(c).strip()) <= YEAR_TO
    ]

    if not year_cols:
        log.warning("WGICSV.csv : aucune colonne annee dans la plage %d-%d",
                    YEAR_FROM, YEAR_TO)
        return []

    records         = []
    skipped_range   = 0
    pays_dans_csv   = set()

    for _, row in df.iterrows():
        iso3     = str(row["Country Code"]).strip()
        wgi_code = str(row["Indicator Code"]).strip()
        osa_code = WGICSV_MAPPING.get(wgi_code)

        if not osa_code:
            continue
        if indicator_filter and osa_code != indicator_filter:
            continue
        if iso3 not in african_iso3:
            continue

        pays_dans_csv.add(iso3)

        for col in year_cols:
            year = int(str(col).strip())
            raw  = row[col]

            if pd.isna(raw) or str(raw).strip() in ("", "..", "NA", "N/A"):
                continue
            try:
                val = float(raw)
            except (ValueError, TypeError):
                continue

            if val < WGI_MIN or val > WGI_MAX:
                log.warning("PGEO_COR hors plage : %s %d -> %.4f -- ignore",
                            iso3, year, val)
                skipped_range += 1
                continue

            records.append((
                osa_code, iso3, year, LAYER_RAW,
                val, None, method_version, "OK",
            ))

    log.info("WGICSV.csv : %d enregistrements PGEO_COR | %d pays",
             len(records), len(pays_dans_csv))
    if skipped_range:
        log.warning("PGEO_COR valeurs ignorees (hors plage) : %d", skipped_range)

    manquants = african_iso3 - pays_dans_csv
    if manquants:
        log.warning("PGEO_COR : pays absents (%d) : %s",
                    len(manquants), ", ".join(sorted(manquants)))

    return records


# ── Insertion batch ───────────────────────────────────────────────────────────
def insert_records(conn, records, dry_run=False):
    if dry_run:
        log.info("[DRY-RUN] %d enregistrements non inseres", len(records))
        cnt = Counter(r[0] for r in records)
        log.info("Apercu par indicateur :")
        for code, n in sorted(cnt.items()):
            log.info("  %-12s : %d valeurs", code, n)
        return len(records)

    sql = """
        INSERT INTO ma.indicator_values
            (indicator_code, country_iso3, year, layer_id,
             raw_value, processed_value, method_version_id, quality_flag)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT DO NOTHING
    """

    all_codes = tuple(set(r[0] for r in records))

    with conn.cursor() as cur:
        cur.execute(
            "SELECT COUNT(*) FROM ma.indicator_values "
            "WHERE layer_id = %s AND indicator_code IN %s",
            (LAYER_RAW, all_codes)
        )
        before = cur.fetchone()[0]

    with conn.cursor() as cur:
        execute_batch(cur, sql, records, page_size=BATCH_SIZE)
    conn.commit()

    with conn.cursor() as cur:
        cur.execute(
            "SELECT COUNT(*) FROM ma.indicator_values "
            "WHERE layer_id = %s AND indicator_code IN %s",
            (LAYER_RAW, all_codes)
        )
        after = cur.fetchone()[0]

    inserted  = after - before
    conflicts = len(records) - inserted
    log.info("Inseres : %d | Conflits ignores : %d", inserted, conflicts)
    return inserted


# ── Bilan final ───────────────────────────────────────────────────────────────
def print_summary(conn, extra_codes=None):
    all_codes = list(WGI_MAPPING.values()) + list(WGICSV_MAPPING.values())
    if extra_codes:
        all_codes += extra_codes
    osa_codes = tuple(set(all_codes))

    with conn.cursor() as cur:
        cur.execute("""
            SELECT indicator_code,
                   COUNT(*)                                    AS total,
                   COUNT(raw_value)                            AS non_null,
                   ROUND(COUNT(raw_value)*100.0/COUNT(*), 1)   AS coverage_pct,
                   ROUND(MIN(raw_value)::numeric, 3)           AS vmin,
                   ROUND(MAX(raw_value)::numeric, 3)           AS vmax
            FROM ma.indicator_values
            WHERE layer_id = %s AND indicator_code IN %s
            GROUP BY indicator_code
            ORDER BY indicator_code
        """, (LAYER_RAW, osa_codes))

        rows = cur.fetchall()
        if rows:
            log.info("Bilan final par indicateur :")
            for code, total, nn, cov, vmin, vmax in rows:
                log.info("  %-12s : %d/%d (%.1f%%) | plage [%.2f, %.2f]",
                         code, nn, total, cov, vmin or 0, vmax or 0)
        else:
            log.warning("Aucune valeur WGI en base")


# ── Point d'entree ────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(
        description="OSA -- Fetcher WGI CSV (GEO_STAB, GEO_RSK, NUM_GOV, PGEO_COR)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Indicateurs integres :
  GEO_STAB  <- GOV_WGI_PV.EST  Political Stability     (WGI_Data.csv)
  GEO_RSK   <- GOV_WGI_RL.EST  Rule of Law             (WGI_Data.csv)
  NUM_GOV   <- GOV_WGI_GE.EST  Government Effectiveness(WGI_Data.csv)
  PGEO_COR  <- GOV_WGI_CC.EST  Control of Corruption   (WGICSV.csv)

Valeurs brutes [-2.5, +2.5] stockees en L1.
Normalisation [0,1] effectuee par normalize_indicator (pipeline L3).

Exemples :
  python fetcher_wgi_csv.py --file data/raw/wgi/WGI_Data.csv --dry-run
  python fetcher_wgi_csv.py --file data/raw/wgi/WGI_Data.csv
  python fetcher_wgi_csv.py --file data/raw/wgi/WGI_Data.csv --indicator GEO_STAB
  python fetcher_wgi_csv.py \\
      --file   data/raw/wgi/WGI_Data.csv \\
      --wgicsv data/raw/wgi/WGICSV.csv \\
      --dry-run
        """
    )
    parser.add_argument("--file",
                        required=True,
                        help="Chemin vers WGI_Data.csv")
    parser.add_argument("--wgicsv",
                        default=None,
                        help="Chemin vers WGICSV.csv (pour PGEO_COR / GOV_WGI_CC.EST)")
    parser.add_argument("--indicator",
                        default=None,
                        help="Limiter a un indicateur OSA "
                             "(GEO_STAB / GEO_RSK / NUM_GOV / PGEO_COR)")
    parser.add_argument("--dry-run",
                        action="store_true",
                        help="Simulation sans ecriture en base")
    parser.add_argument("--output",
                        choices=["csv", "db", "both"],
                        default="both",
                        help="Mode de sortie (compatibilite orchestrateur)")
    args = parser.parse_args()

    if not os.path.exists(args.file):
        log.error("Fichier introuvable : %s", args.file)
        sys.exit(1)

    log.info("=" * 55)
    log.info("OSA -- Fetcher WGI CSV")
    log.info("Fichier    : %s", args.file)
    log.info("WGICSV     : %s", args.wgicsv or "non fourni (PGEO_COR ignore)")
    log.info("Indicateur : %s", args.indicator or "tous")
    log.info("Annees     : %d -> %d", YEAR_FROM, YEAR_TO)
    log.info("Dry-run    : %s", args.dry_run)
    log.info("=" * 55)

    conn = get_conn()
    try:
        african_iso3   = get_african_countries(conn)
        method_version = get_method_version(conn)

        # ── 1. WGI_Data.csv (GEO_STAB, GEO_RSK, NUM_GOV) ────────────────────
        df      = load_wgi_data(args.file)
        records = prepare_records(df, african_iso3, method_version, args.indicator)

        # ── 2. WGICSV.csv (PGEO_COR) ─────────────────────────────────────────
        if args.wgicsv:
            extra = load_wgicsv(
                args.wgicsv, african_iso3, method_version, args.indicator
            )
            records.extend(extra)
            if extra:
                log.info("PGEO_COR : %d enregistrements ajoutes", len(extra))

        if not records:
            log.warning("Aucun enregistrement a inserer")
            return

        # ── 3. Insertion ──────────────────────────────────────────────────────
        n = insert_records(conn, records, args.dry_run)

        if not args.dry_run:
            print_summary(conn)

        log.info("=" * 55)
        log.info("WGI termine | +%d valeurs inserees", n)
        log.info("=" * 55)

    finally:
        conn.close()


if __name__ == "__main__":
    main()
