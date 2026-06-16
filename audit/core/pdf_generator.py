#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
OSA ISA
P8 OPS V2
PDF Generator

Génération des rapports officiels d'audit OPS (ReportLab).

Corrections (AUDIT OSA-2026-001) :
- [P0] IndentationError : toutes les méthodes de PDFGenerator
  étaient au niveau module. Indentation corrigée.
- [P0] if __name__ == "__main__" corrompu (if **name** == "**main**").
  Corrigé.
- [P1] datetime.utcnow() déprécié Python 3.12 → datetime.now(timezone.utc).
- [P2] PageBreak() final superflu après la section Publication Gate
  retiré (génère une page blanche en fin de document).
"""

import os
from datetime import datetime, timezone

from reportlab.platypus import (
    SimpleDocTemplate,
    Paragraph,
    Spacer,
    PageBreak,
    Table,
    TableStyle,
)
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet


class PDFGenerator:

    def __init__(self, cfg: dict):
        self.output_dir = cfg.get("pdf_output_dir", "reports/pdf")
        os.makedirs(self.output_dir, exist_ok=True)

    def build_filename(self) -> str:
        timestamp = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
        return os.path.join(self.output_dir, f"audit_report_{timestamp}.pdf")

    def count_status(self, results: list) -> dict:
        summary = {"PASS": 0, "WARNING": 0, "FAIL": 0}
        for result in results:
            status = result.get("status", "UNKNOWN")
            if status in summary:
                summary[status] += 1
        return summary

    def generate(self, report: dict) -> dict:

        try:
            filename = self.build_filename()

            doc         = SimpleDocTemplate(filename)
            doc.title   = "OSA ISA Audit Report"
            doc.author  = "OSA Observatory"
            doc.subject = "P8 OPS Audit Report"

            styles       = getSampleStyleSheet()
            story        = []
            publication  = report.get("publication", {})
            results      = report.get("results", [])
            status_count = self.count_status(results)
            now_utc      = datetime.now(timezone.utc).isoformat()

            # ── PAGE DE GARDE ─────────────────────────────────────
            story.append(Paragraph("OSA ISA", styles["Title"]))
            story.append(Paragraph("P8 OPS Audit Report", styles["Heading2"]))
            story.append(Spacer(1, 20))
            story.append(Paragraph(f"Audit ID : {report.get('audit_id', 'N/A')}", styles["Normal"]))
            story.append(Paragraph(f"Date UTC : {now_utc}", styles["Normal"]))
            story.append(Paragraph(f"IPRS : {report.get('iprs', 'N/A')}", styles["Normal"]))
            story.append(Paragraph(
                f"Publication : {publication.get('publication_status', 'UNKNOWN')}",
                styles["Normal"],
            ))
            story.append(Paragraph(
                f"Durée : {report.get('audit_duration_seconds', 0)} sec",
                styles["Normal"],
            ))
            story.append(PageBreak())

            # ── RÉSUMÉ EXÉCUTIF ───────────────────────────────────
            story.append(Paragraph("Résumé Exécutif", styles["Heading1"]))

            table = Table([
                ["Statut",   "Nombre"],
                ["PASS",    status_count["PASS"]],
                ["WARNING", status_count["WARNING"]],
                ["FAIL",    status_count["FAIL"]],
            ])
            table.setStyle(TableStyle([
                ("GRID",       (0, 0), (-1, -1), 1, colors.black),
                ("BACKGROUND", (0, 0), (-1,  0), 1, colors.lightgrey),
            ]))
            story.append(table)
            story.append(Spacer(1, 20))

            # ── DÉTAIL DES MODULES ────────────────────────────────
            story.append(Paragraph("Résultats détaillés", styles["Heading1"]))

            for result in results:
                module = result.get("module", "UNKNOWN")
                status = result.get("status", "UNKNOWN")

                story.append(Paragraph(
                    f"<b>{module}</b> : {status}", styles["Heading3"]
                ))
                for key, value in result.items():
                    story.append(Paragraph(f"{key} : {value}", styles["Normal"]))
                story.append(Spacer(1, 10))

            story.append(PageBreak())

            # ── PUBLICATION GATE ──────────────────────────────────
            story.append(Paragraph("Publication Gate", styles["Heading1"]))
            story.append(Paragraph(
                f"Status : {publication.get('publication_status', 'UNKNOWN')}",
                styles["Normal"],
            ))
            story.append(Paragraph(
                f"Warnings : {len(publication.get('warning_modules', []))}",
                styles["Normal"],
            ))
            story.append(Paragraph(
                f"Fails : {len(publication.get('fail_modules', []))}",
                styles["Normal"],
            ))

            if publication.get("warning_modules"):
                story.append(Paragraph("Modules WARNING", styles["Heading2"]))
                for module in publication["warning_modules"]:
                    story.append(Paragraph(str(module), styles["Normal"]))

            if publication.get("fail_modules"):
                story.append(Paragraph("Modules FAIL", styles["Heading2"]))
                for module in publication["fail_modules"]:
                    story.append(Paragraph(str(module), styles["Normal"]))

            # PageBreak() final retiré — évite une page blanche en fin de doc

            doc.build(story)

            return {"status": "PASS", "pdf_file": filename}

        except Exception as e:
            return {"status": "FAIL", "error": str(e)}


if __name__ == "__main__":
    sample_report = {
        "audit_id":               "demo",
        "iprs":                   95.4,
        "audit_duration_seconds": 3.2,
        "publication": {
            "publication_status": "READY_FOR_PUBLICATION",
            "warning_modules":    [],
            "fail_modules":       [],
        },
        "results": [],
    }
    generator = PDFGenerator({})
    print(generator.generate(sample_report))
