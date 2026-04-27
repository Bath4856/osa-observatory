"""
OSA Observatory
collectors/fetcher_pmin_proxy.py -- Indicateurs PMIN depuis proxies disponibles

Calcule 3 indicateurs PMIN depuis les données déjà en base :

  MIN_SEC  <- Sécurité sites miniers
             Proxy : log(1 + PGEO_FAT) normalisé [0,100]
             Source : UCDP fatalités par pays × année
             Direction : - (plus de fatalités = moins sûr)

  MIN_GOV  <- Gouvernance minière
             Proxy : PGEO_COR (WGI Control of Corruption) rebasé [0,100]
             Source : WGI CC.EST par pays × année
             Direction : + (moins de corruption = meilleure gouvernance)

  MIN_COM  <- Commerce minier
             Proxy : MIN_EXP (exportations minières USGS) normalisé [0,100]
             Source : USGS MCS par pays
             Direction : + (plus d'exportations = meilleur commerce)

Justification méthodologique :
  MIN_SEC  : La sécurité des sites miniers est directement liée aux conflits
             armés dans le pays. UCDP FAT est le meilleur proxy disponible
             en l'absence de données ACLED géolocalisées.
  MIN_GOV  : La corruption est le principal déterminant de la qualité de
             gouvernance du secteur extractif (cf. Resource Curse literature).
             WGI CC.EST est la mesure standard utilisée par la Banque Mondiale.
  MIN_COM  : Les exportations minières USGS reflètent l'intégration du pays
             dans les chaînes de valeur minières mondiales. Proxy robuste en
             l'absence de données Comtrade.

Usage :
  python collectors/fetcher_pmin_proxy.py --dry-run
  python collectors/fetcher_pmin_proxy.py
  python collectors/fetcher_pmin_proxy.py --indicator MIN_SEC
"""

import argparse
import logging
import math
import os
import sys
from collections import Counter

import psycopg2
from psycopg2.extras import execute_batch
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(
    level=os.getenv("OSA_LOG_LEVEL", "INFO"),
    format="%(asctime)s | %(levelname)-8s | %(message)s",
)
log = logging.getLogger("fetcher_pmin_proxy")

# ── Constantes ────────────────────────────────────────────────────────────────
LAYER_RAW  = 1
YEAR_FROM  = 2010
YEAR_TO    = 2024
BATCH_SIZE = 500

# ── Définition des proxies ────────────────────────────────────────────────────
PROXIES = {
    "MIN_SEC": {
        "source_code": "PGEO_FAT",
        "transform":   "log_norm",   # log(1+x) puis normalisation [0,100]
        "direction":   "-",          # inverser : plus de fatalités = score bas
        "description": "Proxy sécurité : log(1+PGEO_FAT) inversé normalisé",
    },
    "MIN_GOV": {
        "source_code": "PGEO_COR",
        "transform":   "shift_norm", # WGI [-2.5,+2.5] → [0,100]
        "direction":   "+",
        "description": "Proxy gouvernance : WGI CC.EST rebasé [0,100]",
    },
    "MIN_COM": {
        "source_code": "MIN_EXP",
        "transform":   "norm",       # normalisation min-max [0,100]
        "direction":   "+",
        "description": "Proxy commerce : MIN_EXP USGS normalisé [0,100]",
    },
}


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


# ── Chargement des données source ─────────────────────────────────────────────
def load_source(conn, source_code: str) -> dict:
    """
    Charge les valeurs brutes d'un indicateur source depuis ma.indicator_values.
    Retourne dict {(iso3, year): raw_value}
    """
    with conn.cursor() as cur:
        cur.execute("""
            SELECT country_iso3, year, raw_value
            FROM ma.indicator_values
            WHERE indicator_code = %s
              AND layer_id = %s
              AND raw_value IS NOT NULL
              AND year BETWEEN %s AND %s
        """, (source_code, LAYER_RAW, YEAR_FROM, YEAR_TO))
        rows = cur.fetchall()

    data = {(r[0], r[1]): float(r[2]) for r in rows}
    log.info("Source %-12s : %d valeurs chargées (%d pays × années)",
             source_code, len(data),
             len(set(k[0] for k in data)))
    return data


# ── Transformations ───────────────────────────────────────────────────────────
def transform_log_norm(data: dict, invert: bool = True) -> dict:
    """
    log(1 + x) puis normalisation [0,100].
    Si invert=True : 100 - score (plus de fatalités = score bas).
    """
    # Appliquer log(1+x)
    log_vals = {k: math.log(1 + v) for k, v in data.items()}

    # Normalisation min-max [0,100]
    vmin = min(log_vals.values())
    vmax = max(log_vals.values())

    if vmax == vmin:
        normalized = {k: 50.0 for k in log_vals}
    else:
        normalized = {
            k: round((v - vmin) / (vmax - vmin) * 100, 4)
            for k, v in log_vals.items()
        }

    # Inverser si direction -
    if invert:
        normalized = {k: round(100 - v, 4) for k, v in normalized.items()}

    return normalized


def transform_shift_norm(data: dict) -> dict:
    """
    WGI [-2.5, +2.5] → [0, 100]
    Formula : (v + 2.5) / 5.0 * 100
    """
    return {
        k: round(min(100, max(0, (v + 2.5) / 5.0 * 100)), 4)
        for k, v in data.items()
    }


