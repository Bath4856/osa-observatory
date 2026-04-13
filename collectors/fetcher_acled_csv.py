"""
OSA Observatory
collectors/fetcher_acled_csv.py -- Ingestion ACLED (Armed Conflict Location & Event Data)

Indicateurs integres :
  GEO_CON -- Intensite conflictuelle par pays/an
             Source : ACLED Africa aggregated by country-year
             Transformation : log(1 + events) -- corrige distribution asymetrique
             Direction : '-' (plus de conflits = moins de souverainete)

  GEO_TER -- Impact humain des conflits par pays/an
             Source : ACLED Africa aggregated by country-year
             Transformation : log(1 + fatalities) -- corrige valeurs extremes
             Direction : '-' (plus de victimes = moins de souverainete)

Justification du log transform :
  Distribution brute ACLED : Soudan 7634 evenements vs Seychelles 12
  Sans transformation : normalisation min-max ecrase les pays paisibles
  Avec log(1+x) : compression des valeurs extremes, meilleure discrimination

Les deux indicateurs restent separes (pas de fusion) :
  GEO_CON mesure l'intensite (nb evenements)
  GEO_TER mesure la gravite (nb victimes)
  La combinaison est faite par le pipeline L5 (moyenne PGEO)

Fichier source :
  Genere depuis Africa_aggregated_data_up_to_week_of-XXXX.xlsx
  Agregation : COUNTRY + annee -> SUM(EVENTS) + SUM(FATALITIES)
  Format CSV : country_name, year, events, fatalities
  Placer dans : data/acled/acled_africa_aggregated.csv

Telechargement source :
  https://data.humdata.org/organization/acled  (sans inscription)
  https://acleddata.com/data-export-tool/      (compte requis)

Usage :
  python collectors/fetcher_acled_csv.py --file data/acled/acled_africa_aggregated.csv --dry-run
  python collectors/fetcher_acled_csv.py --file data/acled/acled_africa_aggregated.csv
  python collectors/fetcher_acled_csv.py --file data/acled/acled_africa_aggregated.csv --indicator GEO_CON
"""

import argparse
import csv
import logging
import math
import os
import sys

import psycopg2
from psycopg2.extras import execute_batch
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(
    level=os.getenv("OSA_LOG_LEVEL", "INFO"),
    format="%(asctime)s | %(levelname)-8s | %(message)s",
)
log = logging.getLogger("fetcher_acled")

# ── Constantes ────────────────────────────────────────────────
YEAR_FROM  = 2010
YEAR_TO    = 2024
LAYER_RAW  = 1
BATCH_SIZE = 500

# Mapping indicateur OSA -> colonne CSV
# log(1 + x) applique avant stockage pour corriger la distribution asymetrique
OSA_CODES = {
    "GEO_CON": "events",      # nb evenements -> log(1 + events)
    "GEO_TER": "fatalities",  # nb victimes   -> log(1 + fatalities)
}

# Mapping nom ACLED -> ISO3
# Noms tels qu'ils apparaissent dans le fichier agrege ACLED Afrique
ACLED_NAME_TO_ISO3 = {
    "Algeria":                        "DZA",
    "Angola":                         "AGO",
    "Benin":                          "BEN",
    "Botswana":                       "BWA",
    "Burkina Faso":                   "BFA",
    "Burundi":                        "BDI",
    "Cameroon":                       "CMR",
    "Cape Verde":                     "CPV",
    "Central African Republic":       "CAF",
    "Chad":                           "TCD",
    "Comoros":                        "COM",
    "Democratic Republic of Congo":   "COD",
    "Djibouti":                       "DJI",
    "Egypt":                          "EGY",
    "Equatorial Guinea":              "GNQ",
    "Eritrea":                        "ERI",
    "Eswatini":                       "SWZ",
    "eSwatini":                       "SWZ",
    "Ivory Coast":                    "CIV",
    "Ethiopia":                       "ETH",
    "Gabon":                          "GAB",
    "Gambia":                         "GMB",
    "Ghana":                          "GHA",
    "Guinea":                         "GIN",
    "Guinea-Bissau":                  "GNB",
    "Kenya":                          "KEN",
    "Lesotho":                        "LSO",
    "Liberia":                        "LBR",
    "Libya":                          "LBY",
    "Madagascar":                     "MDG",
    "Malawi":                         "MWI",
    "Mali":                           "MLI",
    "Mauritania":                     "MRT",
    "Mauritius":                      "MUS",
    "Morocco":                        "MAR",
    "Mozambique":                     "MOZ",
    "Namibia":                        "NAM",
    "Niger":                          "NER",
    "Nigeria":                        "NGA",
    "Republic of Congo":              "COG",
    "Rwanda":                         "RWA",
    "Sao Tome and Principe":          "STP",
    "Senegal":                        "SEN",
    "Seychelles":                     "SYC",
    "Sierra Leone":                   "SLE",
    "Somalia":                        "SOM",
    "South Africa":                   "ZAF",
    "South Sudan":                    "SSD",
    "Sudan":                          "SDN",
    "Tanzania":                       "TZA",
    "Togo":                           "TGO",
    "Tunisia":                        "TUN",
    "Uganda":                         "UGA",
    "Zambia":                         "ZMB",
    "Zimbabwe":                       "ZWE",
}


