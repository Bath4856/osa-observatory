#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
OSA ISA – P8 OPS V2
Point d'entrée CLI du runner d'audit.

Corrections (AUDIT OSA-2026-001) :
- [P0] Import path : `from core.audit_runner import run_all` suppose
  que core/ est un sous-dossier du répertoire courant. Dans
  docker-compose, working_dir=/app et audit/ est monté dans /app/audit.
  Corrigé : `from audit.core.audit_runner import run_all` (cohérent
  avec audit_runner.py qui se résout depuis PROJECT_ROOT).
  Alternative : sys.path.insert si la structure de déploiement change.
- [P1] Fichier de config ouvert sans fermeture garantie (open() nu
  sans with). Corrigé avec gestionnaire de contexte.
- [P1] datetime.utcnow() déprécié Python 3.12 → datetime.now(timezone.utc).
- [P2] Rapport JSON sauvegardé avec ensure_ascii=False et default=str
  pour éviter les erreurs de sérialisation sur les types non-JSON
  (dates, Decimal…).
- [P2] Sortie console tronquée : print(report) affiche le dict brut
  complet. Remplacé par un résumé lisible (statut, IPRS, durée).
"""

import sys
import json
import logging
from pathlib import Path
from datetime import datetime, timezone

import yaml

# Résolution du PROJECT_ROOT (osa-observatory/)
PROJECT_ROOT = Path(__file__).resolve().parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from audit.core.audit_runner import run_all  # noqa: E402

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-8s | %(message)s",
)
logger = logging.getLogger(__name__)


def main() -> None:

    config_path = PROJECT_ROOT / "audit" / "config" / "audit_config.yaml"

    logger.info("Chargement de la configuration : %s", config_path)

    with open(config_path, encoding="utf-8") as f:
        cfg = yaml.safe_load(f) or {}

    logger.info("Démarrage du runner d'audit OPS…")
    report = run_all(cfg)

    # ── Sauvegarde JSON ──────────────────────────────────────────────
    reports_dir = PROJECT_ROOT / "reports"
    reports_dir.mkdir(parents=True, exist_ok=True)

    ts       = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    filename = reports_dir / f"audit_{ts}.json"

    with open(filename, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2, ensure_ascii=False, default=str)

    logger.info("Rapport sauvegardé : %s", filename)

    # ── Résumé console ───────────────────────────────────────────────
    pub    = report.get("publication", {})
    status = pub.get("publication_status", "UNKNOWN")
    iprs   = report.get("iprs", "N/A")
    dur    = report.get("audit_duration_seconds", "N/A")
    fails  = pub.get("fail_count", 0)
    warns  = pub.get("warning_count", 0)

    logger.info(
        "Audit terminé | statut=%s | IPRS=%s | durée=%ss | FAIL=%s | WARNING=%s",
        status, iprs, dur, fails, warns
    )


if __name__ == "__main__":
    main()
