import os, logging
import pandas as pd
import psycopg2
from psycopg2.extras import execute_batch

logging.basicConfig(level="INFO", format="%(asctime)s | %(levelname)-8s | %(message)s")
log = logging.getLogger("pmin_smuggling")

INDICATOR  = "PMIN_SMUGGLING_SIGNAL_RANK"
LAYER_RAW  = 1
SOURCE_ID  = 22  # CEPII
BATCH_SIZE = 500
CACHE_CSV  = "/tmp/baci_filtered.csv"

AFRICA_ISO3 = {"DZA","AGO","BEN","BWA","BFA","BDI","CMR","CPV","CAF","TCD","COM","COD","COG",
               "CIV","DJI","EGY","GNQ","ERI","SWZ","ETH","GAB","GMB","GHA","GIN","GNB","KEN",
               "LSO","LBR","LBY","MDG","MWI","MLI","MRT","MUS","MAR","MOZ","NAM","NER","NGA",
               "RWA","STP","SEN","SYC","SLE","SOM","ZAF","SSD","SDN","TZA","TGO","TUN","UGA",
               "ZMB","ZWE"}

# Mapping USGS → chapitre HS BACI
USGS_TO_HS = {
    "MIN_PRD_GOL": "71",
    "MIN_PRD_COP": "26",
    "MIN_PRD_IRN": "26",
    "MIN_PRD_BAU": "26",
    "MIN_PRD_CHR": "26",
    "MIN_PRD_COB": "26",
    "MIN_PRD_MAN": "26",
}

def get_conn():
    return psycopg2.connect(
        host=os.getenv("DB_HOST","localhost"), port=int(os.getenv("DB_PORT",5432)),
        dbname=os.getenv("DB_NAME","osa_db"), user=os.getenv("DB_USER","postgres"),
        password=os.getenv("DB_PASSWORD",""))

def load_usgs(conn):
    """Charge USGS depuis collect.raw_data — MAX pour déduplication unités."""
    with conn.cursor() as cur:
        cur.execute("""
            SELECT indicator_code, country_iso3, year, MAX(value_raw) as production
            FROM collect.raw_data
            WHERE indicator_code LIKE 'MIN_PRD_%'
            AND indicator_code IN ('MIN_PRD_GOL','MIN_PRD_COP','MIN_PRD_IRN',
                                   'MIN_PRD_BAU','MIN_PRD_CHR','MIN_PRD_COB','MIN_PRD_MAN')
            GROUP BY indicator_code, country_iso3, year
            ORDER BY indicator_code, country_iso3, year
        """)
        rows = cur.fetchall()
    df = pd.DataFrame(rows, columns=["usgs_code","iso3","year","production"])
    df["hs_chapter"] = df["usgs_code"].map(USGS_TO_HS)
    log.info("USGS chargé : %d lignes | %d pays | années %s",
             len(df), df["iso3"].nunique(),
             sorted(df["year"].unique().tolist()))
    return df

def load_baci_exports(cache_csv):
    """Charge exports africains depuis cache BACI."""
    df = pd.read_csv(cache_csv)
    af = df[df["exporter_iso3"].isin(AFRICA_ISO3) & ~df["importer_iso3"].isin(AFRICA_ISO3)]
    agg = af.groupby(["t","exporter_iso3","hs_chapter"])["v"].sum().reset_index()
    agg.columns = ["year","iso3","hs_chapter","export_kusd"]
    agg["hs_chapter"] = agg["hs_chapter"].astype(str)
    log.info("BACI exports : %d lignes | %d pays", len(agg), agg["iso3"].nunique())
    return agg

