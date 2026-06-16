#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
OSA ISA
P8 OPS V2
Email Sender

Notification des audits OPS par email (SMTP/STARTTLS).

Configuration YAML requise :
  smtp_host:      smtp.mailjet.com
  smtp_port:      587
  smtp_user:      <clé_api>
  smtp_password:  <clé_secrète>
  email_sender:   audit@osa-observatory.africa

Exemple d'utilisation :
  sender = EmailSender(cfg)
  sender.send_audit_report(report, recipients=["admin@osa-observatory.africa"])

Corrections (AUDIT OSA-2026-001) :
- [P0] IndentationError : toutes les méthodes de EmailSender étaient
  au niveau module. Indentation corrigée.
- [P1] Commentaire de configuration laissé dans un bloc de chaîne
  flottante hors classe retiré et migré en docstring propre.
- [P1] datetime.utcnow() déprécié Python 3.12 → datetime.now(timezone.utc).
"""

import os
import smtplib
from datetime import datetime, timezone
from email.message import EmailMessage


class EmailSender:

    def __init__(self, cfg: dict):
        self.smtp_host     = cfg["smtp_host"]
        self.smtp_port     = cfg["smtp_port"]
        self.smtp_user     = cfg["smtp_user"]
        self.smtp_password = cfg["smtp_password"]
        self.sender        = cfg["email_sender"]

    def send_email(
        self,
        recipients: list,
        subject: str,
        body: str,
        attachments: list = None,
    ) -> dict:

        msg = EmailMessage()
        msg["Subject"] = subject
        msg["From"]    = self.sender
        msg["To"]      = ", ".join(recipients)
        msg.set_content(body)

        for file_path in (attachments or []):
            if not os.path.exists(file_path):
                continue
            with open(file_path, "rb") as f:
                data = f.read()
            msg.add_attachment(
                data,
                maintype="application",
                subtype="octet-stream",
                filename=os.path.basename(file_path),
            )

        try:
            with smtplib.SMTP(self.smtp_host, self.smtp_port, timeout=30) as server:
                server.starttls()
                server.login(self.smtp_user, self.smtp_password)
                server.send_message(msg)

            return {"status": "PASS", "recipients": len(recipients)}

        except Exception as e:
            return {"status": "FAIL", "error": str(e)}

    def send_audit_report(
        self,
        report: dict,
        recipients: list,
        attachment: str = None,
    ) -> dict:

        pub    = report.get("publication", {})
        status = pub.get("publication_status", "UNKNOWN")
        iprs   = report.get("iprs", "N/A")
        ts     = datetime.now(timezone.utc).isoformat()

        subject = f"[OSA ISA] {status} (IPRS={iprs})"

        body = (
            f"OSA ISA – Audit OPS\n"
            f"{'=' * 40}\n\n"
            f"Date UTC         : {ts}\n"
            f"Audit ID         : {report.get('audit_id', 'N/A')}\n"
            f"IPRS             : {iprs}\n"
            f"Publication      : {status}\n"
            f"Durée            : {report.get('audit_duration_seconds', 0)} s\n"
            f"Modules          : {len(report.get('results', []))}\n"
        )

        return self.send_email(
            recipients=recipients,
            subject=subject,
            body=body,
            attachments=[attachment] if attachment else [],
        )


if __name__ == "__main__":
    # Test de connexion SMTP uniquement — ne pas exécuter en production
    # sans un cfg valide.
    print("EmailSender chargé — fournir un cfg valide pour tester.")
