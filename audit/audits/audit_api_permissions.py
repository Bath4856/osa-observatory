#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
OSA ISA – OPS V2
AUDIT API PERMISSIONS

Corrections (AUDIT OSA-2026-001) :
- [P0] Défaut de conception : le module précédent envoyait les
  requêtes AVEC le token d'authentification, y compris pour les
  endpoints attendus à 401. Il testait la disponibilité des endpoints,
  pas le contrôle d'accès.

  Correction : double passe.
    Passe A (unauthenticated) : requêtes SANS headers. Vérifie que
      les endpoints protégés rejettent bien les appels anonymes (401).
      Vérifie que les endpoints publics répondent bien (200).
    Passe B (authenticated) : requêtes AVEC headers. Vérifie que les
      endpoints protégés acceptent un token valide (200 ou 2xx).
      Optionnelle si aucun token n'est configuré dans cfg.

  Un endpoint attendu à 401 qui répond 200 sans token = fuite de
  contrôle d'accès → FAIL immédiat.
"""

import time
import requests

MODULE = "API_PERMISSIONS"

# Règles unauthenticated (sans token)
# Valeur = code HTTP attendu pour une requête anonyme
UNAUTHENTICATED_RULES = {
    "/opendata/":                      200,
    "/api/v2/countries":               401,
    "/api/v2/scores":                  200,
    "/api/v2/predictive/readiness":    401,
    "/api/v2/predictive/signals":      401,
    "/api/v2/predictive/fragility":    401,
}

# Règles authenticated (avec token valide)
# Valeur = liste de codes HTTP acceptables (souvent 200 ou 2xx)
AUTHENTICATED_RULES = {
    "/api/v2/predictive/readiness":    [200],
    "/api/v2/predictive/signals":      [200],
    "/api/v2/predictive/fragility":    [200],
}


def _check(url, headers, expected_codes, timeout=15):
    """Effectue une requête et retourne (ok, got_status, error)."""
    if not isinstance(expected_codes, list):
        expected_codes = [expected_codes]
    try:
        r = requests.get(url, headers=headers, timeout=timeout)
        ok = r.status_code in expected_codes
        return ok, r.status_code, None
    except Exception as e:
        return False, None, str(e)


def run(cfg: dict) -> dict:

    started = time.time()
    base = (cfg.get("api_url") or cfg.get("api_base_url", "")).rstrip("/")

    api_key    = cfg.get("api_key")
    auth_token = cfg.get("auth_token")

    auth_headers = {}
    if api_key:
        auth_headers["X-Api-Key"] = api_key
    if auth_token:
        auth_headers["Authorization"] = auth_token

    failures = []
    warnings = []

    # ─── Passe A : unauthenticated ──────────────────────────────────
    for ep, expected in UNAUTHENTICATED_RULES.items():
        ok, got, error = _check(
            f"{base}{ep}", headers={}, expected_codes=expected
        )
        if error:
            failures.append({
                "pass": "unauthenticated",
                "endpoint": ep,
                "expected": expected,
                "error": error,
            })
        elif got == 429:
            warnings.append(f"RATE_LIMITED (429): {ep} — résultat non concluant")
        elif not ok:
            entry = {
                "pass": "unauthenticated",
                "endpoint": ep,
                "expected": expected,
                "got": got,
            }
            # Endpoint protégé accessible sans token = fuite critique
            if expected == 401 and got == 200:
                entry["severity"] = "CRITICAL"
                entry["detail"] = "endpoint accessible sans authentification"
            failures.append(entry)

    # ─── Passe B : authenticated (optionnelle) ───────────────────────
    if auth_headers:
        for ep, expected_codes in AUTHENTICATED_RULES.items():
            ok, got, error = _check(
                f"{base}{ep}", headers=auth_headers, expected_codes=expected_codes
            )
            if error:
                warnings.append({
                    "pass": "authenticated",
                    "endpoint": ep,
                    "error": error,
                })
            elif not ok:
                failures.append({
                    "pass": "authenticated",
                    "endpoint": ep,
                    "expected": expected_codes,
                    "got": got,
                })
    else:
        warnings.append(
            "Passe B ignorée : aucun api_key ni auth_token dans cfg"
        )

    # Passe B ignorée (pas de token) = WARNING, pas FAIL
    if not failures and warnings:
        status = "WARNING"
    elif failures:
        status = "FAIL"
    else:
        status = "PASS"

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
