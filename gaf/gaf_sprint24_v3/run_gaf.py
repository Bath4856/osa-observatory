#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
OSA ISA – Sprint 24 GAF
Point d'entrée : run_gaf.py

Charge le dernier rapport d'audit JSON, oriente les findings
via orientation_engine.py et les persiste dans PostgreSQL via gaf_ledger.py.

Usage :
  python3 gaf/run_gaf.py                         # dernier rapport
  python3 gaf/run_gaf.py --report <chemin.json>  # rapport spécifique
  python3 gaf/run_gaf.py --dry-run               # orientation seule, sans écriture DB
"""

import sys
import json
import logging
import argparse
from pathlib import Path
from datetime import datetime, timezone

import yaml

PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT_ROOT))

from gaf.core.orientation_engine import OrientationEngine
from gaf.core.gaf_ledger import GAFLedger

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-8s | %(message)s",
)
logger = logging.getLogger(__name__)

SEVERITY_ORDER = {"CRITICAL": 0, "HIGH": 1, "MEDIUM": 2, "LOW": 3, "INFO": 4}


def _latest_report(reports_dir: Path) -> Path:
    reports = sorted(reports_dir.glob("audit_*.json"), reverse=True)
    if not reports:
        raise FileNotFoundError(f"Aucun rapport dans {reports_dir}")
    return reports[0]


def _print_summary(oriented: dict) -> None:
    print()
    print("═" * 60)
    print("  OSA GAF – Résumé d'orientation")
    print("═" * 60)
    print(f"  Findings orientés : {oriented['total_findings']}")
    print()
    print("  Par sévérité :")
    for sev in ("CRITICAL", "HIGH", "MEDIUM", "LOW", "INFO"):
        count = oriented["by_severity"].get(sev, 0)
        if count:
            bar = "█" * min(count, 20)
            print(f"    {sev:10} {bar} {count}")
    print()
    print("  Par module :")
    for mod, count in sorted(oriented["by_module"].items()):
        print(f"    {mod:35} {count}")
    print()
    print("  Findings détaillés :")
    print(f"  {'Sév.':10} {'Code':35} {'Objet':25} {'Owner'}")
    print("  " + "─" * 90)
    for f in sorted(
        oriented["findings"],
        key=lambda x: SEVERITY_ORDER.get(x.get("severity", "INFO"), 9)
    ):
        sev    = f.get("severity", "INFO")
        code   = f.get("finding_code", "?")[:34]
        obj    = (f.get("object_code") or f.get("object_type") or "—")[:24]
        owner  = f.get("owner", "—")
        print(f"  {sev:10} {code:35} {obj:25} {owner}")
    print("═" * 60)


def main():
    parser = argparse.ArgumentParser(description="OSA GAF – Orientation Engine")
    parser.add_argument("--report", type=str, help="Chemin vers le rapport JSON")
    parser.add_argument("--dry-run", action="store_true",
                        help="Orientation seule, sans écriture DB")
    args = parser.parse_args()

    # ── Configuration ─────────────────────────────────────────────────────
    config_path = PROJECT_ROOT / "audit" / "config" / "audit_config.yaml"
    with open(config_path, encoding="utf-8") as f:
        cfg = yaml.safe_load(f) or {}

    reports_dir = PROJECT_ROOT / "reports"

    # ── Chargement du rapport ──────────────────────────────────────────────
    if args.report:
        report_path = Path(args.report)
    else:
        report_path = _latest_report(reports_dir)

    logger.info("Chargement du rapport : %s", report_path)

    with open(report_path, encoding="utf-8") as f:
        report = json.load(f)

    audit_id = report.get("audit_id")
    results  = report.get("results", [])

    logger.info(
        "Rapport chargé — audit_id=%s | modules=%d | IPRS=%s",
        audit_id, len(results), report.get("iprs")
    )

    # ── Orientation ────────────────────────────────────────────────────────
    engine  = OrientationEngine()
    oriented = engine.orient_run(results)

    _print_summary(oriented)

    # ── Persistance ────────────────────────────────────────────────────────
    if args.dry_run:
        logger.info("Mode --dry-run : persistance ignorée.")
        return

    if not audit_id:
        logger.warning(
            "audit_id absent du rapport — les findings ne peuvent pas être "
            "liés à un audit_run. Utilisez audit_ledger pour persister les runs."
        )
        return

    gaf_ledger = GAFLedger(cfg)
    result = gaf_ledger.save_findings(audit_id, oriented)

    logger.info(
        "GAF persisté — findings=%d | recommandations=%d",
        result["findings_saved"],
        result["recommendations_saved"],
    )

    # ── KPIs post-run ──────────────────────────────────────────────────────
    kpis = gaf_ledger.get_kpis()
    print()
    print(f"  KPIs GAF cumulés :")
    print(f"    Total findings      : {kpis['total']}")
    print(f"    Ouverts             : {kpis['total_open']}")
    print(f"    Clôturés            : {kpis['total_closed']}")
    print(f"    Résolution rate     : {kpis['audit_resolution_rate_pct']}%")
    print(f"    CRITICAL ouverts    : {kpis['open_by_severity']['CRITICAL']}")
    print(f"    HIGH ouverts        : {kpis['open_by_severity']['HIGH']}")


if __name__ == "__main__":
    main()
