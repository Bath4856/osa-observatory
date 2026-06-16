#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
OSA ISA – OPS V2
AUDIT DATABASE

Corrections (AUDIT OSA-2026-001) :
- [P1] Schéma pub ajouté à l'inventaire table_schema. pub héberge
  pub.mv_trajectories et les vues matérialisées de publication —
  son absence faussait le décompte total des tables.

- [P2] L'année de référence pour indicator_values_<year> est résolue
  dynamiquement : cfg["ref_year"] > MAX(year) actif dans
  ma.indicator_values > fallback 2024. Plus de 2024 hardcodé.
"""

import time
import psycopg2

MODULE = "DATABASE"


def scalar(cur, sql, params=None):
    cur.execute(sql, params)
    return cur.fetchone()[0]


def _resolve_ref_year(cur, cfg: dict) -> int:
    """Année de référence : cfg > MAX(year) en base > 2024."""
    if cfg.get("ref_year"):
        return int(cfg["ref_year"])
    try:
        cur.execute("SELECT MAX(year) FROM ma.indicator_values")
        row = cur.fetchone()
        if row and row[0] is not None:
            return int(row[0])
    except Exception:
        pass
    return 2024


def run(cfg: dict) -> dict:

    conn = None
    start = time.time()

    try:
        conn = psycopg2.connect(
            host=cfg["db_host"],
            port=cfg["db_port"],
            database=cfg["db_name"],
            user=cfg["db_user"],
            password=cfg["db_password"],
        )
        cur = conn.cursor()

        ref_year = _resolve_ref_year(cur, cfg)

        # ── RÉFÉRENTIELS RF ────────────────────────────────────────
        countries      = scalar(cur, "SELECT COUNT(*) FROM rf.countries")
        regions        = scalar(cur, "SELECT COUNT(*) FROM rf.regions")
        regional_blocs = scalar(cur, "SELECT COUNT(*) FROM rf.regional_blocs")

        # ── INVENTAIRE TABLES (rf + ma + ops + pub) ───────────────
        tables = scalar(cur, """
            SELECT COUNT(*)
            FROM information_schema.tables
            WHERE table_schema IN ('rf', 'ma', 'ops', 'pub')
        """)

        # ── ISA ───────────────────────────────────────────────────
        indicator_values = scalar(
            cur, "SELECT COUNT(*) FROM ma.indicator_values"
        )

        indicator_values_refyear = scalar(cur, """
            SELECT COUNT(*)
            FROM ma.indicator_values
            WHERE year = %s
        """, (ref_year,))

        null_confidence_scores = scalar(cur, """
            SELECT COUNT(*)
            FROM ma.indicator_values
            WHERE confidence_score IS NULL
        """)

        estimated_values = scalar(cur, """
            SELECT COUNT(*)
            FROM ma.indicator_values
            WHERE is_estimated = TRUE
        """)

        quality_flagged = scalar(cur, """
            SELECT COUNT(*)
            FROM ma.indicator_values
            WHERE quality_flag IS NOT NULL
        """)

        avg_confidence = scalar(cur, """
            SELECT ROUND(AVG(confidence_score)::numeric, 4)
            FROM ma.indicator_values
            WHERE year = %s
        """, (ref_year,))

        # ── LEDGER OPS ────────────────────────────────────────────
        audit_runs        = scalar(cur, "SELECT COUNT(*) FROM ops.audit_runs")
        audit_results     = scalar(cur, "SELECT COUNT(*) FROM ops.audit_results")
        publication_gate  = scalar(cur, "SELECT COUNT(*) FROM ops.audit_publication_gate")
        latest_audit      = scalar(cur, "SELECT COUNT(*) FROM ops.v_audit_latest")

        ledger_ok = (
            audit_runs >= 1
            and audit_results >= 1
            and publication_gate >= 1
            and latest_audit >= 1
        )

        # ── STATUT ────────────────────────────────────────────────
        if countries == 0:
            status = "FAIL"
        elif indicator_values == 0:
            status = "FAIL"
        elif indicator_values_refyear == 0:
            status = "FAIL"
        elif not ledger_ok:
            status = "WARNING"
        else:
            status = "PASS"

        elapsed_ms = round((time.time() - start) * 1000, 2)

        return {
            "module":     MODULE,
            "status":     status,
            "elapsed_ms": elapsed_ms,
            "ref_year":   ref_year,

            # RF
            "countries":      countries,
            "regions":        regions,
            "regional_blocs": regional_blocs,

            # META
            "tables": tables,

            # ISA
            "indicator_values":          indicator_values,
            "indicator_values_ref_year": indicator_values_refyear,
            "avg_confidence":            float(avg_confidence) if avg_confidence is not None else None,
            "null_confidence_scores":    null_confidence_scores,
            "estimated_values":          estimated_values,
            "quality_flagged":           quality_flagged,

            # OPS
            "ops_audit_runs":             audit_runs,
            "ops_audit_results":          audit_results,
            "ops_audit_publication_gate": publication_gate,
            "ops_latest_audit":           latest_audit,
        }

    except Exception as e:
        return {
            "module": MODULE,
            "status": "FAIL",
            "error":  str(e),
        }

    finally:
        if conn:
            conn.close()


if __name__ == "__main__":
    import json
    print(json.dumps(run({
        "db_host":     "osa-db",
        "db_port":     5432,
        "db_name":     "osa_db",
        "db_user":     "postgres",
        "db_password": "postgres",
    }), indent=2))
