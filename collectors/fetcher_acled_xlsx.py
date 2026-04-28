"""
OSA Observatory
collectors/fetcher_acled_xlsx.py -- Ingestion ACLED depuis fichiers Excel

Indicateurs produits :

  GEO_CON  <- Nombre evenements violence politique (log(1+x)) [SCORE]
             Source : acled_violence_cy.xlsx (COUNTRY, YEAR, EVENTS)
             Pilier : PGEO | Direction : -

  GEO_TER  <- Impact humain des conflits (log(1+x)) [SCORE]
             Source : acled_fatalities_cy.xlsx (COUNTRY, YEAR, FATALITIES)
             Pilier : PGEO | Direction : -

  PGEO_STR <- Structure des victimes (civils / total) [RATIO]
             Source : acled_civilian_cy.xlsx / acled_fatalities_cy.xlsx
             Pilier : PGEO | Direction : -

  MIL_TER  <- Risque terroriste (log(1+x) normalise [0,100]) [SCORE_0_100]
             Source : acled_violence_cy.xlsx filtre terrorisme
             Pilier : PMIL | Direction : -

  MIN_SEC  <- Securite sites miniers (score ACLED buffer 50km) [SCORE_0_100]
             Source : acled_africa.xlsx (geolocalise)
             Pilier : PMIN | Direction : +
             Necessite : osa.pgeo_site peuple (fetcher_pgeo_wikipedia.py)

Transformation log(1+x) :
  Compresse les valeurs extremes (Nigeria 15000 -> 9.6)
  Preserve les zeros (pays paisibles -> 0.0)
  Standard litterature conflits armes (ACLED methodology)

Usage :
  python collectors/fetcher_acled_xlsx.py --dry-run
  python collectors/fetcher_acled_xlsx.py
  python collectors/fetcher_acled_xlsx.py --indicator GEO_CON
  python collectors/fetcher_acled_xlsx.py --skip-buffer  (sans MIN_SEC spatial)
"""

import argparse
import logging
import math
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
log = logging.getLogger("fetcher_acled")

# ── Constantes ────────────────────────────────────────────────────────────────
LAYER_RAW   = 1
YEAR_FROM   = 2010
YEAR_TO     = 2024
BATCH_SIZE  = 500
BUFFER_M    = 50_000   # 50 km en mètres

DATA_DIR    = Path("data/raw/pgeo")
FILE_VIOLENCE  = DATA_DIR / "acled_violence_cy.xlsx"
FILE_FATALITIES= DATA_DIR / "acled_fatalities_cy.xlsx"
FILE_CIVILIAN  = DATA_DIR / "acled_civilian_cy.xlsx"
FILE_GEO       = DATA_DIR / "acled_africa.xlsx"
FILE_CIVILIANS = DATA_DIR / "acled_civilians_cy.xlsx"

