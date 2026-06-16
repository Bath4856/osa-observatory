#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
OSA ISA
P8 OPS V2
DOCUMENTATION AUDIT

Corrections (AUDIT OSA-2026-001) :
- [P1] coverage_pct calculé sur les fichiers présents (existants +
  vides), pas seulement non-vides. Un fichier vide est présent mais
  non conforme — il doit peser dans la couverture. Deux métriques
  distinctes : presence_pct (fichier présent) et content_pct (fichier
  présent et non vide).
- [P2] REQUIRED_FILES extensible via cfg["required_docs"] pour
  permettre des contrôles spécifiques par sprint sans modifier le code.
"""

from pathlib import Path
import time

MODULE = "DOCUMENTATION"

# Liste de base — peut être complétée via cfg["required_docs"]
_DEFAULT_REQUIRED_FILES = [
    "README.md",
    "audit/config/audit_config.yaml",
    "audit/config/publication_rules.yaml",
    "audit/config/trajectory_rules.yaml",
]


def run(cfg: dict) -> dict:

    started_at = time.time()

    try:
        project_root = Path(cfg.get("project_root", ".")).resolve()

        # Fusionner liste par défaut + éventuels fichiers cfg
        required_files = list(_DEFAULT_REQUIRED_FILES)
        extra = cfg.get("required_docs", [])
        for f in extra:
            if f not in required_files:
                required_files.append(f)

        existing_nonempty = []
        existing_empty    = []
        missing           = []
        file_details      = {}

        for relative_path in required_files:
            full_path = project_root / relative_path

            if not full_path.exists():
                missing.append(relative_path)
                file_details[relative_path] = {"exists": False, "size_bytes": 0}
                continue

            size_bytes = full_path.stat().st_size
            file_details[relative_path] = {"exists": True, "size_bytes": size_bytes}

            if size_bytes == 0:
                existing_empty.append(relative_path)
            else:
                existing_nonempty.append(relative_path)

        required_count = len(required_files)

        # presence_pct : fichier trouvé sur disque (vide ou non)
        presence_pct = round(
            (len(existing_nonempty) + len(existing_empty)) / required_count * 100, 2
        )
        # content_pct : fichier présent ET non vide
        content_pct = round(
            len(existing_nonempty) / required_count * 100, 2
        )

        if missing:
            status = "FAIL"
        elif existing_empty:
            status = "WARNING"
        else:
            status = "PASS"

        elapsed_ms = round((time.time() - started_at) * 1000, 2)

        return {
            "module":          MODULE,
            "status":          status,
            "elapsed_ms":      elapsed_ms,
            "required_count":  required_count,
            "existing_count":  len(existing_nonempty),
            "empty_count":     len(existing_empty),
            "missing_count":   len(missing),
            "presence_pct":    presence_pct,
            "content_pct":     content_pct,
            "existing":        existing_nonempty,
            "empty":           existing_empty,
            "missing":         missing,
            "files":           file_details,
        }

    except Exception as e:
        return {
            "module": MODULE,
            "status": "FAIL",
            "error":  str(e),
        }


if __name__ == "__main__":
    import json
    print(json.dumps(run({"project_root": "/mnt/data/osa-app/osa-observatory"}), indent=2))
