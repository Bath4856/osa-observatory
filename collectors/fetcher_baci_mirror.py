"""
OSA Observatory
collectors/fetcher_baci_mirror.py -- Mirror gap BACI → PMIN_VALUE_CAPTURE

Source : BACI HS92 V202601 (CEPII)
        http://www.cepii.fr/CEPII/en/bdd_modele/bdd_modele_item.asp?id=37

Méthode mirror gap (doctrine OSA conséquentialiste) :
    PMIN_VALUE_CAPTURE = exports africains déclarés (BACI)
                       / imports déclarés par les partenaires (BACI)
                       × 100

    Ratio < 100 → fuite de valeur (le partenaire déclare avoir acheté
                  plus que le pays africain déclare avoir vendu)
    Ratio > 100 → sur-déclaration exports (rare, signale souvent
                  du transit ou de la réexportation)

Chapitres HS couverts :
    26 — Minerais, scories et cendres
    27 — Combustibles minéraux, hydrocarbures
    71 — Métaux précieux, pierres précieuses, bijouterie

Indicateur produit :
    PMIN_VALUE_CAPTURE  [0–200] normalisé, layer 1
    (valeur brute = ratio exports/imports × 100, non borné)

Usage :
    # Extraction + calcul + dry-run
    python fetcher_baci_mirror.py --zip ~/baci_hs92.zip --dry-run

    # Production complète
    python fetcher_baci_mirror.py --zip ~/baci_hs92.zip

    # Depuis CSV déjà extrait
    python fetcher_baci_mirror.py --csv ~/baci_hs92_filtered.csv

    # Mise à jour annuelle (dépose le nouveau zip et relance)
    python fetcher_baci_mirror.py --zip ~/baci_hs92_V202701.zip
"""

import argparse
import logging
import math
import os
import sys
import zipfile
from pathlib import Path

import pandas as pd
import psycopg2
from psycopg2.extras import execute_batch

logging.basicConfig(
    level=os.getenv("OSA_LOG_LEVEL", "INFO"),
    format="%(asctime)s | %(levelname)-8s | %(message)s",
)
log = logging.getLogger("fetcher_baci_mirror")

# ── Constantes ────────────────────────────────────────────────────────────────
LAYER_RAW   = 1
YEAR_FROM   = 2010
YEAR_TO     = 2024
BATCH_SIZE  = 500
INDICATOR   = "PMIN_VALUE_CAPTURE"

# Chapitres HS miniers OSA (2 premiers chiffres du code produit BACI)
HS_CHAPTERS = {"26", "27", "71"}

# Pays africains ISO3 — source UNStats
AFRICA_ISO3 = {
    "DZA","AGO","BEN","BWA","BFA","BDI","CMR","CPV","CAF","TCD","COM","COD","COG",
    "CIV","DJI","EGY","GNQ","ERI","SWZ","ETH","GAB","GMB","GHA","GIN","GNB","KEN",
    "LSO","LBR","LBY","MDG","MWI","MLI","MRT","MUS","MAR","MOZ","NAM","NER","NGA",
    "RWA","STP","SEN","SYC","SLE","SOM","ZAF","SSD","SDN","TZA","TGO","TUN","UGA",
    "ZMB","ZWE",
}

# Mapping code numérique BACI → ISO3
# BACI utilise les codes numériques UN M49
# Fichier country_codes fourni dans le ZIP BACI
BACI_CODE_TO_ISO3 = {}  # chargé dynamiquement depuis country_codes_V202601.csv


# ── Connexion PostgreSQL ──────────────────────────────────────────────────────
def get_conn():
    return psycopg2.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=int(os.getenv("DB_PORT", 5432)),
        dbname=os.getenv("DB_NAME", "osa_db"),
        user=os.getenv("DB_USER", "postgres"),
        password=os.getenv("DB_PASSWORD", ""),
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


