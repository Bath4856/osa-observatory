"""
OSA Observatory — collectors/fetcher_imf_weo_v2.py
Sprint 7 — Avril 2026
Fetcher IMF WEO v2 — Format CSV SDMX (colonnes années)
Indicateurs : ECO_GDP, ECO_GRW, ECO_INV, ECO_EMP, ECO_TAX (PECO)
              MON_INF, MON_EXT, MON_DET, MON_PAY, MON_SAV (PMON)
Usage :
  python collectors/fetcher_imf_weo_v2.py --file data/raw/imf/WEO.csv --dry-run
  python collectors/fetcher_imf_weo_v2.py --file data/raw/imf/WEO.csv
  python collectors/fetcher_imf_weo_v2.py --file data/raw/imf/WEO.csv --pillar PMON
"""
from __future__ import annotations
import argparse, logging, os, sys
import pandas as pd
import psycopg2
from psycopg2.extras import execute_batch
from dotenv import load_dotenv
load_dotenv()

logging.basicConfig(level=os.getenv("OSA_LOG_LEVEL","INFO"),
    format="%(asctime)s | %(levelname)-8s | %(message)s")
log = logging.getLogger("fetcher_imf_weo_v2")

YEAR_MIN, YEAR_MAX, LAYER_RAW, BATCH_SIZE = 2010, 2024, 1, 500

COUNTRY_MAP = {
    "Algeria":"DZA","Angola":"AGO","Benin":"BEN","Botswana":"BWA",
    "Burkina Faso":"BFA","Burundi":"BDI","Cabo Verde":"CPV","Cameroon":"CMR",
    "Central African Republic":"CAF","Chad":"TCD","Comoros":"COM",
    "Congo, Dem. Rep. of the":"COD","Congo, Republic of":"COG",
    "Cote d Ivoire":"CIV","Djibouti":"DJI","Egypt":"EGY",
    "Equatorial Guinea":"GNQ","Eritrea":"ERI","Eswatini":"SWZ",
    "Ethiopia":"ETH","Gabon":"GAB","Gambia, The":"GMB","Ghana":"GHA",
    "Guinea":"GIN","Guinea-Bissau":"GNB","Kenya":"KEN","Lesotho":"LSO",
    "Liberia":"LBR","Libya":"LBY","Madagascar":"MDG","Malawi":"MWI",
    "Mali":"MLI","Mauritania":"MRT","Mauritius":"MUS","Morocco":"MAR",
    "Mozambique":"MOZ","Namibia":"NAM","Niger":"NER","Nigeria":"NGA",
    "Rwanda":"RWA","Sao Tome and Principe":"STP","Senegal":"SEN",
    "Seychelles":"SYC","Sierra Leone":"SLE","Somalia":"SOM",
    "South Africa":"ZAF","South Sudan, Republic of":"SSD","Sudan":"SDN",
    "Tanzania":"TZA","Togo":"TGO","Tunisia":"TUN","Uganda":"UGA",
    "Zambia":"ZMB","Zimbabwe":"ZWE",
}

INDICATOR_MAP = {
    "Gross domestic product (GDP), Current prices, US dollar":
        {"osa_code":"ECO_GDP","pillar":"PECO","min_valid":0,"max_valid":1e6,"direction":"+"},
    "Gross domestic product (GDP), Constant prices, Percent change":
        {"osa_code":"ECO_GRW","pillar":"PECO","min_valid":-50,"max_valid":100,"direction":"+"},
    "Gross capital formation, Percent of GDP":
        {"osa_code":"ECO_INV","pillar":"PECO","min_valid":0,"max_valid":100,"direction":"+"},
    "Unemployment rate":
        {"osa_code":"ECO_UNE","pillar":"PECO","min_valid":0,"max_valid":100,"direction":"-"},
    "Revenue, General government, Percent of GDP":
        {"osa_code":"ECO_TAX","pillar":"PECO","min_valid":0,"max_valid":100,"direction":"+"},
    "All Items, Consumer price index (CPI), Period average, percent change":
        {"osa_code":"MON_INF","pillar":"PMON","min_valid":-50,"max_valid":500,"direction":"-"},
    "Gross debt, General government, Percent of GDP":
        {"osa_code":"MON_EXT","pillar":"PMON","min_valid":0,"max_valid":500,"direction":"-"},
    "Net lending (+) / net borrowing (-), General government, Percent of GDP":
        {"osa_code":"MON_DET","pillar":"PMON","min_valid":-100,"max_valid":50,"direction":"+"},
    "Current account balance (credit less debit), Percent of GDP":
        {"osa_code":"MON_PAY","pillar":"PMON","min_valid":-100,"max_valid":100,"direction":"+"},
    "Gross national savings, Percent of GDP":
        {"osa_code":"MON_RES","pillar":"PMON","min_valid":-50,"max_valid":100,"direction":"+"},
}

