#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
OSA ISA – OPS V2
AUDIT DNS

Corrections (AUDIT OSA-2026-001) :
- [P1] cfg ignoré : run(cfg) reçoit la config mais ne l'utilise pas.
  Les domaines et URLs HTTPS sont désormais lus depuis
  cfg["dns_domains"] et cfg["https_checks"] (avec fallback sur les
  valeurs OSA par défaut). Le module est ainsi réutilisable sur un
  autre environnement (staging, miroir) sans modifier le code.
- [P2] check_https enrichi : mesure du temps de réponse HTTPS
  (elapsed_ms) pour chaque URL, et timeout configurable via
  cfg["dns_https_timeout_s"] (défaut 20 s).
- [P2] Domaines configurables via cfg["dns_domains"]. La liste par
  défaut reste inchangée pour la production OSA.
"""

import socket
import time
import requests

MODULE = "DNS"

_DEFAULT_DOMAINS = [
    "osa-observatory.africa",
    "api.osa-observatory.africa",
    "open.osa-observatory.africa",
]

_DEFAULT_HTTPS_CHECKS = {
    "https_api":  "https://api.osa-observatory.africa/",
    "https_open": "https://open.osa-observatory.africa/",
}


def resolve_host(host: str) -> dict:
    try:
        start = time.time()
        ipv4  = socket.gethostbyname(host)
        elapsed_ms = round((time.time() - start) * 1000, 2)
        return {
            "host":       host,
            "status":     "PASS",
            "ipv4":       ipv4,
            "elapsed_ms": elapsed_ms,
        }
    except Exception as e:
        return {
            "host":   host,
            "status": "FAIL",
            "error":  str(e),
        }


def check_https(url: str, timeout: int = 20) -> dict:
    try:
        start    = time.time()
        response = requests.get(url, timeout=timeout)
        elapsed_ms = round((time.time() - start) * 1000, 2)
        return {
            "status_code": response.status_code,
            "ok":          response.status_code < 400,
            "elapsed_ms":  elapsed_ms,
        }
    except Exception as e:
        return {
            "status_code": None,
            "ok":          False,
            "elapsed_ms":  None,
            "error":       str(e),
        }


def run(cfg: dict) -> dict:

    domains      = cfg.get("dns_domains",      _DEFAULT_DOMAINS)
    https_checks = cfg.get("https_checks",     _DEFAULT_HTTPS_CHECKS)
    https_timeout = int(cfg.get("dns_https_timeout_s", 20))

    results = []
    failed  = []

    for host in domains:
        result = resolve_host(host)
        results.append(result)
        if result["status"] == "FAIL":
            failed.append(host)

    dns_latencies = [
        item["elapsed_ms"]
        for item in results
        if item["status"] == "PASS"
    ]
    avg_latency = (
        round(sum(dns_latencies) / len(dns_latencies), 2)
        if dns_latencies else 0
    )

    # Vérifications HTTPS configurables
    https_results = {
        key: check_https(url, timeout=https_timeout)
        for key, url in https_checks.items()
    }

    # Rétrocompatibilité : les clés https_api et https_open sont
    # exposées directement si présentes
    https_api  = https_results.get("https_api",  {})
    https_open = https_results.get("https_open", {})

    # Statut global
    if failed:
        status = "FAIL"
    elif https_api and not https_api.get("ok", True):
        status = "FAIL"
    elif https_open and not https_open.get("ok", True):
        status = "WARNING"
    else:
        status = "PASS"

    return {
        "module":             MODULE,
        "status":             status,
        "avg_dns_latency_ms": avg_latency,
        "failed_hosts":       failed,
        "https_api":          https_api,
        "https_open":         https_open,
        "https_results":      https_results,
        "hosts":              results,
    }


if __name__ == "__main__":
    import json
    print(json.dumps(run({}), indent=2))