# ── Connexion PostgreSQL ──────────────────────────────────────
def get_conn():
    return psycopg2.connect(
        host=os.getenv("OSA_DB_HOST", "localhost"),
        port=int(os.getenv("OSA_DB_PORT", 5432)),
        dbname=os.getenv("OSA_DB_NAME", "osa_db"),
        user=os.getenv("OSA_DB_USER", "osa_user"),
        password=os.getenv("OSA_DB_PASS", ""),
    )


def get_method_version(conn):
    with conn.cursor() as cur:
        cur.execute(
            "SELECT id FROM ma.indicator_method_versions ORDER BY id DESC LIMIT 1"
        )
        row = cur.fetchone()
        return row[0] if row else 1


def get_african_iso3(conn):
    with conn.cursor() as cur:
        cur.execute("SELECT iso3 FROM rf.countries WHERE iso3 IS NOT NULL")
        return {r[0] for r in cur.fetchall()}


# ── Verification directions ───────────────────────────────────
def check_directions(conn):
    """
    Verifie que GEO_CON et GEO_TER ont direction='-' dans rf.indicators.
    Direction '-' : plus de conflits/victimes = score ISA plus bas.
    """
    with conn.cursor() as cur:
        cur.execute("""
            SELECT code, direction, name_en
            FROM rf.indicators
            WHERE code IN %s
        """, (tuple(OSA_CODES.keys()),))
        rows = cur.fetchall()

    if not rows:
        log.warning("GEO_CON / GEO_TER non trouves dans rf.indicators")
        return

    for code, direction, name in rows:
        if direction == '-':
            log.info("  %-12s : direction='-' OK (%s)", code, name)
        else:
            log.warning("  %-12s : direction='%s' -- devrait etre '-'", code, direction)


# ── Preparation des enregistrements ──────────────────────────
def prepare_records(filepath, african_iso3, method_version, indicator_filter=None):
    """
    Lit le CSV agrege ACLED et produit les tuples d'insertion.

    Transformation log(1 + x) appliquee :
      - Compresse les valeurs extremes (Soudan 7634 -> log 8.94)
      - Preserve les zeros (0 -> 0.0)
      - Standard dans la litterature sur les conflits armes
      - Corrige la distribution ultra-asymetrique de ACLED

    GEO_CON et GEO_TER restent separes :
      Le pipeline L5 fait la combinaison via moyenne PGEO.
      Pas de fusion arbitraire des deux indicateurs.
    """
    records        = []
    pays_couverts  = set()
    pays_sans_iso3 = set()
    n_skip_year    = 0
    stats          = {c: {"n": 0, "min": float('inf'), "max": 0.0}
                      for c in OSA_CODES}

    with open(filepath, newline='', encoding='utf-8') as f:
        reader = csv.DictReader(f)

        # Verifier colonnes obligatoires
        fieldnames   = reader.fieldnames or []
        required     = ["country_name", "year", "events", "fatalities"]
        missing_cols = [c for c in required if c not in fieldnames]
        if missing_cols:
            log.error("Colonnes manquantes dans le CSV : %s", missing_cols)
            log.error("Colonnes disponibles : %s", fieldnames)
            sys.exit(1)

        for row in reader:
            country_name = row.get("country_name", "").strip()

            try:
                year = int(row.get("year", 0))
            except ValueError:
                continue

            if year < YEAR_FROM or year > YEAR_TO:
                n_skip_year += 1
                continue

            # Resoudre ISO3 via mapping explicite
            iso3 = ACLED_NAME_TO_ISO3.get(country_name)
            if not iso3:
                pays_sans_iso3.add(country_name)
                continue

            if iso3 not in african_iso3:
                continue

            pays_couverts.add(iso3)

            # Un enregistrement par indicateur
            for osa_code, col in OSA_CODES.items():
                if indicator_filter and osa_code != indicator_filter:
                    continue

                try:
                    raw = float(row.get(col, 0) or 0)
                except (ValueError, TypeError):
                    raw = 0.0

                if raw < 0:
                    log.warning("Valeur negative ignoree : %s %s %d -> %.0f",
                                osa_code, iso3, year, raw)
                    continue

                # Log transform : log(1 + x)
                val = round(math.log1p(raw), 6)

                # Statistiques
                s = stats[osa_code]
                s["n"]   += 1
                s["min"]  = min(s["min"], val)
                s["max"]  = max(s["max"], val)

                records.append((
                    osa_code,
                    iso3,
                    year,
                    LAYER_RAW,
                    val,             # log(1 + events) ou log(1 + fatalities)
                    None,            # processed_value : calcule par L3
                    method_version,
                    "OK",
                ))

    # Rapport
    log.info("Enregistrements prepares : %d", len(records))
    log.info("Pays couverts            : %d", len(pays_couverts))

    if n_skip_year > 0:
        log.info("Lignes hors periode ignorees : %d", n_skip_year)

    for code, s in stats.items():
        if s["n"] > 0:
            log.info("  %-12s : %d valeurs | log-plage [%.3f, %.3f]",
                     code, s["n"], s["min"], s["max"])

    if pays_sans_iso3:
        log.warning("Pays sans mapping ISO3 (%d) : %s",
                    len(pays_sans_iso3), ", ".join(sorted(pays_sans_iso3)))

    manquants = african_iso3 - pays_couverts
    if manquants:
        log.warning("Pays africains OSA absents du CSV ACLED (%d) : %s",
                    len(manquants), ", ".join(sorted(manquants)))
    else:
        log.info("Couverture pays : tous les pays OSA presents")

    return records


