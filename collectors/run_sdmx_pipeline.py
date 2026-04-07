"""
============================================================
OSA / ISA OBSERVATORY
run_sdmx_pipeline.py — Pipeline SDMX expert
============================================================
Philosophie d'automatisation:
  - AUTOMATISER: découverte SDMX, ingestion brute, versioning
  - SEMI-AUTOMATISER: mapping indicateurs (suggestions)
  - NE JAMAIS AUTOMATISER: validation finale, pondérations, interprétation
============================================================
"""

from __future__ import annotations

import argparse
import json
import logging
import os
import re
from datetime import datetime
from difflib import SequenceMatcher
from typing import Optional

import psycopg2
from dotenv import load_dotenv

from sdmx_crawler import SDMXCrawler

load_dotenv()

logging.basicConfig(
    level=os.getenv("OSA_LOG_LEVEL", "INFO"),
    format="%(asctime)s | %(levelname)-8s | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger("run_sdmx_pipeline")


def connect_db():
    return psycopg2.connect(
        host=os.getenv("OSA_DB_HOST", "localhost"),
        port=int(os.getenv("OSA_DB_PORT", "5432")),
        dbname=os.getenv("OSA_DB_NAME", "osa_db"),
        user=os.getenv("OSA_DB_USER", "postgres"),
        password=os.getenv("OSA_DB_PASS", ""),
        connect_timeout=10,
    )


def generate_mapping_suggestions(
    conn,
    provider_code: str,
    dataset_filter: Optional[str] = None,
    min_score: float = 0.45,
) -> int:
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT provider_code, dataset_id, codelist_id, code_value, code_name
            FROM collect.sdmx_codelist_codes
            WHERE provider_code = %s
            """,
            (provider_code,),
        )
        code_rows = cur.fetchall()

        cur.execute(
            """
            SELECT indicator_code, source_indicator_code, COALESCE(source_notes, '')
            FROM collect.indicator_source
            """
        )
        indicators = cur.fetchall()

        inserted = 0
        for p_code, dataset_id, _, code_value, code_name in code_rows:
            if dataset_filter and dataset_filter not in dataset_id:
                continue

            candidate_text = f"{code_value} {code_name}".lower()
            best_indicator = None
            best_score = 0.0
            rationale = ""

            for indicator_code, source_code, source_notes in indicators:
                ref_text = f"{source_code} {source_notes}".lower()
                score = SequenceMatcher(None, candidate_text, ref_text).ratio()
                if score > best_score:
                    best_score = score
                    best_indicator = indicator_code
                    rationale = f"similarite texte={score:.2f} entre '{code_value}' et '{source_code}'"

            if best_score < min_score:
                continue

            cur.execute(
                """
                INSERT INTO collect.sdmx_mapping_suggestions
                    (provider_code, dataset_id, candidate_code,
                     suggested_indicator_code, score, rationale, status)
                VALUES (%s, %s, %s, %s, %s, %s, 'PENDING')
                """,
                (p_code, dataset_id, code_value, best_indicator,
                 round(best_score * 100, 2), rationale),
            )
            inserted += 1

    conn.commit()
    return inserted


def export_validation_queue(conn, output_path: str) -> int:
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT provider_code, dataset_id, candidate_code,
                   suggested_indicator_code, score, rationale, status
            FROM collect.sdmx_mapping_suggestions
            WHERE status = 'PENDING'
            ORDER BY score DESC, provider_code, dataset_id
            """
        )
        rows = cur.fetchall()

    with open(output_path, "w", encoding="utf-8") as f:
        f.write(
            "provider_code,dataset_id,candidate_code,suggested_indicator_code,score,rationale,status\n")
        for row in rows:
            escaped = [
                str(v).replace('"', '""') if v is not None else ""
                for v in row
            ]
            f.write(
                ",".join([f'"{v}"' for v in escaped]) + "\n"
            )

    return len(rows)


def assert_manual_validation_gate() -> None:
    log.warning("Validation finale: MANUELLE UNIQUEMENT")
    log.warning("Pondérations: MANUELLES UNIQUEMENT")
    log.warning("Interprétation: MANUELLE UNIQUEMENT")


