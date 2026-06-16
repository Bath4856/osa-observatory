#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
OSA ISA – OPS V2
AUDIT REPOSITORY STRUCTURE

Corrections (AUDIT OSA-2026-001) :
- [P2] REQUIRED_DIRS et REQUIRED_FILES extensibles via
  cfg["required_dirs"] / cfg["required_files"] pour permettre
  des validations sprint-spécifiques sans modifier le code.
- [P2] Distinction warnings/fails : un répertoire optionnel manquant
  (ex. reports/pdf non encore généré) peut être déclaré dans
  cfg["optional_dirs"] — son absence donne WARNING, pas FAIL.
"""

from pathlib import Path
import time

MODULE = "REPOSITORY_STRUCTURE"

_DEFAULT_REQUIRED_DIRS = [
    "audit",
    "audit/audits",
    "audit/core",
    "audit/config",
    "reports",
    "reports/pdf",
    "reports/grafana",
]

_DEFAULT_REQUIRED_FILES = [
    "README.md",
    "audit/config/audit_config.yaml",
]


def run(cfg: dict) -> dict:

    started = time.time()
    root = Path(cfg.get("project_root", ".")).resolve()

    # Listes configurables
    required_dirs  = list(_DEFAULT_REQUIRED_DIRS)  + list(cfg.get("required_dirs",  []))
    required_files = list(_DEFAULT_REQUIRED_FILES) + list(cfg.get("required_files", []))
    optional_dirs  = list(cfg.get("optional_dirs", []))

    missing_dirs  = [d for d in required_dirs  if not (root / d).is_dir()]
    missing_files = [f for f in required_files if not (root / f).is_file()]
    warn_dirs     = [d for d in optional_dirs  if not (root / d).is_dir()]

    if missing_dirs or missing_files:
        status = "FAIL"
    elif warn_dirs:
        status = "WARNING"
    else:
        status = "PASS"

    elapsed = round((time.time() - started) * 1000, 2)

    return {
        "module":        MODULE,
        "status":        status,
        "elapsed_ms":    elapsed,
        "missing_dirs":  missing_dirs,
        "missing_files": missing_files,
        "warnings":      [f"optional dir absent: {d}" for d in warn_dirs],
    }


if __name__ == "__main__":
    import json
    print(json.dumps(run({"project_root": "."}), indent=2))
