"""
compute_pres_stability.py — Calcul OSA PRES_EN_STABILITY et PRES_WA_VARIABILITY
CV inverse / CV brut sur fenetre glissante 5 ans
Insere les resultats en L1 avec value_status=COMPUTED
"""
import pandas as pd
import psycopg2
import psycopg2.extras
import logging

logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(levelname)-8s | %(message)s", datefmt="%Y-%m-%d %H:%M:%S")
log = logging.getLogger(__name__)

DB_CONFIG = {"host": "localhost", "dbname": "osa_db", "user": "osa_user"}
WINDOW = 5
MIN_PERIODS = 3

COMPUTED_INDICATORS = {
    "PRES_EN_STABILITY": {
        "source": "PRES_EN_ELEC_PROD",
        "method": "cv_inverted",
    },
    "PRES_WA_VARIABILITY": {
        "source": "PRES_WA_RES_TOTAL",
        "method": "cv_raw",
    },
}

def compute_cv_inverted(series):
    mean = series.rolling(window=WINDOW, min_periods=MIN_PERIODS).mean()
    std  = series.rolling(window=WINDOW, min_periods=MIN_PERIODS).std()
    cv   = std / mean.replace(0, pd.NA)
    return (1 - cv).clip(lower=0, upper=1)

def compute_cv_raw(series):
    mean = series.rolling(window=WINDOW, min_periods=MIN_PERIODS).mean()
    std  = series.rolling(window=WINDOW, min_periods=MIN_PERIODS).std()
    cv   = std / mean.replace(0, pd.NA)
    return cv.clip(lower=0, upper=1)

def load_series(conn, indicator_code):
    sql = """
        SELECT country_iso3, year, raw_value
        FROM ma.indicator_values
        WHERE indicator_code = %s AND layer_id = 1
        AND raw_value IS NOT NULL
        ORDER BY country_iso3, year
    """
    with conn.cursor() as cur:
        cur.execute(sql, [indicator_code])
        rows = cur.fetchall()
    return pd.DataFrame(rows, columns=["country_iso3", "year", "raw_value"])

def insert_computed(conn, rows):
    sql = """
        INSERT INTO ma.indicator_values
            (indicator_code, country_iso3, year, raw_value, value_status, layer_id, confidence_score, method_version_id)
        VALUES
            (%(code)s, %(iso3)s, %(year)s, %(value)s, %(status)s, 1, %(confidence)s, 1)
        ON CONFLICT (indicator_code, country_iso3, year, layer_id, method_version_id)
        DO UPDATE SET
            raw_value        = EXCLUDED.raw_value,
            value_status     = EXCLUDED.value_status,
            confidence_score = EXCLUDED.confidence_score,
            created_at       = now()
    """
    with conn.cursor() as cur:
        psycopg2.extras.execute_batch(cur, sql, rows, page_size=500)
    conn.commit()
    return len(rows)

def process_indicator(conn, target_code, config):
    source_code = config["source"]
    method      = config["method"]
    log.info("[%s] source=%s methode=%s", target_code, source_code, method)
    df = load_series(conn, source_code)
    if df.empty:
        log.warning("[%s] Aucune donnee source — skip", target_code)
        return 0
    rows = []
    for iso3, group in df.groupby("country_iso3"):
        g = group.sort_values("year").set_index("year")["raw_value"]
        if method == "cv_inverted":
            computed   = compute_cv_inverted(g)
            confidence = 0.80
        else:
            computed   = compute_cv_raw(g)
            confidence = 0.80
        for year, value in computed.items():
            if pd.isna(value):
                continue
            rows.append({
                "code":       target_code,
                "iso3":       iso3,
                "year":       int(year),
                "value":      round(float(value), 6),
                "status":     "OBSERVED",
                "confidence": confidence,
            })
    inserted = insert_computed(conn, rows)
    log.info("[%s] %d valeurs inserees", target_code, inserted)
    return inserted

def main():
    log.info("======================================")
    log.info("Calcul OSA — PRES STABILITY/VARIABILITY")
    log.info("======================================")
    conn  = psycopg2.connect(**DB_CONFIG)
    total = 0
    for code, config in COMPUTED_INDICATORS.items():
        total += process_indicator(conn, code, config)
    conn.close()
    log.info("Total insere : %d valeurs", total)
    log.info("======================================")

if __name__ == "__main__":
    main()
