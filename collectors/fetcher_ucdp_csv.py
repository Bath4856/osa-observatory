"""
OSA Observatory
collectors/fetcher_ucdp_csv.py -- Ingestion UCDP (Uppsala Conflict Data Program)

Calcule et insere les 9 indicateurs PGEO depuis les fichiers CSV UCDP v25.1 :

  PGEO_FAT  <- Fatalites totales       (sb + ns + os deaths best estimate)
  PGEO_EVT  <- Nombre d evenements     (dyades state-based actives)
  PGEO_INT  <- Part conflits internes  (intrastate / total deaths)
  PGEO_INS  <- Intensite moyenne       (fatalities / events)
  PGEO_SPR  <- Dispersion spatiale     (nb de conflits distincts via UcdpPrioConflict)
  PGEO_TRD  <- Tendance annuelle       ((fat_t - fat_t-1) / (fat_t-1 + 1))
  PGEO_PEAK <- Annee de pic            (1 si fat == max historique pays)
  PGEO_STR  <- Structure des victimes  (civils / fatalities)
  PGEO_PRE  <- Pression cumulee 3 ans  (fat_t + fat_t-1 + fat_t-2)

Sources UCDP :
  organizedviolencecy_v25_1.csv  : agregat annuel par pays (source principale)
  UcdpPrioConflict_v25_1.csv     : conflits distincts (pour PGEO_SPR)

Telechargement :
  https://ucdp.uu.se/downloads
  → UCDP Organized Violence - country-year (v25.1)
  → UCDP/PRIO Armed Conflict Dataset (v25.1)

Valeurs brutes stockees en L1.
Normalisation [0,1] effectuee par normalize_indicator (pipeline L3).

Notes methodologiques :
  - PGEO_FAT : somme sb + ns + os (state-based + non-state + one-sided)
  - PGEO_INT : intrastate_deaths / total → mesure conflictualite interne
  - PGEO_SPR : nb conflits distincts dans UcdpPrioConflict (proxy dispersion)
  - PGEO_TRD : peut etre negatif (amelioration) → stocker brut
  - PGEO_PEAK : binaire 0/1 → SCORE_0_1 en base
  - PGEO_PRE : rolling 3 ans, min_periods=1 pour les premieres annees

Usage :
  python collectors/fetcher_ucdp_csv.py \\
      --file data/manual/organizedviolencecy_v25_1.csv --dry-run

  python collectors/fetcher_ucdp_csv.py \\
      --file data/manual/organizedviolencecy_v25_1.csv \\
      --conflict data/manual/UcdpPrioConflict_v25_1.csv

  python collectors/fetcher_ucdp_csv.py \\
      --file data/manual/organizedviolencecy_v25_1.csv \\
      --indicator PGEO_FAT --dry-run
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
log = logging.getLogger("fetcher_ucdp")

# ── Constantes ────────────────────────────────────────────────────────────────
YEAR_FROM  = 2010
YEAR_TO    = 2024
LAYER_RAW  = 1
BATCH_SIZE = 500

# ── Codes OSA produits ────────────────────────────────────────────────────────
OSA_CODES = [
    "PGEO_FAT", "PGEO_EVT", "PGEO_INT", "PGEO_INS",
    "PGEO_SPR", "PGEO_TRD", "PGEO_PEAK", "PGEO_STR", "PGEO_PRE",
]

# ── Mapping nom pays UCDP → ISO3 ─────────────────────────────────────────────
# UCDP n'inclut pas de colonne ISO3 dans organizedviolencecy
# Ce mapping couvre les 54 pays africains presents dans UCDP v25.1
COUNTRY_TO_ISO3 = {
    "Algeria": "DZA", "Angola": "AGO", "Benin": "BEN",
    "Botswana": "BWA", "Burkina Faso": "BFA", "Burundi": "BDI",
    "Cameroon": "CMR", "Cape Verde": "CPV",
    "Central African Republic": "CAF", "Chad": "TCD",
    "Comoros": "COM", "Congo": "COG",
    "Democratic Republic of the Congo": "COD",
    "DR Congo": "COD", "DRC": "COD",
    "Djibouti": "DJI", "Egypt": "EGY",
    "Equatorial Guinea": "GNQ", "Eritrea": "ERI",
    "Eswatini": "SWZ", "Swaziland": "SWZ",
    "Ethiopia": "ETH", "Gabon": "GAB",
    "Gambia": "GMB", "Ghana": "GHA",
    "Guinea": "GIN", "Guinea-Bissau": "GNB",
    "Ivory Coast": "CIV", "Cote d'Ivoire": "CIV",
    "Kenya": "KEN", "Lesotho": "LSO",
    "Liberia": "LBR", "Libya": "LBY",
    "Madagascar": "MDG", "Malawi": "MWI",
    "Mali": "MLI", "Mauritania": "MRT",
    "Mauritius": "MUS", "Morocco": "MAR",
    "Mozambique": "MOZ", "Namibia": "NAM",
    "Niger": "NER", "Nigeria": "NGA",
    "Rwanda": "RWA", "Sao Tome and Principe": "STP",
    "Senegal": "SEN", "Seychelles": "SYC",
    "Sierra Leone": "SLE", "Somalia": "SOM",
    "South Africa": "ZAF", "South Sudan": "SSD",
    "Sudan": "SDN", "Tanzania": "TZA",
    "Togo": "TGO", "Tunisia": "TUN",
    "Uganda": "UGA", "Zambia": "ZMB",
    "Zimbabwe": "ZWE",
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


def get_african_countries(conn):
    with conn.cursor() as cur:
        cur.execute("SELECT iso3 FROM rf.countries WHERE iso3 IS NOT NULL")
        return {r[0] for r in cur.fetchall()}


def get_method_version(conn):
    with conn.cursor() as cur:
        cur.execute(
            "SELECT id FROM ma.indicator_method_versions ORDER BY id DESC LIMIT 1"
        )
        row = cur.fetchone()
        return row[0] if row else 1


# ── Chargement organizedviolencecy_v25_1.csv ─────────────────────────────────
def load_orgvio(filepath: str) -> pd.DataFrame:
    """
    Charge le fichier UCDP Organized Violence country-year.
    Colonnes utilisees :
      country_cy, year_cy,
      sb_dyad_count_cy,
      sb_deaths_parties_cy, sb_deaths_civilians_cy, sb_deaths_unknown_cy,
      sb_total_deaths_best_cy, sb_intrastate_deaths_best_cy,
      ns_total_deaths_best_cy, os_total_deaths_best_cy
    """
    log.info("Chargement : %s", filepath)
    df = pd.read_csv(filepath, low_memory=False)

    required = ["country_cy", "year_cy", "sb_total_deaths_best_cy"]
    missing  = [c for c in required if c not in df.columns]
    if missing:
        log.error("Colonnes manquantes dans organizedviolencecy : %s", missing)
        sys.exit(1)

    # Ajouter ISO3 depuis le mapping nom → code
    df["iso3"] = df["country_cy"].map(COUNTRY_TO_ISO3)

    # Filtrer Afrique uniquement
    df_africa = df[df["iso3"].notna()].copy()
    unmapped  = df[df["iso3"].isna()]["country_cy"].unique()
    if len(unmapped) > 0:
        log.debug("Pays non mappés (hors Afrique ou manquants) : %s",
                  ", ".join(str(c) for c in unmapped[:10]))

    # Filtrer plage temporelle
    df_africa["year"] = pd.to_numeric(df_africa["year_cy"], errors="coerce")
    df_africa = df_africa[
        (df_africa["year"] >= YEAR_FROM) & (df_africa["year"] <= YEAR_TO)
    ]

    # S'assurer que les colonnes numériques sont bien typées
    num_cols = [
        "sb_dyad_count_cy",
        "sb_deaths_parties_cy", "sb_deaths_civilians_cy", "sb_deaths_unknown_cy",
        "sb_total_deaths_best_cy", "sb_intrastate_deaths_best_cy",
        "ns_total_deaths_best_cy", "os_total_deaths_best_cy",
    ]
    for col in num_cols:
        if col in df_africa.columns:
            df_africa[col] = pd.to_numeric(df_africa[col], errors="coerce").fillna(0)
        else:
            df_africa[col] = 0

    log.info("organizedviolencecy : %d lignes africaines (%d-%d)",
             len(df_africa), YEAR_FROM, YEAR_TO)
    return df_africa


# ── Chargement UcdpPrioConflict_v25_1.csv (pour PGEO_SPR) ───────────────────
def load_conflict_spread(filepath: str) -> pd.DataFrame:
    """
    Charge UcdpPrioConflict pour calculer PGEO_SPR (dispersion spatiale).
    Compte le nombre de conflits distincts (locations) par pays × année.
    La colonne 'location' contient le(s) pays affectés par le conflit.
    """
    log.info("Chargement dispersion : %s", filepath)
    df = pd.read_csv(filepath, low_memory=False)

    if "location" not in df.columns or "year" not in df.columns:
        log.warning("UcdpPrioConflict : colonnes location/year absentes — PGEO_SPR = 0")
        return pd.DataFrame(columns=["iso3", "year", "pgeo_spread"])

    # Explode : un conflit peut toucher plusieurs pays (séparés par virgule)
    df["year"] = pd.to_numeric(df["year"], errors="coerce")
    df = df[
        (df["year"] >= YEAR_FROM) & (df["year"] <= YEAR_TO)
    ]

    rows = []
    for _, row in df.iterrows():
        locations = str(row["location"]).split(",")
        for loc in locations:
            iso3 = COUNTRY_TO_ISO3.get(loc.strip())
            if iso3:
                rows.append({
                    "iso3": iso3,
                    "year": int(row["year"]),
                    "conflict_id": row.get("conflict_id", 0),
                })

    if not rows:
        log.warning("UcdpPrioConflict : aucun pays africain identifié")
        return pd.DataFrame(columns=["iso3", "year", "pgeo_spread"])

    df_rows = pd.DataFrame(rows)
    spread  = (
        df_rows.groupby(["iso3", "year"])["conflict_id"]
        .nunique()
        .rename("pgeo_spread")
        .reset_index()
    )
    log.info("PGEO_SPR : %d lignes iso3 × année", len(spread))
    return spread


# ── Calcul des 9 indicateurs PGEO ────────────────────────────────────────────
def compute_indicators(df: pd.DataFrame, spread_df: pd.DataFrame) -> pd.DataFrame:
    """
    Calcule les 9 indicateurs PGEO à partir du DataFrame organizedviolencecy.

    Formules :
      PGEO_FAT  = sb_total + ns_total + os_total (best estimates)
      PGEO_EVT  = sb_dyad_count (dyades actives)
      PGEO_INT  = sb_intrastate / sb_total (part interne)
      PGEO_INS  = PGEO_FAT / PGEO_EVT (intensite)
      PGEO_SPR  = nb conflits distincts (UcdpPrioConflict)
      PGEO_TRD  = (fat_t - fat_t-1) / (fat_t-1 + 1)
      PGEO_PEAK = 1 si fat == max(fat_pays), sinon 0
      PGEO_STR  = sb_deaths_civilians / PGEO_FAT
      PGEO_PRE  = rolling sum 3 ans
    """
    log.info("Calcul des 9 indicateurs PGEO...")

    agg = df[["iso3", "year",
              "sb_dyad_count_cy",
              "sb_deaths_civilians_cy",
              "sb_total_deaths_best_cy",
              "sb_intrastate_deaths_best_cy",
              "ns_total_deaths_best_cy",
              "os_total_deaths_best_cy"]].copy()

    # ── PGEO_FAT : total des fatalités (sb + ns + os) ─────────────────────────
    agg["pgeo_fat"] = (
        agg["sb_total_deaths_best_cy"]
        + agg["ns_total_deaths_best_cy"]
        + agg["os_total_deaths_best_cy"]
    )

    # ── PGEO_EVT : dyades state-based actives ────────────────────────────────
    agg["pgeo_evt"] = agg["sb_dyad_count_cy"]

    # ── PGEO_INT : part des conflits internes ────────────────────────────────
    # sb_intrastate / sb_total → ratio [0,1]
    agg["pgeo_int"] = (
        agg["sb_intrastate_deaths_best_cy"]
        / agg["sb_total_deaths_best_cy"].replace(0, pd.NA)
    )

    # ── PGEO_INS : intensité moyenne ─────────────────────────────────────────
    # fatalities / events → peut être très élevé
    agg["pgeo_ins"] = (
        agg["pgeo_fat"]
        / agg["pgeo_evt"].replace(0, pd.NA)
    )

    # ── PGEO_STR : structure des victimes (part civils) ──────────────────────
    agg["pgeo_str"] = (
        agg["sb_deaths_civilians_cy"]
        / agg["pgeo_fat"].replace(0, pd.NA)
    )

    # ── Trier pour les calculs temporels ─────────────────────────────────────
    agg = agg.sort_values(["iso3", "year"]).reset_index(drop=True)

    # ── PGEO_TRD : tendance annuelle ─────────────────────────────────────────
    agg["fat_lag"] = agg.groupby("iso3")["pgeo_fat"].shift(1)
    agg["pgeo_trd"] = (
        (agg["pgeo_fat"] - agg["fat_lag"])
        / (agg["fat_lag"].fillna(0) + 1)
    )

    # ── PGEO_PEAK : année de pic historique ──────────────────────────────────
    max_fat = agg.groupby("iso3")["pgeo_fat"].transform("max")
    agg["pgeo_peak"] = ((agg["pgeo_fat"] == max_fat) & (agg["pgeo_fat"] > 0)).astype(float)

    # ── PGEO_PRE : pression cumulée 3 ans ────────────────────────────────────
    agg["pgeo_pre"] = (
        agg.groupby("iso3")["pgeo_fat"]
        .transform(lambda s: s.rolling(window=3, min_periods=1).sum())
    )

    # ── PGEO_SPR : dispersion spatiale (depuis UcdpPrioConflict) ─────────────
    if not spread_df.empty:
        agg = agg.merge(spread_df, on=["iso3", "year"], how="left")
        agg["pgeo_spread"] = agg["pgeo_spread"].fillna(0)
    else:
        # Fallback : nombre de dyades comme proxy de dispersion
        agg["pgeo_spread"] = agg["pgeo_evt"]
        log.info("PGEO_SPR : fallback sur sb_dyad_count (UcdpPrioConflict absent)")

    # Nettoyer les colonnes intermédiaires
    agg = agg.drop(columns=[
        "sb_dyad_count_cy", "sb_deaths_civilians_cy",
        "sb_total_deaths_best_cy", "sb_intrastate_deaths_best_cy",
        "ns_total_deaths_best_cy", "os_total_deaths_best_cy",
        "fat_lag",
    ], errors="ignore")

    log.info("Indicateurs calcules : %d lignes pays x annee", len(agg))
    return agg


# ── Transformation en enregistrements L1 ─────────────────────────────────────
def build_records(
    agg: pd.DataFrame,
    african_iso3: set,
    method_version: int,
    indicator_filter: str = None,
) -> list:
    """
    Transforme le DataFrame agrégé en liste de tuples pour ma.indicator_values.

    Mapping colonne → code OSA :
      pgeo_fat   → PGEO_FAT
      pgeo_evt   → PGEO_EVT
      pgeo_int   → PGEO_INT
      pgeo_ins   → PGEO_INS
      pgeo_spread→ PGEO_SPR
      pgeo_trd   → PGEO_TRD
      pgeo_peak  → PGEO_PEAK
      pgeo_str   → PGEO_STR
      pgeo_pre   → PGEO_PRE
    """
    col_to_osa = {
        "pgeo_fat":    "PGEO_FAT",
        "pgeo_evt":    "PGEO_EVT",
        "pgeo_int":    "PGEO_INT",
        "pgeo_ins":    "PGEO_INS",
        "pgeo_spread": "PGEO_SPR",
        "pgeo_trd":    "PGEO_TRD",
        "pgeo_peak":   "PGEO_PEAK",
        "pgeo_str":    "PGEO_STR",
        "pgeo_pre":    "PGEO_PRE",
    }

    records      = []
    skipped_iso3 = set()

    for _, row in agg.iterrows():
        iso3 = row["iso3"]
        year = int(row["year"])

        if iso3 not in african_iso3:
            skipped_iso3.add(iso3)
            continue

        for col, osa_code in col_to_osa.items():
            if indicator_filter and osa_code != indicator_filter:
                continue
            if col not in agg.columns:
                continue

            val = row[col]
            if pd.isna(val):
                continue

            records.append((
                osa_code,       # indicator_code
                iso3,           # country_iso3
                year,           # year
                LAYER_RAW,      # layer_id = 1
                float(val),     # raw_value
                None,           # processed_value (calcule par L3)
                method_version, # method_version_id
                "OK",           # quality_flag
            ))

    if skipped_iso3:
        log.debug("ISO3 hors referentiel OSA ignores : %s",
                  ", ".join(sorted(skipped_iso3)))

    log.info("Enregistrements prepares : %d", len(records))

    # Apercu par indicateur
    cnt = Counter(r[0] for r in records)
    for code in sorted(cnt):
        log.info("  %-12s : %d valeurs", code, cnt[code])

    return records


# ── Insertion batch ───────────────────────────────────────────────────────────
def insert_records(conn, records: list, dry_run: bool = False) -> int:
    if dry_run:
        log.info("[DRY-RUN] %d enregistrements non inseres", len(records))
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
def print_summary(conn):
    osa_codes = tuple(OSA_CODES)
    with conn.cursor() as cur:
        cur.execute("""
            SELECT indicator_code,
                   COUNT(*)                                    AS total,
                   COUNT(raw_value)                            AS non_null,
                   ROUND(COUNT(raw_value)*100.0/COUNT(*), 1)   AS pct,
                   ROUND(MIN(raw_value)::numeric, 3)           AS vmin,
                   ROUND(MAX(raw_value)::numeric, 3)           AS vmax,
                   ROUND(AVG(raw_value)::numeric, 3)           AS vmean
            FROM ma.indicator_values
            WHERE layer_id = %s AND indicator_code IN %s
            GROUP BY indicator_code
            ORDER BY indicator_code
        """, (LAYER_RAW, osa_codes))

        rows = cur.fetchall()
        if rows:
            log.info("Bilan final :")
            log.info("  %-12s %8s %8s %7s %8s %8s %8s",
                     "Code", "Total", "NonNull", "Cov%", "Min", "Max", "Mean")
            for code, total, nn, pct, vmin, vmax, vmean in rows:
                log.info("  %-12s %8d %8d %6.1f%% %8.3f %8.3f %8.3f",
                         code, total, nn, pct or 0,
                         vmin or 0, vmax or 0, vmean or 0)
        else:
            log.warning("Aucune valeur UCDP en base")


# ── Point d'entree ────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(
        description="OSA -- Fetcher UCDP CSV (9 indicateurs PGEO)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Indicateurs calcules :
  PGEO_FAT  Fatalites totales        (sb + ns + os best estimates)
  PGEO_EVT  Nombre d evenements      (dyades state-based)
  PGEO_INT  Part conflits internes   (intrastate / total)
  PGEO_INS  Intensite moyenne        (fat / events)
  PGEO_SPR  Dispersion spatiale      (conflits distincts)
  PGEO_TRD  Tendance annuelle        ((fat_t - fat_t1) / (fat_t1 + 1))
  PGEO_PEAK Annee de pic             (1 si max historique)
  PGEO_STR  Structure des victimes   (civils / total)
  PGEO_PRE  Pression cumulee 3 ans   (rolling sum)

Exemples :
  python fetcher_ucdp_csv.py \\
      --file data/manual/organizedviolencecy_v25_1.csv --dry-run

  python fetcher_ucdp_csv.py \\
      --file data/manual/organizedviolencecy_v25_1.csv \\
      --conflict data/manual/UcdpPrioConflict_v25_1.csv

  python fetcher_ucdp_csv.py \\
      --file data/manual/organizedviolencecy_v25_1.csv \\
      --indicator PGEO_FAT
        """
    )
    parser.add_argument(
        "--file", required=True,
        help="Chemin vers organizedviolencecy_v25_1.csv"
    )
    parser.add_argument(
        "--conflict", default=None,
        help="Chemin vers UcdpPrioConflict_v25_1.csv (pour PGEO_SPR)"
    )
    parser.add_argument(
        "--indicator", default=None, choices=OSA_CODES,
        help="Calculer un seul indicateur"
    )
    parser.add_argument(
        "--from", dest="year_from", type=int, default=YEAR_FROM,
        help=f"Annee de debut (defaut: {YEAR_FROM})"
    )
    parser.add_argument(
        "--to", dest="year_to", type=int, default=YEAR_TO,
        help=f"Annee de fin (defaut: {YEAR_TO})"
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Simulation sans ecriture en base"
    )
    parser.add_argument(
        "--output", choices=["csv", "db", "both"], default="both",
        help="Mode de sortie (compatibilite orchestrateur)"
    )
    args = parser.parse_args()

    if not os.path.exists(args.file):
        log.error("Fichier introuvable : %s", args.file)
        sys.exit(1)

    log.info("=" * 60)
    log.info("OSA -- Fetcher UCDP CSV")
    log.info("Fichier    : %s", args.file)
    log.info("Conflict   : %s", args.conflict or "non fourni (PGEO_SPR = fallback)")
    log.info("Indicateur : %s", args.indicator or "tous (9)")
    log.info("Annees     : %d -> %d", args.year_from, args.year_to)
    log.info("Dry-run    : %s", args.dry_run)
    log.info("=" * 60)

    conn = get_conn()
    try:
        african_iso3   = get_african_countries(conn)
        method_version = get_method_version(conn)

        # ── 1. Charger organizedviolencecy (source principale) ────────────────
        df = load_orgvio(args.file)

        # ── 2. Charger UcdpPrioConflict (PGEO_SPR) ───────────────────────────
        spread_df = pd.DataFrame()
        if args.conflict and os.path.exists(args.conflict):
            spread_df = load_conflict_spread(args.conflict)
        elif args.conflict:
            log.warning("Fichier conflict introuvable : %s", args.conflict)

        # ── 3. Calculer les 9 indicateurs ─────────────────────────────────────
        agg = compute_indicators(df, spread_df)

        # ── 4. Construire les enregistrements L1 ──────────────────────────────
        records = build_records(agg, african_iso3, method_version, args.indicator)

        if not records:
            log.warning("Aucun enregistrement a inserer")
            return

        # ── 5. Insérer en base ────────────────────────────────────────────────
        n = insert_records(conn, records, args.dry_run)

        if not args.dry_run:
            print_summary(conn)

        log.info("=" * 60)
        log.info("UCDP termine | +%d valeurs inserees", n)
        log.info("=" * 60)

    finally:
        conn.close()


if __name__ == "__main__":
    main()
