#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
OSA ISA – OPS V2
AUDIT API CONTRACT (AUTHENTICATED)
"""

import time
import requests

MODULE = "API_CONTRACT"

EXPECTED_ENDPOINTS = [
    "/api/v2/countries",
    "/api/v2/scores",
    "/api/v2/predictive/readiness",
    "/api/v2/predictive/signals",
    "/api/v2/predictive/fragility",
    "/api/v2/release",
    "/api/v2/opportunities",
    "/api/v2/methodology",
    "/api/v2/sovereign-projects",
    "/api/v2/early-warning/civilian-protection",
    "/api/v2/early-warning/conflict-economy",
    "/api/v2/early-warning/composite",
    "/api/v2/sovereignty/swot",
    "/api/v2/sovereignty/fiscal-margin",
    "/opendata/"
]


def run(cfg):

    started = time.time()
    base = cfg["api_url"]

    api_key = cfg.get("api_key")
    auth_token = cfg.get("auth_token")

    headers = {}

    if api_key:
        headers["X-Api-Key"] = api_key

    if auth_token:
        headers["Authorization"] = auth_token

    missing = []
    slow = []

    for ep in EXPECTED_ENDPOINTS:

        url = f"{base}{ep}"
        t0 = time.time()

        try:
            r = requests.get(url, headers=headers, timeout=30)
            elapsed = round((time.time() - t0) * 1000, 2)

            # 401 = endpoint protégé mais existant → OK
            if r.status_code == 401:
                continue

            # 404 = endpoint inexistant → FAIL
            if r.status_code == 404:
                missing.append({"endpoint": ep, "status": 404})

            # 500 / 503 = erreur serveur → FAIL
            if r.status_code >= 500:
                missing.append({"endpoint": ep, "status": r.status_code})

            # Lenteur → WARNING
            if elapsed > 5000:
                slow.append({"endpoint": ep, "elapsed_ms": elapsed})

        except Exception as e:
            missing.append({"endpoint": ep, "error": str(e)})

    status = "PASS"
    warnings = []

    if missing:
        status = "FAIL"

    if slow and status == "PASS":
        status = "WARNING"
        warnings.append("SLOW_ENDPOINTS")

    elapsed = round((time.time() - started) * 1000, 2)

    return {
        "module": MODULE,
        "status": status,
        "elapsed_ms": elapsed,
        "missing_endpoints": missing,
        "slow_endpoints": slow,
        "warnings": warnings
    }


if __name__ == "__main__":
    print(run({"api_url": "https://api.osa-observatory.africa"}))
