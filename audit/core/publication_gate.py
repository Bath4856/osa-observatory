#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
OSA ISA
P8 OPS V2
Publication Gate

Décision officielle de publication.

Règles :
  FAIL présent            → REVIEW_REQUIRED
  UNKNOWN statut présent  → REVIEW_REQUIRED
  IPRS < 70               → REVIEW_REQUIRED
  70 <= IPRS < 85         → CONDITIONAL_PUBLICATION
  IPRS >= 85              → READY_FOR_PUBLICATION
  IPRS None + pas de FAIL → CONDITIONAL_PUBLICATION (cas dégradé)

Corrections (AUDIT OSA-2026-001) :
- [P1] Cas limite IPRS=None sans FAIL : la version originale retournait
  READY_FOR_PUBLICATION par défaut — décision optimiste injustifiée
  sans score calculé. Corrigé : IPRS=None donne CONDITIONAL_PUBLICATION
  avec raison IPRS_UNAVAILABLE.
- [P1] Cas limite results=[] (liste vide) : retournait également
  READY_FOR_PUBLICATION. Corrigé : liste vide → REVIEW_REQUIRED avec
  raison NO_MODULES_EXECUTED.
- [P2] Facteur health_ratio documenté dans le résultat (proportion de
  modules PASS sur total). Utilisable comme signal secondaire.
"""

DEFAULT_REVIEW_THRESHOLD = 70
DEFAULT_READY_THRESHOLD  = 85


def publication_decision(
    results: list,
    iprs: float = None,
    review_threshold: float = DEFAULT_REVIEW_THRESHOLD,
    ready_threshold:  float = DEFAULT_READY_THRESHOLD,
) -> dict:
    """
    Détermine le statut de publication officiel OSA.

    Paramètres
    ----------
    results           : liste des dicts retournés par les modules d'audit
    iprs              : score IPRS calculé par compute_publication_score
    review_threshold  : seuil en dessous duquel REVIEW_REQUIRED (défaut 70)
    ready_threshold   : seuil à partir duquel READY_FOR_PUBLICATION (défaut 85)
    """

    if not isinstance(results, list):
        raise ValueError("results must be a list")

    pass_modules    = []
    warning_modules = []
    fail_modules    = []
    unknown_modules = []

    for result in results:
        module = result.get("module", "UNKNOWN")
        status = str(result.get("status", "FAIL")).upper()

        if   status == "PASS":    pass_modules.append(module)
        elif status == "WARNING":  warning_modules.append(module)
        elif status == "FAIL":     fail_modules.append(module)
        else:                      unknown_modules.append(module)

    total_modules   = len(results)
    pass_count      = len(pass_modules)
    warning_count   = len(warning_modules)
    fail_count      = len(fail_modules)
    unknown_count   = len(unknown_modules)

    health_ratio = (
        round(pass_count / total_modules, 4) if total_modules > 0 else 0.0
    )

    # ── Décision ─────────────────────────────────────────────────────

    # Cas limite : aucun module exécuté
    if total_modules == 0:
        publication_status = "REVIEW_REQUIRED"
        reason             = "NO_MODULES_EXECUTED"

    # Priorité 1 : FAIL bloquant
    elif fail_count > 0:
        publication_status = "REVIEW_REQUIRED"
        reason             = "FAIL_MODULES_DETECTED"

    # Priorité 2 : statut inconnu
    elif unknown_count > 0:
        publication_status = "REVIEW_REQUIRED"
        reason             = "UNKNOWN_MODULE_STATUS"

    # Priorité 3 : IPRS indisponible (score non calculé)
    elif iprs is None:
        publication_status = "CONDITIONAL_PUBLICATION"
        reason             = "IPRS_UNAVAILABLE"

    # Priorité 4 : IPRS insuffisant
    elif iprs < review_threshold:
        publication_status = "REVIEW_REQUIRED"
        reason             = "LOW_IPRS"

    elif iprs < ready_threshold:
        publication_status = "CONDITIONAL_PUBLICATION"
        reason             = "MEDIUM_IPRS"

    else:
        publication_status = "READY_FOR_PUBLICATION"
        reason             = "ALL_CHECKS_PASSED"

    return {
        "publication_status": publication_status,
        "reason":             reason,
        "iprs":               iprs,
        "health_ratio":       health_ratio,
        "total_modules":      total_modules,
        "pass_modules":       pass_modules,
        "warning_modules":    warning_modules,
        "fail_modules":       fail_modules,
        "unknown_modules":    unknown_modules,
        "pass_count":         pass_count,
        "warning_count":      warning_count,
        "fail_count":         fail_count,
        "unknown_count":      unknown_count,
        "review_threshold":   review_threshold,
        "ready_threshold":    ready_threshold,
    }


if __name__ == "__main__":
    import json

    sample = [
        {"module": "DNS",    "status": "PASS"},
        {"module": "OPENAPI","status": "PASS"},
        {"module": "SWOT",   "status": "WARNING"},
    ]
    print(json.dumps(publication_decision(sample, iprs=92), indent=2))

    # Cas limites
    print("IPRS=None:", publication_decision(sample, iprs=None)["publication_status"])
    print("0 modules:", publication_decision([], iprs=None)["publication_status"])
