#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
OSA ISA – OPS V2
AUDIT SECURITY

Corrections (AUDIT OSA-2026-001) :
- [P0] Faux positifs massifs : les patterns ("password", "token"…)
  matchent les noms de variables dans le code source lui-même
  (ex. cfg["db_password"], headers["Authorization"]) — chaque fichier
  Python du projet déclencherait un finding. Correction : les fichiers
  Python (.py) et YAML de config sont exclus du scan de contenu ; seuls
  les fichiers de configuration non versionnés (.env, *.pem, *.key,
  *.p12…) et les fichiers texte génériques sont inspectés.
- [P0] Scan du dossier '.' englobe tout le repo récursivement, y
  compris .git, __pycache__, node_modules. Correction : exclusion
  explicite de ces répertoires + les sous-dossiers déjà couverts par
  des entrées plus précises (audit/, api/) ne sont pas rescannés depuis
  la racine.
- [P1] Déduplication des findings : un même (fichier, pattern) ne
  remonte qu'une seule fois, même si le pattern apparaît plusieurs fois
  dans le fichier.
- [P2] Extensions et dossiers exclus configurables via
  cfg["security_exclude_dirs"] et cfg["security_exclude_extensions"].
"""

import time
from pathlib import Path

MODULE = "SECURITY"

SENSITIVE_PATTERNS = [
    "password",
    "secret",
    "apikey",
    "api_key",
    "token",
    "PRIVATE_KEY",
    "BEGIN RSA",
    "BEGIN OPENSSH",
]

# Dossiers de scan — la racine '.' est retirée pour éviter le scan
# global récursif incontrôlé. Seuls audit/ et api/ sont ciblés.
_DEFAULT_SCAN_DIRS = [
    "audit",
    "api",
]

# Extensions dont le contenu est inspecté (fichiers texte probables)
_SCAN_EXTENSIONS = {
    ".env", ".cfg", ".ini", ".conf", ".json",
    ".txt", ".log", ".sh", ".bash",
    ".pem", ".key", ".p12", ".pfx", ".crt",
}

# Dossiers systématiquement exclus du scan
_EXCLUDED_DIRS = {
    ".git", "__pycache__", "node_modules", ".venv",
    "venv", ".mypy_cache", ".pytest_cache", "dist", "build",
}

# Extensions exclues du scan de contenu (code source, binaires…)
_DEFAULT_EXCLUDED_EXTENSIONS = {
    ".py", ".pyc", ".pyo",
    ".yaml", ".yml",
    ".jpg", ".jpeg", ".png", ".gif", ".svg", ".ico",
    ".pdf", ".docx", ".xlsx", ".pptx",
    ".zip", ".gz", ".tar", ".bz2",
    ".woff", ".woff2", ".ttf", ".eot",
    ".mp4", ".mp3", ".avi",
}


def _should_skip_dir(path: Path, excluded: set) -> bool:
    return path.name in excluded


def _should_scan_file(file: Path, excluded_extensions: set) -> bool:
    suffix = file.suffix.lower()
    # Toujours inspecter les fichiers sans extension dans les dossiers cibles
    # (ex. fichier nommé "secret", ".env" sans extension déclarée)
    if suffix == "":
        return file.name.startswith(".")  # .env, .secret…
    return suffix in _SCAN_EXTENSIONS and suffix not in excluded_extensions


def run(cfg: dict) -> dict:

    started = time.time()
    root = Path(cfg.get("project_root", ".")).resolve()

    scan_dirs          = cfg.get("security_scan_dirs",        _DEFAULT_SCAN_DIRS)
    extra_excluded_ext = set(cfg.get("security_exclude_extensions", []))
    excluded_ext       = _DEFAULT_EXCLUDED_EXTENSIONS | extra_excluded_ext
    extra_excluded_dir = set(cfg.get("security_exclude_dirs",  []))
    excluded_dirs      = _EXCLUDED_DIRS | extra_excluded_dir

    seen     = set()   # (filepath, pattern) — déduplication
    findings = []

    for folder in scan_dirs:
        path = root / folder
        if not path.exists():
            continue

        for file in path.rglob("*"):
            # Ignorer les dossiers exclus (tous niveaux)
            if any(part in excluded_dirs for part in file.parts):
                continue
            if not file.is_file():
                continue
            if not _should_scan_file(file, excluded_ext):
                continue

            try:
                text = file.read_text(errors="ignore")
            except Exception:
                continue

            for pattern in SENSITIVE_PATTERNS:
                key = (str(file), pattern)
                if key in seen:
                    continue
                if pattern.lower() in text.lower():
                    seen.add(key)
                    findings.append({
                        "file":    str(file.relative_to(root)),
                        "pattern": pattern,
                    })

    status  = "WARNING" if findings else "PASS"
    elapsed = round((time.time() - started) * 1000, 2)

    return {
        "module":    MODULE,
        "status":    status,
        "elapsed_ms": elapsed,
        "scanned_dirs": scan_dirs,
        "findings":  findings,
    }


if __name__ == "__main__":
    import json
    print(json.dumps(run({"project_root": "."}), indent=2))