def get_pg_conn():
    return psycopg2.connect(
        host=os.getenv("OSA_DB_HOST","localhost"),
        port=int(os.getenv("OSA_DB_PORT",5432)),
        dbname=os.getenv("OSA_DB_NAME","osa_db"),
        user=os.getenv("OSA_DB_USER","postgres"),
        password=os.getenv("OSA_DB_PASS",""),
    )

def parse_weo(filepath, pillar_filter=None):
    log.info("Chargement : %s", filepath)
    df = pd.read_csv(filepath, encoding="latin-1", low_memory=False)
    log.info("  Fichier charge : %d lignes x %d colonnes", *df.shape)
    year_cols = [c for c in df.columns if c.isdigit() and YEAR_MIN <= int(c) <= YEAR_MAX]
    log.info("  Annees : %s -> %s (%d colonnes)", year_cols[0], year_cols[-1], len(year_cols))
    df_af = df[df["COUNTRY"].isin(COUNTRY_MAP.keys())].copy()
    log.info("  Pays africains : %d / 54", df_af["COUNTRY"].nunique())
    ind_filter = {k:v for k,v in INDICATOR_MAP.items()
                  if pillar_filter is None or v["pillar"] == pillar_filter}
    df_af = df_af[df_af["INDICATOR"].isin(ind_filter.keys())].copy()
    log.info("  Indicateurs retenus : %d", len(ind_filter))
    records = []
    for _, row in df_af.iterrows():
        iso3 = COUNTRY_MAP.get(row["COUNTRY"])
        meta = ind_filter.get(row["INDICATOR"])
        if not iso3 or not meta:
            continue
        for year_str in year_cols:
            try:
                val = float(str(row.get(year_str,"")).replace(",","").strip())
            except (ValueError, TypeError):
                continue
            if pd.isna(val):
                continue
            if not (meta["min_valid"] <= val <= meta["max_valid"]):
                continue
            records.append({"indicator_code":meta["osa_code"],
                            "country_iso3":iso3,
                            "year":int(year_str),
                            "raw_value":val})
    df_out = pd.DataFrame(records)
    log.info("  Enregistrements prepares : %d", len(df_out))
    return df_out

def insert_to_db(conn, df, dry_run=False):
    if df.empty:
        return 0
    valid = pd.read_sql("SELECT iso3 FROM rf.countries", conn)["iso3"].tolist()
    df = df[df["country_iso3"].isin(valid)].dropna(subset=["raw_value"]).copy()
    if dry_run:
        for ind, grp in df.groupby("indicator_code"):
            log.info("  [DRY-RUN] %s : %d valeurs | %d pays",
                     ind, len(grp), grp["country_iso3"].nunique())
        log.info("  [DRY-RUN] Total : %d valeurs non inserees", len(df))
        return len(df)
    sql = """
        INSERT INTO ma.indicator_values
            (indicator_code, country_iso3, year, layer_id,
             raw_value, quality_flag, confidence_score, value_status)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT DO NOTHING
    """
    batch = [(r["indicator_code"], r["country_iso3"], int(r["year"]),
              LAYER_RAW, float(r["raw_value"]), "OK", 1.0, "OBSERVED")
             for _, r in df.iterrows()]
    with conn.cursor() as cur:
        execute_batch(cur, sql, batch, page_size=BATCH_SIZE)
    conn.commit()
    log.info("  -> %d inseres", len(batch))
    return len(batch)

def main():
    parser = argparse.ArgumentParser(description="OSA Fetcher IMF WEO v2")
    parser.add_argument("--file",    required=True)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--pillar",  default=None, choices=["PECO","PMON"])
    args = parser.parse_args()
    log.info("="*60)
    log.info("OSA Fetcher IMF WEO v2")
    log.info("  Fichier : %s | Pilier : %s | Dry-run : %s",
             args.file, args.pillar or "tous", args.dry_run)
    log.info("="*60)
    df = parse_weo(args.file, pillar_filter=args.pillar)
    if df.empty:
        log.warning("Aucune donnee extraite.")
        sys.exit(1)
    conn = get_pg_conn()
    try:
        n = insert_to_db(conn, df, dry_run=args.dry_run)
    finally:
        conn.close()
    print("\n" + "="*60)
    print("RAPPORT IMF WEO v2")
    print("="*60)
    print(f"Mode     : {'DRY-RUN' if args.dry_run else 'COLLECT'}")
    print(f"Prepares : {len(df)}")
    print(f"Inseres  : {n}")
    if not df.empty:
        print("\nPar indicateur :")
        for ind, grp in df.groupby("indicator_code"):
            pillar = next((v["pillar"] for k,v in INDICATOR_MAP.items()
                          if v["osa_code"]==ind), "?")
            print(f"  [{pillar}] {ind:<20} : {len(grp):>5} val | "
                  f"{grp['country_iso3'].nunique()} pays | "
                  f"{grp['year'].min()}-{grp['year'].max()}")
    print("="*60)

if __name__ == "__main__":
    main()
