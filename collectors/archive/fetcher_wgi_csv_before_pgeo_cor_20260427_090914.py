"""
OSA Observatory
collectors/fetcher_wgi_csv.py -- Ingestion WGI (Worldwide Governance Indicators)

Indicateurs integres :
  GOV_WGI_PV.EST -> GEO_STAB  Political Stability and Absence of Violence
  GOV_WGI_RL.EST -> GEO_RSK   Rule of Law
  GOV_WGI_GE.EST -> NUM_GOV   Government Effectiveness

Valeurs brutes WGI : echelle [-2.5, +2.5]
La normalisation [0,1] est effectuee par normalize_indicator (pipeline L3)
-- pas dans ce fetcher.

Telechargement manuel du CSV :
  https://databank.worldbank.org/source/worldwide-governance-indicators
  Selectionner : pays africains + series PV/RL/GE + annees 2010-2024
  Export CSV -> data/wgi/WGI_Data.csv

Usage :
  python collectors/fetcher_wgi_csv.py --file data/wgi/WGI_Data.csv --dry-run
  python collectors/fetcher_wgi_csv.py --file data/wgi/WGI_Data.csv
  python collectors/fetcher_wgi_csv.py --file data/wgi/WGI_Data.csv --indicator GEO_STAB
"""

import argparse
import logging
import os
import sys

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

# ── Mapping WGI -> OSA ────────────────────────────────────────
# Cles = Series Code tel qu'il apparait dans le CSV WGI DataBank
# Valeurs = code indicateur OSA dans rf.indicators
WGI_MAPPING = {
    "GOV_WGI_PV.EST": "GEO_STAB",   # Political Stability and Absence of Violence
    "GOV_WGI_RL.EST": "GEO_RSK",    # Rule of Law
    "GOV_WGI_GE.EST": "NUM_GOV",    # Government Effectiveness
}

# ── Constantes ────────────────────────────────────────────────
YEAR_FROM  = 2010
YEAR_TO    = 2024
LAYER_RAW  = 1
BATCH_SIZE = 500
WGI_MIN    = -2.5   # plage theorique WGI
WGI_MAX    =  2.5


# ── Connexion PostgreSQL ──────────────────────────────────────
def get_conn():
    return psycopg2.connect(
        host=os.getenv("OSA_DB_HOST", "localhost"),
        port=int(os.getenv("OSA_DB_PORT", 5432)),
        dbname=os.getenv("OSA_DB_NAME", "osa_db"),
        user=os.getenv("OSA_DB_USER", "osa_user"),
        password=os.getenv("OSA_DB_PASS", ""),
    )


# ── Chargement CSV ────────────────────────────────────────────
def load_csv(filepath):
    """
    Charge le CSV WGI et filtre sur les series connues.
    Format attendu (DataBank export) :
      Country Name, Country Code, Series Name, Series Code, 2005 [YR2005]...
    """
    df = pd.read_csv(filepath)

    # Verifier les colonnes obligatoires
    required = ["Country Code", "Series Code"]
    for col in required:
        if col not in df.columns:
            log.error("Colonne manquante dans le CSV : %s", col)
            sys.exit(1)

    # Filtrer sur les series WGI connues
    df = df[df["Series Code"].isin(WGI_MAPPING.keys())].copy()

    if df.empty:
        log.error("Aucune serie WGI connue trouvee dans le CSV.")
        log.error("Series attendues : %s", list(WGI_MAPPING.keys()))
        sys.exit(1)

    log.info("CSV charge : %d lignes | %d pays | %d series",
             len(df),
             df["Country Code"].nunique(),
             df["Series Code"].nunique())

    return df


# ── Pays africains du referentiel OSA ────────────────────────
def get_african_countries(conn):
    with conn.cursor() as cur:
        cur.execute("SELECT iso3 FROM rf.countries WHERE iso3 IS NOT NULL")
        return {r[0] for r in cur.fetchall()}


# ── Version methode ───────────────────────────────────────────
def get_method_version(conn):
    with conn.cursor() as cur:
        cur.execute("SELECT id FROM ma.indicator_method_versions ORDER BY id DESC LIMIT 1")
        row = cur.fetchone()
        return row[0] if row else 1


