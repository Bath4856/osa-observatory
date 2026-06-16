#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
OSA ISA – OPS V2
AUDIT API

Corrections (AUDIT OSA-2026-001) :
- [P0] Clé cfg lue via cfg.get("api_url") ou cfg.get("api_base_url")
  avec priorité api_url pour rétrocompatibilité. Lève ValueError
  explicite si aucune des deux n'est présente, plutôt qu'un KeyError
  opaque.
- [P2] Seuil de latence WARNING configurable via
  cfg.get("api_latency_warn_ms", 1000).
"""

import requests
import time

MODULE = "API"


def _get_base(cfg: dict) -> str:
    """
    Résout la clé d'URL de base de l'API.
    Accepte api_url (historique) ou api_base_url (standard runner).
    """
    base = cfg.get("api_url") or cfg.get("api_base_url")
    if not base:
        raise ValueError(
            "cfg manque api_url ou api_base_url"
        )
    return base.rstrip("/")


def check_endpoint(url, timeout=30):

    start = time.time()

    try:
        response = requests.get(url, timeout=timeout)
        elapsed = round((time.time() - start) * 1000, 2)

        return {
            "status_code": response.status_code,
            "elapsed_ms": elapsed,
            "ok": response.status_code == 200,
        }

    except Exception as e:
        return {
            "status_code": None,
            "elapsed_ms": None,
            "ok": False,
            "error": str(e),
        }


def run(cfg: dict) -> dict:

    base = _get_base(cfg)
    latency_warn_ms = int(cfg.get("api_latency_warn_ms", 1000))

    checks = {
        "root":    check_endpoint(f"{base}/"),
        "health":  check_endpoint(f"{base}/health"),
        "docs":    check_endpoint(f"{base}/docs"),
        "openapi": check_endpoint(f"{base}/openapi.json"),
        "scores":  check_endpoint(f"{base}/api/v2/scores"),
        "swot":    check_endpoint(f"{base}/api/v2/sovereignty/swot"),
    }

    failures = [k for k, v in checks.items() if not v["ok"]]

    valid_latencies = [
        v["elapsed_ms"] for v in checks.values() if v["elapsed_ms"] is not None
    ]

    avg_latency = (
        round(sum(valid_latencies) / len(valid_latencies), 2)
        if valid_latencies
        else 0.0
    )

    if failures:
        status = "FAIL"
    elif avg_latency > latency_warn_ms:
        status = "WARNING"
    else:
        status = "PASS"

    return {
        "module": MODULE,
        "status": status,
        "avg_latency_ms": avg_latency,
        "failed_checks": failures,
        "checks": checks,
    }


if __name__ == "__main__":
    import json
    print(json.dumps(
        run({"api_url": "https://api.osa-observatory.africa"}),
        indent=2,
    ))
