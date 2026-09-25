#!/usr/bin/env python3
"""
OSA Observatory — collectors/fetcher_imf_weo_sdmx3.py
Fetcher IMF WEO — API SDMX 3.0 en direct (api.imf.org)

Remplace fetcher_imf_weo_v2.py, ecrit pour un ancien fichier CSV
telecharge manuellement depuis une page imf.org retiree entre avril et
octobre 2025 (migration vers le nouveau IMF Data Portal). Verifie et
construit le 2026-09-24 -- endpoint reel confirme :

  https://api.imf.org/external/sdmx/3.0/data/dataflow/IMF.RES/WEO/9.0.0/{PAYS}.{INDICATEUR}.A

Indicateurs couverts (les seuls, parmi les indicateurs OSA touches par
le defaut source_id=11, a n'avoir aucune autre source fonctionnelle --
les autres candidats IMF sont deja corriges via fetcher_wb_pres_pmil_pnum.py) :
  ECO_UNE -> LUR (Unemployment rate)
  MON_PAY -> BCA (Current account balance, USD)

Usage :
  python fetcher_imf_weo_sdmx3.py --dry-run
  python fetcher_imf_weo_sdmx3.py --output db
"""

import argparse
import json
import logging
import os
import sys
import urllib.request
from pathlib import Path

import psycopg2
from psycopg2.extras import execute_batch

log = logging.getLogger("fetcher_imf_weo_sdmx3")
logging.basicConfig(level=os.getenv("OSA_LOG_LEVEL", "INFO"),
                     format="%(asctime)s | %(levelname)-8s | %(message)s")

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

API_BASE = "https://api.imf.org/external/sdmx/3.0/data/dataflow/IMF.RES/WEO/9.0.0"
LAYER_RAW = 1
YEAR_FROM = 2010
YEAR_TO = 2024

WEO_INDICATOR_MAP = {
    "LUR": {
        "osa_code":   "ECO_UNE",
        "name_fr":    "Taux de chomage (modelise, % population active)",
        "min_valid":  0.0,
        "max_valid":  100.0,
    },
    "BCA": {
        "osa_code":   "MON_PAY",
        "name_fr":    "Solde de la balance courante (USD)",
        "min_valid":  -1e13,
        "max_valid":  1e13,
    },
}


def get_pg_conn():
    return psycopg2.connect(
        host=os.getenv("OSA_DB_HOST", "localhost"),
        port=os.getenv("OSA_DB_PORT", "5432"),
        dbname=os.getenv("OSA_DB_NAME", "osa_db"),
        user=os.getenv("OSA_DB_USER", "postgres"),
        password=os.getenv("OSA_DB_PASS", ""),
        connect_timeout=10,
    )


def get_african_iso3(conn) -> list[str]:
    with conn.cursor() as cur:
        cur.execute("SELECT iso3 FROM rf.countries WHERE is_active = true ORDER BY iso3")
        return [r[0] for r in cur.fetchall()]


def fetch_weo_indicator(weo_code: str, countries: list[str]) -> dict:
    """Retourne {iso3: {annee: valeur}} pour un indicateur WEO, tous pays."""
    key = "+".join(countries) + f".{weo_code}.A"
    url = f"{API_BASE}/{key}?startPeriod={YEAR_FROM}&endPeriod={YEAR_TO}&format=csv"
    req = urllib.request.Request(url, headers={"User-Agent": "OSA-Observatory/1.0"})
    with urllib.request.urlopen(req, timeout=60) as resp:
        payload = json.loads(resp.read().decode("utf-8"))

    result: dict[str, dict[int, float]] = {}
    datasets = payload.get("data", {}).get("dataSets", [])
    if not datasets:
        return result
    series = datasets[0].get("series", {})
    structures = payload.get("data", {}).get("structures", [{}])[0]
    series_dims = structures.get("dimensions", {}).get("series", [])
    country_dim = next((d for d in series_dims if d["id"] == "COUNTRY"), None)
    if not country_dim:
        return result
    country_values = [v["id"] for v in country_dim.get("values", [])]

    obs_dims = structures.get("dimensions", {}).get("observation", [])
    time_dim = next((d for d in obs_dims if d["id"] == "TIME_PERIOD"), None)
    # Note : TIME_PERIOD utilise la cle "value", pas "id" comme COUNTRY --
    # incoherence de format constatee dans la vraie reponse API (2026-09-24)
    time_values = [v.get("value", v.get("id")) for v in time_dim.get("values", [])] if time_dim else []

    for series_key, series_data in series.items():
        country_idx = int(series_key.split(":")[0])
        if country_idx >= len(country_values):
            continue
        iso3 = country_values[country_idx]
        obs = series_data.get("observations", {})
        year_values: dict[int, float] = {}
        for obs_idx, obs_val in obs.items():
            t_idx = int(obs_idx)
            if t_idx >= len(time_values):
                continue
            try:
                year = int(time_values[t_idx])
                val = float(obs_val[0])
            except (ValueError, TypeError, IndexError):
                continue
            if not (YEAR_FROM <= year <= YEAR_TO):
                continue
            year_values[year] = val
        result[iso3] = year_values
    return result


