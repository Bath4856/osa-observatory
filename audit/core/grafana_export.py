#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
OSA ISA
P8 OPS V2
Grafana Export

Export des résultats d'audit vers Grafana (fichiers JSON).

Corrections (AUDIT OSA-2026-001) :
- [P0] IndentationError : toutes les méthodes de GrafanaExporter
  étaient au niveau module. Indentation corrigée.
- [P0] if __name__ == "__main__" corrompu (if **name** == "**main**").
  Corrigé.
- [P1] datetime.utcnow() déprécié Python 3.12 → datetime.now(timezone.utc).
"""

import os
import json
from datetime import datetime, timezone


class GrafanaExporter:

    def __init__(self, cfg: dict):
        self.output_dir = cfg.get("grafana_export_dir", "reports/grafana")
        os.makedirs(self.output_dir, exist_ok=True)

    def build_dashboard_payload(self, report: dict) -> dict:
        publication = report.get("publication", {})
        return {
            "timestamp":              datetime.now(timezone.utc).isoformat(),
            "audit_id":               report.get("audit_id"),
            "iprs":                   report.get("iprs"),
            "audit_duration_seconds": report.get("audit_duration_seconds"),
            "publication_status":     publication.get("publication_status"),
            "warning_modules":        publication.get("warning_modules", []),
            "fail_modules":           publication.get("fail_modules", []),
            "module_results":         report.get("results", []),
        }

    def export_json(self, report: dict) -> dict:
        """Exporte un fichier horodaté dans le répertoire historique."""
        payload  = self.build_dashboard_payload(report)
        filename = (
            "grafana_audit_"
            + datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
            + ".json"
        )
        output_file = os.path.join(self.output_dir, filename)

        with open(output_file, "w", encoding="utf-8") as f:
            json.dump(payload, f, indent=2, ensure_ascii=False)

        return {"status": "PASS", "file": output_file}

    def export_latest(self, report: dict) -> str:
        """Écrase latest_audit.json pour que Grafana ait toujours le dernier état."""
        payload     = self.build_dashboard_payload(report)
        latest_file = os.path.join(self.output_dir, "latest_audit.json")

        with open(latest_file, "w", encoding="utf-8") as f:
            json.dump(payload, f, indent=2, ensure_ascii=False)

        return latest_file

    def export(self, report: dict) -> dict:
        """Exporte le rapport en historique ET en latest."""
        historical = self.export_json(report)
        latest     = self.export_latest(report)
        return {
            "status":     "PASS",
            "historical": historical,
            "latest":     latest,
        }


if __name__ == "__main__":
    sample_report = {
        "audit_id":               "demo",
        "iprs":                   95.2,
        "audit_duration_seconds": 3.4,
        "publication": {
            "publication_status": "READY_FOR_PUBLICATION",
            "warning_modules":    [],
            "fail_modules":       [],
        },
        "results": [],
    }
    exporter = GrafanaExporter({"grafana_export_dir": "reports/grafana"})
    print(exporter.export(sample_report))
