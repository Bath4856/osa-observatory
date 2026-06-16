#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
OSA ISA – OPS V2
AUDIT API SCHEMA VALIDATION

Corrections (AUDIT OSA-2026-001) :
- [P0] Bug critique : la validation `field not in str(data)` convertit
  la réponse entière en chaîne et cherche par substring. Cela produit
  des faux positifs (le nom du champ apparaît dans une valeur) et des
  faux négatifs (le champ est absent mais son nom est sous-chaîne d'un
  autre champ).

  Correction : validation structurée sur le premier élément si la
  réponse est une liste, ou sur la racine si c'est un dict. Les champs
  manquants sont identifiés avec set difference — aucune conversion en
  chaîne.

- [P2] Le rapport indique désormais les champs effectivement présents
  vs attendus, pour faciliter le diagnostic.
"""

import time
import requests

MODULE = "API_SCHEMA"

# Champs attendus dans la réponse de chaque endpoint.
# Pour les endpoints renvoyant une liste, les champs sont vérifiés
# sur le premier élément.
SCHEMA_CHECKS = {
    "/api/v2/countries":       ["iso3", "country", "isa_score"],
    "/api/v2/scores":          ["iso3", "isa_score", "position"],
    "/api/v2/sovereignty/swot": ["iso3", "pillar", "signal_type"],
    "/opendata/":              ["datasets"],
}


def _check_fields(data, required_fields: list) -> list:
    """
    Retourne la liste des champs manquants.

    Supporte :
      - dict  → vérification directe sur les clés
      - list  → vérification sur le premier élément (dict attendu)
      - autres → tous les champs considérés manquants (structure inattendue)
    """
    if isinstance(data, dict):
        present = set(data.keys())
    elif isinstance(data, list):
        if not data:
            # Liste vide : impossible de vérifier — on signale en warning
            return [f"<liste vide — champs non vérifiables : {required_fields}>"]
        first = data[0]
        if not isinstance(first, dict):
            return required_fields[:]
        present = set(first.keys())
    else:
        return required_fields[:]

    return [f for f in required_fields if f not in present]


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

    failures = []
    warnings = []

    for ep, required_fields in SCHEMA_CHECKS.items():

        url = f"{base}{ep}"

        try:
            r = requests.get(url, headers=headers, timeout=20)
            if r.status_code == 429:
                warnings.append({"endpoint": ep, "detail": "rate limit (429)"})
                continue

            if r.status_code in (401, 403):
                # Endpoint protégé sans token valide → non vérifiable
                warnings.append({
                    "endpoint": ep,
                    "detail": f"non vérifié (HTTP {r.status_code})",
                })
                continue

            if r.status_code != 200:
                failures.append({
                    "endpoint": ep,
                    "status": r.status_code,
                })
                continue

            try:
                data = r.json()
            except Exception:
                failures.append({
                    "endpoint": ep,
                    "detail": "réponse non JSON",
                })
                continue

            missing = _check_fields(data, required_fields)

            if missing:
                warnings.append({
                    "endpoint":        ep,
                    "missing_fields":  missing,
                    "expected_fields": required_fields,
                })

        except Exception as e:
            failures.append({"endpoint": ep, "error": str(e)})

    status = "PASS"
    if failures:
        status = "FAIL"
    elif warnings:
        status = "WARNING"

    elapsed = round((time.time() - started) * 1000, 2)

    return {
        "module":    MODULE,
        "status":    status,
        "elapsed_ms": elapsed,
        "failures":  failures,
        "warnings":  warnings,
    }


if __name__ == "__main__":
    import json
    print(json.dumps(
        run({"api_url": "https://api.osa-observatory.africa"}),
        indent=2,
    ))
