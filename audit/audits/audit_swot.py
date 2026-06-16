#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
OSA ISA – OPS V2
AUDIT SWOT

Corrections (AUDIT OSA-2026-001) :
- [P1] year=2024 hardcodé dans l'URL remplacé par résolution dynamique :
  cfg["ref_year"] > now()-1. Même logique que les autres modules API.
- [P2] Clé api_url / api_base_url unifiée.
"""

import time
import requests
from datetime import datetime

MODULE = "SWOT"


def _get_base(cfg: dict) -> str:
    base = cfg.get("api_url") or cfg.get("api_base_url")
    if not base:
        raise ValueError("cfg manque api_url ou api_base_url")
    return base.rstrip("/")


def _resolve_year(cfg: dict) -> int:
    if cfg.get("ref_year"):
        return int(cfg["ref_year"])
    return datetime.now().year - 1


def run(cfg: dict) -> dict:

    start       = time.time()
    base        = _get_base(cfg)
    target_year = _resolve_year(cfg)

    try:
        response = requests.get(
            f"{base}/api/v2/sovereignty/swot?year={target_year}&limit=1000",
            timeout=60,
        )

        elapsed_ms = round((time.time() - start) * 1000, 2)

        if response.status_code != 200:
            return {
                "module":      MODULE,
                "status":      "FAIL",
                "status_code": response.status_code,
                "elapsed_ms":  elapsed_ms,
            }

        rows = response.json()

        if not isinstance(rows, list):
            return {
                "module":    MODULE,
                "status":    "FAIL",
                "reason":    "INVALID_PAYLOAD",
                "elapsed_ms": elapsed_ms,
            }

        total_rows           = len(rows)
        countries            = set()
        pillars              = set()
        publication_statuses = set()
        strategic_classes    = set()
        strategic_roles      = set()
        risk_scores          = []
        upside_scores        = []

        for row in rows:
            iso3               = row.get("country_iso3")
            pillar             = row.get("pillar_code")
            publication_status = row.get("publication_status")
            strategic_class    = row.get("strategic_attention_class")
            strategic_role     = row.get("swot_strategic_role")

            if iso3:               countries.add(iso3)
            if pillar:             pillars.add(pillar)
            if publication_status: publication_statuses.add(publication_status)
            if strategic_class:    strategic_classes.add(strategic_class)
            if strategic_role:     strategic_roles.add(strategic_role)

            for val, lst in [
                (row.get("strategic_risk_score"),   risk_scores),
                (row.get("strategic_upside_score"), upside_scores),
            ]:
                if val is not None:
                    try:
                        lst.append(float(val))
                    except Exception:
                        pass

        avg_risk   = round(sum(risk_scores)   / len(risk_scores),   4) if risk_scores   else None
        avg_upside = round(sum(upside_scores) / len(upside_scores), 4) if upside_scores else None

        if total_rows == 0:
            status = "FAIL"
        elif len(countries) < 54:
            status = "WARNING"
        elif len(pillars) < 10:
            status = "WARNING"
        else:
            status = "PASS"

        return {
            "module":               MODULE,
            "status":               status,
            "elapsed_ms":           elapsed_ms,
            "target_year":          target_year,
            "rows":                 total_rows,
            "countries":            len(countries),
            "pillars":              sorted(list(pillars)),
            "publication_statuses": sorted(list(publication_statuses)),
            "strategic_classes":    sorted(list(strategic_classes)),
            "strategic_roles":      sorted(list(strategic_roles)),
            "avg_risk":             avg_risk,
            "avg_upside":           avg_upside,
            "min_risk":             min(risk_scores)   if risk_scores   else None,
            "max_risk":             max(risk_scores)   if risk_scores   else None,
            "min_upside":           min(upside_scores) if upside_scores else None,
            "max_upside":           max(upside_scores) if upside_scores else None,
        }

    except Exception as e:
        return {
            "module": MODULE,
            "status": "FAIL",
            "error":  str(e),
        }


if __name__ == "__main__":
    import json
    print(json.dumps(run({
        "api_url": "https://api.osa-observatory.africa",
    }), indent=2))
