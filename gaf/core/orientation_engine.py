#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
OSA ISA – Sprint 24 GAF
Lot B : orientation_engine.py

Moteur d'orientation automatique des findings.

Rôle :
  Prend les findings bruts produits par audit_runner (liste de dicts)
  et les transforme en findings structurés avec :
    - finding_code  : code normalisé identifiant le type d'anomalie
    - severity      : CRITICAL / HIGH / MEDIUM / LOW / INFO
    - object_type   : TABLE / INDICATOR / ENDPOINT / LAYER / CONFIG
    - object_code   : identifiant précis de l'objet concerné
    - description   : texte humain normalisé
    - recommended_action : action recommandée
    - priority      : CRITICAL / HIGH / MEDIUM / LOW
    - owner         : acteur responsable du traitement
    - sprint_target : sprint cible pour la correction
    - rule_code     : code de la règle d'orientation appliquée

Architecture :
  Les règles sont définies dans ORIENTATION_RULES — une liste de dicts
  contenant un pattern (callable) et les attributs à appliquer.
  Le moteur applique la première règle qui match le finding brut.
  Si aucune règle ne match, le finding est classé INFO / UNCLASSIFIED.

Usage :
  from gaf.core.orientation_engine import OrientationEngine
  engine = OrientationEngine()
  structured = engine.orient_run(audit_results)
