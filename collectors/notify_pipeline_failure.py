"""
============================================================
OSA / ISA OBSERVATORY
notify_pipeline_failure.py — Alerte echec run nocturne
============================================================
"""

from __future__ import annotations

import argparse
import json
import logging
import os

import psycopg2
import requests
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(
    level=os.getenv("OSA_LOG_LEVEL", "INFO"),
    format="%(asctime)s | %(levelname)-8s | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger("notify_pipeline_failure")


def connect_db():
    return psycopg2.connect(
        host=os.getenv("OSA_DB_HOST", "localhost"),
        port=int(os.getenv("OSA_DB_PORT", "5432")),
        dbname=os.getenv("OSA_DB_NAME", "osa_db"),
        user=os.getenv("OSA_DB_USER", "postgres"),
        password=os.getenv("OSA_DB_PASS", ""),
        connect_timeout=10,
    )


def fetch_latest_run(conn, year: int):
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT id, year, status, quality_score, validation_id, message, started_at, completed_at
            FROM collect.pipeline_runs
            WHERE year = %s
            ORDER BY id DESC
            LIMIT 1
            """,
            (year,),
        )
        row = cur.fetchone()

    if not row:
        return None

    return {
        "id": row[0],
        "year": row[1],
        "status": row[2],
        "quality_score": float(row[3]) if row[3] is not None else None,
        "validation_id": row[4],
        "message": row[5],
        "started_at": str(row[6]) if row[6] is not None else None,
        "completed_at": str(row[7]) if row[7] is not None else None,
    }


def send_webhook(webhook_url: str, payload: dict) -> None:
    response = requests.post(webhook_url, json=payload, timeout=10)
    response.raise_for_status()


def main() -> None:
    parser = argparse.ArgumentParser(description="Alerte echec pipeline OSA")
    parser.add_argument("--year", type=int, required=True)
    parser.add_argument("--reason", type=str, default="Nightly run failed")
    parser.add_argument("--log-file", type=str, default=None)
    parser.add_argument("--webhook-url", type=str,
                        default=os.getenv("OSA_ALERT_WEBHOOK_URL"))
    parser.add_argument("--test-alert", action="store_true",
                        help="Envoie une alerte de test sans interroger la base")
    args = parser.parse_args()

    latest = None
    if not args.test_alert:
        conn = connect_db()
        try:
            latest = fetch_latest_run(conn, args.year)
        finally:
            conn.close()

    payload = {
        "service": "osa-observatory",
        "event": "nightly_failure_test" if args.test_alert else "nightly_failure",
        "reason": args.reason,
        "year": args.year,
        "log_file": args.log_file,
        "latest_run": latest,
        "is_test": args.test_alert,
    }

    log.error("ALERTE OSA: %s", json.dumps(payload, ensure_ascii=False))

    if args.webhook_url:
        try:
            send_webhook(args.webhook_url, payload)
            log.info("Webhook alerte envoye")
        except Exception as exc:
            log.error("Echec envoi webhook: %s", exc)


if __name__ == "__main__":
    main()
