"""
OSA Observatory -- Sprint 13
Export statique Open Data -- CSV + JSON
Génère les fichiers téléchargeables pour les 6 datasets Couche 0

Usage :
  py -3.12 scripts/generate/osa_export_opendata.py
  py -3.12 scripts/generate/osa_export_opendata.py --year 2024
  py -3.12 scripts/generate/osa_export_opendata.py --formats csv json

Sorties :
  exports/opendata/
    ISA_COUNTRY_LATEST_YYYYMMDD.csv / .json
    ISA_COUNTRY_HISTORY_YYYYMMDD.csv / .json
    ISA_PILLAR_BREAKDOWN_YYYYMMDD.csv / .json
    ISA_OPPORTUNITY_CATALOG_YYYYMMDD.csv / .json
    ISA_AMAR_ALERTS_YYYYMMDD.csv / .json
    ISA_P7J_TRAJECTORIES_YYYYMMDD.csv / .json
    MANIFEST_YYYYMMDD.json
"""

from __future__ import annotations

import argparse
import csv
import json
import logging
import os
import sys
from datetime import datetime
from pathlib import Path

import psycopg2
import psycopg2.extras

sys.path.insert(0, r"G:\python-packages")

REPO_ROOT   = Path(__file__).parent.parent.parent
EXPORT_DIR  = REPO_ROOT / "exports" / "opendata"

DB_HOST = os.getenv("OSA_DB_HOST", "127.0.0.1")
DB_PORT = os.getenv("OSA_DB_PORT", "5432")
DB_NAME = os.getenv("OSA_DB_NAME", "osa_db")
DB_USER = os.getenv("OSA_DB_USER", "postgres")
DB_PASS = os.getenv("OSA_DB_PASS", "")

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-8s | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger("osa_export_opendata")

_DISCLAIMER = (
    "OSA Observatory -- Observatoire de la Souverainete Africaine. "
    "Published under CC-BY-4.0. "
    "Early-warning analytical tool -- not a legal or diplomatic qualification. "
    "Subscribe at open.osa-observatory.org for full scores and analytics."
)

# ── Datasets a exporter ───────────────────────────────────────
DATASETS = [
    {
        "code":    "ISA_COUNTRY_LATEST",
        "label":   "Sovereign state -- latest",
        "sql":     """
            SELECT country_iso3, reference_year, region_code, region_label,
                   data_coverage_class, nb_pillars_observed,
                   nb_pillars_accelerating, nb_pillars_progressing,
                   nb_pillars_stable, nb_pillars_declining, nb_pillars_critical,
                   sovereign_momentum, amar_risk_band
            FROM pub.v_isa_country_latest
            ORDER BY country_iso3
        """,
    },
    {
        "code":    "ISA_COUNTRY_HISTORY",
        "label":   "Sovereign trajectory -- 2020-2024",
        "sql":     """
            SELECT country_iso3, year, region_code, region_label,
                   annual_direction, amar_risk_band, nb_pillars_observed,
                   publication_status
            FROM pub.v_isa_country_history
            ORDER BY country_iso3, year
        """,
    },
    {
        "code":    "ISA_PILLAR_BREAKDOWN",
        "label":   "Pillar trajectories -- 2020-2024",
        "sql":     """
            SELECT country_iso3, year, pillar_code, region_code,
                   trajectory_class, trajectory_signal,
                   intervention_family_label, intervention_priority_class,
                   pillar_direction, nb_indicators_observed
            FROM pub.v_isa_pillar_breakdown
            ORDER BY country_iso3, year, pillar_code
        """,
    },
    {
        "code":    "ISA_OPPORTUNITY_CATALOG",
        "label":   "Sovereign development opportunities",
        "sql":     """
            SELECT country_iso3, year, pillar_code,
                   intervention_family_code, intervention_family_label,
                   strategic_objective, consultation_theme,
                   opportunity_class, delta_potential_label
            FROM pub.v_isa_opportunity_catalog
            ORDER BY
                CASE opportunity_class
                    WHEN 'HIGH_IMPACT_OPPORTUNITY'  THEN 1
                    WHEN 'SIGNIFICANT_OPPORTUNITY'  THEN 2
                    WHEN 'UNLOCK_OPPORTUNITY'       THEN 3
                    ELSE 4
                END, country_iso3, pillar_code
        """,
    },
    {
        "code":    "ISA_AMAR_ALERTS",
        "label":   "Atrocity precursor alerts -- 2020-2024",
        "sql":     """
            SELECT country_iso3, year, risk_code, risk_band,
                   source_engine, public_narrative
            FROM mg.v_public_p7i_amar_alerts
            WHERE year >= 2020
            ORDER BY year DESC, risk_band, country_iso3
        """,
    },
    {
        "code":    "ISA_P7J_TRAJECTORIES",
        "label":   "Sovereign trajectories P7J -- 2020-2024",
        "sql":     """
            SELECT country_iso3, year, pillar_code,
                   trajectory_class, trajectory_signal,
                   intervention_family_label,
                   country_sovereign_alert_level
            FROM mg.v_public_p7j_recommendations
            ORDER BY year DESC, country_iso3, pillar_code
        """,
    },
]


