#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
OSA ISA – OPS V2
AUDIT DATA QUALITY

Corrections (AUDIT OSA-2026-001) :
- [P0] Connexion leakée : ajout d'un bloc try/finally pour garantir
  que conn.close() est appelé même en cas d'exception SQL.

- [P1] Contrôle "valeurs hors bornes" (value < 0 OR value > 100)
  restreint à layer_id = 3 (L3 normalisé). Les couches L1 et L2
  contiennent des valeurs brutes (USD, ratios > 100, etc.) qui
  déclencheraient des faux positifs massifs.

- [P2] Ajout du contrôle layer_id = 3 explicite dans le résultat
  retourné, pour traçabilité.
"""

import time
import psycopg2

MODULE = "DATA_QUALITY"


def run(cfg: dict) -> dict:

    started = time.time()
    warnings = []

    conn = psycopg2.connect(
        host=cfg["db_host"],
        port=cfg["db_port"],
        dbname=cfg["db_name"],
        user=cfg["db_user"],
        password=cfg["db_password"],
    )

    try:
        cur = conn.cursor()

        # 1) Valeurs nulles (toutes couches)
        cur.execute("""
            SELECT COUNT(*)
            FROM ma.indicator_values
            WHERE value IS NULL
        """)
        null_values = cur.fetchone()[0]

        # 2) Confiance négative (toutes couches)
        cur.execute("""
            SELECT COUNT(*)
            FROM ma.indicator_values
            WHERE confidence_score < 0
        """)
        negative_conf = cur.fetchone()[0]

        # 3) Scores hors bornes [0, 100] — L3 uniquement
        #    L1 et L2 contiennent des valeurs brutes non normalisées.
        cur.execute("""
            SELECT COUNT(*)
            FROM ma.indicator_values
            WHERE layer_id = 3
              AND (value < 0 OR value > 100)
        """)
        out_of_range = cur.fetchone()[0]

        cur.close()

    finally:
        conn.close()

    status = "PASS"

    if null_values > 0:
        warnings.append("NULL_VALUES")
        status = "WARNING"

    if negative_conf > 0:
        warnings.append("NEGATIVE_CONFIDENCE")
        status = "WARNING"

    if out_of_range > 0:
        warnings.append("OUT_OF_RANGE_VALUES_L3")
        status = "WARNING"

    elapsed = round((time.time() - started) * 1000, 2)

    return {
        "module":            MODULE,
        "status":            status,
        "elapsed_ms":        elapsed,
        "null_values":       null_values,
        "negative_confidence": negative_conf,
        "out_of_range_l3":   out_of_range,
        "out_of_range_scope": "layer_id = 3 (L3 normalisé uniquement)",
        "warnings":          warnings,
    }


if __name__ == "__main__":
    import json
    print(json.dumps(run({
        "db_host":     "localhost",
        "db_port":     5432,
        "db_name":     "osa_db",
        "db_user":     "postgres",
        "db_password": "CHANGE_ME",
    }), indent=2))