# ── Insertion batch ───────────────────────────────────────────
def insert_records(conn, records, dry_run=False):
    """Insertion via execute_batch. Compte reelle via COUNT avant/apres."""
    if dry_run:
        log.info("[DRY-RUN] %d enregistrements non inseres", len(records))
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

    with conn.cursor() as cur:
        cur.execute(
            "SELECT COUNT(*) FROM ma.indicator_values "
            "WHERE layer_id = %s AND indicator_code IN %s",
            (LAYER_RAW, osa_codes)
        )
        before = cur.fetchone()[0]

    with conn.cursor() as cur:
        execute_batch(cur, sql, records, page_size=BATCH_SIZE)
    conn.commit()

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
    osa_codes = tuple(OSA_CODES.keys())
    with conn.cursor() as cur:
        cur.execute("""
            SELECT indicator_code,
                   COUNT(*)                                    AS total,
                   COUNT(raw_value)                            AS non_null,
                   ROUND(COUNT(raw_value)*100.0/COUNT(*), 1)   AS coverage_pct,
                   ROUND(MIN(raw_value)::numeric, 3)           AS vmin,
                   ROUND(MAX(raw_value)::numeric, 3)           AS vmax,
                   ROUND(AVG(raw_value)::numeric, 3)           AS vmoy,
                   COUNT(DISTINCT country_iso3)                AS n_pays
            FROM ma.indicator_values
            WHERE layer_id = %s AND indicator_code IN %s
            GROUP BY indicator_code ORDER BY indicator_code
        """, (LAYER_RAW, osa_codes))

        log.info("Bilan final (valeurs log-transformees) :")
        for code, total, nn, cov, vmin, vmax, vmoy, npays in cur.fetchall():
            log.info("  %-12s : %d/%d (%.1f%%) | pays=%d | log [%.3f, %.3f] | moy=%.3f",
                     code, nn, total, cov, npays,
                     vmin or 0, vmax or 0, vmoy or 0)


# ── Point d'entree ────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(
        description="OSA -- Fetcher ACLED CSV (GEO_CON + GEO_TER avec log transform)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Indicateurs integres :
  GEO_CON <- log(1 + events)      Intensite conflictuelle / pays / an
  GEO_TER <- log(1 + fatalities)  Impact humain conflits / pays / an

Transformation log(1 + x) :
  Compresse les valeurs extremes (Soudan 7634 -> 8.94)
  Preserve les zeros (pays paisibles -> 0.0)
  Standard litterature conflits armes

Direction '-' dans rf.indicators :
  Plus de conflits = score ISA plus bas

Exemples :
  python fetcher_acled_csv.py --file data/acled/acled_africa_aggregated.csv --dry-run
  python fetcher_acled_csv.py --file data/acled/acled_africa_aggregated.csv
  python fetcher_acled_csv.py --file data/acled/acled_africa_aggregated.csv --indicator GEO_CON
        """
    )
    parser.add_argument("--file",       required=True,
                        help="Chemin vers acled_africa_aggregated.csv")
    parser.add_argument("--indicator",  default=None,
                        choices=list(OSA_CODES.keys()),
                        help="Limiter a un indicateur")
    parser.add_argument("--dry-run",    action="store_true",
                        help="Simulation sans ecriture en base")
    args = parser.parse_args()

    if not os.path.exists(args.file):
        log.error("Fichier introuvable : %s", args.file)
        sys.exit(1)

    log.info("=" * 60)
    log.info("OSA -- Fetcher ACLED CSV")
    log.info("Fichier    : %s", args.file)
    log.info("Indicateur : %s", args.indicator or "tous (GEO_CON + GEO_TER)")
    log.info("Annees     : %d -> %d", YEAR_FROM, YEAR_TO)
    log.info("Transform  : log(1 + x) sur events et fatalities")
    log.info("Dry-run    : %s", args.dry_run)
    log.info("=" * 60)

    conn = get_conn()
    try:
        log.info("Verification directions indicateurs :")
        check_directions(conn)

        african_iso3   = get_african_iso3(conn)
        method_version = get_method_version(conn)

        records = prepare_records(
            args.file, african_iso3, method_version, args.indicator
        )

        if not records:
            log.warning("Aucun enregistrement a inserer")
            return

        n = insert_records(conn, records, args.dry_run)

        if not args.dry_run:
            print_summary(conn)

        log.info("=" * 60)
        log.info("ACLED termine | +%d valeurs inserees", n)
        log.info("=" * 60)

    finally:
        conn.close()


if __name__ == "__main__":
    main()
