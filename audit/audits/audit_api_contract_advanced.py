#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
OSA ISA – OPS V2
AUDIT API CONTRACT (ADVANCED, AUTHENTICATED)

Ce module remplace et consolide audit_api_contract.py et
audit_api_contract_advanced.py, qui étaient identiques sur la liste
EXPECTED_ENDPOINTS et ne différaient que sur des détails mineurs
(seuil slow : 5 s vs 10 s, gestion 403 absente dans la version de
base). audit_api_contract.py doit être retiré de la liste AUDITS dans
audit_runner.py.

Corrections (AUDIT OSA-2026-001) :
- [P0] Clé cfg : cfg["api_url"] remplacé par _get_base(cfg) qui
  accepte api_url ou api_base_url.
- [P0] Bug logique : les blocs `if status_code == 404` et
  `if status_code >= 500` étaient deux `if` indépendants sans
  `continue` après le premier. Un code 404 évaluait les deux blocs
  (aucun double ajout dans ce cas précis, mais la logique était
  fragile). Corrigé par une structure if/elif/else explicite avec
  `continue` précoce pour les codes acceptés (2xx, 401, 403).
  Un code inattendu (302, 503…) est désormais capturé.
- [P1] Codes 3xx (redirections) : requests suit les redirections par
  défaut (allow_redirects=True). Un endpoint qui redirige vers une
  page d'erreur peut retourner 200 après redirect — comportement
  accepté ici (cohérent avec le comportement client réel). Ajout de
  `allow_redirects=True` explicite pour documenter l'intention.
- [P2] EXPECTED_ENDPOINTS et seuils configurables via cfg.
- [P2] __main__ ajouté.
"""

import time
import requests

MODULE = "API_CONTRACT_ADVANCED"

_DEFAULT_EXPECTED_ENDPOINTS = [
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
    "/opendata/",
]

_DEFAULT_SLOW_MS   = 10_000
_DEFAULT_TIMEOUT_S = 30


def _get_base(cfg: dict) -> str:
    base = cfg.get("api_url") or cfg.get("api_base_url")
    if not base:
        raise ValueError("cfg manque api_url ou api_base_url")
    return base.rstrip("/")


def run(cfg: dict) -> dict:

    started = time.time()
    base    = _get_base(cfg)

    api_key    = cfg.get("api_key")
    auth_token = cfg.get("auth_token")

    headers = {}
    if api_key:
        headers["X-Api-Key"] = api_key
    if auth_token:
        headers["Authorization"] = auth_token

    endpoints  = cfg.get("contract_endpoints", _DEFAULT_EXPECTED_ENDPOINTS)
    slow_ms    = int(cfg.get("contract_slow_ms",   _DEFAULT_SLOW_MS))
    timeout_s  = int(cfg.get("contract_timeout_s", _DEFAULT_TIMEOUT_S))

    missing  = []
    slow     = []
    warnings = []

    for ep in endpoints:

        url = f"{base}{ep}"
        t0  = time.time()

        try:
            r = requests.get(
                url,
                headers=headers,
                timeout=timeout_s,
                allow_redirects=True,
            )
            elapsed = round((time.time() - t0) * 1000, 2)

            # Codes acceptés sans vérification supplémentaire
            if r.status_code in (200, 401, 403):
                # Lenteur uniquement sur les réponses valides
                if elapsed > slow_ms:
                    slow.append({"endpoint": ep, "elapsed_ms": elapsed})
                continue

            # 404 = endpoint inexistant → FAIL
            if r.status_code == 404:
                missing.append({"endpoint": ep, "status": 404})
                continue

            # 5xx = erreur serveur → FAIL
            if r.status_code >= 500:
                missing.append({"endpoint": ep, "status": r.status_code})
                continue

            # Tout autre code inattendu (302 non suivi, 429…) → WARNING
            warnings.append(
                f"UNEXPECTED_STATUS {r.status_code}: {ep}"
            )

        except requests.exceptions.Timeout:
            warnings.append(f"TIMEOUT: {ep}")
        except Exception as e:
            missing.append({"endpoint": ep, "error": str(e)})

    if missing:
        status = "FAIL"
    elif slow or warnings:
        status = "WARNING"
    else:
        status = "PASS"

    elapsed_total = round((time.time() - started) * 1000, 2)

    return {
        "module":            MODULE,
        "status":            status,
        "elapsed_ms":        elapsed_total,
        "missing_endpoints": missing,
        "slow_endpoints":    slow,
        "warnings":          warnings,
        "thresholds": {
            "slow_ms":   slow_ms,
            "timeout_s": timeout_s,
        },
    }


if __name__ == "__main__":
    import json
    print(json.dumps(run({
        "api_url": "https://api.osa-observatory.africa",
    }), indent=2))
