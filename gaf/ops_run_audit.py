#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
OSA ISA – P8 OPS V2
Point d'entrée CLI du runner d'audit.

Corrections (AUDIT OSA-2026-001) :
- [P0] Import path corrigé : from audit.core.audit_runner import run_all
- [P1] Fichier config avec gestionnaire de contexte
- [P1] datetime.utcnow() → datetime.now(timezone.utc)
- [P2] Résumé console lisible

Ajout Sprint 24 GAF :
- [GAF-P0] Intégration audit_ledger : le run est persisté dans
  ops.audit_runs via AuditLedger.save_full_audit(), et l'audit_id
  retourné est injecté dans le rapport avant sauvegarde JSON.
  Sans audit_id, run_gaf.py ne peut pas lier les findings à leur run.
- [GAF-P1] Appel automatique de run_gaf après chaque audit si
  cfg["gaf"]["enabled"] = true (optionnel, défaut False pour
  ne pas bloquer un audit si GAF n'est pas encore déployé).
- [GAF-P2] git_commit injecté dynamiquement depuis git rev-parse
  si cfg["git_commit"] = "auto".
"""

import sys
import json
import logging
import subprocess
from pathlib import Path
from datetime import datetime, timezone

import yaml

PROJECT_ROOT = Path(__file__).resolve().parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from audit.core.audit_runner import run_all           # noqa: E402
from audit.core.audit_ledger import AuditLedger       # noqa: E402

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-8s | %(message)s",
)
logger = logging.getLogger(__name__)


def _resolve_git_commit(cfg: dict) -> str:
    """
    Résout le git_commit à injecter dans le rapport.
    Si cfg["git_commit"] == "auto", appelle git rev-parse --short HEAD.
    """
    commit = cfg.get("git_commit", "unknown")
    if commit == "auto":
        try:
            result = subprocess.run(
                ["git", "rev-parse", "--short", "HEAD"],
                capture_output=True, text=True, cwd=str(PROJECT_ROOT)
            )
            if result.returncode == 0:
                return result.stdout.strip()
        except Exception:
            pass
        return "unknown"
    return commit


def main() -> None:

    config_path = PROJECT_ROOT / "audit" / "config" / "audit_config.yaml"
    logger.info("Chargement de la configuration : %s", config_path)

    with open(config_path, encoding="utf-8") as f:
        cfg = yaml.safe_load(f) or {}

    git_commit = _resolve_git_commit(cfg)
    logger.info("git_commit : %s", git_commit)
    logger.info("Démarrage du runner d'audit OPS…")

    report = run_all(cfg)

    # ── Persistance ledger + injection audit_id ───────────────────────────
    audit_id = None
    if cfg.get("ledger", {}).get("enabled", False):
        try:
            ledger   = AuditLedger(cfg)
            audit_id = ledger.save_full_audit(report, git_commit=git_commit)
            report["audit_id"] = audit_id
            logger.info("Ledger persisté — audit_id=%s", audit_id)
        except Exception as e:
            logger.warning("Ledger non persisté (non bloquant) : %s", e)
    else:
        logger.info("Ledger désactivé (cfg.ledger.enabled=false)")

    # ── Sauvegarde JSON ───────────────────────────────────────────────────
    reports_dir = PROJECT_ROOT / "reports"
    reports_dir.mkdir(parents=True, exist_ok=True)

    ts       = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    filename = reports_dir / f"audit_{ts}.json"

    with open(filename, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2, ensure_ascii=False, default=str)

    logger.info("Rapport sauvegardé : %s", filename)

    # ── Résumé console ────────────────────────────────────────────────────
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

    # ── GAF automatique ───────────────────────────────────────────────────
    gaf_cfg = cfg.get("gaf", {})
    if gaf_cfg.get("enabled", False):
        try:
            sys.path.insert(0, str(PROJECT_ROOT))
            from gaf.core.gaf_runner import run_gaf
            gaf_result = run_gaf(cfg, report, dry_run=False)
            logger.info(
                "GAF terminé — findings=%d | CRITICAL=%d | HIGH=%d",
                gaf_result["total_findings"],
                gaf_result["by_severity"].get("CRITICAL", 0),
                gaf_result["by_severity"].get("HIGH", 0),
            )
        except Exception as e:
            logger.warning("GAF non exécuté (non bloquant) : %s", e)
    else:
        logger.info(
            "GAF désactivé (cfg.gaf.enabled=false) — "
            "lancer manuellement : python3 gaf/run_gaf.py"
        )


if __name__ == "__main__":
    main()