# ── Preparation des enregistrements ──────────────────────────
def prepare_records(df, african_iso3, method_version, indicator_filter=None):
    """
    Transforme le DataFrame large en liste de tuples prets a inserer.

    Corrections appliquees :
    [3.3] Controle plage WGI [-2.5, +2.5] -- valeur ignoree si hors plage
    [3.4] Rapport des pays africains absents du CSV
    """
    # Colonnes annees dans la plage voulue
    year_cols = [
        c for c in df.columns
        if c[:4].isdigit() and YEAR_FROM <= int(c[:4]) <= YEAR_TO
    ]

    records          = []
    skipped_country  = set()
    skipped_range    = 0
    pays_dans_csv    = set()

    for _, row in df.iterrows():
        iso3     = str(row["Country Code"]).strip()
        wgi_code = str(row["Series Code"]).strip()
        osa_code = WGI_MAPPING.get(wgi_code)

        if not osa_code:
            continue

        # Filtre optionnel sur un indicateur
        if indicator_filter and osa_code != indicator_filter:
            continue

        # Filtrer les pays hors referentiel OSA
        if iso3 not in african_iso3:
            skipped_country.add(iso3)
            continue

        pays_dans_csv.add(iso3)

        for col in year_cols:
            year = int(col[:4])
            raw  = row[col]

            # Ignorer les valeurs manquantes
            if pd.isna(raw) or str(raw).strip() in ("", "..", "NA", "N/A"):
                continue

            try:
                val = float(raw)
            except (ValueError, TypeError):
                continue

            # [3.3] Controle plage WGI [-2.5, +2.5]
            if val < WGI_MIN or val > WGI_MAX:
                log.warning("Valeur hors plage WGI [%.1f, %.1f] : "
                            "%s %s %d -> %.4f -- ignoree",
                            WGI_MIN, WGI_MAX, osa_code, iso3, year, val)
                skipped_range += 1
                continue

            records.append((
                osa_code,        # indicator_code
                iso3,            # country_iso3
                year,            # year
                LAYER_RAW,       # layer_id = 1
                val,             # raw_value : brut [-2.5, +2.5]
                None,            # processed_value : calcule par normalize_indicator (L3)
                method_version,  # method_version_id
                "OK",            # quality_flag
            ))

    # Logs de synthese
    log.info("Enregistrements prepares : %d", len(records))

    if skipped_range > 0:
        log.warning("Valeurs ignorees (hors plage WGI) : %d", skipped_range)

    if skipped_country:
        log.info("Pays ignores (hors referentiel OSA) : %s",
                 ", ".join(sorted(skipped_country)))

    # [3.4] Pays africains absents du CSV WGI
    manquants = african_iso3 - pays_dans_csv
    if manquants:
        log.warning("Pays africains absents du CSV WGI (%d) : %s",
                    len(manquants), ", ".join(sorted(manquants)))
    else:
        log.info("Couverture pays : tous les pays OSA sont dans le CSV")

    return records


# ── Insertion batch ───────────────────────────────────────────
def insert_records(conn, records, dry_run=False):
    """
    Insere les enregistrements en L1 via execute_batch.
    ON CONFLICT DO NOTHING -- conforme a la politique OSA
    (pas de reecriture silencieuse -- vider L1 et reingerer si mise a jour).
    Compte les insertions reelles via COUNT avant/apres.
    """
    if dry_run:
        log.info("[DRY-RUN] %d enregistrements non inseres", len(records))
        # Apercu par indicateur
        from collections import Counter
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

    osa_codes = tuple(set(r[0] for r in records))

    # Compter avant insertion
    with conn.cursor() as cur:
        cur.execute(
            "SELECT COUNT(*) FROM ma.indicator_values "
            "WHERE layer_id = %s AND indicator_code IN %s",
            (LAYER_RAW, osa_codes)
        )
        before = cur.fetchone()[0]

    # Insertion batch
    with conn.cursor() as cur:
        execute_batch(cur, sql, records, page_size=BATCH_SIZE)
    conn.commit()

    # Compter apres insertion
    with conn.cursor() as cur:
        cur.execute(
            "SELECT COUNT(*) FROM ma.indicator_values "
            "WHERE layer_id = %s AND indicator_code IN %s",
            (LAYER_RAW, osa_codes)
        )
        after = cur.fetchone()[0]

    inserted  = after - before
    conflicts = len(records) - inserted

    log.info("Inseres : %d | Conflits ignores : %d", inserted, conflicts)
    return inserted


# ── Bilan final ───────────────────────────────────────────────
def print_summary(conn):
    """Affiche la couverture finale par indicateur WGI."""
    osa_codes = tuple(WGI_MAPPING.values())
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


# ── Point d'entree ────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(
        description="OSA -- Fetcher WGI CSV (GEO_STAB, GEO_RSK, NUM_GOV)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Indicateurs integres :
  GEO_STAB <- GOV_WGI_PV.EST  Political Stability
  GEO_RSK  <- GOV_WGI_RL.EST  Rule of Law
  NUM_GOV  <- GOV_WGI_GE.EST  Government Effectiveness

Valeurs brutes [-2.5, +2.5] stockees en L1.
Normalisation [0,1] effectuee par normalize_indicator (pipeline L3).

Exemples :
  python fetcher_wgi_csv.py --file data/wgi/WGI_Data.csv --dry-run
  python fetcher_wgi_csv.py --file data/wgi/WGI_Data.csv
  python fetcher_wgi_csv.py --file data/wgi/WGI_Data.csv --indicator GEO_STAB
        """
    )
    parser.add_argument("--file",       required=True,
                        help="Chemin vers WGI_Data.csv")
    parser.add_argument("--indicator",  default=None,
                        help="Limiter a un indicateur OSA (GEO_STAB / GEO_RSK / NUM_GOV)")
    parser.add_argument("--dry-run",    action="store_true",
    parser.add_argument("--output", choices=["csv", "db", "both"], default="both")
                        help="Simulation sans ecriture en base")
    args = parser.parse_args()

    if not os.path.exists(args.file):
        log.error("Fichier introuvable : %s", args.file)
        sys.exit(1)

    log.info("=" * 55)
    log.info("OSA -- Fetcher WGI CSV")
    log.info("Fichier    : %s", args.file)
    log.info("Indicateur : %s", args.indicator or "tous")
    log.info("Annees     : %d -> %d", YEAR_FROM, YEAR_TO)
    log.info("Dry-run    : %s", args.dry_run)
    log.info("=" * 55)

    conn = get_conn()
    try:
        df             = load_csv(args.file)
        african_iso3   = get_african_countries(conn)
        method_version = get_method_version(conn)

        records = prepare_records(df, african_iso3, method_version, args.indicator)

        if not records:
            log.warning("Aucun enregistrement a inserer")
            return

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
