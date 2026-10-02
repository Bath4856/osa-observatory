"""
OSA Observatory
collectors/fetcher_wgi_csv.py -- Ingestion WGI (Worldwide Governance Indicators)

Indicateurs integres :
  GOV_WGI_PV.EST -> GEO_STAB   Political Stability and Absence of Violence
  GOV_WGI_RL.EST -> GEO_RSK    Rule of Law
  GOV_WGI_GE.EST -> NUM_GOV    Government Effectiveness
  GOV_WGI_CC.EST -> PGEO_COR   Control of Corruption

Valeurs brutes WGI : echelle [-2.5, +2.5]
La normalisation [0,1] est effectuee par normalize_indicator (pipeline L3).

PGEO_COR — Pourquoi essentiel pour OSA :
  La corruption mine la souverainete effective des Etats africains.
  Elle affecte PMIN (revenus miniers detournes), PECO (fuite des capitaux),
  PGEO (instabilite liee aux rentes).

============================================================
CORRECTIF DU 2026-10-02 -- A LIRE AVANT TOUTE MODIFICATION
============================================================
L'ancienne version attendait DEUX fichiers (WGI_Data.csv pour
PV/RL/GE, WGICSV.csv pour CC seulement), avec --file (WGI_Data.csv)
OBLIGATOIRE -- un fichier dont on n'a jamais dispose sur ce projet.

Decouverte en inspectant le vrai contenu de WGICSV.csv (fourni par
l'utilisateur le 2026-10-02, export DataBank WB) : il contient en
realite TOUS les indicateurs WGI (PV.EST, RL.EST, GE.EST, CC.EST, RQ.EST,
VA.EST, et pour chacun EST/SC/SC_LB/SC_UB/SE/SR), pas seulement CC.EST
comme l'ancien code le supposait. Un seul fichier suffit desormais pour
les 4 composantes -- plus besoin de WGI_Data.csv.

Couverture verifiee sur ce fichier : 54/54 pays OSA, donnees jusqu'en
2024 incluse sur les 4 composantes -- MEILLEURE couverture que l'API
directe de la Banque mondiale (PV.EST, GE.EST, RL.EST y sont introuvables
depuis 2026, cf. incident du 2026-09-24 -- "deleted or archived"). Ce
fichier DataBank les a conserves.

La colonne "Country Code" de WGICSV.csv correspond deja exactement aux
codes ISO3 (verifie sur les 54 pays OSA) -- aucune resolution de noms
necessaire, comme pour EGDI.

Autres corrections, memes qu'ailleurs dans ce chantier :
  - source_id resolu dynamiquement (code 'WGI', ajoute a
    mm.source_origins le 2026-10-02 -- absent jusque-la des deux
    tables de sources) -- jamais d ID en dur.
  - ON CONFLICT ... DO UPDATE au lieu de DO NOTHING, pour corriger les
    lignes deja existantes.
============================================================

Source : WGICSV.csv (export complet DataBank WB)
  https://databank.worldbank.org/source/worldwide-governance-indicators

Usage :
  python collectors/fetcher_wgi_csv.py --file data/raw/wgi/WGICSV.csv --dry-run
  python collectors/fetcher_wgi_csv.py --file data/raw/wgi/WGICSV.csv
  python collectors/fetcher_wgi_csv.py --file data/raw/wgi/WGICSV.csv --indicator GEO_STAB
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

# ── Mapping WGICSV.csv -> OSA (les 4 composantes, un seul fichier) ───────────
WGI_MAPPING = {
    "GOV_WGI_PV.EST": "GEO_STAB",   # Political Stability and Absence of Violence
    "GOV_WGI_RL.EST": "GEO_RSK",    # Rule of Law
    "GOV_WGI_GE.EST": "NUM_GOV",    # Government Effectiveness
    "GOV_WGI_CC.EST": "PGEO_COR",   # Control of Corruption
}

# ── Constantes ────────────────────────────────────────────────────────────────
YEAR_FROM  = 2010
YEAR_TO    = 2024
LAYER_RAW  = 1
BATCH_SIZE = 500
# Pas de bornes de plage : l'echelle WGI (nominalement -2.5 a +2.5) est une
# distribution standardisee, pas une borne stricte -- des etats tres fragiles
# (Somalie, Mali 2023) peuvent legitimement la depasser legerement. Decision
# utilisateur du 2026-10-02 : garder toutes les valeurs reelles, sans filtre
# de plage. L'ancien filtre [-2.5, 2.5] excluait 7 valeurs reelles (Somalie
# jusqu'a -3.02, Mali 2023 a -2.56), precisement les pires annees des pays
# les plus fragiles -- pas des erreurs de saisie.


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


def get_wgi_source_id(conn) -> int:
    with conn.cursor() as cur:
        cur.execute("SELECT id FROM mm.source_origins WHERE code = %s", ("WGI",))
        row = cur.fetchone()
        if not row:
            raise RuntimeError(
                "mm.source_origins : code WGI introuvable -- "
                "executer add_wgi_source_20261002.sql avant de collecter"
            )
        return row[0]


# ── Chargement WGICSV.csv (format complet WGI, source unique) ───────────────
def load_wgicsv(filepath):
    """
    Charge WGICSV.csv (export DataBank complet).
    Format : Country Name, Country Code, Indicator Name, Indicator Code,
             1996, 1998, 2000, 2002, 2003, ... (annees en colonnes)
    Contient les 4 composantes WGI utilisees par OSA (PV, RL, GE, CC)
    dans un seul fichier -- verifie le 2026-10-02.
    """
    df = pd.read_csv(filepath)

    required = ["Country Code", "Indicator Code"]
    for col in required:
        if col not in df.columns:
            log.error("Colonne manquante : %s", col)
            log.error("Colonnes disponibles : %s", list(df.columns))
            sys.exit(1)

    df = df[df["Indicator Code"].isin(WGI_MAPPING.keys())].copy()
    if df.empty:
        log.error("Aucune des 4 composantes WGI trouvee. Attendues : %s",
                   list(WGI_MAPPING.keys()))
        sys.exit(1)

    log.info("WGICSV.csv : %d lignes | %d pays | %d composantes",
             len(df), df["Country Code"].nunique(), df["Indicator Code"].nunique())
    return df


# ── Preparation des enregistrements ──────────────────────────────────────────
def prepare_records(df, african_iso3, method_version, indicator_filter=None):
    """
    Transforme le DataFrame large en liste de tuples prets a inserer.
    Controle plage WGI [-2.5, +2.5].
    """
    year_cols = [
        c for c in df.columns
        if str(c).strip().isdigit() and YEAR_FROM <= int(str(c).strip()) <= YEAR_TO
    ]

    records         = []
    skipped_country = set()
    pays_par_code   = {code: set() for code in WGI_MAPPING.values()}

    for _, row in df.iterrows():
        iso3     = str(row["Country Code"]).strip()
        wgi_code = str(row["Indicator Code"]).strip()
        osa_code = WGI_MAPPING.get(wgi_code)

        if not osa_code:
            continue
        if indicator_filter and osa_code != indicator_filter:
            continue
        if iso3 not in african_iso3:
            skipped_country.add(iso3)
            continue

        pays_par_code[osa_code].add(iso3)

        for col in year_cols:
            year = int(str(col).strip())
            raw  = row[col]

            if pd.isna(raw) or str(raw).strip() in ("", "..", "NA", "N/A"):
                continue
            try:
                val = float(raw)
            except (ValueError, TypeError):
                continue

            records.append((
                osa_code, iso3, year, LAYER_RAW,
                val, None, method_version, "OK",
            ))

    log.info("Enregistrements prepares : %d", len(records))
    if skipped_country:
        log.debug("Pays hors referentiel ignores : %s", ", ".join(sorted(skipped_country)))

    for osa_code, pays in pays_par_code.items():
        if not indicator_filter or osa_code == indicator_filter:
            manquants = african_iso3 - pays
            if manquants:
                log.warning("%s : pays africains absents du fichier (%d) : %s",
                            osa_code, len(manquants), ", ".join(sorted(manquants)))

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

    if not records:
        return 0

    # Resolution dynamique de source_id -- jamais d ID en dur (cf. incident
    # 2026-09-24 : WB_SOURCE_ID=11 code en dur dans fetcher_wb_pres_pmil_pnum.py).
    # WGI ajoute a mm.source_origins le 2026-10-02 (n existait pas jusque-la).
    wgi_source_id = get_wgi_source_id(conn)
    records = [r + (wgi_source_id,) for r in records]

    sql = """
        INSERT INTO ma.indicator_values
            (indicator_code, country_iso3, year, layer_id,
             raw_value, processed_value, method_version_id, quality_flag, source_id)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT (indicator_code, country_iso3, year, layer_id, method_version_id)
        DO UPDATE SET
            raw_value       = EXCLUDED.raw_value,
            quality_flag    = EXCLUDED.quality_flag,
            source_id       = EXCLUDED.source_id
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
def print_summary(conn):
    osa_codes = tuple(set(WGI_MAPPING.values()))

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
Indicateurs integres (un seul fichier source, WGICSV.csv) :
  GEO_STAB  <- GOV_WGI_PV.EST  Political Stability
  GEO_RSK   <- GOV_WGI_RL.EST  Rule of Law
  NUM_GOV   <- GOV_WGI_GE.EST  Government Effectiveness
  PGEO_COR  <- GOV_WGI_CC.EST  Control of Corruption

Valeurs brutes [-2.5, +2.5] stockees en L1.
Normalisation [0,1] effectuee par normalize_indicator (pipeline L3).

Exemples :
  python fetcher_wgi_csv.py --file data/raw/wgi/WGICSV.csv --dry-run
  python fetcher_wgi_csv.py --file data/raw/wgi/WGICSV.csv
  python fetcher_wgi_csv.py --file data/raw/wgi/WGICSV.csv --indicator GEO_STAB
        """
    )
    parser.add_argument("--file",
                        required=True,
                        help="Chemin vers WGICSV.csv")
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
    log.info("Indicateur : %s", args.indicator or "tous (4)")
    log.info("Annees     : %d -> %d", YEAR_FROM, YEAR_TO)
    log.info("Dry-run    : %s", args.dry_run)
    log.info("=" * 55)

    conn = get_conn()
    try:
        african_iso3   = get_african_countries(conn)
        method_version = get_method_version(conn)

        df      = load_wgicsv(args.file)
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
