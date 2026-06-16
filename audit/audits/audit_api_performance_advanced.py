#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
OSA ISA – OPS V2
AUDIT API PERFORMANCE (ADVANCED)

Corrections (AUDIT OSA-2026-001) :
- [P0] Bug logique seuils : avec elif, un endpoint à 12 000 ms tombait
  dans > 10000 (WARNING) sans jamais atteindre la branche > 15000
  (FAIL). Corrigé : évaluation séquentielle avec if/elif sur des
  branches exclusives correctement ordonnées, et chaque entrée porte
  un label severity pour distinguer les niveaux dans le rapport.
- [P2] Seuils configurables via cfg (fail_ms, warn_high_ms,
  warn_medium_ms). Valeurs par défaut inchangées.
"""

import time
import requests

MODULE = "API_PERFORMANCE_ADVANCED"

ENDPOINTS = [
    "/api/v2/countries",
    "/api/v2/scores",
    "/api/v2/sovereignty/swot",
    "/opendata/",
]

# Seuils par défaut (ms)
_DEFAULT_FAIL_MS       = 15_000
_DEFAULT_WARN_HIGH_MS  = 10_000
_DEFAULT_WARN_MED_MS   =  5_000


def run(cfg: dict) -> dict:

    started = time.time()
    base = (cfg.get("api_url") or cfg.get("api_base_url", "")).rstrip("/")

    api_key    = cfg.get("api_key")
    auth_token = cfg.get("auth_token")

    headers = {}
    if api_key:
        headers["X-Api-Key"] = api_key
    if auth_token:
        headers["Authorization"] = auth_token

    # Seuils configurables
    fail_ms      = int(cfg.get("perf_fail_ms",      _DEFAULT_FAIL_MS))
    warn_high_ms = int(cfg.get("perf_warn_high_ms", _DEFAULT_WARN_HIGH_MS))
    warn_med_ms  = int(cfg.get("perf_warn_med_ms",  _DEFAULT_WARN_MED_MS))

    results  = []
    failures = []
    warnings = []

    for ep in ENDPOINTS:

        url = f"{base}{ep}"
        t0  = time.time()

        try:
            requests.get(url, headers=headers, timeout=20)
            elapsed = round((time.time() - t0) * 1000, 2)

            entry = {"endpoint": ep, "elapsed_ms": elapsed}
            results.append(entry)

            # Évaluation exclusive du plus grave vers le moins grave
            if elapsed > fail_ms:
                failures.append({**entry, "severity": "CRITICAL"})
            elif elapsed > warn_high_ms:
                warnings.append({**entry, "severity": "HIGH"})
            elif elapsed > warn_med_ms:
                warnings.append({**entry, "severity": "MEDIUM"})

        except Exception as e:
            entry = {"endpoint": ep, "error": str(e)}
            failures.append({**entry, "severity": "CRITICAL"})

    if failures:
        status = "FAIL"
    elif warnings:
        status = "WARNING"
    else:
        status = "PASS"

    elapsed_total = round((time.time() - started) * 1000, 2)

    return {
        "module":      MODULE,
        "status":      status,
        "elapsed_ms":  elapsed_total,
        "results":     results,
        "warnings":    warnings,
        "failures":    failures,
        "thresholds": {
            "fail_ms":      fail_ms,
            "warn_high_ms": warn_high_ms,
            "warn_med_ms":  warn_med_ms,
        },
    }
