#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
OSA ISA – Sprint 24 GAF
gaf_runner.py

Orchestrateur GAF : enchaîne en un seul appel
  1. Chargement du rapport d'audit
  2. Orientation des findings (OrientationEngine)
  3. Persistance (GAFLedger)
  4. Retour du résumé

Appelé depuis run_gaf.py ou directement depuis audit_runner
après un run complet.

Usage programmatique :
  from gaf.core.gaf_runner import run_gaf
  result = run_gaf(cfg, report)
"""

import json
import logging
from datetime import datetime, timezone
from pathlib import Path

from gaf.core.orientation_engine import OrientationEngine
from gaf.core.gaf_ledger import GAFLedger

logger = logging.getLogger(__name__)


def run_gaf(
    cfg: dict,
    report: dict,
    dry_run: bool = False,
) -> dict:
    """
    Orchestrateur principal GAF.

    Paramètres :
      cfg     : configuration OSA (audit_config.yaml)
      report  : rapport JSON produit par audit_runner.run_all()
      dry_run : si True, oriente sans persister en DB

    Retourne :
      {
        "gaf_run_at":          ISO timestamp,
        "audit_id":            int ou None,
        "total_findings":      int,
        "by_severity":         dict,
        "by_module":           dict,
        "findings_saved":      int,
        "recommendations_saved": int,
        "kpis":                dict ou None,
        "dry_run":             bool,
      }
    """

    started_at = datetime.now(timezone.utc)
    audit_id   = report.get("audit_id")
    results    = report.get("results", [])

    logger.info(
        "GAF run démarré — audit_id=%s | modules=%d | dry_run=%s",
        audit_id, len(results), dry_run
    )

    # ── 1. Orientation ────────────────────────────────────────────────────
    engine   = OrientationEngine()
    oriented = engine.orient_run(results)

    logger.info(
        "Orientation terminée — %d findings | CRITICAL=%d | HIGH=%d",
        oriented["total_findings"],
        oriented["by_severity"].get("CRITICAL", 0),
        oriented["by_severity"].get("HIGH", 0),
    )

    findings_saved        = 0
    recommendations_saved = 0
    kpis                  = None

    # ── 2. Persistance ────────────────────────────────────────────────────
    if not dry_run:
        if not audit_id:
            logger.warning(
                "audit_id absent du rapport — findings non persistés. "
                "Assurez-vous que audit_ledger.save_full_audit() a été appelé "
                "et que audit_id est inclus dans le rapport."
            )
        else:
            ledger = GAFLedger(cfg)
            saved  = ledger.save_findings(audit_id, oriented)
            findings_saved        = saved["findings_saved"]
            recommendations_saved = saved["recommendations_saved"]

            # KPIs post-run
            try:
                kpis = ledger.get_kpis()
            except Exception as e:
                logger.warning("Impossible de calculer les KPIs GAF : %s", e)

    elapsed = round(
        (datetime.now(timezone.utc) - started_at).total_seconds(), 2
    )

    result = {
        "gaf_run_at":             started_at.isoformat(),
        "audit_id":               audit_id,
        "elapsed_seconds":        elapsed,
        "total_findings":         oriented["total_findings"],
        "by_severity":            oriented["by_severity"],
        "by_module":              oriented["by_module"],
        "findings":               oriented["findings"],
        "findings_saved":         findings_saved,
        "recommendations_saved":  recommendations_saved,
        "kpis":                   kpis,
        "dry_run":                dry_run,
    }

    logger.info(
        "GAF run terminé — %ds | findings=%d | sauvegardés=%d",
        elapsed, oriented["total_findings"], findings_saved
    )

    return result


def run_gaf_from_file(
    cfg: dict,
    report_path: Path,
    dry_run: bool = False,
) -> dict:
    """
    Variante : charge le rapport depuis un fichier JSON puis appelle run_gaf.
    """
    with open(report_path, encoding="utf-8") as f:
        report = json.load(f)
    return run_gaf(cfg, report, dry_run=dry_run)