# ── Chargement codes pays BACI ────────────────────────────────────────────────
def load_country_codes(zip_path: Path) -> dict:
    """
    Charge le mapping code numérique BACI → ISO3 depuis le ZIP.
    Le fichier country_codes_V*.csv est inclus dans chaque release BACI.
    """
    global BACI_CODE_TO_ISO3
    with zipfile.ZipFile(zip_path, "r") as z:
        cc_files = [f for f in z.namelist() if "country_codes" in f.lower() and f.endswith(".csv")]
        if not cc_files:
            log.warning("Fichier country_codes introuvable dans le ZIP — utilisation du mapping intégré")
            return {}
        with z.open(cc_files[0]) as f:
            df = pd.read_csv(f, encoding="latin-1")
            log.info("Codes pays chargés : %d entrées depuis %s", len(df), cc_files[0])

        # Colonnes BACI : country_code, iso_3digit_alpha, country_name_abbreviation
        code_col = next((c for c in df.columns if "code" in c.lower()), df.columns[0])
        iso_col  = next((c for c in df.columns if "iso" in c.lower() or "alpha" in c.lower()), df.columns[1])

        mapping = {}
        for _, row in df.iterrows():
            try:
                mapping[int(row[code_col])] = str(row[iso_col]).strip().upper()
            except (ValueError, TypeError):
                pass

        BACI_CODE_TO_ISO3 = mapping
        log.info("Mapping BACI codes : %d pays chargés", len(mapping))
        return mapping


# ── Extraction et filtrage BACI ───────────────────────────────────────────────
def load_baci_zip(zip_path: Path, cache_csv: Path = None) -> pd.DataFrame:
    """
    Extrait les fichiers BACI annuels depuis le ZIP.
    Filtre sur :
      - Années 2010–2024
      - Chapitres HS 26, 27, 71
      - Exportateur OU importateur africain

    Format BACI HS92 :
      t  : année
      i  : code exportateur (numérique UN M49)
      j  : code importateur (numérique UN M49)
      k  : code produit HS6 (6 chiffres)
      v  : valeur en milliers USD
      q  : quantité (tonnes)
    """
    if cache_csv and cache_csv.exists():
        log.info("Chargement depuis cache : %s", cache_csv)
        return pd.read_csv(cache_csv, low_memory=False)

    log.info("Extraction ZIP BACI : %s", zip_path)
    dfs = []

    with zipfile.ZipFile(zip_path, "r") as z:
        # Charger les codes pays d'abord
        load_country_codes(zip_path)

        # Fichiers annuels : BACI_HS92_Y2010_V202601.csv etc.
        annual_files = sorted([
            f for f in z.namelist()
            if f.endswith(".csv") and "_Y" in f and "country" not in f.lower()
        ])
        log.info("Fichiers annuels trouvés : %d", len(annual_files))

        for fname in annual_files:
            # Extraire l'année depuis le nom de fichier
            try:
                year = int([p for p in fname.replace(".csv","").split("_") if p.startswith("Y")][0][1:])
            except (IndexError, ValueError):
                log.warning("Impossible d'extraire l'année de : %s", fname)
                continue

            if not (YEAR_FROM <= year <= YEAR_TO):
                continue

            log.info("  Chargement %s (année %d)...", fname, year)
            with z.open(fname) as f:
                df = pd.read_csv(f, encoding="latin-1", low_memory=False,
                                 dtype={"k": str})

            # Normaliser colonnes
            df.columns = [c.strip().lower() for c in df.columns]
            df["t"] = year

            # Chapitre HS (2 premiers chiffres du code produit)
            df["hs_chapter"] = df["k"].astype(str).str.zfill(6).str[:2]
            df = df[df["hs_chapter"].isin(HS_CHAPTERS)]
            if df.empty:
                continue

            # Mapper codes pays → ISO3
            df["exporter_iso3"] = df["i"].map(BACI_CODE_TO_ISO3)
            df["importer_iso3"] = df["j"].map(BACI_CODE_TO_ISO3)

            # Garder uniquement les flux impliquant l'Afrique
            mask = (df["exporter_iso3"].isin(AFRICA_ISO3)) | (df["importer_iso3"].isin(AFRICA_ISO3))
            df = df[mask]

            if not df.empty:
                dfs.append(df[["t", "exporter_iso3", "importer_iso3", "hs_chapter", "v"]])
                log.info("    → %d lignes retenues", len(df))

    if not dfs:
        log.error("Aucune donnée extraite — vérifier le ZIP et les paramètres")
        sys.exit(1)

    result = pd.concat(dfs, ignore_index=True)
    result["v"] = pd.to_numeric(result["v"], errors="coerce").fillna(0)

    log.info("Total extrait : %d lignes | %d–%d",
             len(result), int(result["t"].min()), int(result["t"].max()))

    # Cache pour éviter de ré-extraire
    if cache_csv:
        result.to_csv(cache_csv, index=False)
        log.info("Cache sauvegardé : %s", cache_csv)

    return result