"""

import re
from datetime import datetime, timezone
from typing import Any


# ─────────────────────────────────────────────────────────────────────────────
# Règles d'orientation
# Chaque règle : {pattern, finding_code, severity, object_type,
#                 recommended_action, priority, owner, sprint_target, rule_code}
# pattern : callable(module, finding_text) -> bool
# ─────────────────────────────────────────────────────────────────────────────

ORIENTATION_RULES = [

    # ── CRITIQUE : doublons / method_version_id NULL ──────────────────────
    {
        "rule_code": "R01_METHOD_VERSION_NULL",
        "publication_impact": "BLOCKING",
        "iprs_weight": 5.0,
        "pattern": lambda m, f: "method_version_id IS NULL" in f,
        "finding_code": "METHOD_VERSION_ID_NULL",
        "severity": "CRITICAL",
        "object_type": "TABLE",
        "object_code": "ma.indicator_values",
        "recommended_action":
            "Ajouter DEFAULT 1 sur method_version_id dans ma.indicator_values "
            "et dédupliquer les lignes existantes. "
            "Mettre à jour tous les producteurs INSERT INTO ma.indicator_values.",
        "priority": "CRITICAL",
        "owner": "DATA_STEWARD",
        "sprint_target": "Sprint 24",
    },

    # ── CRITIQUE : doublons détectés ──────────────────────────────────────
    {
        "rule_code": "R02_DUPLICATE_VALUES",
        "publication_impact": "BLOCKING",
        "iprs_weight": 5.0,
        "pattern": lambda m, f: "lignes excedentaires" in f or "doublons" in f.lower(),
        "finding_code": "DUPLICATE_INDICATOR_VALUES",
        "severity": "CRITICAL",
        "object_type": "TABLE",
        "object_code": "ma.indicator_values",
        "recommended_action":
            "Dédupliquer ma.indicator_values par (indicator_code, country_iso3, "
            "year, layer_id). Corriger la contrainte UNIQUE.",
        "priority": "CRITICAL",
        "owner": "DATA_STEWARD",
        "sprint_target": "Sprint 24",
    },

    # ── HIGH : poids incohérents ───────────────────────────────────────────
    {
        "rule_code": "R03_WEIGHT_CONSISTENCY",
        "publication_impact": "CONDITIONAL",
        "iprs_weight": 3.0,
        "pattern": lambda m, f: "weight sum=" in f,
        "finding_code": "WEIGHT_SUM_INCONSISTENT",
        "severity": "HIGH",
        "object_type": "TABLE",
        "object_code": "ma.indicator_meta_links",
        "recommended_action":
            "Revoir les poids dans ma.indicator_meta_links pour SOV_PECO et "
            "SOV_PMON. La somme doit être exactement 1.0 par (meta_code, ref_year).",
        "priority": "HIGH",
        "owner": "METHODOLOGY_COMMITTEE",
        "sprint_target": "Sprint 24",
    },

    # ── HIGH : indicateur non lié ──────────────────────────────────────────
    {
        "rule_code": "R04_INDICATOR_NOT_LINKED",
        "publication_impact": "CONDITIONAL",
        "iprs_weight": 2.0,
        "pattern": lambda m, f: "not linked and not excluded" in f,
        "finding_code": "INDICATOR_UNLINKED",
        "severity": "HIGH",
        "object_type": "INDICATOR",
        "object_code": None,  # extrait dynamiquement
        "recommended_action":
            "Lier l'indicateur dans ma.indicator_meta_links ou l'ajouter "
            "à ma.indicator_exclusions avec justification.",
        "priority": "HIGH",
        "owner": "METHODOLOGY_COMMITTEE",
        "sprint_target": "Sprint 24",
    },

    # ── HIGH : endpoint API manquant ──────────────────────────────────────
    {
        "rule_code": "R05_ENDPOINT_MISSING",
        "publication_impact": "CONDITIONAL",
        "iprs_weight": 2.0,
        "pattern": lambda m, f: m == "API_CONTRACT_ADVANCED" and (
            "404" in f or "error" in f.lower()
        ),
        "finding_code": "API_ENDPOINT_MISSING",
        "severity": "HIGH",
        "object_type": "ENDPOINT",
        "object_code": None,  # extrait dynamiquement
        "recommended_action":
            "Vérifier que l'endpoint est bien implémenté dans l'API FastAPI "
            "et que le router est enregistré dans main.py.",
        "priority": "HIGH",
        "owner": "OPS_ADMINISTRATOR",
        "sprint_target": "Sprint 24",
    },

    # ── MEDIUM : timeout endpoint ──────────────────────────────────────────
    {
        "rule_code": "R06_ENDPOINT_TIMEOUT",
        "publication_impact": "NONE",
        "iprs_weight": 1.0,
        "pattern": lambda m, f: "TIMEOUT" in f or "timeout" in f.lower(),
        "finding_code": "API_ENDPOINT_TIMEOUT",
        "severity": "MEDIUM",
        "object_type": "ENDPOINT",
        "object_code": None,
        "recommended_action":
            "Vérifier si l'endpoint utilise une vue non matérialisée. "
            "Créer une vue matérialisée pub.mv_* si nécessaire.",
        "priority": "MEDIUM",
        "owner": "OPS_ADMINISTRATOR",
        "sprint_target": "Sprint 25",
    },

    # ── MEDIUM : latence élevée ────────────────────────────────────────────
    {
        "rule_code": "R07_ENDPOINT_SLOW",
        "publication_impact": "NONE",
        "iprs_weight": 0.5,
        "pattern": lambda m, f: "elapsed_ms" in f and "severity" in f,
        "finding_code": "API_ENDPOINT_SLOW",
        "severity": "MEDIUM",
        "object_type": "ENDPOINT",
        "object_code": None,
        "recommended_action":
            "Analyser le plan d'exécution (EXPLAIN ANALYZE) et envisager "
            "une vue matérialisée ou un index supplémentaire.",
        "priority": "MEDIUM",
        "owner": "OPS_ADMINISTRATOR",
        "sprint_target": "Sprint 25",
    },

    # ── MEDIUM : valeurs nulles dans indicator_values ─────────────────────
    {
        "rule_code": "R08_NULL_VALUES",
        "publication_impact": "NONE",
        "iprs_weight": 1.0,
        "pattern": lambda m, f: m == "DATA_QUALITY" and "NULL_VALUES" in f,
        "finding_code": "DATA_NULL_VALUES",
        "severity": "MEDIUM",
        "object_type": "TABLE",
        "object_code": "ma.indicator_values",
        "recommended_action":
            "Identifier les indicateurs et années concernés par les valeurs "
            "nulles. Vérifier les collecteurs source.",
        "priority": "MEDIUM",
        "owner": "DATA_STEWARD",
        "sprint_target": "Sprint 25",
    },

    # ── MEDIUM : indicateur TRAJECTOIRE inactif ───────────────────────────
    {
        "rule_code": "R09_TRAJECTORY_INACTIVE",
        "publication_impact": "NONE",
        "iprs_weight": 0.5,
        "pattern": lambda m, f: m == "TRAJECTORY" and "inactive" in f.lower(),
        "finding_code": "TRAJECTORY_INDICATOR_INACTIVE",
        "severity": "MEDIUM",
        "object_type": "INDICATOR",
        "object_code": None,
        "recommended_action":
            "Vérifier la disponibilité des données source pour l'année de "
            "référence. Appliquer la doctrine P7E si imputation > 50%.",
        "priority": "MEDIUM",
        "owner": "METHODOLOGY_COMMITTEE",
        "sprint_target": "Sprint 25",
    },

    # ── LOW : fichiers sensibles détectés par SECURITY ────────────────────
    {
        "rule_code": "R10_SECURITY_SENSITIVE",
        "publication_impact": "NONE",
        "iprs_weight": 0.25,
        "pattern": lambda m, f: m == "SECURITY",
        "finding_code": "SECURITY_SENSITIVE_PATTERN",
        "severity": "LOW",
        "object_type": "CONFIG",
        "object_code": None,
        "recommended_action":
            "Vérifier que les fichiers signalés ne contiennent pas de "
            "credentials en clair. Utiliser des variables d'environnement.",
        "priority": "LOW",
        "owner": "OPS_ADMINISTRATOR",
        "sprint_target": "Sprint 25",
    },

    # ── LOW : pays manquant dans coverage ─────────────────────────────────
    {
        "rule_code": "R11_MISSING_COUNTRY",
        "publication_impact": "NONE",
        "iprs_weight": 0.25,
        "pattern": lambda m, f: "missing_country" in f.lower() or "LCA" in f,
        "finding_code": "COVERAGE_MISSING_COUNTRY",
        "severity": "LOW",
        "object_type": "TABLE",
        "object_code": "rf.countries",
        "recommended_action":
            "Vérifier la liste de référence des pays africains dans "
            "rf.countries et les modules d'audit (_AFRICA_ISO3).",
        "priority": "LOW",
        "owner": "DATA_STEWARD",
        "sprint_target": "Sprint 26",
    },

    # ── INFO : pas de token configuré ─────────────────────────────────────
    {
        "rule_code": "R12_NO_AUTH_TOKEN",
        "publication_impact": "NONE",
        "iprs_weight": 0.0,
        "pattern": lambda m, f: "api_key" in f.lower() or "auth_token" in f.lower(),
        "finding_code": "AUTH_TOKEN_NOT_CONFIGURED",
        "severity": "INFO",
        "object_type": "CONFIG",
        "object_code": "audit_config.yaml",
        "recommended_action":
            "Configurer api_key et auth_token dans audit_config.yaml "
            "pour activer la passe B du module API_PERMISSIONS.",
        "priority": "LOW",
        "owner": "OPS_ADMINISTRATOR",
        "sprint_target": "Sprint 25",
    },
]


def _extract_object_code(finding_text: str, rule: dict) -> str | None:
    """
    Tente d'extraire l'object_code depuis le texte du finding
    pour les règles dont object_code est None (dynamique).
    """
    # Endpoint : extraire /api/v2/...
    ep_match = re.search(r"(/api/v2/[^\s',}\]]+|/opendata/)", finding_text)
    if ep_match and rule.get("object_type") == "ENDPOINT":
        return ep_match.group(1)

    # Indicateur : extraire CODE_INDICATEUR majuscule
    ind_match = re.search(r"\b([A-Z]{2,}_[A-Z_]+)\b", finding_text)
    if ind_match and rule.get("object_type") == "INDICATOR":
        return ind_match.group(1)

    # Layer : extraire L1/L2/L3
    layer_match = re.search(r"\bL([123])\b", finding_text)
    if layer_match and rule.get("object_type") == "LAYER":
        return f"layer_id={layer_match.group(1)}"

    return rule.get("object_code")


def _normalize_findings(module_result: dict) -> list[str]:
    """
    Extrait tous les textes de findings d'un résultat de module.
    Supporte findings (liste), warnings (liste), error (str).
    """
    texts = []
    for key in ("findings", "warnings", "missing_endpoints",
                "slow_endpoints", "failures"):
        val = module_result.get(key)
        if isinstance(val, list):
            for item in val:
                if isinstance(item, str):
                    texts.append(item)
                elif isinstance(item, dict):
                    texts.append(str(item))
    if module_result.get("error"):
        texts.append(str(module_result["error"]))
    return texts


class OrientationEngine:
    """
    Transforme les findings bruts du runner en findings structurés GAF.
    """

    def __init__(self, rules: list = None):
        self.rules = rules or ORIENTATION_RULES

    def classify_finding(
        self,
        module: str,
        finding_text: str,
    ) -> dict:
        """
        Applique la première règle qui match et retourne un finding structuré.
        """
        for rule in self.rules:
            try:
                if rule["pattern"](module, finding_text):
                    object_code = _extract_object_code(finding_text, rule)
                    return {
                        "finding_code":       rule["finding_code"],
                        "severity":           rule["severity"],
                        "publication_impact": rule.get("publication_impact", "NONE"),
                        "iprs_weight":        rule.get("iprs_weight", 0.0),
                        "object_type":        rule.get("object_type"),
                        "object_code":        object_code,
                        "description":        finding_text[:1000],
                        "recommended_action": rule["recommended_action"],
                        "priority":           rule["priority"],
                        "owner":              rule["owner"],
                        "sprint_target":      rule["sprint_target"],
                        "rule_code":          rule["rule_code"],
                    }
            except Exception:
                continue

        # Aucune règle matchée → INFO / UNCLASSIFIED
        return {
            "finding_code":       "UNCLASSIFIED",
            "severity":           "INFO",
            "object_type":        None,
            "object_code":        None,
            "description":        finding_text[:1000],
            "recommended_action": "Analyser manuellement ce finding.",
            "priority":           "LOW",
            "owner":              "OPS_ADMINISTRATOR",
            "sprint_target":      None,
            "rule_code":          "R00_UNCLASSIFIED",
            "publication_impact": "NONE",
        }

    def orient_module(self, module_result: dict) -> list[dict]:
        """
        Oriente tous les findings d'un module.
        Retourne une liste de findings structurés.
        """
        module = module_result.get("module", "UNKNOWN")
        finding_texts = _normalize_findings(module_result)

        structured = []
        for text in finding_texts:
            if not text or len(text.strip()) < 5:
                continue
            classified = self.classify_finding(module, text)
            classified["module"]      = module
            classified["raw_finding"] = {"text": text, "module": module}
            structured.append(classified)

        return structured

    def orient_run(self, audit_results: list[dict]) -> dict:
        """
        Oriente l'ensemble des findings d'un audit run.

        Retourne :
          {
            "oriented_at": ISO timestamp,
            "total_findings": int,
            "by_severity": {CRITICAL: int, HIGH: int, ...},
            "by_module": {module: int, ...},
            "findings": [finding structuré, ...]
          }
        """
        all_findings = []

        for module_result in audit_results:
            if module_result.get("status") in ("FAIL", "WARNING"):
                all_findings.extend(self.orient_module(module_result))

        # Agrégats
        by_severity = {"CRITICAL": 0, "HIGH": 0, "MEDIUM": 0, "LOW": 0, "INFO": 0}
        by_module   = {}

        for f in all_findings:
            sev = f.get("severity", "INFO")
            by_severity[sev] = by_severity.get(sev, 0) + 1
            mod = f.get("module", "UNKNOWN")
            by_module[mod] = by_module.get(mod, 0) + 1

        return {
            "oriented_at":    datetime.now(timezone.utc).isoformat(),
            "total_findings": len(all_findings),
            "by_severity":    by_severity,
            "by_module":      by_module,
            "findings":       all_findings,
        }


if __name__ == "__main__":
    import json

    # Test avec findings simulés
    sample_results = [
        {
            "module": "METHODOLOGY",
            "status": "FAIL",
            "findings": [
                "L3: 997865/998675 lignes (99.92%) avec method_version_id IS NULL",
                "SOV_PECO/2024 weight sum=0.93750000",
                "PECO: ECO_LOG not linked and not excluded",
            ]
        },
        {
            "module": "API_CONTRACT_ADVANCED",
            "status": "WARNING",
            "warnings": ["TIMEOUT: /api/v2/early-warning/conflict-economy"]
        },
        {
            "module": "DATA_QUALITY",
            "status": "WARNING",
            "warnings": ["NULL_VALUES"]
        },
    ]

    engine = OrientationEngine()
    result = engine.orient_run(sample_results)

    print(f"Findings orientés : {result['total_findings']}")
    print(f"Par sévérité : {result['by_severity']}")
    print()
    for f in result["findings"]:
        print(f"[{f['severity']:8}] {f['finding_code']:35} → {f['owner']}")
