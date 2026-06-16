#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
OSA ISA
P8 OPS V2
SCORING ENGINE

Corrections (AUDIT OSA-2026-001) :
- [P0] Bug formule IPRS : le score d'un module PASS sans coverage_pct
  ni total_rows donnait 50 (status_score*0.5 + 0 + 0). Les modules
  infra/API (DNS, OPENAPI, API, DATABASE…) ne retournent jamais ces
  champs → IPRS plafonné à ~55 même en PASS total. Les seuils
  REVIEW=70 et READY=85 de publication_gate étaient donc de facto
  inaccessibles sur un run complet.

  Correction : les pondérations coverage (0.3) et volume (0.2) ne
  s'appliquent qu'aux modules qui exposent ces champs. Pour les modules
  qui ne les exposent pas, le status_score reçoit la totalité du poids
  (1.0). Un module DNS PASS contribue ainsi 100, pas 50.

- [P2] compute_quality_score exposé mais jamais appelé depuis
  audit_runner. Conservé pour usage futur, documenté.
"""


def compute_publication_score(results: list) -> float:
    """
    Calcule l'IPRS (Indice de Publication et de Robustesse du Système).

    Pour chaque module :
    - Si le module expose coverage_pct et/ou total_rows, les trois
      dimensions sont pondérées (status 50 %, coverage 30 %, volume 20 %).
    - Si le module n'expose pas ces champs (modules infra/API), seul le
      statut compte (100 % du score du module).

    Retourne un score de 0 à 100.
    """
    if not isinstance(results, list) or len(results) == 0:
        return 0.0

    total_score  = 0.0
    module_count = 0

    for module in results:

        if not isinstance(module, dict):
            continue

        module_count += 1

        status     = module.get("status", "FAIL")
        coverage   = module.get("coverage_pct")   # None si absent
        total_rows = module.get("total_rows")      # None si absent

        # Score statut OPS
        if status == "PASS":
            status_score = 100.0
        elif status == "WARNING":
            status_score = 60.0
        else:
            status_score = 0.0

        has_coverage = coverage   is not None
        has_volume   = total_rows is not None

        if not has_coverage and not has_volume:
            # Module infra/API : le statut porte 100 % du score
            module_score = status_score
        else:
            # Module de données : pondération tripartite
            coverage_score = min(max(float(coverage or 0), 0.0), 100.0)

            if has_volume and total_rows > 0:
                volume_score = min(100.0, 20.0 + (total_rows ** 0.5) * 5.0)
            else:
                volume_score = 0.0

            module_score = (
                status_score  * 0.5 +
                coverage_score * 0.3 +
                volume_score   * 0.2
            )

        total_score += module_score

    if module_count == 0:
        return 0.0

    return round(total_score / module_count, 2)


def compute_quality_score(results: list) -> float:
    """
    Score de qualité basé sur la confiance moyenne des modules de données.
    Non utilisé dans le runner principal — réservé à un usage analytique
    futur (rapport de qualité détaillé).
    """
    if not isinstance(results, list):
        return 0.0

    confidences = [
        module["avg_confidence"]
        for module in results
        if isinstance(module, dict)
        and isinstance(module.get("avg_confidence"), (int, float))
    ]

    if not confidences:
        return 0.0

    return round((sum(confidences) / len(confidences)) * 100, 2)
