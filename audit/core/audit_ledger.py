#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
OSA ISA
P8 OPS V2

Audit Ledger

Historisation centralisée des audits OPS.

Tables :

  ops.audit_runs
  ops.audit_results
  ops.audit_publication_gate

Corrections (AUDIT OSA-2026-001) :
- [P0] IndentationError : toutes les méthodes de la classe AuditLedger
  étaient au niveau module (hors classe). Indentation corrigée.
- [P1] conn.autocommit = False déplacé avant toute opération DML pour
  garantir le comportement transactionnel dès l'ouverture.
"""

import json
import hashlib
from datetime import datetime

import psycopg2


class AuditLedger:

    def __init__(self, config: dict):
        self.config = config

    def get_connection(self):
        return psycopg2.connect(
            host=self.config["db_host"],
            port=self.config["db_port"],
            dbname=self.config["db_name"],
            user=self.config["db_user"],
            password=self.config["db_password"],
        )

    @staticmethod
    def compute_hash(payload: dict) -> str:
        content = json.dumps(payload, sort_keys=True, default=str)
        return hashlib.sha256(content.encode("utf-8")).hexdigest()

    def validate_report(self, report: dict) -> None:
        required_keys = [
            "iprs",
            "audit_duration_seconds",
            "results",
            "publication",
        ]
        for key in required_keys:
            if key not in report:
                raise ValueError(f"Missing report key: {key}")

    def save_full_audit(
        self,
        report: dict,
        git_commit: str = "unknown",
    ) -> int:
        """
        Persiste un audit complet dans ops.*
        Retourne l'audit_id généré.
        Toute erreur déclenche un rollback complet.
        """
        self.validate_report(report)

        conn = self.get_connection()
        conn.autocommit = False

        try:
            cur = conn.cursor()

            report_hash = self.compute_hash(report)

            signature_hash = self.compute_hash({
                "report_hash": report_hash,
                "git_commit":  git_commit,
                "timestamp":   datetime.utcnow().isoformat(),
            })

            # ── AUDIT RUN ─────────────────────────────────────────
            cur.execute("""
                INSERT INTO ops.audit_runs (
                    audit_duration_seconds,
                    iprs,
                    publication_status,
                    git_commit,
                    report_hash,
                    signature_hash
                )
                VALUES (%s, %s, %s, %s, %s, %s)
                RETURNING audit_id
            """, (
                report["audit_duration_seconds"],
                report["iprs"],
                report["publication"]["publication_status"],
                git_commit,
                report_hash,
                signature_hash,
            ))

            audit_id = cur.fetchone()[0]

            # ── MODULE RESULTS ────────────────────────────────────
            for result in report["results"]:
                cur.execute("""
                    INSERT INTO ops.audit_results (
                        audit_id,
                        module_name,
                        status,
                        details
                    )
                    VALUES (%s, %s, %s, %s::jsonb)
                """, (
                    str(audit_id),
                    result["module"],
                    result["status"],
                    json.dumps(result, default=str),
                ))

            # ── PUBLICATION GATE ──────────────────────────────────
            cur.execute("""
                INSERT INTO ops.audit_publication_gate (
                    audit_id,
                    publication_status,
                    warning_modules,
                    fail_modules
                )
                VALUES (%s, %s, %s::jsonb, %s::jsonb)
            """, (
                str(audit_id),
                report["publication"]["publication_status"],
                json.dumps(report["publication"].get("warning_modules", [])),
                json.dumps(report["publication"].get("fail_modules",    [])),
            ))

            conn.commit()
            return audit_id

        except Exception:
            conn.rollback()
            raise

        finally:
            conn.close()
