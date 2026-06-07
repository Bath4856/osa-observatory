import os, logging, time
import pandas as pd
import psycopg2
from psycopg2.extras import execute_batch
import requests

logging.basicConfig(level="INFO", format="%(asctime)s | %(levelname)-8s | %(message)s")
log = logging.getLogger("phum_value_capture")

INDICATOR  = "PHUM_VALUE_CAPTURE"
LAYER_RAW  = 1
BATCH_SIZE = 500

AFRICA_ISO3 = ["DZA","AGO","BEN","BWA","BFA","BDI","CMR","CPV","CAF","TCD","COM","COD","COG",
               "CIV","DJI","EGY","GNQ","ERI","SWZ","ETH","GAB","GMB","GHA","GIN","GNB","KEN",
               "LSO","LBR","LBY","MDG","MWI","MLI","MRT","MUS","MAR","MOZ","NAM","NER","NGA",
               "RWA","STP","SEN","SYC","SLE","SOM","ZAF","SSD","SDN","TZA","TGO","TUN","UGA",
               "ZMB","ZWE"]

WB_INDICATORS = {
    "SH.MED.PHYS.ZS": "medecins_1000",
    "SE.TER.ENRR":    "scolarisation_tertiaire",
}
WEIGHTS = {"medecins_1000": 0.6, "scolarisation_tertiaire": 0.4}

def get_conn():
    return psycopg2.connect(
        host=os.getenv("DB_HOST","localhost"), port=int(os.getenv("DB_PORT",5432)),
        dbname=os.getenv("DB_NAME","osa_db"), user=os.getenv("DB_USER","postgres"),
        password=os.getenv("DB_PASSWORD",""))

def fetch_wb(indicator, countries, retries=2):
    url = (f"https://api.worldbank.org/v2/country/{chr(59).join(countries)}"
           f"/indicator/{indicator}?format=json&per_page=500&date=2010:2024")
    for attempt in range(retries):
        try:
            r = requests.get(url, timeout=30)
            d = r.json()
            if len(d) > 1 and d[1]:
                return [x for x in d[1] if x.get("value") is not None]
        except Exception as e:
            log.warning("Batch erreur (tentative %d): %s", attempt+1, e)
            time.sleep(2)
    return []

def collect_wb():
    """Collecte WB par lots de 10 pays."""
    data = {name: [] for name in WB_INDICATORS.values()}
    for wb_code, col_name in WB_INDICATORS.items():
        log.info("Collecte WB %s...", wb_code)
        for i in range(0, len(AFRICA_ISO3), 10):
            batch = AFRICA_ISO3[i:i+10]
            vals = fetch_wb(wb_code, batch)
            data[col_name].extend(vals)
            time.sleep(0.5)
        log.info("  %s : %d valeurs, %d pays",
                 wb_code, len(data[col_name]),
                 len(set(x["country"]["id"] for x in data[col_name])))
    return data

def compute(raw_data):
    """
    PHUM_VALUE_CAPTURE = score composite rétention capital humain.
    Benchmark = moyenne africaine par année pour chaque indicateur.
    Score = min(valeur_pays / moyenne_africaine, 1) × 100
    Score composite = médecins×0.6 + scolarisation×0.4
    """
    dfs = {}
    ISO2_TO_ISO3 = {
        "DZ":"DZA","AO":"AGO","BJ":"BEN","BW":"BWA","BF":"BFA","BI":"BDI","CM":"CMR",
        "CV":"CPV","CF":"CAF","TD":"TCD","KM":"COM","CD":"COD","CG":"COG","CI":"CIV",
        "DJ":"DJI","EG":"EGY","GQ":"GNQ","ER":"ERI","SZ":"SWZ","ET":"ETH","GA":"GAB",
        "GM":"GMB","GH":"GHA","GN":"GIN","GW":"GNB","KE":"KEN","LS":"LSO","LR":"LBR",
        "LY":"LBY","MG":"MDG","MW":"MWI","ML":"MLI","MR":"MRT","MU":"MUS","MA":"MAR",
        "MZ":"MOZ","NA":"NAM","NE":"NER","NG":"NGA","RW":"RWA","ST":"STP","SN":"SEN",
        "SC":"SYC","SL":"SLE","SO":"SOM","ZA":"ZAF","SS":"SSD","SD":"SDN","TZ":"TZA",
        "TG":"TGO","TN":"TUN","UG":"UGA","ZM":"ZMB","ZW":"ZWE"
    }
    for col_name, records in raw_data.items():
        rows = []
        for x in records:
            iso2 = x["country"]["id"]
            iso3 = ISO2_TO_ISO3.get(iso2)
            if not iso3 or iso3 not in AFRICA_ISO3:
                continue
            rows.append({"iso3": iso3, "year": int(x["date"]), "value": float(x["value"])})
        if rows:
            dfs[col_name] = pd.DataFrame(rows)

    if not dfs:
        log.error("Aucune donnée collectée")
        return pd.DataFrame()

    scores = []
    all_years = set()
    for df in dfs.values():
        all_years.update(df["year"].unique())

    for year in sorted(all_years):
        year_scores = {}
        for col_name, df in dfs.items():
            yr = df[df["year"] == year].copy()
            if yr.empty:
                continue
            # Benchmark = moyenne africaine cette année
            benchmark = yr["value"].mean()
            if benchmark <= 0:
                continue
            yr["score"] = yr["value"].apply(
                lambda v: round(min(v / benchmark, 1) * 100, 4)
            )
            for _, row in yr.iterrows():
                if row["iso3"] not in year_scores:
                    year_scores[row["iso3"]] = {}
                year_scores[row["iso3"]][col_name] = row["score"]

        for iso3, comp_scores in year_scores.items():
            if not comp_scores:
                continue
            # Score composite pondéré
            total_weight = sum(WEIGHTS[k] for k in comp_scores)
            composite = sum(comp_scores[k] * WEIGHTS[k] for k in comp_scores) / total_weight
            scores.append({
                "iso3": iso3, "year": year,
                "score": round(composite, 4),
                "nb_composantes": len(comp_scores),
            })

    result = pd.DataFrame(scores)
    if result.empty:
        return result

    log.info("%s : %d valeurs | %d pays | %d-%d",
             INDICATOR, len(result), result["iso3"].nunique(),
             int(result["year"].min()), int(result["year"].max()))

    # Top fuites
    avg = result.groupby("iso3")["score"].mean().sort_values()
    log.info("Top 5 fuites capital humain (score moyen le plus bas) :")
    for iso, v in avg.head(5).items():
        log.info("  %s : %.1f", iso, v)

    return result

