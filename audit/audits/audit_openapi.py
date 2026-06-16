#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
OSA ISA – OPS V2
AUDIT OPENAPI

Corrections (AUDIT OSA-2026-001) :
- [P0] Clé cfg : cfg["api_url"] remplacé par _get_base(cfg) qui
  accepte api_url ou api_base_url — alignement avec tous les autres
  modules du pack audit.
- [P1] missing_paths → FAIL, pas WARNING. Un endpoint requis absent
  du spec OpenAPI signifie qu'il n'est pas documenté (ou n'existe pas)
  — ce n'est pas un état acceptable avant publication. Les chemins
  obsolètes (deprecated) restent en WARNING car leur présence ne bloque
  pas la publication, elle signale seulement une dette de nettoyage.
- [P2] required_paths et deprecated_paths configurables via
  cfg["openapi_required_paths"] et cfg["openapi_deprecated_paths"]
  avec fallback sur les listes OSA par défaut. Permet des validations
  sprint-spécifiques sans modifier le code.
- [P2] __main__ ajouté pour cohérence avec les autres modules.
"""

import time
import requests

MODULE = "OPENAPI"

_DEFAULT_REQUIRED_PATHS = [
    "/health",
    "/api/v2/scores",
    "/api/v2/sovereignty/swot",
    "/api/v2/opportunities",
]

_DEFAULT_DEPRECATED_PATHS = [
    "/api/v2/early-warning/escalation",
    "/api/v2/early-warning/priority-queue",
]


def _get_base(cfg: dict) -> str:
    base = cfg.get("api_url") or cfg.get("api_base_url")
    if not base:
        raise ValueError("cfg manque api_url ou api_base_url")
    return base.rstrip("/")


def run(cfg: dict) -> dict:

    start = time.time()

    try:
        base = _get_base(cfg)
        url  = f"{base}/openapi.json"

        response = requests.get(url, timeout=30)

        elapsed_ms = round((time.time() - start) * 1000, 2)

        if response.status_code != 200:
            return {
                "module":      MODULE,
                "status":      "FAIL",
                "status_code": response.status_code,
                "elapsed_ms":  elapsed_ms,
            }

        spec = response.json()

        if not isinstance(spec, dict):
            return {
                "module":    MODULE,
                "status":    "FAIL",
                "reason":    "INVALID_OPENAPI_DOCUMENT",
                "elapsed_ms": elapsed_ms,
            }

        openapi_version = spec.get("openapi")
        info            = spec.get("info", {})
        title           = info.get("title")
        version         = info.get("version")
        paths           = spec.get("paths", {})
        nb_paths        = len(paths)

        # Listes configurables
        required_paths   = cfg.get("openapi_required_paths",   _DEFAULT_REQUIRED_PATHS)
        deprecated_paths = cfg.get("openapi_deprecated_paths", _DEFAULT_DEPRECATED_PATHS)

        missing_paths  = [p for p in required_paths   if p not in paths]
        obsolete_paths = [p for p in deprecated_paths if p in paths]

        # Décision de statut
        # nb_paths == 0 → FAIL (spec vide)
        # missing_paths  → FAIL (endpoint requis non documenté)
        # obsolete_paths → WARNING seulement (dette de nettoyage)
        if nb_paths == 0:
            status = "FAIL"
        elif missing_paths:
            status = "FAIL"
        elif obsolete_paths:
            status = "WARNING"
        else:
            status = "PASS"

        return {
            "module":          MODULE,
            "status":          status,
            "elapsed_ms":      elapsed_ms,
            "openapi_version": openapi_version,
            "title":           title,
            "api_version":     version,
            "nb_paths":        nb_paths,
            "missing_paths":   missing_paths,
            "obsolete_paths":  obsolete_paths,
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
