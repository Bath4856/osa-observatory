#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
OSA ISA
P8 OPS V2
Signature Engine

Corrections (AUDIT OSA-2026-001) :
- [P0] IndentationError : toutes les méthodes de SignatureEngine étaient
  au niveau module (hors classe). Indentation corrigée.
- [P1] datetime.utcnow() déprécié depuis Python 3.12. Remplacé par
  datetime.now(timezone.utc).isoformat() dans toute la classe.
"""

import json
import hashlib
from datetime import datetime, timezone


class SignatureEngine:

    @staticmethod
    def canonical_json(payload: dict) -> str:
        return json.dumps(
            payload,
            sort_keys=True,
            ensure_ascii=False,
            default=str,
            separators=(",", ":"),
        )

    @staticmethod
    def compute_hash(payload: dict) -> str:
        content = SignatureEngine.canonical_json(payload)
        return hashlib.sha256(content.encode("utf-8")).hexdigest()

    @staticmethod
    def build_signature_payload(
        report_hash: str,
        git_commit: str = "unknown",
    ) -> dict:
        return {
            "report_hash": report_hash,
            "git_commit":  git_commit,
            "signed_at":   datetime.now(timezone.utc).isoformat(),
        }

    @staticmethod
    def compute_signature(
        report: dict,
        git_commit: str = "unknown",
    ) -> dict:
        report_hash       = SignatureEngine.compute_hash(report)
        signature_payload = SignatureEngine.build_signature_payload(
            report_hash, git_commit
        )
        signature_hash    = SignatureEngine.compute_hash(signature_payload)

        return {
            "report_hash":       report_hash,
            "signature_hash":    signature_hash,
            "signature_payload": signature_payload,
        }

    @staticmethod
    def verify_report_hash(report: dict, expected_hash: str) -> bool:
        return SignatureEngine.compute_hash(report) == expected_hash

    @staticmethod
    def verify_signature(
        report: dict,
        expected_signature: str,
        signature_payload: dict,
    ) -> bool:
        """
        Vérifie la signature en utilisant le signature_payload original stocké
        (qui contient le signed_at figé au moment de la signature).

        NE PAS recalculer signature_payload depuis le report : signed_at
        changerait à chaque appel, produisant un hash différent → toujours False.

        Paramètres
        ----------
        report              : rapport original
        expected_signature  : signature_hash stocké (issu de compute_signature)
        signature_payload   : signature_payload stocké (issu de compute_signature)
        """
        report_hash       = SignatureEngine.compute_hash(report)
        # Vérifier que le report n'a pas changé depuis la signature
        if report_hash != signature_payload.get("report_hash"):
            return False
        # Recalculer le hash de la signature à partir du payload original figé
        computed_sig_hash = SignatureEngine.compute_hash(signature_payload)
        return computed_sig_hash == expected_signature


if __name__ == "__main__":
    import json as _json

    report = {
        "iprs": 94.8,
        "publication": {"publication_status": "READY_FOR_PUBLICATION"},
    }

    result = SignatureEngine.compute_signature(report, git_commit="v2.0.0")
    print(_json.dumps(result, indent=2))
    print("verify_hash:", SignatureEngine.verify_report_hash(report, result["report_hash"]))
    print("verify_sig: ", SignatureEngine.verify_signature(
        report,
        result["signature_hash"],
        result["signature_payload"],   # payload figé au moment de la signature
    ))