def insert_indicator(conn, osa_code: str, meta: dict, data: dict,
                      imf_source_id: int, dry_run: bool = False) -> tuple[int, int]:
    records = []
    for iso3, year_values in data.items():
        for year, val in year_values.items():
            if not (meta["min_valid"] <= val <= meta["max_valid"]):
                log.warning("  [%s] Hors bornes [%s, %s] : %s %d -> %s",
                            osa_code, meta["min_valid"], meta["max_valid"], iso3, year, val)
                continue
            records.append((osa_code, iso3, year, val))

    if dry_run:
        log.info("  [DRY-RUN] [%s] %d lignes pretes", osa_code, len(records))
        return len(records), 0

    sql = """
        INSERT INTO ma.indicator_values
            (indicator_code, country_iso3, year, layer_id,
             raw_value, processed_value, confidence_score,
             quality_flag, value_status, source_id)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT (indicator_code, country_iso3, year, layer_id, method_version_id)
        DO UPDATE SET
            raw_value        = EXCLUDED.raw_value,
            processed_value  = EXCLUDED.processed_value,
            confidence_score = EXCLUDED.confidence_score,
            quality_flag     = EXCLUDED.quality_flag,
            value_status     = EXCLUDED.value_status,
            source_id        = EXCLUDED.source_id
    """
    batch = [(osa_code, iso3, year, LAYER_RAW, val, val, 0.90, "OK", "OBSERVED", imf_source_id)
             for osa_code, iso3, year, val in records]

    with conn.cursor() as cur:
        cur.execute("SELECT COUNT(*) FROM ma.indicator_values WHERE indicator_code=%s AND layer_id=%s",
                    (osa_code, LAYER_RAW))
        before = cur.fetchone()[0]
        execute_batch(cur, sql, batch, page_size=500)
    conn.commit()
    with conn.cursor() as cur:
        cur.execute("SELECT COUNT(*) FROM ma.indicator_values WHERE indicator_code=%s AND layer_id=%s",
                    (osa_code, LAYER_RAW))
        after = cur.fetchone()[0]

    return len(batch), after - before


def main():
    parser = argparse.ArgumentParser(description="OSA Fetcher IMF WEO — SDMX 3.0")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--output", choices=["db"], default="db")
    parser.add_argument("--indicator", choices=list(WEO_INDICATOR_MAP.keys()), default=None)
    args = parser.parse_args()

    log.info("=" * 60)
    log.info("OSA Fetcher IMF WEO — SDMX 3.0 (api.imf.org)")
    log.info("=" * 60)

    conn = get_pg_conn()
    countries = get_african_iso3(conn)
    log.info("Pays actifs : %d", len(countries))

    imf_source_id = None
    if not args.dry_run:
        with conn.cursor() as cur:
            cur.execute("SELECT id FROM mm.source_origins WHERE code = %s", ("IMF",))
            row = cur.fetchone()
            if not row:
                raise RuntimeError("mm.source_origins : code IMF introuvable")
            imf_source_id = row[0]

    targets = [args.indicator] if args.indicator else list(WEO_INDICATOR_MAP.keys())
    total_inserted = 0
    for weo_code in targets:
        meta = WEO_INDICATOR_MAP[weo_code]
        log.info("-" * 60)
        log.info("[WEO] %s -> %s", weo_code, meta["osa_code"])
        try:
            data = fetch_weo_indicator(weo_code, countries)
        except Exception as exc:
            log.error("  Echec telechargement %s : %s", weo_code, exc)
            continue
        nb_pays = len([iso3 for iso3, yv in data.items() if yv])
        log.info("  Telecharge : %d pays avec au moins une valeur", nb_pays)
        prepared, inserted = insert_indicator(conn, meta["osa_code"], meta, data,
                                               imf_source_id, dry_run=args.dry_run)
        log.info("  [%s -> %s] %d lignes preparees, %d nouvelles",
                  weo_code, meta["osa_code"], prepared, inserted)
        total_inserted += inserted

    conn.close()
    log.info("=" * 60)
    log.info("Termine | total nouvelles lignes: %d", total_inserted)
    log.info("=" * 60)


if __name__ == "__main__":
    main()