# ── Mapping nom pays → ISO3 ───────────────────────────────────────────────────
NAME_TO_ISO3 = {
    "Algeria":"DZA","Angola":"AGO","Benin":"BEN","Botswana":"BWA",
    "Burkina Faso":"BFA","Burundi":"BDI","Cabo Verde":"CPV","Cape Verde":"CPV",
    "Cameroon":"CMR","Central African Republic":"CAF","Chad":"TCD",
    "Comoros":"COM","Congo":"COG","Cote d'Ivoire":"CIV","Ivory Coast":"CIV",
    "Democratic Republic of the Congo":"COD","Djibouti":"DJI","Egypt":"EGY",
    "Equatorial Guinea":"GNQ","Eritrea":"ERI","Eswatini":"SWZ","Ethiopia":"ETH",
    "Gabon":"GAB","Gambia":"GMB","Ghana":"GHA","Guinea":"GIN",
    "Guinea-Bissau":"GNB","Kenya":"KEN","Lesotho":"LSO","Liberia":"LBR",
    "Libya":"LBY","Madagascar":"MDG","Malawi":"MWI","Mali":"MLI",
    "Mauritania":"MRT","Mauritius":"MUS","Morocco":"MAR","Mozambique":"MOZ",
    "Namibia":"NAM","Niger":"NER","Nigeria":"NGA","Rwanda":"RWA",
    "Sao Tome and Principe":"STP","Senegal":"SEN","Seychelles":"SYC",
    "Sierra Leone":"SLE","Somalia":"SOM","South Africa":"ZAF",
    "South Sudan":"SSD","Sudan":"SDN",
    "United Republic of Tanzania":"TZA","Tanzania":"TZA",
    "Togo":"TGO","Tunisia":"TUN","Uganda":"UGA",
    "Zambia":"ZMB","Zimbabwe":"ZWE",
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


# ── Chargement fichiers agrégés pays × année ─────────────────────────────────
def load_cy_file(path: Path, value_col: str) -> pd.DataFrame:
    """
    Charge un fichier ACLED agrégé country-year.
    Format : COUNTRY | YEAR | <valeur>
    Retourne DataFrame [iso3, year, <value_col>] filtré Afrique 2010-2024.
    """
    if not path.exists():
        log.warning("Fichier absent : %s", path)
        return pd.DataFrame()

    df = pd.read_excel(path)
    df["iso3"] = df["COUNTRY"].map(NAME_TO_ISO3)
    df = df[df["iso3"].notna()].copy()
    df["year"] = pd.to_numeric(df["YEAR"], errors="coerce")
    df[value_col] = pd.to_numeric(df.iloc[:, 2], errors="coerce").fillna(0)
    df = df[
        (df["year"] >= YEAR_FROM) & (df["year"] <= YEAR_TO)
    ]
    log.info("%-30s : %d lignes | %d pays | %d-%d",
             path.name, len(df), df["iso3"].nunique(),
             int(df["year"].min()) if len(df) else 0,
             int(df["year"].max()) if len(df) else 0)
    return df[["iso3", "year", value_col]]


# ── Transformation log(1+x) ───────────────────────────────────────────────────
def log_transform(df: pd.DataFrame, col: str) -> pd.DataFrame:
    """Applique log(1+x) sur la colonne spécifiée."""
    df = df.copy()
    df[col] = df[col].apply(lambda x: math.log(1 + max(0, x)))
    return df


# ── Calcul GEO_CON ────────────────────────────────────────────────────────────
def compute_geo_con(african_iso3: set) -> dict:
    """
    GEO_CON : log(1 + nb_evenements) par pays × année.
    Score brut non normalisé — la normalisation est faite par L3.
    """
    df = load_cy_file(FILE_VIOLENCE, "events")
    if df.empty:
        return {}

    df = log_transform(df, "events")
    df = df[df["iso3"].isin(african_iso3)]

    result = {}
    for _, row in df.iterrows():
        result[(row["iso3"], int(row["year"]))] = round(float(row["events"]), 4)

    log.info("GEO_CON : %d valeurs calculées", len(result))
    return result


# ── Calcul GEO_TER ────────────────────────────────────────────────────────────
def compute_geo_ter(african_iso3: set) -> dict:
    """
    GEO_TER : log(1 + fatalites_totales) par pays × année.
    """
    df = load_cy_file(FILE_FATALITIES, "fatalities")
    if df.empty:
        return {}

    df = log_transform(df, "fatalities")
    df = df[df["iso3"].isin(african_iso3)]

    result = {}
    for _, row in df.iterrows():
        result[(row["iso3"], int(row["year"]))] = round(float(row["fatalities"]), 4)

    log.info("GEO_TER : %d valeurs calculées", len(result))
    return result


# ── Calcul PGEO_STR ───────────────────────────────────────────────────────────
def compute_pgeo_str(african_iso3: set) -> dict:
    """
    PGEO_STR : fatalites_civils / fatalites_totales [0,1].
    Mesure la proportion de civils dans les victimes.
    """
    df_civ = load_cy_file(FILE_CIVILIAN,   "civ_fat")
    df_tot = load_cy_file(FILE_FATALITIES, "tot_fat")

    if df_civ.empty or df_tot.empty:
        return {}

    df = df_civ.merge(df_tot, on=["iso3", "year"], how="inner")
    df = df[df["iso3"].isin(african_iso3)]

    result = {}
    for _, row in df.iterrows():
        tot = float(row["tot_fat"])
        civ = float(row["civ_fat"])
        if tot > 0:
            ratio = round(min(1.0, civ / tot), 4)
            result[(row["iso3"], int(row["year"]))] = ratio

    log.info("PGEO_STR : %d valeurs calculées", len(result))
    return result


# ── Calcul MIL_TER ────────────────────────────────────────────────────────────
def compute_mil_ter(african_iso3: set) -> dict:
    """
    MIL_TER : risque terroriste normalisé [0,100].
    Utilise le même fichier violence_cy — proxy terrorisme.
    Normalisation intra-année pour comparaison relative.
    """
    df = load_cy_file(FILE_VIOLENCE, "events")
    if df.empty:
        return {}

    df = log_transform(df, "events")
    df = df[df["iso3"].isin(african_iso3)]

    # Normalisation intra-année [0,100]
    result = {}
    for year in df["year"].unique():
        yr_df = df[df["year"] == year]
        vmin  = yr_df["events"].min()
        vmax  = yr_df["events"].max()
        for _, row in yr_df.iterrows():
            if vmax == vmin:
                score = 50.0
            else:
                score = round((row["events"] - vmin) / (vmax - vmin) * 100, 4)
            result[(row["iso3"], int(year))] = float(score)

    log.info("MIL_TER : %d valeurs calculées", len(result))
    return result



def compute_pgeo_civ(african_iso3: set) -> dict:
    """PGEO_CIV : log(1 + evenements ciblant les civils) par pays x annee."""
    df = load_cy_file(FILE_CIVILIANS, "civ_events")
    if df.empty:
        return {}
    df = log_transform(df, "civ_events")
    df = df[df["iso3"].isin(african_iso3)]
    result = {}
    for _, row in df.iterrows():
        result[(row["iso3"], int(row["year"]))] = round(float(row["civ_events"]), 4)
    log.info("PGEO_CIV : %d valeurs calculees", len(result))
    return result
# ── Calcul MIN_SEC (buffer spatial) ──────────────────────────────────────────
def compute_min_sec(conn, african_iso3: set) -> dict:
    """
    MIN_SEC : score de sécurité des sites miniers.
    Buffer 50km autour de chaque site osa.pgeo_site.
    Agrège les fatalités ACLED géolocalisées dans le buffer.
    Normalise [0,100] et inverse (moins de fatalités = score élevé).
    """
    # Vérifier que pgeo_site est peuplé
    with conn.cursor() as cur:
        cur.execute("SELECT COUNT(*) FROM osa.pgeo_site")
        n_sites = cur.fetchone()[0]

    if n_sites == 0:
        log.warning("MIN_SEC : osa.pgeo_site vide — lancez fetcher_pgeo_wikipedia.py d'abord")
        return {}

    if not FILE_GEO.exists():
        log.warning("MIN_SEC : %s absent", FILE_GEO)
        return {}

    try:
        import geopandas as gpd
        from shapely.geometry import Point
    except ImportError:
        log.warning("MIN_SEC : geopandas non installé — pip install geopandas")
        return {}

    log.info("MIN_SEC : chargement acled_africa.xlsx (%d sites PGEO)...", n_sites)

    # Charger les sites miniers
    with conn.cursor() as cur:
        cur.execute("""
            SELECT site_code, country_iso3, latitude, longitude
            FROM osa.pgeo_site
            WHERE latitude IS NOT NULL AND longitude IS NOT NULL
        """)
        sites = cur.fetchall()

    if not sites:
        log.warning("MIN_SEC : aucun site avec coordonnées dans osa.pgeo_site")
        return {}

    sites_gdf = gpd.GeoDataFrame(
        sites,
        columns=["site_code", "iso3", "lat", "lon"],
        geometry=[Point(r[3], r[2]) for r in sites],
        crs="EPSG:4326"
    ).to_crs(epsg=3857)
    sites_gdf["buffer"] = sites_gdf.geometry.buffer(BUFFER_M)

    # Charger ACLED géolocalisé
    log.info("  Lecture acled_africa.xlsx...")
    df_geo = pd.read_excel(FILE_GEO)
    df_geo["year"] = pd.to_datetime(df_geo["WEEK"], errors="coerce").dt.year
    df_geo = df_geo[
        (df_geo["year"] >= YEAR_FROM) &
        (df_geo["year"] <= YEAR_TO) &
        df_geo["CENTROID_LATITUDE"].notna() &
        df_geo["CENTROID_LONGITUDE"].notna()
    ].copy()

    acled_gdf = gpd.GeoDataFrame(
        df_geo,
        geometry=gpd.points_from_xy(
            df_geo["CENTROID_LONGITUDE"],
            df_geo["CENTROID_LATITUDE"]
        ),
        crs="EPSG:4326"
    ).to_crs(epsg=3857)

    log.info("  %d événements ACLED géolocalisés (%d-%d)",
             len(acled_gdf), YEAR_FROM, YEAR_TO)

    # Jointure spatiale par année
    result_raw = {}   # {(iso3, year): fatalities_in_buffer}

    buffer_gdf = sites_gdf[["iso3", "buffer"]].set_geometry("buffer")

    for year in range(YEAR_FROM, YEAR_TO + 1):
        acled_yr = acled_gdf[acled_gdf["year"] == year]
        if acled_yr.empty:
            continue

        joined = gpd.sjoin(
            acled_yr[["FATALITIES", "geometry"]],
            buffer_gdf,
            how="inner",
            predicate="within"
        )

        fat_by_iso3 = joined.groupby("iso3")["FATALITIES"].sum()
        for iso3, fat in fat_by_iso3.items():
            key = (str(iso3), year)
            result_raw[key] = result_raw.get(key, 0) + float(fat)

    if not result_raw:
        log.warning("MIN_SEC : aucune correspondance spatiale trouvée")
        return {}

    # Normalisation globale [0,100] puis inversion
    vals = list(result_raw.values())
    vmin, vmax = min(vals), max(vals)

    result = {}
    for (iso3, year), fat in result_raw.items():
        if iso3 not in african_iso3:
            continue
        if vmax == vmin:
            score = 50.0
        else:
            # Inverser : plus de fatalités = moins sûr = score bas
            score = round(100 - (fat - vmin) / (vmax - vmin) * 100, 4)
        result[(iso3, year)] = score

    log.info("MIN_SEC : %d valeurs calculées (%d pays)",
             len(result), len(set(k[0] for k in result)))
    return result


# ── Construction des enregistrements ─────────────────────────────────────────
def build_records(
    osa_code: str,
    data: dict,
    method_version: int,
) -> list:
    records = []
    for (iso3, year), val in data.items():
        records.append((
            osa_code, iso3, year, LAYER_RAW,
            val, None, method_version, "OK",
        ))
    return records


# ── Insertion batch ───────────────────────────────────────────────────────────
def insert_records(conn, records: list, dry_run: bool = False) -> int:
    if not records:
        return 0

    osa_code = records[0][0]

    if dry_run:
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
def print_summary(conn, codes: list):
    with conn.cursor() as cur:
        cur.execute("""
            SELECT indicator_code,
                   COUNT(*) AS total, COUNT(DISTINCT country_iso3) AS pays,
                   MIN(year) AS yr_min, MAX(year) AS yr_max,
                   ROUND(MIN(raw_value)::numeric,3) AS vmin,
                   ROUND(MAX(raw_value)::numeric,3) AS vmax
            FROM ma.indicator_values
            WHERE layer_id = %s AND indicator_code IN %s
            GROUP BY indicator_code ORDER BY indicator_code
        """, (LAYER_RAW, tuple(codes)))
        rows = cur.fetchall()
        if rows:
            log.info("Bilan final :")
            log.info("  %-12s %7s %5s %6s %6s %8s %8s",
                     "Code","Lignes","Pays","YMin","YMax","Min","Max")
            for r in rows:
                log.info("  %-12s %7d %5d %6d %6d %8.3f %8.3f", *r)


# ── Point d'entrée ────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(
        description="OSA -- Fetcher ACLED Excel (GEO_CON, GEO_TER, PGEO_STR, MIL_TER, MIN_SEC)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Indicateurs produits :
  GEO_CON   log(1+events)           PGEO  conflits
  GEO_TER   log(1+fatalities)       PGEO  impact humain
  PGEO_STR  civils/total            PGEO  structure victimes
  MIL_TER   events normalise [0,100] PMIL  risque terroriste
  MIN_SEC   buffer 50km [0,100]     PMIN  securite sites

Exemples :
  python fetcher_acled_xlsx.py --dry-run
  python fetcher_acled_xlsx.py
  python fetcher_acled_xlsx.py --indicator GEO_CON
  python fetcher_acled_xlsx.py --skip-buffer  (ignorer MIN_SEC spatial)
        """
    )
    parser.add_argument(
        "--indicator",
        choices=["GEO_CON","GEO_TER","PGEO_STR","PGEO_CIV","MIL_TER","MIN_SEC"],
        default=None,
        help="Calculer un seul indicateur"
    )
    parser.add_argument(
        "--skip-buffer", action="store_true",
        help="Ignorer MIN_SEC (jointure spatiale lente)"
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Simulation sans écriture en base"
    )
    parser.add_argument(
        "--output",
        choices=["csv","db","both"],
        default="both",
        help="Mode de sortie (compatibilité orchestrateur)"
    )
    args = parser.parse_args()

    log.info("=" * 55)
    log.info("OSA -- Fetcher ACLED Excel")
    log.info("Indicateur : %s", args.indicator or "tous (5)")
    log.info("Dry-run    : %s", args.dry_run)
    log.info("=" * 55)

    conn = get_conn()
    try:
        african_iso3   = get_african_countries(conn)
        method_version = get_method_version(conn)
        total          = 0

        indicators = {
            "GEO_CON":  lambda: compute_geo_con(african_iso3),
            "GEO_TER":  lambda: compute_geo_ter(african_iso3),
            "PGEO_STR": lambda: compute_pgeo_str(african_iso3),
            "MIL_TER":  lambda: compute_mil_ter(african_iso3),
            "PGEO_CIV":  lambda: compute_pgeo_civ(african_iso3),
            "MIN_SEC":  lambda: compute_min_sec(conn, african_iso3),
        }

        codes_done = []
        for i, (osa_code, compute_fn) in enumerate(indicators.items(), 1):
            if args.indicator and osa_code != args.indicator:
                continue
            if args.skip_buffer and osa_code == "MIN_SEC":
                log.info("[%d/%d] %s — ignoré (--skip-buffer)",
                         i, len(indicators), osa_code)
                continue

            log.info("[%d/%d] %s", i, len(indicators), osa_code)
            data    = compute_fn()
            records = build_records(osa_code, data, method_version)
            n       = insert_records(conn, records, args.dry_run)
            total  += n
            codes_done.append(osa_code)

        if not args.dry_run and codes_done:
            print_summary(conn, codes_done)

        log.info("=" * 55)
        log.info("ACLED terminé | +%d valeurs insérées", total)
        log.info("=" * 55)

    finally:
        conn.close()


if __name__ == "__main__":
    main()