# ── Calcul PMIN_VALUE_CAPTURE ─────────────────────────────────────────────────
def compute_value_capture(df: pd.DataFrame) -> pd.DataFrame:
    """
    Mirror gap par pays africain × année × chapitre HS.

    Pour chaque (pays_africain, année, hs_chapter) :
      - exports_declared  = somme v où exporter_iso3 = pays africain
      - imports_by_partners = somme v où importer_iso3 = pays africain
        (= ce que les partenaires déclarent avoir acheté au pays africain)

    PMIN_VALUE_CAPTURE = exports_declared / imports_by_partners × 100

    Interprétation :
      100  → parfait alignement
      < 100 → fuite de valeur (sous-déclaration exports ou sur-facturation imports)
      > 100 → sur-déclaration exports africains (transit, réexport)

    Score OSA normalisé [0–100] :
      cap à 200 (ratio > 2× = anomalie structurelle)
      puis normalisation linéaire → [0–100]
    """
    # Exports africains déclarés par le pays africain lui-même
    exports = (
        df[df["exporter_iso3"].isin(AFRICA_ISO3)]
        .groupby(["t", "exporter_iso3", "hs_chapter"])["v"]
        .sum()
        .reset_index()
        .rename(columns={"exporter_iso3": "iso3", "v": "exports_declared"})
    )

    # Imports déclarés par les partenaires (ce qu'ils disent avoir acheté à l'Afrique)
    imports = (
        df[df["importer_iso3"].isin(AFRICA_ISO3) == False]  # noqa
        [df["exporter_iso3"].isin(AFRICA_ISO3)]
        .groupby(["t", "exporter_iso3", "hs_chapter"])["v"]
        .sum()
        .reset_index()
        .rename(columns={"exporter_iso3": "iso3", "v": "imports_by_partners"})
    )

    # Reconstruire correctement : partenaires importent depuis Afrique
    imports_mirror = (
        df[df["exporter_iso3"].isin(AFRICA_ISO3) & ~df["importer_iso3"].isin(AFRICA_ISO3)]
        .groupby(["t", "exporter_iso3", "hs_chapter"])["v"]
        .sum()
        .reset_index()
        .rename(columns={"exporter_iso3": "iso3", "v": "imports_by_partners"})
    )

    # Fusion
    combined = exports.merge(
        imports_mirror,
        on=["t", "iso3", "hs_chapter"],
        how="outer"
    ).fillna(0)

    # Calcul ratio brut
    def ratio(row):
        if row["imports_by_partners"] <= 0:
            return None  # Pas de données miroir — ne pas imputer
        if row["exports_declared"] <= 0:
            return 0.0   # Exports nuls mais partenaires déclarent achats → fuite totale
        return round(row["exports_declared"] / row["imports_by_partners"] * 100, 4)

    combined["ratio_raw"] = combined.apply(ratio, axis=1)

    # Score OSA normalisé [0–100]
    # ratio_raw 100 → score 100 (alignement parfait)
    # ratio_raw 0   → score 0   (fuite totale)
    # ratio_raw 200+ → score 100 (sur-déclaration = cap)
    def normalize(r):
        if r is None:
            return None
        capped = min(r, 200.0)
        return round(capped / 2.0, 4)  # [0,200] → [0,100]

    combined["score"] = combined["ratio_raw"].apply(normalize)
    combined = combined[combined["score"].notna()]
    combined = combined.rename(columns={"t": "year"})

    log.info("PMIN_VALUE_CAPTURE : %d valeurs calculées | %d pays | %d–%d",
             len(combined),
             combined["iso3"].nunique(),
             int(combined["year"].min()),
             int(combined["year"].max()))

    # Log des cas de fuite majeure (ratio < 50%)
    fuites = combined[combined["ratio_raw"] < 50].sort_values("ratio_raw")
    if not fuites.empty:
        log.info("⚠ Fuites majeures détectées (ratio < 50%%) : %d cas", len(fuites))
        for _, row in fuites.head(10).iterrows():
            log.info("  %s HS%s %d : exports=%.0f vs miroir=%.0f → ratio=%.1f%%",
                     row["iso3"], row["hs_chapter"], int(row["year"]),
                     row["exports_declared"], row["imports_by_partners"], row["ratio_raw"])

    return combined