def transform_norm(data: dict) -> dict:
    """
    Normalisation min-max [0,100] par année.
    Pour MIN_EXP : normaliser intra-année (comparaison entre pays la même année).
    """
    # Grouper par année
    by_year: dict[int, dict] = {}
    for (iso3, year), val in data.items():
        by_year.setdefault(year, {})[iso3] = val

    result = {}
    for year, vals in by_year.items():
        vmin = min(vals.values())
        vmax = max(vals.values())
        for iso3, v in vals.items():
            if vmax == vmin:
                result[(iso3, year)] = 50.0
            else:
                result[(iso3, year)] = round((v - vmin) / (vmax - vmin) * 100, 4)

    return result


# ── Construction des enregistrements ─────────────────────────────────────────
def build_records(
    osa_code: str,
    transformed: dict,
    african_iso3: set,
    method_version: int,
) -> list:
    records = []
    for (iso3, year), val in transformed.items():
        if iso3 not in african_iso3:
            continue
        records.append((
            osa_code,
            iso3,
            year,
            LAYER_RAW,
            val,
            None,
            method_version,
            "OK",   # quality_flag indique que c'est un proxy
        ))
    return records


# ── Insertion batch ───────────────────────────────────────────────────────────
def insert_records(conn, records: list, dry_run: bool = False) -> int:
    if not records:
        return 0

    osa_code = records[0][0]

    if dry_run:
        cnt = Counter(r[0] for r in records)
        log.info("[DRY-RUN] %-12s → %d enregistrements (non insérés)",
                 osa_code, len(records))
        return len(records)

    sql = """
        INSERT INTO ma.indicator_values
            (indicator_code, country_iso3, year, layer_id,
             raw_value, processed_value, method_version_id, quality_flag)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT DO NOTHING
    """

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
    log.info("  %-12s → %d insérés | %d conflits ignorés",
             osa_code, inserted, conflicts)
    return inserted


# ── Bilan final ───────────────────────────────────────────────────────────────
def print_summary(conn):
    codes = tuple(PROXIES.keys())
    with conn.cursor() as cur:
        cur.execute("""
            SELECT indicator_code,
                   COUNT(*)                             AS total,
                   COUNT(DISTINCT country_iso3)         AS pays,
                   MIN(year)                            AS yr_min,
                   MAX(year)                            AS yr_max,
                   ROUND(MIN(raw_value)::numeric, 1)    AS vmin,
                   ROUND(MAX(raw_value)::numeric, 1)    AS vmax,
                   ROUND(AVG(raw_value)::numeric, 1)    AS vmoy
            FROM ma.indicator_values
            WHERE layer_id = %s AND indicator_code IN %s
            GROUP BY indicator_code
            ORDER BY indicator_code
        """, (LAYER_RAW, codes))

        rows = cur.fetchall()
        if rows:
            log.info("Bilan final :")
            log.info("  %-12s %7s %5s %6s %6s %8s %8s %8s",
                     "Code", "Lignes", "Pays", "YrMin", "YrMax", "Min", "Max", "Moy")
            for code, total, pays, yr_min, yr_max, vmin, vmax, vmoy in rows:
                log.info("  %-12s %7d %5d %6d %6d %8.1f %8.1f %8.1f",
                         code, total, pays, yr_min, yr_max,
                         vmin or 0, vmax or 0, vmoy or 0)


# ── Point d'entrée ────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(
        description="OSA -- Fetcher PMIN proxies (MIN_SEC, MIN_GOV, MIN_COM)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Indicateurs calcules :
  MIN_SEC  Securite sites miniers    <- log(1+PGEO_FAT) inverse  [0,100]
  MIN_GOV  Gouvernance miniere       <- PGEO_COR rebase          [0,100]
  MIN_COM  Commerce minier           <- MIN_EXP normalise        [0,100]

Exemples :
  python fetcher_pmin_proxy.py --dry-run
  python fetcher_pmin_proxy.py
  python fetcher_pmin_proxy.py --indicator MIN_SEC --dry-run
        """
    )
    parser.add_argument(
        "--indicator",
        choices=list(PROXIES.keys()),
        default=None,
        help="Calculer un seul indicateur"
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
    log.info("OSA -- Fetcher PMIN Proxies")
    log.info("Indicateurs : %s", args.indicator or "tous (3)")
    log.info("Dry-run     : %s", args.dry_run)
    log.info("=" * 55)

    conn = get_conn()
    try:
        african_iso3   = get_african_countries(conn)
        method_version = get_method_version(conn)
        total_inserted = 0

        for osa_code, cfg in PROXIES.items():
            if args.indicator and osa_code != args.indicator:
                continue

            log.info("[%s] Source : %s | Transform : %s",
                     osa_code, cfg["source_code"], cfg["transform"])

            # Charger données source
            source_data = load_source(conn, cfg["source_code"])
            if not source_data:
                log.warning("  %s : aucune donnée source — skip", osa_code)
                continue

            # Appliquer transformation
            transform = cfg["transform"]
            invert    = cfg["direction"] == "-"

            if transform == "log_norm":
                transformed = transform_log_norm(source_data, invert=invert)
            elif transform == "shift_norm":
                transformed = transform_shift_norm(source_data)
            elif transform == "norm":
                transformed = transform_norm(source_data)
            else:
                log.error("Transform inconnu : %s", transform)
                continue

            log.info("  %d valeurs transformées", len(transformed))

            # Construire et insérer les enregistrements
            records = build_records(
                osa_code, transformed, african_iso3, method_version
            )

            n = insert_records(conn, records, args.dry_run)
            total_inserted += n

        if not args.dry_run:
            print_summary(conn)

        log.info("=" * 55)
        log.info("PMIN Proxies terminé | +%d valeurs insérées", total_inserted)
        log.info("=" * 55)

    finally:
        conn.close()


if __name__ == "__main__":
    main()