def find_approved_conflicts(
    conn,
    provider_code: str,
) -> list[tuple[str, str, str, int]]:
    """
    Détecte les conflits de mapping parmi les suggestions APPROVED.
    Un conflit = même candidate_code mappé à plusieurs indicator_code.
    """
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT
                provider_code,
                dataset_id,
                candidate_code,
                COUNT(DISTINCT suggested_indicator_code) AS indicator_count
            FROM collect.sdmx_mapping_suggestions
            WHERE provider_code = %s
              AND status = 'APPROVED'
              AND suggested_indicator_code IS NOT NULL
            GROUP BY provider_code, dataset_id, candidate_code
            HAVING COUNT(DISTINCT suggested_indicator_code) > 1
            ORDER BY dataset_id, candidate_code
            """,
            (provider_code,),
        )
        return cur.fetchall()


def export_conflicts_report(
    conn,
    provider_code: str,
    output_path: str,
) -> int:
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT
                provider_code,
                dataset_id,
                candidate_code,
                suggested_indicator_code,
                score,
                reviewer,
                reviewed_at,
                id AS suggestion_id
            FROM collect.sdmx_mapping_suggestions
            WHERE provider_code = %s
              AND status = 'APPROVED'
              AND suggested_indicator_code IS NOT NULL
              AND (provider_code, dataset_id, candidate_code) IN (
                    SELECT provider_code, dataset_id, candidate_code
                    FROM collect.sdmx_mapping_suggestions
                    WHERE provider_code = %s
                      AND status = 'APPROVED'
                      AND suggested_indicator_code IS NOT NULL
                    GROUP BY provider_code, dataset_id, candidate_code
                    HAVING COUNT(DISTINCT suggested_indicator_code) > 1
              )
            ORDER BY dataset_id, candidate_code, score DESC, id
            """,
            (provider_code, provider_code),
        )
        rows = cur.fetchall()

    with open(output_path, "w", encoding="utf-8") as f:
        f.write(
            "provider_code,dataset_id,candidate_code,suggested_indicator_code,score,reviewer,reviewed_at,suggestion_id\n"
        )
        for row in rows:
            escaped = [
                str(v).replace('"', '""') if v is not None else ""
                for v in row
            ]
            f.write(
                ",".join([f'\"{v}\"' for v in escaped]) + "\n"
            )

    return len(rows)


