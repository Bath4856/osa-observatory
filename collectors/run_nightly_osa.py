"""
============================================================
OSA / ISA OBSERVATORY
run_nightly_osa.py — Orchestration nocturne production
============================================================
Enchaine:
  1) Ingestion reelle via matrice (fetchers)
  2) Pipeline SQL complet (qualite, validation, analytics, publication)
  3) Export audit CSV dashboard
"""

from __future__ import annotations

import argparse
import logging
import os
from datetime import datetime
from pathlib import Path

import psycopg2
from dotenv import load_dotenv

from run_ingestion_from_matrix import build_execution_plan, connect_db as connect_ingest_db, execute_plan
from source_matrix_dashboard import export_dashboard_csv

load_dotenv()

logging.basicConfig(
    level=os.getenv("OSA_LOG_LEVEL", "INFO"),
    format="%(asctime)s | %(levelname)-8s | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger("run_nightly_osa")


def connect_db():
    return psycopg2.connect(
        host=os.getenv("OSA_DB_HOST", "localhost"),
        port=int(os.getenv("OSA_DB_PORT", "5432")),
        dbname=os.getenv("OSA_DB_NAME", "osa_db"),
        user=os.getenv("OSA_DB_USER", "postgres"),
        password=os.getenv("OSA_DB_PASS", ""),
        connect_timeout=10,
    )


def run_full_pipeline(
    conn,
    year: int,
    include_pilot: bool,
    requested_by: str,
    method_version_id: int,
    require_validation: bool,
    validation_id: int | None,
    quality_threshold: float,
):
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT run_id, status, quality_score, validation_id, message
            FROM collect.run_full_osa_pipeline(%s, %s, %s, %s, %s, %s, %s)
            """,
            (
                year,
                include_pilot,
                requested_by,
                method_version_id,
                require_validation,
                validation_id,
                quality_threshold,
            ),
        )
        row = cur.fetchone()

    if not row:
        raise RuntimeError("run_full_osa_pipeline a retourne un resultat vide")

    return {
        "run_id": row[0],
        "status": row[1],
        "quality_score": row[2],
        "validation_id": row[3],
        "message": row[4],
    }


def auto_approve_validation(
    conn,
    validation_id: int,
    approver_1: str,
    approver_2: str,
    signature_hash_1: str,
    signature_hash_2: str,
) -> bool:
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT rf.validate_dataset(%s, %s, %s, %s, %s)
            """,
            (validation_id, approver_1, approver_2,
             signature_hash_1, signature_hash_2),
        )
        row = cur.fetchone()
    return bool(row and row[0])


def main() -> None:
    parser = argparse.ArgumentParser(description="OSA — run nocturne complet")
    parser.add_argument("--year", type=int, default=datetime.now().year - 1)
    parser.add_argument("--include-pilot", action="store_true")
    parser.add_argument("--requested-by", type=str, default="SCHEDULER")
    parser.add_argument("--method-version-id", type=int, default=1)
    parser.add_argument("--quality-threshold", type=float, default=0.70)
    parser.add_argument("--require-validation",
                        action="store_true", default=True)
    parser.add_argument("--no-require-validation", action="store_true")
    parser.add_argument("--validation-id", type=int, default=None)
    parser.add_argument("--auto-approve", action="store_true")
    parser.add_argument("--approver-1", type=str, default="validator_a")
    parser.add_argument("--approver-2", type=str, default="validator_b")
    parser.add_argument("--signature-hash-1", type=str, default="sig_hash_a")
    parser.add_argument("--signature-hash-2", type=str, default="sig_hash_b")
    parser.add_argument("--export-audit-csv", action="store_true")
    parser.add_argument("--export-dir", type=str,
                        default="logs/source_dashboard_exports")
    parser.add_argument("--dry-run-ingestion", action="store_true")
    args = parser.parse_args()

    require_validation = False if args.no_require_validation else args.require_validation

    log.info("=== OSA NIGHTLY START year=%s include_pilot=%s ===",
             args.year, args.include_pilot)

    conn_ing = connect_ingest_db()
    try:
        plan = build_execution_plan(
            conn=conn_ing,
            year_from=args.year,
            year_to=args.year,
            include_pilot=args.include_pilot,
            requested_by=args.requested_by,
        )
    finally:
        conn_ing.close()

    execute_plan(
        plan=plan,
        year_from=args.year,
        year_to=args.year,
        dry_run=args.dry_run_ingestion,
    )

    final_result = None

    conn = connect_db()
    try:
        first = run_full_pipeline(
            conn=conn,
            year=args.year,
            include_pilot=args.include_pilot,
            requested_by=args.requested_by,
            method_version_id=args.method_version_id,
            require_validation=require_validation,
            validation_id=args.validation_id,
            quality_threshold=args.quality_threshold,
        )
        log.info("Run#%s status=%s quality=%s validation_id=%s msg=%s",
                 first["run_id"], first["status"], first["quality_score"], first["validation_id"], first["message"])
        final_result = first

        if first["status"] == "WAITING_VALIDATION" and args.auto_approve and first["validation_id"]:
            approved = auto_approve_validation(
                conn=conn,
                validation_id=int(first["validation_id"]),
                approver_1=args.approver_1,
                approver_2=args.approver_2,
                signature_hash_1=args.signature_hash_1,
                signature_hash_2=args.signature_hash_2,
            )
            log.info("Auto-approve validation_id=%s result=%s",
                     first["validation_id"], approved)

            if approved:
                second = run_full_pipeline(
                    conn=conn,
                    year=args.year,
                    include_pilot=args.include_pilot,
                    requested_by=args.requested_by,
                    method_version_id=args.method_version_id,
                    require_validation=require_validation,
                    validation_id=int(first["validation_id"]),
                    quality_threshold=args.quality_threshold,
                )
                log.info("Run#%s status=%s quality=%s validation_id=%s msg=%s",
                         second["run_id"], second["status"], second["quality_score"], second["validation_id"], second["message"])
                final_result = second

        if args.export_audit_csv:
            paths = export_dashboard_csv(
                conn=conn,
                export_dir=Path(args.export_dir).resolve(),
                year=args.year,
            )
            for path in paths:
                log.info("Audit CSV: %s", path)
    finally:
        conn.close()

    if final_result and final_result["status"] in ("FAILED", "FAILED_QUALITY"):
        raise SystemExit(2)

    log.info("=== OSA NIGHTLY END ===")


if __name__ == "__main__":
    main()
