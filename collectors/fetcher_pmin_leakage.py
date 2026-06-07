"""
OSA Observatory — PMIN_VALUE_LEAKAGE
Fuite de valeur ajoutée minière : ratio exports bruts / exports miniers totaux
Source : BACI HS92 (CEPII) — cache /tmp/baci_filtered.csv
Formule : exports_HS26_27 / (exports_HS26_27 + exports_HS71) × 100
Interprétation : ratio élevé → pays exporte du brut, pas de transformation locale
"""
import os, sys, logging
import pandas as pd
import psycopg2
from psycopg2.extras import execute_batch

logging.basicConfig(level="INFO", format="%(asctime)s | %(levelname)-8s | %(message)s")
log = logging.getLogger("pmin_leakage")

INDICATOR   = "PMIN_VALUE_LEAKAGE"
LAYER_RAW   = 1
SOURCE_ID   = 22  # CEPII dans mm.source_origins
BATCH_SIZE  = 500
CACHE_CSV   = "/tmp/baci_filtered.csv"

AFRICA_ISO3 = {'DZA','AGO','BEN','BWA','BFA','BDI','CMR','CPV','CAF','TCD','COM','COD','COG',
               'CIV','DJI','EGY','GNQ','ERI','SWZ','ETH','GAB','GMB','GHA','GIN','GNB','KEN',
               'LSO','LBR','LBY','MDG','MWI','MLI','MRT','MUS','MAR','MOZ','NAM','NER','NGA',
               'RWA','STP','SEN','SYC','SLE','SOM','ZAF','SSD','SDN','TZA','TGO','TUN','UGA',
               'ZMB','ZWE'}

def get_conn():
    return psycopg2.connect(
        host=os.getenv("DB_HOST","localhost"), port=int(os.getenv("DB_PORT",5432)),
        dbname=os.getenv("DB_NAME","osa_db"), user=os.getenv("DB_USER","postgres"),
        password=os.getenv("DB_PASSWORD",""),
    )

def compute(cache_csv=CACHE_CSV):
    log.info("Chargement cache BACI : %s", cache_csv)
    df = pd.read_csv(cache_csv)

    # Flux Afrique → Non-Afrique uniquement
    af = df[df['exporter_iso3'].isin(AFRICA_ISO3) & ~df['importer_iso3'].isin(AFRICA_ISO3)]

    agg = af.groupby(['t','exporter_iso3','hs_chapter'])['v'].sum().reset_index()
    agg.columns = ['year','iso3','hs_chapter','value_kusd']

    pivot = agg.pivot_table(
        index=['year','iso3'], columns='hs_chapter',
        values='value_kusd', fill_value=0
    ).reset_index()
    pivot.columns = [str(c) for c in pivot.columns]
    pivot.columns.name = None

    pivot['brut']      = pivot.get('26', 0) + pivot.get('27', 0)
    pivot['transforme'] = pivot.get('71', 0)
    pivot['total']     = pivot['brut'] + pivot['transforme']

    pivot['ratio_raw'] = pivot.apply(
        lambda r: round(r['brut'] / r['total'] * 100, 4) if r['total'] > 0 else None, axis=1
    )
    # Score OSA [0-100] : ratio élevé = fuite élevée = score SOUVERAINETÉ bas
    # On inverse : score = 100 - ratio (100% brut → score 0, 0% brut → score 100)
    pivot['score'] = pivot['ratio_raw'].apply(
        lambda r: round(100 - r, 4) if r is not None else None
    )

    result = pivot[pivot['ratio_raw'].notna()][['year','iso3','ratio_raw','score','brut','transforme','total']]
    log.info("PMIN_VALUE_LEAKAGE : %d valeurs | %d pays | %d-%d",
             len(result), result['iso3'].nunique(),
             int(result['year'].min()), int(result['year'].max()))

    # Top fuites
    avg = result.groupby('iso3')['ratio_raw'].mean().sort_values(ascending=False)
    log.info("Top 5 fuites (exports bruts %%) :")
    for iso, v in avg.head(5).items():
        log.info("  %s : %.1f%%", iso, v)

    return result

def insert(conn, df, dry_run=False):
    # Enregistrement rf.indicators
    with conn.cursor() as cur:
        cur.execute("""
            INSERT INTO rf.indicators
                (code, name_fr, name_en, pillar_code, unit_code, direction,
                 description, is_active, imputation_regime, is_composite_score,
                 has_structural_zeros, is_port_indicator, doctrine_compliance_flag)
            VALUES (
                'PMIN_VALUE_LEAKAGE',
                'Fuite de valeur minière',
                'Mineral value leakage',
                'PMIN', 'SCORE_0_100', '-',
                'Part des exports miniers bruts (HS26+27) dans les exports miniers totaux (HS26+27+71). Ratio élevé = fuite de valeur ajoutée. Source CEPII BACI HS92.',
                true, 'STANDARD', false, true, false, true
            ) ON CONFLICT (code) DO NOTHING
        """)

    # Endpoint BACI_MIRROR
    with conn.cursor() as cur:
        cur.execute("SELECT id FROM collect.provider_endpoints WHERE endpoint_code='BACI_MIRROR'")
        endpoint_id = cur.fetchone()[0]

    records_raw = []
    records_iv  = []

    for _, row in df.iterrows():
        if row['iso3'] not in AFRICA_ISO3:
            continue
        records_raw.append((endpoint_id, INDICATOR, row['iso3'], int(row['year']), float(row['ratio_raw'])))
        records_iv.append((
            INDICATOR, row['iso3'], int(row['year']), LAYER_RAW,
            float(row['ratio_raw']), float(row['score']),
            1, SOURCE_ID, 'OBSERVED', 0.90
        ))

    if dry_run:
        log.info("[DRY-RUN] %s → %d enregistrements", INDICATOR, len(records_iv))
        return len(records_iv)

    # Purge
    with conn.cursor() as cur:
        cur.execute("DELETE FROM ma.indicator_values WHERE indicator_code=%s AND layer_id=%s",
                    (INDICATOR, LAYER_RAW))
        cur.execute("DELETE FROM collect.raw_data WHERE indicator_code=%s", (INDICATOR,))

    sql_raw = """INSERT INTO collect.raw_data
        (endpoint_id, indicator_code, country_iso3, year, value_raw)
        VALUES (%s,%s,%s,%s,%s) ON CONFLICT DO NOTHING"""

    sql_iv = """INSERT INTO ma.indicator_values
        (indicator_code, country_iso3, year, layer_id,
         raw_value, processed_value, method_version_id,
         source_id, value_status, confidence_score)
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s) ON CONFLICT DO NOTHING"""

    with conn.cursor() as cur:
        execute_batch(cur, sql_raw, records_raw, page_size=BATCH_SIZE)
        execute_batch(cur, sql_iv,  records_iv,  page_size=BATCH_SIZE)
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

    df = compute(args.cache)
    conn = get_conn()
    try:
        n = insert(conn, df, dry_run=args.dry_run)
        log.info("Terminé | +%d valeurs %s", n, INDICATOR)
    finally:
        conn.close()

if __name__ == "__main__":
    main()