def get_conn():
    return psycopg2.connect(
        host=DB_HOST, port=DB_PORT, dbname=DB_NAME,
        user=DB_USER, password=DB_PASS,
        options="-c client_encoding=UTF8",
    )


def fetch(conn, sql: str) -> list[dict]:
    with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        cur.execute(sql)
        return [dict(r) for r in cur.fetchall()]


def export_csv(rows: list[dict], path: Path) -> None:
    if not rows:
        log.warning("Aucune ligne -- %s ignoré", path.name)
        return
    with open(path, "w", newline="", encoding="utf-8-sig") as f:
        writer = csv.DictWriter(f, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)
    log.info("CSV : %s (%d lignes)", path.name, len(rows))


def export_json(rows: list[dict], path: Path, dataset: dict, ts: str) -> None:
    payload = {
        "dataset":     dataset["code"],
        "label":       dataset["label"],
        "license":     "CC-BY-4.0",
        "access":      "Couche 0 -- Open Data",
        "generated":   ts,
        "disclaimer":  _DISCLAIMER,
        "source":      "open.osa-observatory.org",
        "count":       len(rows),
        "data":        rows,
    }
    with open(path, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2, default=str)
    log.info("JSON: %s (%d lignes)", path.name, len(rows))


def export_manifest(results: list[dict], path: Path, ts: str) -> None:
    manifest = {
        "generated":   ts,
        "license":     "CC-BY-4.0",
        "disclaimer":  _DISCLAIMER,
        "source":      "open.osa-observatory.org",
        "datasets":    results,
    }
    with open(path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
    log.info("MANIFEST: %s", path.name)


def main():
    parser = argparse.ArgumentParser(
        description="OSA Export Open Data -- CSV + JSON statiques"
    )
    parser.add_argument(
        "--formats", nargs="+", default=["csv", "json"],
        choices=["csv", "json"],
        help="Formats a exporter (defaut : csv json)"
    )
    args = parser.parse_args()

    ts       = datetime.now().strftime("%Y%m%d_%H%M%S")
    ts_label = datetime.now().strftime("%Y-%m-%dT%H:%M:%S")
    date_tag = datetime.now().strftime("%Y%m%d")

    EXPORT_DIR.mkdir(parents=True, exist_ok=True)
    log.info("=" * 55)
    log.info("OSA Export Open Data -- %s", ts_label)
    log.info("Destination : %s", EXPORT_DIR)
    log.info("=" * 55)

    conn    = get_conn()
    results = []

    for ds in DATASETS:
        log.info("Export %s...", ds["code"])
        try:
            rows = fetch(conn, ds["sql"])
        except Exception as e:
            log.error("Erreur %s : %s", ds["code"], e)
            continue

        files = []
        if "csv" in args.formats:
            csv_path = EXPORT_DIR / f"{ds['code']}_{date_tag}.csv"
            export_csv(rows, csv_path)
            files.append(str(csv_path.name))

        if "json" in args.formats:
            json_path = EXPORT_DIR / f"{ds['code']}_{date_tag}.json"
            export_json(rows, json_path, ds, ts_label)
            files.append(str(json_path.name))

        results.append({
            "dataset_code": ds["code"],
            "label":        ds["label"],
            "nb_rows":      len(rows),
            "files":        files,
            "generated":    ts_label,
        })

    conn.close()

    # Manifest
    manifest_path = EXPORT_DIR / f"MANIFEST_{date_tag}.json"
    export_manifest(results, manifest_path, ts_label)

    # Résumé console
    print(f"\n{'='*55}")
    print(f"  OSA Open Data Export -- {ts_label}")
    print(f"{'='*55}")
    total_rows = sum(r["nb_rows"] for r in results)
    print(f"  Datasets exportes : {len(results)}")
    print(f"  Lignes totales    : {total_rows}")
    print(f"  Destination       : {EXPORT_DIR}")
    for r in results:
        print(f"  {r['dataset_code']:35s} {r['nb_rows']:5d} lignes")
    print(f"{'='*55}\n")


if __name__ == "__main__":
    main()