def insert(conn, df, dry_run=False):
    # Enregistrer source WB si pas déjà présente
    with conn.cursor() as cur:
        cur.execute("SELECT id FROM mm.source_origins WHERE code='WB'")
        wb_source_id = cur.fetchone()[0]

        cur.execute("SELECT id FROM collect.provider_endpoints WHERE endpoint_code='WB_ALL_COUNTRIES'")
        endpoint_id = cur.fetchone()[0]

        cur.execute("""
            INSERT INTO rf.indicators
                (code,name_fr,name_en,pillar_code,unit_code,direction,
                 description,is_active,imputation_regime,is_composite_score,
                 has_structural_zeros,is_port_indicator,doctrine_compliance_flag)
            VALUES ('PHUM_VALUE_CAPTURE',
                    'Capture de valeur du capital humain',
                    'Human capital value capture',
                    'PHUM','SCORE_0_100','+',
                    'Rétention du capital humain formé. Score composite : médecins/1000 (WB SH.MED.PHYS.ZS, 60%) + scolarisation tertiaire (WB SE.TER.ENRR, 40%). Benchmark = moyenne africaine annuelle.',
                    true,'STANDARD',false,true,false,true)
            ON CONFLICT (code) DO NOTHING""")

    records_raw, records_iv = [], []
    for _, row in df.iterrows():
        if row["iso3"] not in AFRICA_ISO3:
            continue
        records_raw.append((endpoint_id, INDICATOR, row["iso3"], int(row["year"]), float(row["score"])))
        records_iv.append((
            INDICATOR, row["iso3"], int(row["year"]), LAYER_RAW,
            float(row["score"]), float(row["score"]),
            1, wb_source_id, "OBSERVED", 0.80
        ))

    if dry_run:
        log.info("[DRY-RUN] %s → %d enregistrements", INDICATOR, len(records_iv))
        top = df.nsmallest(5, "score")
        for _, r in top.iterrows():
            log.info("  SAMPLE fuite: %s %d score=%.1f", r["iso3"], r["year"], r["score"])
        return len(records_iv)

    with conn.cursor() as cur:
        cur.execute("DELETE FROM ma.indicator_values WHERE indicator_code=%s AND layer_id=%s",
                    (INDICATOR, LAYER_RAW))
        cur.execute("DELETE FROM collect.raw_data WHERE indicator_code=%s", (INDICATOR,))

    with conn.cursor() as cur:
        execute_batch(cur, """INSERT INTO collect.raw_data
            (endpoint_id,indicator_code,country_iso3,year,value_raw)
            VALUES (%s,%s,%s,%s,%s) ON CONFLICT DO NOTHING""",
            records_raw, page_size=BATCH_SIZE)
        execute_batch(cur, """INSERT INTO ma.indicator_values
            (indicator_code,country_iso3,year,layer_id,raw_value,processed_value,
             method_version_id,source_id,value_status,confidence_score)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s) ON CONFLICT DO NOTHING""",
            records_iv, page_size=BATCH_SIZE)
    conn.commit()

    with conn.cursor() as cur:
        cur.execute("SELECT COUNT(*) FROM ma.indicator_values WHERE indicator_code=%s", (INDICATOR,))
        total = cur.fetchone()[0]
    log.info("%s → %d valeurs en base", INDICATOR, total)
    return total

def main():
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    raw_data = collect_wb()
    conn = get_conn()
    try:
        df = compute(raw_data)
        if df.empty:
            log.error("Aucune valeur calculée")
            return
        n = insert(conn, df, dry_run=args.dry_run)
        log.info("Terminé | +%d valeurs %s", n, INDICATOR)
    finally:
        conn.close()

if __name__ == "__main__":
    main()