# ── Insertion en base ─────────────────────────────────────────────────────────
def insert_records(conn, df: pd.DataFrame, method_version: int,
                   african_iso3: set, dry_run: bool = False) -> int:
    records = []
    for _, row in df.iterrows():
        if row["iso3"] not in african_iso3:
            continue
        records.append((
            INDICATOR,
            row["iso3"],
            int(row["year"]),
            LAYER_RAW,
            float(row["ratio_raw"]),   # valeur brute = ratio %
            float(row["score"]),       # valeur normalisée [0–100]
            method_version,
            "OBSERVED",
            0.90,                      # confidence_score BACI (source harmonisée)
        ))

    if not records:
        log.warning("Aucun enregistrement à insérer")
        return 0

    if dry_run:
        log.info("[DRY-RUN] %s → %d enregistrements (non insérés)", INDICATOR, len(records))
        # Afficher un échantillon
        sample = records[:5]
        for r in sample:
            log.info("  SAMPLE: %s %s %d raw=%.1f score=%.1f",
                     r[0], r[1], r[2], r[4], r[5])
        return len(records)

    # Supprimer les anciennes valeurs avant réingestion
    with conn.cursor() as cur:
        cur.execute(
            "DELETE FROM ma.indicator_values WHERE indicator_code = %s AND layer_id = %s",
            (INDICATOR, LAYER_RAW)
        )
        deleted = cur.rowcount
    if deleted > 0:
        log.info("Suppression %d anciennes valeurs %s", deleted, INDICATOR)

    sql = """
        INSERT INTO ma.indicator_values
            (indicator_code, country_iso3, year, layer_id,
             raw_value, processed_value, method_version_id,
             value_status, confidence_score)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT DO NOTHING
    """
    with conn.cursor() as cur:
        execute_batch(cur, sql, records, page_size=BATCH_SIZE)
    conn.commit()

    with conn.cursor() as cur:
        cur.execute(
            "SELECT COUNT(*) FROM ma.indicator_values WHERE indicator_code = %s AND layer_id = %s",
            (INDICATOR, LAYER_RAW)
        )
        total = cur.fetchone()[0]

    log.info("%s → %d valeurs insérées en base", INDICATOR, total)
    return total


# ── Insérer aussi dans collect.raw_data ──────────────────────────────────────
def insert_raw_data(conn, df: pd.DataFrame, dry_run: bool = False) -> int:
    """
    Insère également dans collect.raw_data pour traçabilité L1.
    Endpoint_code : BACI_MIRROR
    """
    if dry_run:
        log.info("[DRY-RUN] collect.raw_data : %d enregistrements (non insérés)", len(df))
        return len(df)

    # Vérifier/créer l'endpoint BACI_MIRROR
    with conn.cursor() as cur:
        cur.execute("""
            INSERT INTO collect.provider_endpoints
                (endpoint_code, provider_name, description, url, is_active)
            VALUES ('BACI_MIRROR', 'CEPII BACI',
                    'Base pour données harmonisée CEPII — mirror gap minerais africains',
                    'http://www.cepii.fr/CEPII/en/bdd_modele/bdd_modele_item.asp?id=37',
                    true)
            ON CONFLICT (endpoint_code) DO NOTHING
        """)

        cur.execute(
            "SELECT id FROM collect.provider_endpoints WHERE endpoint_code = 'BACI_MIRROR'"
        )
        endpoint_id = cur.fetchone()[0]

    records = []
    for _, row in df.iterrows():
        records.append((
            endpoint_id,
            INDICATOR,
            row["iso3"],
            int(row["year"]),
            float(row["ratio_raw"]),
        ))

    sql = """
        INSERT INTO collect.raw_data
            (endpoint_id, indicator_code, country_iso3, year, value_raw)
        VALUES (%s, %s, %s, %s, %s)
        ON CONFLICT DO NOTHING
    """
    with conn.cursor() as cur:
        execute_batch(cur, sql, records, page_size=BATCH_SIZE)
    conn.commit()

    log.info("collect.raw_data : %d enregistrements BACI_MIRROR insérés", len(records))
    return len(records)


