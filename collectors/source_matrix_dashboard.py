"""
============================================================
OSA / ISA OBSERVATORY
source_matrix_dashboard.py — Snapshot GO/PILOT/NO_GO + fallback
============================================================
"""

from __future__ import annotations

import argparse
import csv
import logging
import os
from datetime import datetime
from pathlib import Path

import psycopg2
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(
    level=os.getenv("OSA_LOG_LEVEL", "INFO"),
    format="%(asctime)s | %(levelname)-8s | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger("source_matrix_dashboard")


def connect_db():
    return psycopg2.connect(
        host=os.getenv("OSA_DB_HOST", "localhost"),
        port=int(os.getenv("OSA_DB_PORT", "5432")),
        dbname=os.getenv("OSA_DB_NAME", "osa_db"),
        user=os.getenv("OSA_DB_USER", "postgres"),
        password=os.getenv("OSA_DB_PASS", ""),
        connect_timeout=10,
    )


def print_status_summary(conn) -> None:
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT status, sources_count, min_priority, max_priority, avg_reliability
            FROM collect.v_source_status_summary
            ORDER BY CASE status WHEN 'GO' THEN 1 WHEN 'PILOT' THEN 2 ELSE 3 END
            """
        )
        rows = cur.fetchall()

    log.info("=== SOURCE STATUS SUMMARY ===")
    for status, count, pmin, pmax, rel in rows:
        log.info(
            "status=%s count=%s priority=[%s..%s] avg_reliability=%s",
            status,
            count,
            pmin,
            pmax,
            rel,
        )


def print_live_dashboard(conn) -> None:
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT source_id, status, priority, latest_decision, latest_supported
            FROM collect.v_source_dashboard_live
            ORDER BY priority, source_id
            """
        )
        rows = cur.fetchall()

    log.info("=== SOURCE DASHBOARD LIVE ===")
    for source_id, status, priority, decision, supported in rows:
        log.info(
            "source=%s status=%s priority=%s decision=%s supported=%s",
            source_id,
            status,
            priority,
            decision,
            supported,
        )


def print_fallback_preview(conn, indicator_code: str, year: int, include_pilot: bool) -> None:
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT indicator_code, country_iso3, selected_source_code,
                   resolved_value, used_fallback, candidate_sources
            FROM collect.resolve_indicator_fallback_set(%s, %s, %s, 1)
            WHERE resolved_value IS NOT NULL
            ORDER BY country_iso3
            LIMIT 20
            """,
            (indicator_code, year, include_pilot),
        )
        rows = cur.fetchall()

    log.info("=== FALLBACK PREVIEW (%s, %s) ===", indicator_code, year)
    for ind, iso3, src, value, used_fallback, candidates in rows:
        log.info(
            "indicator=%s iso3=%s source=%s value=%s fallback=%s candidates=%s",
            ind,
            iso3,
            src,
            value,
            used_fallback,
            candidates,
        )


def export_dashboard_csv(conn, export_dir: Path, year: int) -> list[Path]:
    export_dir.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")

    files = {
        "summary": export_dir / f"source_status_summary_{stamp}.csv",
        "live": export_dir / f"source_dashboard_live_{stamp}.csv",
        "fallback": export_dir / f"fallback_coverage_{year}_{stamp}.csv",
    }

    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT status, sources_count, min_priority, max_priority, avg_reliability
            FROM collect.v_source_status_summary
            ORDER BY CASE status WHEN 'GO' THEN 1 WHEN 'PILOT' THEN 2 ELSE 3 END
            """
        )
        summary_rows = cur.fetchall()

    with files["summary"].open("w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["status", "sources_count",
                        "min_priority", "max_priority", "avg_reliability"])
        writer.writerows(summary_rows)

    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT source_id, name, status, priority, api_type,
                   latest_decision, latest_supported, latest_reason,
                   reliability_score, freshness_score, completeness_score,
                   latest_decision_at
            FROM collect.v_source_dashboard_live
            ORDER BY priority, source_id
            """
        )
        live_rows = cur.fetchall()

    with files["live"].open("w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(
            [
                "source_id", "name", "status", "priority", "api_type",
                "latest_decision", "latest_supported", "latest_reason",
                "reliability_score", "freshness_score", "completeness_score",
                "latest_decision_at",
            ]
        )
        writer.writerows(live_rows)

    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT year, indicator_code, selected_source_id,
                   selected_source_status, selected_source_priority,
                   resolved_points, fallback_points,
                   fallback_rate_pct, avg_candidate_sources
            FROM collect.v_fallback_coverage_by_source
            WHERE year = %s
            ORDER BY indicator_code, selected_source_priority, selected_source_id
            """,
            (year,),
        )
        fallback_rows = cur.fetchall()

    with files["fallback"].open("w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(
            [
                "year", "indicator_code", "selected_source_id",
                "selected_source_status", "selected_source_priority",
                "resolved_points", "fallback_points",
                "fallback_rate_pct", "avg_candidate_sources",
            ]
        )
        writer.writerows(fallback_rows)

    return [files["summary"], files["live"], files["fallback"]]


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Dashboard matrice sources OSA")
    parser.add_argument("--fallback-indicator", type=str, default=None)
    parser.add_argument("--year", type=int, default=2024)
    parser.add_argument("--include-pilot", action="store_true")
    parser.add_argument("--export-csv", action="store_true")
    parser.add_argument("--export-dir", type=str,
                        default="logs/source_dashboard_exports")
    args = parser.parse_args()

    conn = connect_db()
    try:
        print_status_summary(conn)
        print_live_dashboard(conn)

        if args.fallback_indicator:
            print_fallback_preview(
                conn=conn,
                indicator_code=args.fallback_indicator,
                year=args.year,
                include_pilot=args.include_pilot,
            )

        if args.export_csv:
            paths = export_dashboard_csv(
                conn=conn,
                export_dir=Path(args.export_dir),
                year=args.year,
            )
            for path in paths:
                log.info("CSV exporte: %s", path)
    finally:
        conn.close()


if __name__ == "__main__":
    main()
