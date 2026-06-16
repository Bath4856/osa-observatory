#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
OSA ISA – OPS V2
AUDIT ISA

Corrections (AUDIT OSA-2026-001) :
- [P2] `api_year != 2024` remplacé par une comparaison dynamique.
  L'année attendue est résolue depuis cfg["ref_year"] si présent,
  sinon calculée comme l'année courante - 1 (N-1, conformément à la
  politique de publication OSA : Y = publication, Y-1 = données).
  Un WARNING est émis si api_year < expected_year (données en retard)
  ou api_year > expected_year (données plus récentes qu'attendu —
  cas PRELIMINARY, non bloquant).
"""

import time
import requests
from datetime import datetime

MODULE = "ISA"


def _expected_year(cfg: dict) -> int:
    """Année de données attendue : cfg["ref_year"] ou année courante - 1."""
    if cfg.get("ref_year"):
        return int(cfg["ref_year"])
    return datetime.now().year - 1


def run(cfg: dict) -> dict:

    start = time.time()
    base  = (cfg.get("api_url") or cfg.get("api_base_url", "")).rstrip("/")
    expected_year = _expected_year(cfg)

    try:
        response = requests.get(
            f"{base}/api/v2/scores",
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

        payload = response.json()

        if not isinstance(payload, dict):
            return {
                "module":    MODULE,
                "status":    "FAIL",
                "reason":    "INVALID_PAYLOAD",
                "elapsed_ms": elapsed_ms,
            }

        api_year  = payload.get("year")
        api_count = payload.get("count", 0)
        scores    = payload.get("scores", [])

        if not isinstance(scores, list):
            return {
                "module":    MODULE,
                "status":    "FAIL",
                "reason":    "INVALID_SCORES_ARRAY",
                "elapsed_ms": elapsed_ms,
            }

        countries            = set()
        years                = set()
        valid_scores         = 0
        min_score            = None
        max_score            = None
        avg_confidence       = []
        trajectories         = set()
        publication_statuses = set()

        for row in scores:
            iso3               = row.get("country_iso3")
            year               = row.get("year")
            score              = row.get("isa_observed_score")
            confidence         = row.get("data_confidence")
            trajectory         = row.get("sovereign_trajectory")
            publication_status = row.get("publication_status")

            if iso3:               countries.add(iso3)
            if year is not None:   years.add(year)
            if trajectory:         trajectories.add(trajectory)
            if publication_status: publication_statuses.add(publication_status)

            if confidence is not None:
                try:
                    avg_confidence.append(float(confidence))
                except Exception:
                    pass

            if score is not None:
                valid_scores += 1
                try:
                    score = float(score)
                    if min_score is None or score < min_score:
                        min_score = score
                    if max_score is None or score > max_score:
                        max_score = score
                except Exception:
                    pass

        mean_confidence = (
            round(sum(avg_confidence) / len(avg_confidence), 4)
            if avg_confidence
            else None
        )

        # ── Statut ────────────────────────────────────────────────
        warnings = []
        status   = "PASS"

        if api_count < 54 or len(countries) < 54:
            status = "FAIL"
        elif valid_scores == 0:
            status = "FAIL"
        elif api_year is not None and api_year < expected_year:
            status = "WARNING"
            warnings.append(
                f"api_year={api_year} < expected={expected_year} "
                f"(données en retard)"
            )
        elif api_year is not None and api_year > expected_year:
            warnings.append(
                f"api_year={api_year} > expected={expected_year} "
                f"(données PRELIMINARY ou avance sur le calendrier)"
            )

        return {
            "module":               MODULE,
            "status":               status,
            "elapsed_ms":           elapsed_ms,
            "api_year":             api_year,
            "expected_year":        expected_year,
            "api_count":            api_count,
            "countries":            len(countries),
            "years":                sorted(list(years)),
            "valid_scores":         valid_scores,
            "min_score":            min_score,
            "max_score":            max_score,
            "avg_confidence":       mean_confidence,
            "publication_statuses": sorted(list(publication_statuses)),
            "trajectories":         sorted(list(trajectories)),
            "warnings":             warnings,
        }

    except Exception as e:
        return {
            "module": MODULE,
            "status": "FAIL",
            "error":  str(e),
        }


if __name__ == "__main__":
    import json
    print(json.dumps(
        run({"api_url": "https://api.osa-observatory.africa"}),
        indent=2,
    ))
