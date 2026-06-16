#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
OSA ISA
P8 OPS V2
SCIENTIFIC DRIFT AUDIT

Corrections (AUDIT OSA-2026-001) :
- [P0] Clé api_url / api_base_url unifiée (même helper que les autres
  modules).
- [P1] Années current_year / previous_year hardcodées (2024/2023)
  remplacées par résolution dynamique : cfg["ref_year"] pour l'année
  courante, cfg["ref_year"] - 1 pour la précédente. Fallback :
  now().year - 1 / now().year - 2.
- [P2] Seuils warning_threshold et fail_threshold configurables via
  cfg["drift_thresholds"] = {"warning": 0.05, "fail": 0.15}.
"""

import statistics
import requests
from datetime import datetime

MODULE = "SCIENTIFIC_DRIFT"

_DEFAULT_WARN_THRESHOLD = 0.05
_DEFAULT_FAIL_THRESHOLD = 0.15


def _get_base(cfg: dict) -> str:
    base = cfg.get("api_url") or cfg.get("api_base_url")
    if not base:
        raise ValueError("cfg manque api_url ou api_base_url")
    return base.rstrip("/")


def _resolve_years(cfg: dict) -> tuple[int, int]:
    """Retourne (current_year, previous_year)."""
    ref = cfg.get("ref_year")
    if ref:
        current = int(ref)
    else:
        current = datetime.now().year - 1
    return current, current - 1


class ScientificDriftAudit:

    def __init__(self, cfg: dict):
        self.cfg  = cfg
        self.base = _get_base(cfg)

        drift_cfg = cfg.get("drift_thresholds", {})
        self.warning_threshold = float(drift_cfg.get("warning", _DEFAULT_WARN_THRESHOLD))
        self.fail_threshold    = float(drift_cfg.get("fail",    _DEFAULT_FAIL_THRESHOLD))

    def get_scores(self, year: int) -> dict:
        response = requests.get(
            f"{self.base}/api/v2/scores?year={year}",
            timeout=60,
        )
        response.raise_for_status()
        payload = response.json()
        if not isinstance(payload, dict):
            raise ValueError("INVALID_PAYLOAD")
        return payload

    def extract_scores(self, payload: dict) -> list[float]:
        values = []
        for row in payload.get("scores", []):
            score = row.get("isa_observed_score")
            if score is None:
                continue
            try:
                values.append(float(score))
            except Exception:
                pass
        return values

    def compare_years(self, current_year: int, previous_year: int) -> dict:

        current_payload  = self.get_scores(current_year)
        previous_payload = self.get_scores(previous_year)

        current_scores  = self.extract_scores(current_payload)
        previous_scores = self.extract_scores(previous_payload)

        if not current_scores:
            return {"module": MODULE, "status": "FAIL", "reason": "NO_CURRENT_DATA"}
        if not previous_scores:
            return {"module": MODULE, "status": "FAIL", "reason": "NO_PREVIOUS_DATA"}

        avg_current  = round(statistics.mean(current_scores),  4)
        avg_previous = round(statistics.mean(previous_scores), 4)
        drift        = round(abs(avg_current - avg_previous),  4)
        std_current  = round(statistics.pstdev(current_scores),  4)
        std_previous = round(statistics.pstdev(previous_scores), 4)

        if drift >= self.fail_threshold:
            status = "FAIL"
        elif drift >= self.warning_threshold:
            status = "WARNING"
        else:
            status = "PASS"

        return {
            "module":            MODULE,
            "status":            status,
            "current_year":      current_year,
            "previous_year":     previous_year,
            "countries_current": len(current_scores),
            "countries_previous":len(previous_scores),
            "avg_current":       avg_current,
            "avg_previous":      avg_previous,
            "std_current":       std_current,
            "std_previous":      std_previous,
            "drift":             drift,
            "warning_threshold": self.warning_threshold,
            "fail_threshold":    self.fail_threshold,
        }


def run(cfg: dict) -> dict:
    current_year, previous_year = _resolve_years(cfg)
    audit = ScientificDriftAudit(cfg)
    return audit.compare_years(current_year, previous_year)


if __name__ == "__main__":
    import json
    print(json.dumps(run({
        "api_url": "https://api.osa-observatory.africa",
    }), indent=2))