# ── Bilan final ───────────────────────────────────────────────────────────────
def print_summary(conn):
    with conn.cursor() as cur:
        cur.execute("""
            SELECT
                COUNT(*)                                AS total,
                COUNT(DISTINCT country_iso3)            AS pays,
                MIN(year)                               AS yr_min,
                MAX(year)                               AS yr_max,
                ROUND(AVG(raw_value)::numeric, 1)       AS ratio_moy,
                ROUND(MIN(raw_value)::numeric, 1)       AS ratio_min,
                ROUND(MAX(raw_value)::numeric, 1)       AS ratio_max,
                COUNT(*) FILTER (WHERE raw_value < 50)  AS fuites_majeures,
                COUNT(*) FILTER (WHERE raw_value > 150) AS sur_declarations
            FROM ma.indicator_values
            WHERE indicator_code = %s AND layer_id = %s
        """, (INDICATOR, LAYER_RAW))
        row = cur.fetchone()
        if row and row[0]:
            log.info("=" * 60)
            log.info("Bilan %s", INDICATOR)
            log.info("  Total lignes      : %d", row[0])
            log.info("  Pays couverts     : %d", row[1])
            log.info("  Période           : %d–%d", row[2], row[3])
            log.info("  Ratio moyen       : %.1f%%", row[4])
            log.info("  Ratio min/max     : %.1f%% / %.1f%%", row[5], row[6])
            log.info("  Fuites majeures   : %d (ratio < 50%%)", row[7])
            log.info("  Sur-déclarations  : %d (ratio > 150%%)", row[8])
            log.info("=" * 60)

        # Top 10 pays avec les plus grandes fuites
        cur.execute("""
            SELECT country_iso3,
                   ROUND(AVG(raw_value)::numeric, 1) AS ratio_moy,
                   COUNT(DISTINCT year)              AS nb_ans
            FROM ma.indicator_values
            WHERE indicator_code = %s AND layer_id = %s
            GROUP BY country_iso3
            ORDER BY ratio_moy ASC
            LIMIT 10
        """, (INDICATOR, LAYER_RAW))
        rows = cur.fetchall()
        if rows:
            log.info("Top 10 fuites de valeur (ratio moyen le plus bas) :")
            for r in rows:
                log.info("  %s : %.1f%% (%d années)", r[0], r[1], r[2])


# ── Point d'entrée ────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(
        description="OSA — Fetcher BACI Mirror Gap (PMIN_VALUE_CAPTURE)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Indicateur produit :
  PMIN_VALUE_CAPTURE  Mirror gap exports africains vs imports partenaires
                      Chapitres HS : 26, 27, 71
                      Source : BACI HS92 (CEPII)

Exemples :
  # Télécharger BACI sur le VPS puis lancer :
  wget https://www.cepii.fr/DATA_DOWNLOAD/baci/data/BACI_HS92_V202601.zip -O ~/baci_hs92.zip
  python fetcher_baci_mirror.py --zip ~/baci_hs92.zip --dry-run
  python fetcher_baci_mirror.py --zip ~/baci_hs92.zip

  # Mise à jour annuelle Sprint 22+ :
  wget https://www.cepii.fr/DATA_DOWNLOAD/baci/data/BACI_HS92_V202701.zip -O ~/baci_hs92_2027.zip
  python fetcher_baci_mirror.py --zip ~/baci_hs92_2027.zip
        """
    )
    parser.add_argument("--zip", type=Path, help="Chemin vers le ZIP BACI HS92")
    parser.add_argument("--csv", type=Path, help="CSV BACI déjà filtré (cache)")
    parser.add_argument("--cache", type=Path, default=Path("/tmp/baci_filtered.csv"),
                        help="Chemin cache CSV filtré (défaut: /tmp/baci_filtered.csv)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Simulation sans écriture en base")
    parser.add_argument("--output", choices=["csv", "db", "both"], default="both")
    args = parser.parse_args()

    if not args.zip and not args.csv:
        parser.error("--zip ou --csv requis")

    log.info("=" * 60)
    log.info("OSA — Fetcher BACI Mirror Gap")
    log.info("Source     : %s", args.zip or args.csv)
    log.info("Dry-run    : %s", args.dry_run)
    log.info("=" * 60)

    # 1. Charger BACI
    if args.csv:
        df_raw = pd.read_csv(args.csv, low_memory=False)
        log.info("CSV chargé : %d lignes", len(df_raw))
    else:
        df_raw = load_baci_zip(args.zip, cache_csv=args.cache)

    if df_raw.empty:
        log.error("Aucune donnée disponible")
        sys.exit(1)

    # 2. Calculer PMIN_VALUE_CAPTURE
    df_result = compute_value_capture(df_raw)

    if df_result.empty:
        log.error("Calcul mirror gap : aucun résultat")
        sys.exit(1)

    # 3. Connexion DB et insertion
    conn = get_conn()
    try:
        african_iso3   = get_african_countries(conn)
        method_version = get_method_version(conn)

        # Insérer dans collect.raw_data (L1)
        insert_raw_data(conn, df_result, dry_run=args.dry_run)

        # Insérer dans ma.indicator_values (L2)
        n = insert_records(conn, df_result, method_version, african_iso3,
                           dry_run=args.dry_run)

        if not args.dry_run:
            print_summary(conn)

        log.info("=" * 60)
        log.info("BACI mirror gap terminé | +%d valeurs %s", n, INDICATOR)
        log.info("=" * 60)

    finally:
        conn.close()


if __name__ == "__main__":
    main()
