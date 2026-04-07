"""
============================================================
OSA / ISA OBSERVATORY
load_source_matrix.py — Charge la matrice YAML dans PostgreSQL
============================================================
"""

from __future__ import annotations

import argparse
import logging
import os
from pathlib import Path

import psycopg2
import yaml  # pyright: ignore[reportMissingImports]
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(
    level=os.getenv("OSA_LOG_LEVEL", "INFO"),
    format="%(asctime)s | %(levelname)-8s | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger("load_source_matrix")


DEFAULT_MATRIX_FILE = Path(__file__).resolve(
).parent.parent / "matrice_sources_go_nogo_osa.yaml"


def connect_db():
    return psycopg2.connect(
        host=os.getenv("OSA_DB_HOST", "localhost"),
        port=int(os.getenv("OSA_DB_PORT", "5432")),
        dbname=os.getenv("OSA_DB_NAME", "osa_db"),
        user=os.getenv("OSA_DB_USER", "postgres"),
        password=os.getenv("OSA_DB_PASS", ""),
        connect_timeout=10,
    )


def load_yaml(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as f:
        data = yaml.safe_load(f)
    if not isinstance(data, dict):
        raise ValueError("YAML invalide: racine attendue de type objet")
    if "sources" not in data or not isinstance(data["sources"], list):
        raise ValueError("YAML invalide: cle 'sources' absente ou non liste")
    return data


def upsert_source_registry(conn, payload: dict, dry_run: bool = False) -> tuple[int, int]:
    quality = payload.get("quality", {}) or {}
    sources = payload.get("sources", [])

    source_count = 0
    indicator_count = 0

    with conn.cursor() as cur:
        for src in sources:
            source_id = src.get("source_id")
            if not source_id:
                continue

            if not dry_run:
                cur.execute(
                    """
                    INSERT INTO collect.source_registry(
                        source_id, name, organization, api_type, base_url,
                        status, priority, coverage, stability, limits, reason,
                        freshness_score, completeness_score, reliability_score,
                        is_active, updated_at
                    )
                    VALUES (
                        %s, %s, %s, %s, %s,
                        %s, %s, %s, %s, %s, %s,
                        %s, %s, %s,
                        TRUE, now()
                    )
                    ON CONFLICT (source_id)
                    DO UPDATE SET
                        name = EXCLUDED.name,
                        organization = EXCLUDED.organization,
                        api_type = EXCLUDED.api_type,
                        base_url = EXCLUDED.base_url,
                        status = EXCLUDED.status,
                        priority = EXCLUDED.priority,
                        coverage = EXCLUDED.coverage,
                        stability = EXCLUDED.stability,
                        limits = EXCLUDED.limits,
                        reason = EXCLUDED.reason,
                        freshness_score = EXCLUDED.freshness_score,
                        completeness_score = EXCLUDED.completeness_score,
                        reliability_score = EXCLUDED.reliability_score,
                        is_active = TRUE,
                        updated_at = now()
                    """,
                    (
                        source_id,
                        src.get("name") or source_id,
                        src.get("organization"),
                        src.get("api_type"),
                        src.get("base_url"),
                        src.get("status", "PILOT"),
                        int(src.get("priority", 999)),
                        src.get("coverage"),
                        src.get("stability"),
                        src.get("limits"),
                        src.get("reason"),
                        quality.get("freshness_score"),
                        quality.get("completeness_score"),
                        quality.get("reliability_score"),
                    ),
                )

                cur.execute(
                    "DELETE FROM collect.source_registry_indicators WHERE source_id = %s",
                    (source_id,),
                )

            source_count += 1

            for ind in src.get("indicators", []) or []:
                source_code = ind.get("source_code")
                if not source_code:
                    continue

                indicator_count += 1
                if dry_run:
                    continue

                cur.execute(
                    """
                    INSERT INTO collect.source_registry_indicators(
                        source_id, osa_code, source_code, endpoint,
                        fallback, unit, frequency, decision,
                        is_active, updated_at
                    )
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, TRUE, now())
                    ON CONFLICT (source_id, source_code)
                    DO UPDATE SET
                        osa_code = EXCLUDED.osa_code,
                        endpoint = EXCLUDED.endpoint,
                        fallback = EXCLUDED.fallback,
                        unit = EXCLUDED.unit,
                        frequency = EXCLUDED.frequency,
                        decision = EXCLUDED.decision,
                        is_active = TRUE,
                        updated_at = now()
                    """,
                    (
                        source_id,
                        ind.get("osa_code"),
                        source_code,
                        ind.get("endpoint"),
                        ind.get("fallback"),
                        ind.get("unit"),
                        ind.get("frequency"),
                        ind.get("decision", "PILOT"),
                    ),
                )

    if not dry_run:
        conn.commit()

    return source_count, indicator_count


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Charge la matrice source OSA en base")
    parser.add_argument("--file", type=str, default=str(DEFAULT_MATRIX_FILE))
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    matrix_path = Path(args.file).resolve()
    if not matrix_path.exists():
        raise FileNotFoundError(f"Fichier introuvable: {matrix_path}")

    payload = load_yaml(matrix_path)

    conn = connect_db()
    try:
        source_count, indicator_count = upsert_source_registry(
            conn=conn,
            payload=payload,
            dry_run=args.dry_run,
        )
        log.info(
            "Matrice chargee | sources:%d | indicateurs:%d | dry_run:%s",
            source_count,
            indicator_count,
            args.dry_run,
        )
    finally:
        conn.close()


if __name__ == "__main__":
    main()
