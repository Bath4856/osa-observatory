#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
OSA ISA
P8 OPS V2

AUDIT RUNNER – VERSION COMPLÈTE

Orchestrateur principal des audits OPS.

Fonctions :

- exécution séquentielle de tous les audits
- calcul de l'IPRS
- décision de publication
- génération du rapport final

Contraintes :

- aucune écriture directe dans PostgreSQL
- aucun export Grafana direct
- lecture unique de la configuration YAML

Corrections appliquées (AUDIT OSA-2026-001) :

- [P0] Imports dégradables : chaque module est importé individuellement
  dans un try/except — un module manquant n'empêche plus le runner de
  démarrer. Les modules manquants sont loggés et exclus de l'exécution.

- [P1] Validation minimale de cfg : clés obligatoires vérifiées avant
  dispatch aux audits. Erreur levée tôt avec message explicite.

- [P1] Timeout par audit : chaque module est exécuté dans un thread
  séparé via concurrent.futures.ThreadPoolExecutor. Timeout configurable
  via cfg["audit_timeout_seconds"] (défaut 60 s). Un audit bloquant
  (DNS injoignable, connexion pendante) ne bloque plus le runner.

- [P2] module.__name__ remplacé par getattr(..., "__name__", ...) dans
  le chemin d'erreur pour éviter AttributeError sur des objets proxy.
"""

import sys
import time
import logging
import importlib
from pathlib import Path
from datetime import datetime, timezone
from concurrent.futures import ThreadPoolExecutor, TimeoutError as FuturesTimeoutError

PROJECT_ROOT = Path(__file__).resolve().parents[2]

if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

logger = logging.getLogger(__name__)

# ─────────────────────────────────────────────────────────────────────────────
# Imports dégradables
# Un module manquant ou cassé est loggé et exclu — le runner continue.
# ─────────────────────────────────────────────────────────────────────────────

_AUDIT_MODULE_NAMES = [
    # INFRA / CONNECTIVITÉ
    "audit.audits.audit_dns",
    "audit.audits.audit_openapi",
    "audit.audits.audit_api",
    "audit.audits.audit_database",

    # CŒUR OPS (ISA / SWOT / P7I / TRAJECTORY / DRIFT)
    "audit.audits.audit_isa",
    "audit.audits.audit_swot",
    "audit.audits.audit_p7i",
    "audit.audits.audit_trajectory",
    "audit.audits.audit_scientific_drift",

    # QUALITÉ / STRUCTURE / SÉCURITÉ
    "audit.audits.audit_documentation",
    "audit.audits.audit_performance",
    "audit.audits.audit_repository_structure",
    "audit.audits.audit_security",

    # QUALITÉ DONNÉES
    "audit.audits.audit_methodology",
    "audit.audits.audit_data_quality",
    # PACK API COMPLET
    "audit.audits.audit_api_contract_advanced",
    "audit.audits.audit_api_schema",
    "audit.audits.audit_api_permissions",
    "audit.audits.audit_api_performance_advanced",
]

AUDITS = []
SKIPPED_IMPORTS = []

for _mod_name in _AUDIT_MODULE_NAMES:
    try:
        AUDITS.append(importlib.import_module(_mod_name))
    except Exception as _exc:
        logger.error("Import échoué — module exclu : %s (%s)", _mod_name, _exc)
        SKIPPED_IMPORTS.append({"module": _mod_name, "error": str(_exc)})

from audit.core.scoring import compute_publication_score         # noqa: E402
from audit.core.publication_gate import publication_decision     # noqa: E402

# ─────────────────────────────────────────────────────────────────────────────
# Clés cfg obligatoires
# ─────────────────────────────────────────────────────────────────────────────

_REQUIRED_CFG_KEYS = ["db_host", "db_name", "api_url"]


def _validate_cfg(cfg: dict) -> None:
    """
    Lève ValueError si une clé obligatoire est absente de cfg.
    Appelé en tête de run_all() pour un diagnostic précoce.
    """
    missing = [k for k in _REQUIRED_CFG_KEYS if k not in cfg]
    if missing:
        raise ValueError(
            f"audit_config.yaml incomplet — clés manquantes : {missing}"
        )


# ─────────────────────────────────────────────────────────────────────────────
# Exécution d'un audit avec timeout
# ─────────────────────────────────────────────────────────────────────────────

def _module_label(module) -> str:
    return getattr(module, "__name__", "UNKNOWN_MODULE")


def execute_audit(module, cfg: dict, timeout: int = 60) -> dict:
    """
    Exécute module.run(cfg) dans un thread avec timeout.

    Chaque audit doit exposer run(cfg) retournant un dict.
    En cas d'échec (exception, timeout, réponse invalide), retourne
    un dict FAIL avec le détail de l'erreur — le runner continue.
    """
    label = _module_label(module)

    def _run():
        return module.run(cfg)

    try:
        with ThreadPoolExecutor(max_workers=1) as executor:
            future = executor.submit(_run)
            result = future.result(timeout=timeout)

        if not isinstance(result, dict):
            return {
                "module": label,
                "status": "FAIL",
                "error": "INVALID_AUDIT_RESPONSE",
            }

        if "module" not in result:
            result["module"] = label

        return result

    except FuturesTimeoutError:
        logger.error("Timeout (%ds) dépassé pour %s", timeout, label)
        return {
            "module": label,
            "status": "FAIL",
            "error": f"TIMEOUT_AFTER_{timeout}s",
        }

    except Exception as exc:
        logger.exception("Erreur dans %s", label)
        return {
            "module": label,
            "status": "FAIL",
            "error": str(exc),
        }


# ─────────────────────────────────────────────────────────────────────────────
# Orchestrateur principal
# ─────────────────────────────────────────────────────────────────────────────

def run_all(cfg: dict) -> dict:
    """
    Exécute l'ensemble des audits définis dans AUDITS,
    calcule l'IPRS et applique la décision de publication.
    """

    _validate_cfg(cfg)

    if "project_root" not in cfg:
        cfg["project_root"] = str(PROJECT_ROOT)

    timeout = int(cfg.get("audit_timeout_seconds", 60))

    started_at = time.time()
    results = []

    for module in AUDITS:
        results.append(execute_audit(module, cfg, timeout=timeout))

    # Modules non chargés → signalés comme FAIL dans les résultats
    for skipped in SKIPPED_IMPORTS:
        results.append({
            "module": skipped["module"],
            "status": "FAIL",
            "error": f"IMPORT_ERROR: {skipped['error']}",
        })

    iprs = compute_publication_score(results)
    publication = publication_decision(results, iprs)

    duration_seconds = round(time.time() - started_at, 2)

    return {
        "audit_timestamp": datetime.now(timezone.utc).isoformat(),
        "audit_duration_seconds": duration_seconds,
        "iprs": iprs,
        "results": results,
        "publication": publication,
        "skipped_imports": SKIPPED_IMPORTS,
    }


# ─────────────────────────────────────────────────────────────────────────────
# Point d'entrée CLI
# ─────────────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    import yaml
    import json

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
    )

    config_path = PROJECT_ROOT / "audit" / "config" / "audit_config.yaml"

    with open(config_path, "r", encoding="utf-8") as f:
        cfg = yaml.safe_load(f) or {}

    report = run_all(cfg)

    print(
        json.dumps(
            report,
            indent=2,
            ensure_ascii=False,
            default=str,
        )
    )