def compute(usgs, baci):
    """
    Signal ordinal : pour chaque minerai × année,
    calculer rang_export_BACI et rang_production_USGS,
    puis score = rang_prod - rang_export (normalisé).

    Score élevé → pays exporte beaucoup MAIS produit peu → signal suspect.
    Score = 0   → rang export = rang production → cohérent.
    Score négatif → exporte moins que sa production → normal.
    """
    records = []

    for usgs_code, hs_chapter in USGS_TO_HS.items():
        usgs_min = usgs[usgs["usgs_code"] == usgs_code].copy()
        baci_min = baci[baci["hs_chapter"] == hs_chapter].copy()

        if usgs_min.empty or baci_min.empty:
            continue

        for year in sorted(usgs_min["year"].unique()):
            u_yr = usgs_min[usgs_min["year"] == year].copy()
            b_yr = baci_min[baci_min["year"] == year].copy()

            if u_yr.empty or b_yr.empty:
                continue

            # Rang production USGS (1 = plus grand producteur)
            u_yr = u_yr.sort_values("production", ascending=False).reset_index(drop=True)
            u_yr["rang_prod"] = u_yr.index + 1
            n_prod = len(u_yr)

            # Rang export BACI (1 = plus grand exportateur)
            b_yr = b_yr.sort_values("export_kusd", ascending=False).reset_index(drop=True)
            b_yr["rang_exp"] = b_yr.index + 1
            n_exp = len(b_yr)

            # Merge sur pays présents dans les deux
            merged = u_yr[["iso3","rang_prod","production"]].merge(
                b_yr[["iso3","rang_exp","export_kusd"]], on="iso3", how="inner"
            )

            if merged.empty:
                continue

            # Signal = écart normalisé [0-100]
            # rang_prod élevé = petit producteur, rang_exp faible = grand exportateur
            # Signal suspect = rang_prod > rang_exp (exporte plus que sa production le suggère)
            merged["ecart"] = merged["rang_prod"] - merged["rang_exp"]
            max_ecart = max(abs(merged["ecart"].max()), abs(merged["ecart"].min()), 1)

            for _, row in merged.iterrows():
                # Normaliser [-max, +max] → [0, 100]
                # 100 = très suspect (exporte bcp, produit peu)
                # 50  = neutre
                # 0   = exporte moins que sa production
                score = round(50 + (row["ecart"] / max_ecart) * 50, 4)
                score = max(0, min(100, score))

                records.append({
                    "iso3": row["iso3"],
                    "year": int(year),
                    "usgs_code": usgs_code,
                    "hs_chapter": hs_chapter,
                    "rang_prod": int(row["rang_prod"]),
                    "rang_exp": int(row["rang_exp"]),
                    "ecart": float(row["ecart"]),
                    "score": score,
                    "production": float(row["production"]),
                    "export_kusd": float(row["export_kusd"]),
                })

    df = pd.DataFrame(records)
    if df.empty:
        return df

    # Score final par pays × année = moyenne des scores par minerai
    final = df.groupby(["iso3","year"]).agg(
        score=("score","mean"),
        nb_minerais=("usgs_code","nunique"),
        max_ecart=("ecart","max")
    ).reset_index()
    final["score"] = final["score"].round(4)

    log.info("%s : %d valeurs | %d pays | années %s",
             INDICATOR, len(final), final["iso3"].nunique(),
             sorted(final["year"].unique().tolist()))

    # Top suspects
    suspects = final[final["score"] > 60].sort_values("score", ascending=False)
    if not suspects.empty:
        log.info("Pays suspects (score > 60) :")
        for _, r in suspects.head(10).iterrows():
            log.info("  %s %d : score=%.1f ecart_max=%.0f sur %d minerais",
                     r["iso3"], r["year"], r["score"], r["max_ecart"], r["nb_minerais"])

    return final, df

def insert(conn, final, detail, dry_run=False):
    # Enregistrer indicateur
    with conn.cursor() as cur:
        cur.execute("""
            INSERT INTO rf.indicators
                (code,name_fr,name_en,pillar_code,unit_code,direction,
                 description,is_active,imputation_regime,is_composite_score,
                 has_structural_zeros,is_port_indicator,doctrine_compliance_flag)
            VALUES ('PMIN_SMUGGLING_SIGNAL_RANK',
                    'Signal contrebande miniere (ordinal)',
                    'Mining smuggling signal (ordinal)',
                    'PMIN','SCORE_0_100','-',
                    'Signal P7E observation pure. Ecart rang export BACI vs rang production USGS. Score > 60 = pays exporte davantage que sa production nationale ne le justifie. Sources CEPII BACI HS92 x USGS MIN_PRD.',
                    true,'STANDARD',false,true,false,true)
            ON CONFLICT (code) DO NOTHING""")

        cur.execute("SELECT id FROM collect.provider_endpoints WHERE endpoint_code='BACI_MIRROR'")
        endpoint_id = cur.fetchone()[0]

    records_raw, records_iv = [], []
    for _, row in final.iterrows():
        if row["iso3"] not in AFRICA_ISO3:
            continue
        records_raw.append((endpoint_id, INDICATOR, row["iso3"], int(row["year"]), float(row["score"])))
        records_iv.append((
            INDICATOR, row["iso3"], int(row["year"]), LAYER_RAW,
            float(row["score"]), float(row["score"]),
            1, SOURCE_ID, "OBSERVED", 0.75
        ))

    if dry_run:
        log.info("[DRY-RUN] %s → %d enregistrements", INDICATOR, len(records_iv))
        # Afficher top suspects
        top = final.sort_values("score", ascending=False).head(5)
        for _, r in top.iterrows():
            log.info("  SAMPLE: %s %d score=%.1f", r["iso3"], r["year"], r["score"])
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
    p.add_argument("--cache", default=CACHE_CSV)
    args = p.parse_args()

    conn = get_conn()
    try:
        usgs = load_usgs(conn)
        baci = load_baci_exports(args.cache)
        final, detail = compute(usgs, baci)
        if final.empty:
            log.error("Aucune valeur calculee")
            return
        n = insert(conn, final, detail, dry_run=args.dry_run)
        log.info("Termine | +%d valeurs %s", n, INDICATOR)
    finally:
        conn.close()

if __name__ == "__main__":
    main()