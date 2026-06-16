#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
OSA ISA
P8 OPS V2
PERFORMANCE AUDIT

Corrections (AUDIT OSA-2026-001) :
- [P0] Injection SQL via f-string : `WHERE year = {target_year}` avec
  target_year pouvant valoir None génère `WHERE year = None` — syntaxe
  PostgreSQL invalide qui lève une ProgrammingError. Corrigé par
  paramétrage psycopg2 (`%s`, params tuple) sur toutes les requêtes
  utilisant target_year.
- [P1] target_year résolu dynamiquement si absent de cfg :
  cfg["publication_year"] > MAX(year) en base > fallback now()-1.
  Plus de risque de None silencieux.
- [P2] Clé api_url / api_base_url unifiée (même helper que les autres
  modules).
"""

import time
import requests
import psycopg2
from datetime import datetime

MODULE = "PERFORMANCE"


def scalar(cur, sql, params=None):
    cur.execute(sql, params)
    return cur.fetchone()[0]


def _get_base(cfg: dict) -> str:
    base = cfg.get("api_url") or cfg.get("api_base_url")
    if not base:
        raise ValueError("cfg manque api_url ou api_base_url")
    return base.rstrip("/")


def _resolve_year(cur, cfg: dict) -> int:
    """cfg["publication_year"] > MAX(year) en base > now()-1."""
    if cfg.get("publication_year"):
        return int(cfg["publication_year"])
    try:
        cur.execute("SELECT MAX(year) FROM ma.indicator_values")
        row = cur.fetchone()
        if row and row[0] is not None:
            return int(row[0])
    except Exception:
        pass
    return datetime.now().year - 1


def run(cfg: dict) -> dict:

    conn = None
    global_start = time.time()

    try:
        perf_cfg = cfg.get("performance", {})
        api_limit_ms      = perf_cfg.get("api_max_ms",      250)
        database_limit_ms = perf_cfg.get("database_max_ms", 200)
        total_limit_ms    = perf_cfg.get("total_max_ms",    500)

        base = _get_base(cfg)

        # ── API HEALTH ────────────────────────────────────────────
        api_start = time.time()
        try:
            response = requests.get(f"{base}/health", timeout=30)
            api_status = response.status_code
        except Exception:
            api_status = None
        api_elapsed_ms = round((time.time() - api_start) * 1000, 2)

        if api_status != 200:
            return {
                "module":          MODULE,
                "status":          "FAIL",
                "reason":          "API_UNREACHABLE",
                "api_status_code": api_status,
                "api_elapsed_ms":  api_elapsed_ms,
            }

        # ── DATABASE ──────────────────────────────────────────────
        conn = psycopg2.connect(
            host=cfg["db_host"],
            port=cfg["db_port"],
            dbname=cfg["db_name"],
            user=cfg["db_user"],
            password=cfg["db_password"],
        )
        cur = conn.cursor()

        # Résolution de l'année AVANT toute requête paramétrée
        target_year = _resolve_year(cur, cfg)

        db_start = time.time()

        countries        = scalar(cur, "SELECT COUNT(*) FROM rf.countries")
        indicator_values = scalar(cur, "SELECT COUNT(*) FROM ma.indicator_values")

        # Paramétrage psycopg2 — plus de f-string avec target_year
        indicator_values_year = scalar(cur, """
            SELECT COUNT(*)
            FROM ma.indicator_values
            WHERE year = %s
        """, (target_year,))

        avg_confidence = scalar(cur, """
            SELECT ROUND(AVG(confidence_score)::numeric, 4)
            FROM ma.indicator_values
            WHERE year = %s
        """, (target_year,))

        db_elapsed_ms    = round((time.time() - db_start) * 1000, 2)
        total_elapsed_ms = round((time.time() - global_start) * 1000, 2)

        # ── ANALYSE ───────────────────────────────────────────────
        warnings = []
        status   = "PASS"

        if countries < 54:
            status = "FAIL"
            warnings.append("INVALID_COUNTRY_COVERAGE")

        if indicator_values == 0:
            status = "FAIL"
            warnings.append("NO_INDICATOR_VALUES")

        if indicator_values_year == 0:
            status = "FAIL"
            warnings.append("NO_DATA_FOR_PUBLICATION_YEAR")

        if api_elapsed_ms > api_limit_ms and status == "PASS":
            status = "WARNING"
            warnings.append("API_SLOW")

        if db_elapsed_ms > database_limit_ms and status == "PASS":
            status = "WARNING"
            warnings.append("DATABASE_SLOW")

        if total_elapsed_ms > total_limit_ms and status == "PASS":
            status = "WARNING"
            warnings.append("GLOBAL_PERFORMANCE_DEGRADED")

        return {
            "module":                 MODULE,
            "status":                 status,
            "api_elapsed_ms":         api_elapsed_ms,
            "database_elapsed_ms":    db_elapsed_ms,
            "total_elapsed_ms":       total_elapsed_ms,
            "target_year":            target_year,
            "countries":              countries,
            "indicator_values":       indicator_values,
            "indicator_values_year":  indicator_values_year,
            "avg_confidence":         float(avg_confidence) if avg_confidence else None,
            "api_limit_ms":           api_limit_ms,
            "database_limit_ms":      database_limit_ms,
            "total_limit_ms":         total_limit_ms,
            "warnings":               warnings,
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
        "api_url":          "https://api.osa-observatory.africa",
        "db_host":          "osa-db",
        "db_port":          5432,
        "db_name":          "osa_db",
        "db_user":          "postgres",
        "db_password":      "CHANGE_ME",
        "publication_year": 2024,
        "performance": {
            "api_max_ms":      250,
            "database_max_ms": 200,
            "total_max_ms":    500,
        },
    }), indent=2))
