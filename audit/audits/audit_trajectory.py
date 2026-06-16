#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
OSA ISA
P8 OPS V2
TRAJECTORY AUDIT

Corrections (AUDIT OSA-2026-001) :
- [P0] Indicateurs `ECO_PUBLIC_LEAKAGE` et `MIN_LEAKAGE_RISK` retirés
  de la liste TRAJECTORY_INDICATORS : ces deux indicateurs n'ont pas
  été ingérés au Sprint 21 et ne sont pas prévus avant Sprint 23+.
  Leur présence dans la liste garantissait un FAIL systématique
  ("missing") sur la plateforme actuelle — faux négatif bloquant.
- [P1] Liste des indicateurs à auditer lue dynamiquement depuis
  rf.indicators (groupe TRAJECTOIRE) si la table est disponible.
  Fallback sur la liste statique des 4 indicateurs Sprint 21 ingérés.
  Principe OSA : les listes hardcodées doivent toujours pouvoir être
  overridées par la DB.
- [P2] target_year résolu dynamiquement : cfg > MAX(year) en base >
  now()-1.
"""

import time
import psycopg2
from datetime import datetime

MODULE = "TRAJECTORY"

# Fallback statique — indicateurs réellement ingérés au Sprint 21
_TRAJECTORY_INDICATORS_FALLBACK = [
    "PMIN_VALUE_CAPTURE",
    "PMIN_VALUE_LEAKAGE",
    "PMIN_SMUGGLING_SIGNAL_RANK",
    "PHUM_VALUE_CAPTURE",
]


def _resolve_year(cur, cfg: dict) -> int:
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


def _load_trajectory_indicators(cur) -> list[str]:
    """
    Lit les indicateurs du groupe TRAJECTOIRE depuis rf.indicators.
    Retourne le fallback Sprint 21 si la table ou le groupe est absent.
    """
    try:
        cur.execute("""
            SELECT code
            FROM rf.indicators
            WHERE indicator_group = 'TRAJECTOIRE'
              AND is_active = true
            ORDER BY code
        """)
        rows = cur.fetchall()
        if rows:
            return [r[0] for r in rows]
    except Exception:
        pass
    return list(_TRAJECTORY_INDICATORS_FALLBACK)


def run(cfg: dict) -> dict:

    conn       = None
    started_at = time.time()

    try:
        conn = psycopg2.connect(
            host=cfg["db_host"],
            port=cfg["db_port"],
            dbname=cfg["db_name"],
            user=cfg["db_user"],
            password=cfg["db_password"],
        )
        cur = conn.cursor()

        target_year          = _resolve_year(cur, cfg)
        trajectory_indicators = _load_trajectory_indicators(cur)

        # Référentiel des codes existants dans ma.indicator_values
        cur.execute("SELECT DISTINCT indicator_code FROM ma.indicator_values")
        existing_codes = {row[0] for row in cur.fetchall()}

        active          = []
        inactive        = []
        missing         = []
        indicator_stats = {}
        total_rows      = 0

        for indicator in trajectory_indicators:

            if indicator not in existing_codes:
                missing.append(indicator)
                indicator_stats[indicator] = {
                    "exists":          False,
                    "count":           0,
                    "avg_confidence":  None,
                }
                continue

            cur.execute("""
                SELECT
                    COUNT(*),
                    ROUND(AVG(confidence_score)::numeric, 4)
                FROM ma.indicator_values
                WHERE indicator_code = %s
                  AND year = %s
            """, (indicator, target_year))

            count, avg_conf = cur.fetchone()
            total_rows += count

            indicator_stats[indicator] = {
                "exists":         True,
                "count":          count,
                "avg_confidence": float(avg_conf) if avg_conf is not None else None,
            }

            if count > 0:
                active.append(indicator)
            else:
                inactive.append(indicator)

        declared_count = len(trajectory_indicators)
        active_count   = len(active)
        coverage_pct   = round((active_count / declared_count) * 100, 2) if declared_count else 0.0

        confidences = [
            v["avg_confidence"]
            for v in indicator_stats.values()
            if v["avg_confidence"] is not None
        ]
        avg_confidence = (
            round(sum(confidences) / len(confidences), 4) if confidences else None
        )

        if missing:
            status = "FAIL"
        elif total_rows == 0:
            status = "FAIL"
        elif coverage_pct < 100:
            status = "WARNING"
        else:
            status = "PASS"

        elapsed_ms = round((time.time() - started_at) * 1000, 2)

        return {
            "module":            MODULE,
            "status":            status,
            "target_year":       target_year,
            "elapsed_ms":        elapsed_ms,
            "declared_count":    declared_count,
            "active_count":      active_count,
            "inactive_count":    len(inactive),
            "missing_count":     len(missing),
            "coverage_pct":      coverage_pct,
            "total_rows":        total_rows,
            "avg_confidence":    avg_confidence,
            "active":            active,
            "inactive":          inactive,
            "missing":           missing,
            "indicator_stats":   indicator_stats,
            "indicators_source": "rf.indicators (TRAJECTOIRE)" if not missing else "fallback Sprint 21",
        }

    except Exception as e:
        if conn is not None:
            try:
                conn.rollback()
            except Exception:
                pass
        return {
            "module": MODULE,
            "status": "FAIL",
            "error":  str(e),
        }

    finally:
        if conn is not None:
            conn.close()


if __name__ == "__main__":
    import json
    print(json.dumps(run({
        "db_host":          "osa-db",
        "db_port":          5432,
        "db_name":          "osa_db",
        "db_user":          "postgres",
        "db_password":      "CHANGE_ME",
        "publication_year": 2024,
    }), indent=2))
