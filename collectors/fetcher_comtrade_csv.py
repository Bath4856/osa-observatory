"""
OSA Observatory
collectors/fetcher_comtrade_csv.py -- Ingestion Comtrade+ minerais

Calcule MIN_COM (Commerce minier) depuis les exports CSV Comtrade+ v2.

Source : https://comtradeplus.un.org
Format : CSV export API v2
Colonnes clés : reporterISO, refYear, cmdCode, flowCode,
                primaryValue, fobvalue, cifvalue

Codes HS couverts (chapitres miniers complets) :
  25 : Sel, soufre, terres, pierres, platres, chaux, ciment
  26 : Minerais, scories et cendres (tous metaux)
  27 : Combustibles mineraux, huiles, hydrocarbures
  28 : Produits chimiques inorganiques (uranium, thorium)
  71 : Perles, pierres precieuses, metaux precieux, bijouterie

Indicateurs produits :
  MIN_COM  <- Valeur totale commerce minier (export + import) normalise [0,100]
              par pays × annee × chapitre HS

Usage :
  python collectors/fetcher_comtrade_csv.py --dry-run
  python collectors/fetcher_comtrade_csv.py
  python collectors/fetcher_comtrade_csv.py \\
      --dir data/raw/pmin/comtrade \\
      --dry-run
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
log = logging.getLogger("fetcher_comtrade")

# ── Constantes ────────────────────────────────────────────────────────────────
LAYER_RAW  = 1
YEAR_FROM  = 2010
YEAR_TO    = 2024
BATCH_SIZE = 500

DEFAULT_DIR = Path("data/raw/pmin/comtrade")

# Chapitres HS miniers OSA
HS_MINERAL_CHAPTERS = {"25", "26", "27", "28", "71"}

# Mapping chapitre HS → catégorie ressource OSA
HS_TO_CATEGORY = {
    "25": "Non-metal",
    "26": "Metal",
    "27": "Hydrocarbon",
    "28": "Chemical",
    "71": "Precious",
}

# Pays africains ISO3 (mapping nom → ISO3 pour Comtrade qui utilise parfois les noms)
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

AFRICA_ISO3 = set(NAME_TO_ISO3.values())


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


# ── Chargement des fichiers CSV Comtrade ──────────────────────────────────────
def load_comtrade_dir(data_dir: Path) -> pd.DataFrame:
    """
    Charge tous les fichiers CSV Comtrade dans le dossier.
    Supporte le format API v2 Comtrade+.
    """
    csv_files = list(data_dir.glob("*.csv"))
    if not csv_files:
        log.error("Aucun fichier CSV dans : %s", data_dir)
        sys.exit(1)

    dfs = []
    for f in sorted(csv_files):
        try:
            df = pd.read_csv(f, encoding="latin-1", low_memory=False)
            log.info("  Chargé : %s (%d lignes)", f.name, len(df))
            dfs.append(df)
        except Exception as e:
            log.warning("  Erreur lecture %s : %s", f.name, e)

    if not dfs:
        log.error("Aucun fichier lisible")
        sys.exit(1)

    df = pd.concat(dfs, ignore_index=True)
    log.info("Total brut : %d lignes", len(df))
    return df


def normalize_comtrade(df: pd.DataFrame) -> pd.DataFrame:
    """Format Comtrade+ v2 — colonnes fixes connues."""
    HS_NAME_MAP = {
        "Salt; sulphur; earths, stone; plastering materials, lime and cement": "25",
        "Ores, slag and ash": "26",
        "Mineral fuels, mineral oils and products of their distillation; bituminous substances; mineral waxes": "27",
        "Inorganic chemicals; organic and inorganic compounds of precious metals; of rare earth metals, of radio-active elements and of isotopes": "28",
        "Natural, cultured pearls; precious, semi-precious stones; precious metals, metals clad with precious metal, and articles thereof; imitation jewellery; coin": "71",
    }
    df = df.copy()
    df["iso3"]        = df["reporterCode"].astype(str).str.strip().str.upper()
    df["year"]        = pd.to_numeric(df["refPeriodId"], errors="coerce")
    df["hs_chapter"]  = df["cmdCode"].map(HS_NAME_MAP)
    df["trade_value"] = pd.to_numeric(df["fobvalue"], errors="coerce").fillna(0)
    df["flow"]        = df["flowCode"].astype(str).str.upper().str[:1]
    df = df[df["iso3"].isin(AFRICA_ISO3)]
    df = df[df["year"].between(YEAR_FROM, YEAR_TO)]
    df = df[df["hs_chapter"].isin(HS_MINERAL_CHAPTERS)]
    log.info("Apres filtres : %d lignes | %d pays | annees %d-%d | chapitres : %s",
             len(df), df["iso3"].nunique(),
             int(df["year"].min()) if len(df) else 0,
             int(df["year"].max()) if len(df) else 0,
             sorted(df["hs_chapter"].unique().tolist()))
    return df[["iso3", "year", "hs_chapter", "flow", "trade_value"]]

def normalize_comtrade_legacy(df: pd.DataFrame) -> pd.DataFrame:
    """Ancienne version avec detection automatique — conservee pour compatibilite."""
    """
    Normalise le DataFrame Comtrade v2 :
    - Détecte les colonnes reporter ISO3 et année
    - Mappe noms pays → ISO3 si nécessaire
    - Filtre sur les chapitres HS miniers
    - Filtre Afrique + 2010-2024
    """
    # ── Détecter colonne ISO3 reporter ───────────────────────────────────────
    iso_col = None
    for candidate in ["reporterCode", "reporterISO", "Reporter ISO", "iso3", "reporter_iso"]:
        if candidate in df.columns:
            iso_col = candidate
            break

    if iso_col is None:
        log.error("Colonne ISO3 introuvable. Colonnes : %s", list(df.columns[:10]))
        sys.exit(1)

    # Vérifier si la colonne contient des ISO3 ou des noms
    sample = df[iso_col].dropna().iloc[0] if len(df) > 0 else ""
    if len(str(sample)) > 3:
        # Noms de pays → mapper vers ISO3
        log.info("Conversion noms pays → ISO3...")
        df["iso3"] = df[iso_col].map(NAME_TO_ISO3)
    else:
        df["iso3"] = df[iso_col].astype(str).str.strip().str.upper()

    # ── Détecter colonne année ────────────────────────────────────────────────
    year_col = None
    for candidate in ["refPeriodId", "refYear", "Year", "year", "period", "Period"]:
        if candidate in df.columns:
            year_col = candidate
            break

    if year_col is None:
        log.error("Colonne année introuvable")
        sys.exit(1)

    df["year"] = pd.to_numeric(df[year_col], errors="coerce")

    # ── Détecter colonne cmdCode ──────────────────────────────────────────────
    cmd_col = None
    for candidate in ["cmdCode", "CmdCode", "commodity", "Commodity Code"]:
        if candidate in df.columns:
            cmd_col = candidate
            break

    if cmd_col is None:
        log.error("Colonne cmdCode introuvable")
        sys.exit(1)

    df["hs_code"] = df[cmd_col].astype(str).str.strip()

    # ── Détecter colonne valeur ───────────────────────────────────────────────
    val_col = None
    for candidate in ["fobvalue", "FOBvalue", "primaryValue", "TradeValue", "tradeValue", "Value"]:
        if candidate in df.columns and pd.to_numeric(
            df[candidate], errors="coerce"
        ).sum() > 0:
            val_col = candidate
            break

    if val_col is None:
        log.error("Colonne valeur introuvable ou vide")
        sys.exit(1)

    df["trade_value"] = pd.to_numeric(df[val_col], errors="coerce").fillna(0)

    # ── Détecter flux (Import/Export) ─────────────────────────────────────────
    flow_col = None
    for candidate in ["flowCode", "FlowCode", "flowDesc", "Flow"]:
        if candidate in df.columns:
            flow_col = candidate
            break

    if flow_col:
        df["flow"] = df[flow_col].astype(str).str.upper().str[:1]  # M ou X
    else:
        df["flow"] = "X"  # Export par défaut

    # ── Extraire chapitre HS (2 premiers chiffres) ────────────────────────────
    df["hs_chapter"] = df["hs_code"].str[:2]

    # ── Filtres ───────────────────────────────────────────────────────────────
    # Chapitres miniers uniquement
    df = df[df["hs_chapter"].isin(HS_MINERAL_CHAPTERS)]

    # Afrique uniquement
    df = df[df["iso3"].isin(AFRICA_ISO3)]

    # Années 2010-2024
    df = df[
        (df["year"] >= YEAR_FROM) &
        (df["year"] <= YEAR_TO)
    ]


    log.info(
        "Après filtres : %d lignes | %d pays | années %d-%d | chapitres : %s",
        len(df),
        df["iso3"].nunique(),
        int(df["year"].min()) if len(df) else 0,
        int(df["year"].max()) if len(df) else 0,
        sorted(df["hs_chapter"].unique().tolist()),
    )

    return df[["iso3", "year", "hs_chapter", "flow", "trade_value"]]


# ── Calcul MIN_COM ────────────────────────────────────────────────────────────
def compute_min_com(df: pd.DataFrame) -> dict:
    """
    Calcule MIN_COM par pays × année.

    Méthode :
    1. Agréger trade_value par pays × année (export + import)
    2. log(1 + total) pour compresser les extrêmes
    3. Normalisation intra-année [0,100]

    Retourne dict {(iso3, year): score}
    """
    # Agrégation pays × année (toutes ressources confondues)
    agg = (
        df.groupby(["iso3", "year"])["trade_value"]
        .sum()
        .reset_index()
        .rename(columns={"trade_value": "total_value"})
    )

    # log(1 + x)
    agg["log_value"] = agg["total_value"].apply(lambda x: math.log(1 + x))

    # Normalisation intra-année [0,100]
    result = {}
    for year in agg["year"].unique():
        yr = agg[agg["year"] == year]
        vmin = yr["log_value"].min()
        vmax = yr["log_value"].max()

        for _, row in yr.iterrows():
            if vmax == vmin:
                score = 50.0
            else:
                score = round(
                    (row["log_value"] - vmin) / (vmax - vmin) * 100, 4
                )
            result[(row["iso3"], int(year))] = float(score)

    log.info("MIN_COM : %d valeurs calculées (%d pays)",
             len(result), len(set(k[0] for k in result)))
    return result


def compute_min_com_by_chapter(df: pd.DataFrame) -> dict:
    """
    Calcule MIN_COM ventilé par chapitre HS.
    Utile pour analyse par type de ressource.
    Retourne dict {(iso3, year, chapter): score}
    """
    agg = (
        df.groupby(["iso3", "year", "hs_chapter"])["trade_value"]
        .sum()
        .reset_index()
    )

    agg["log_value"] = agg["trade_value"].apply(lambda x: math.log(1 + x))

    result = {}
    for (year, chapter), grp in agg.groupby(["year", "hs_chapter"]):
        vmin = grp["log_value"].min()
        vmax = grp["log_value"].max()
        for _, row in grp.iterrows():
            if vmax == vmin:
                score = 50.0
            else:
                score = round(
                    (row["log_value"] - vmin) / (vmax - vmin) * 100, 4
                )
            result[(row["iso3"], int(year), chapter)] = score

    return result


# ── Construction des enregistrements ─────────────────────────────────────────
def build_records(
    data: dict,
    african_iso3: set,
    method_version: int,
) -> list:
    records = []
    for (iso3, year), val in data.items():
        if iso3 not in african_iso3:
            continue
        records.append((
            "MIN_COM", iso3, year, LAYER_RAW,
            val, None, method_version, "OK",
        ))
    return records


# ── Insertion batch ───────────────────────────────────────────────────────────
def insert_records(conn, records: list, dry_run: bool = False) -> int:
    if not records:
        return 0

    if dry_run:
        log.info("[DRY-RUN] MIN_COM → %d enregistrements (non insérés)",
                 len(records))
        return len(records)

    # Supprimer les anciennes valeurs proxy MIN_COM avant d'insérer
    with conn.cursor() as cur:
        cur.execute(
            "DELETE FROM ma.indicator_values "
            "WHERE indicator_code = 'MIN_COM' AND layer_id = %s",
            (LAYER_RAW,)
        )
        deleted = cur.rowcount
    if deleted > 0:
        log.info("Suppression %d anciennes valeurs MIN_COM proxy", deleted)

    sql = """
        INSERT INTO ma.indicator_values
            (indicator_code, country_iso3, year, layer_id,
             raw_value, processed_value, method_version_id, quality_flag)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT DO NOTHING
    """

    with conn.cursor() as cur:
        execute_batch(cur, sql, records, page_size=BATCH_SIZE)
    conn.commit()

    with conn.cursor() as cur:
        cur.execute(
            "SELECT COUNT(*) FROM ma.indicator_values "
            "WHERE indicator_code = 'MIN_COM' AND layer_id = %s",
            (LAYER_RAW,)
        )
        total = cur.fetchone()[0]

    log.info("MIN_COM → %d valeurs insérées", total)
    return total


# ── Bilan final ───────────────────────────────────────────────────────────────
def print_summary(conn):
    with conn.cursor() as cur:
        cur.execute("""
            SELECT COUNT(*) AS total,
                   COUNT(DISTINCT country_iso3) AS pays,
                   MIN(year) AS yr_min, MAX(year) AS yr_max,
                   ROUND(MIN(raw_value)::numeric, 1) AS vmin,
                   ROUND(MAX(raw_value)::numeric, 1) AS vmax,
                   ROUND(AVG(raw_value)::numeric, 1) AS vmoy
            FROM ma.indicator_values
            WHERE indicator_code = 'MIN_COM' AND layer_id = %s
        """, (LAYER_RAW,))
        row = cur.fetchone()
        if row and row[0]:
            log.info("Bilan MIN_COM : %d lignes | %d pays | %d-%d | [%.1f, %.1f] moy=%.1f",
                     *row)


# ── Point d'entrée ────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(
        description="OSA -- Fetcher Comtrade CSV (MIN_COM commerce minier)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Indicateur produit :
  MIN_COM  Commerce minier total (export+import) normalise [0,100]
           Chapitres HS : 25, 26, 27, 28, 71

Fichiers attendus dans --dir :
  comtrade_minerals_2010_2021.csv  (export Comtrade+ 2010-2021)
  comtrade_minerals_2022_2024.csv  (export Comtrade+ 2022-2024)

Telechargement :
  https://comtradeplus.un.org
  Reporter : 54 pays africains
  Commodity : 25, 26, 27, 28, 71
  Flow : Import + Export
  Format : CSV

Exemples :
  python fetcher_comtrade_csv.py --dry-run
  python fetcher_comtrade_csv.py --dir data/raw/pmin/comtrade
  python fetcher_comtrade_csv.py --dir data/raw/pmin/comtrade --dry-run
        """
    )
    parser.add_argument(
        "--dir",
        default=str(DEFAULT_DIR),
        help=f"Dossier contenant les CSV Comtrade (défaut: {DEFAULT_DIR})"
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

    data_dir = Path(args.dir)
    if not data_dir.exists():
        log.error("Dossier introuvable : %s", data_dir)
        sys.exit(1)

    log.info("=" * 55)
    log.info("OSA -- Fetcher Comtrade CSV")
    log.info("Dossier    : %s", data_dir)
    log.info("Dry-run    : %s", args.dry_run)
    log.info("=" * 55)

    # ── 1. Charger tous les CSV ───────────────────────────────────────────────
    df_raw = load_comtrade_dir(data_dir)

    # ── 2. Normaliser ────────────────────────────────────────────────────────
    df = normalize_comtrade(df_raw)

    if df.empty:
        log.error("Aucune donnée après filtrage — vérifiez les codes HS et pays")
        sys.exit(1)

    # ── 3. Calculer MIN_COM ───────────────────────────────────────────────────
    data = compute_min_com(df)

    # ── 4. Insérer en base ────────────────────────────────────────────────────
    conn = get_conn()
    try:
        african_iso3   = get_african_countries(conn)
        method_version = get_method_version(conn)

        records = build_records(data, african_iso3, method_version)
        n = insert_records(conn, records, args.dry_run)

        if not args.dry_run:
            print_summary(conn)

        log.info("=" * 55)
        log.info("Comtrade terminé | +%d valeurs MIN_COM insérées", n)
        log.info("=" * 55)

    finally:
        conn.close()


if __name__ == "__main__":
    main()