def apply_approved_mappings(
    conn,
    provider_code: str,
    reviewer: str,
    dry_run: bool = False,
) -> tuple[int, int]:
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT id, provider_code, dataset_id, candidate_code,
                   suggested_indicator_code, score
            FROM collect.sdmx_mapping_suggestions
            WHERE provider_code = %s
              AND status = 'APPROVED'
              AND suggested_indicator_code IS NOT NULL
            ORDER BY score DESC, id
            """,
            (provider_code,),
        )
        approved_rows = cur.fetchall()

        if dry_run:
            return len(approved_rows), 0

        applied = 0
        skipped = 0

        for row in approved_rows:
            (
                suggestion_id,
                p_code,
                dataset_id,
                candidate_code,
                indicator_code,
                score,
            ) = row

            cur.execute(
                """
                INSERT INTO collect.sdmx_indicator_mapping
                    (provider_code, dataset_id, candidate_code, indicator_code,
                     mapping_source, suggestion_id, approved_score,
                     approved_by, approved_at, is_active, updated_at)
                VALUES (%s, %s, %s, %s,
                        'HUMAN_APPROVAL', %s, %s,
                        %s, now(), TRUE, now())
                ON CONFLICT (provider_code, dataset_id, candidate_code)
                DO UPDATE SET
                    indicator_code = EXCLUDED.indicator_code,
                    mapping_source = 'HUMAN_APPROVAL',
                    suggestion_id = EXCLUDED.suggestion_id,
                    approved_score = EXCLUDED.approved_score,
                    approved_by = EXCLUDED.approved_by,
                    approved_at = now(),
                    is_active = TRUE,
                    updated_at = now()
                """,
                (
                    p_code,
                    dataset_id,
                    candidate_code,
                    indicator_code,
                    suggestion_id,
                    score,
                    reviewer,
                ),
            )

            if cur.rowcount >= 1:
                applied += 1
            else:
                skipped += 1

    conn.commit()
    return applied, skipped


def main() -> None:
    parser = argparse.ArgumentParser(
        description="OSA — Pipeline SDMX (expert)")
    parser.add_argument("--provider", choices=["IMF", "OECD"], required=True)
    parser.add_argument("--discover-limit", type=int, default=30)
    parser.add_argument("--dataset-regex", type=str, default=None)
    parser.add_argument("--ingest-dataset", type=str, default=None)
    parser.add_argument("--ingest-start-year", type=int, default=2018)
    parser.add_argument("--ingest-end-year", type=int, default=2024)
    parser.add_argument("--ingest-max-series", type=int, default=100)
    parser.add_argument("--skip-discovery", action="store_true")
    parser.add_argument("--skip-ingestion", action="store_true")
    parser.add_argument("--skip-mapping", action="store_true")
    parser.add_argument("--apply-approved", action="store_true",
                        help="Applique les suggestions APPROVED vers le mapping officiel")
    parser.add_argument("--check-conflicts", action="store_true",
                        help="Vérifie les conflits APPROVED avant application")
    parser.add_argument("--force-apply-approved", action="store_true",
                        help="Force l'application meme si conflits APPROVED détectés")
    parser.add_argument("--conflicts-export", type=str,
                        default="logs/sdmx_conflicts_report.csv")
    parser.add_argument("--reviewer", type=str, default="OSA_REVIEWER")
    parser.add_argument("--validation-export", type=str,
                        default="logs/sdmx_validation_queue.csv")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    selected_dataset = args.ingest_dataset

    if not args.skip_discovery:
        crawler = SDMXCrawler(dry_run=args.dry_run, db_write=not args.dry_run)
        try:
            crawler.connect_db()
            result = crawler.run_discovery(
                provider_code=args.provider,
                dataset_regex=args.dataset_regex,
                limit=args.discover_limit,
            )
            log.info("Découverte %s: %s", args.provider,
                     json.dumps(result, ensure_ascii=False))

            if not selected_dataset and args.dataset_regex:
                flows = crawler.discover_dataflows(args.provider)
                pattern = re.compile(args.dataset_regex)
                for flow in flows:
                    if pattern.search(flow["dataset_id"]) or pattern.search(flow.get("dataset_name", "")):
                        selected_dataset = flow["dataset_id"]
                        break
        finally:
            crawler.close_db()

    if not args.skip_ingestion and selected_dataset:
        crawler = SDMXCrawler(dry_run=args.dry_run, db_write=not args.dry_run)
        try:
            crawler.connect_db()
            ingest = crawler.ingest_raw_observations(
                provider_code=args.provider,
                dataset_id=selected_dataset,
                start_year=args.ingest_start_year,
                end_year=args.ingest_end_year,
                max_series=args.ingest_max_series,
            )
            log.info("Ingestion brute: %s", json.dumps(
                ingest, ensure_ascii=False))
        finally:
            crawler.close_db()
    elif not args.skip_ingestion:
        log.warning(
            "Ingestion brute ignorée: aucun dataset sélectionné (utiliser --ingest-dataset ou --dataset-regex)")

    if args.skip_mapping and not args.apply_approved:
        assert_manual_validation_gate()
        return

    conn = connect_db()
    try:
        conflict_count = 0

        if not args.skip_mapping:
            generated = generate_mapping_suggestions(
                conn=conn,
                provider_code=args.provider,
                dataset_filter=None,
                min_score=0.45,
            )
            log.info("Suggestions mapping générées: %d", generated)

            queue_count = export_validation_queue(conn, args.validation_export)
            log.info("File de validation exportée: %d lignes -> %s",
                     queue_count, args.validation_export)

        if args.check_conflicts or args.apply_approved:
            conflicts = find_approved_conflicts(
                conn=conn, provider_code=args.provider)
            conflict_count = len(conflicts)
            log.info("Conflits APPROVED détectés: %d", conflict_count)

            if conflict_count > 0:
                conflict_lines = export_conflicts_report(
                    conn=conn,
                    provider_code=args.provider,
                    output_path=args.conflicts_export,
                )
                log.warning(
                    "Rapport conflits exporté: %d lignes -> %s",
                    conflict_lines,
                    args.conflicts_export,
                )

        if args.apply_approved:
            if conflict_count > 0 and not args.force_apply_approved:
                log.error(
                    "Application bloquée: conflits APPROVED présents. "
                    "Résoudre le rapport ou utiliser --force-apply-approved."
                )
                assert_manual_validation_gate()
                return

            applied, skipped = apply_approved_mappings(
                conn=conn,
                provider_code=args.provider,
                reviewer=args.reviewer,
                dry_run=args.dry_run,
            )
            log.info("Mappings APPROVED appliqués: %d | ignorés: %d",
                     applied, skipped)

        assert_manual_validation_gate()
        log.info("Horodatage pipeline: %s", datetime.now().isoformat())
    finally:
        conn.close()


if __name__ == "__main__":
    main()
