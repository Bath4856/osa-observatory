"""
collectors/merge_patches.py
═══════════════════════════════════════════════════════════════════════════
Fusionne tous les patches wb_indicator_map_*_patch.py dans wb_indicator_map.py
et les patches imputer_*_patch.py dans imputer_v3.py.

À exécuter AVANT archive_collectors.py.

Usage :
  python collectors/merge_patches.py --dry-run   ← montre ce qui sera ajouté
  python collectors/merge_patches.py             ← fusion réelle
═══════════════════════════════════════════════════════════════════════════
"""

from __future__ import annotations

import argparse
import logging
import re
import shutil
from datetime import datetime
from pathlib import Path

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("merge_patches")

PROJECT_ROOT   = Path(__file__).resolve().parent
COLLECTORS_DIR = PROJECT_ROOT / "collectors"
ARCHIVE_DIR    = COLLECTORS_DIR / "archive"


# ── Définition des fusions à effectuer ───────────────────────────────────────
#
# Chaque entrée décrit :
#   target      : fichier cible à enrichir
#   patches     : patches à fusionner (dans l'ordre)
#   marker      : chaîne repère après laquelle insérer le nouveau contenu
#   extract_fn  : fonction qui extrait le dict/bloc à insérer depuis le patch

MERGE_PLAN = [
    {
        "target":  "wb_indicator_map.py",
        "patches": [
            "wb_indicator_map_pmil_patch.py",
            "wb_indicator_map_pnum_patch.py",
            "wb_indicator_map_pres_patch.py",
            "wb_indicator_map_ptra_final_patch.py",
            "wb_indicator_map_patch_wgi.py",
        ],
        "description": "Ajout des indicateurs PMIL, PNUM, PTRA, PRES, WGI dans WB_INDICATOR_MAP",
    },
    {
        "target":  "imputer_v3.py",
        "patches": [
            "imputer_ptra_patch.py",
            "imputer_sprint6_patch.py",
        ],
        "description": "Intégration des corrections PTRA et Sprint 6 dans imputer_v3.py",
    },
]


def backup(path: Path) -> Path:
    """Crée une sauvegarde horodatée avant toute modification."""
    ts  = datetime.now().strftime("%Y%m%d_%H%M%S")
    bak = path.with_suffix(f".bak_{ts}{path.suffix}")
    shutil.copy2(str(path), str(bak))
    log.info(f"  Sauvegarde : {bak.name}")
    return bak


def extract_indicator_blocks(patch_content: str) -> list[str]:
    """
    Extrait les blocs d'indicateurs d'un fichier patch.
    Recherche les patterns :
      "CODE_OSA": { ... },
    et les retourne comme liste de chaînes prêtes à insérer.
    """
    # Chercher les dictionnaires d'indicateurs dans INDICATOR_MAP ou équivalent
    blocks = []

    # Pattern 1 : clé de type "PXXX_..." suivie d'un dict multiligne
    pattern = re.compile(
        r'("P[A-Z]{3,4}_[A-Z_0-9]+")\s*:\s*\{[^}]*?\}',
        re.DOTALL,
    )
    for m in pattern.finditer(patch_content):
        block = m.group(0).strip()
        if block not in blocks:
            blocks.append(block)

    return blocks


def extract_new_codes(patch_path: Path, target_content: str) -> list[str]:
    """
    Retourne les blocs d'indicateurs du patch qui ne sont pas encore dans target.
    """
    patch_content = patch_path.read_text(encoding="utf-8", errors="ignore")
    blocks        = extract_indicator_blocks(patch_content)
    new_blocks    = []

    for block in blocks:
        # Extraire le code OSA du bloc
        code_match = re.search(r'"(P[A-Z]{3,4}_[A-Z_0-9]+)"', block)
        if code_match:
            code = code_match.group(1)
            if code not in target_content:
                new_blocks.append((code, block))
            else:
                log.info(f"    Déjà présent : {code}")
        else:
            new_blocks.append(("?", block))

    return new_blocks


def find_insertion_point(target_content: str) -> int:
    """
    Trouve la position d'insertion dans wb_indicator_map.py :
    juste avant la dernière accolade fermante du dict WB_INDICATOR_MAP.
    """
    # Chercher la fin du dictionnaire principal
    # Pattern : dernière "}" avant fin de fichier ou avant "# ──"
    marker_patterns = [
        r'WB_INDICATOR_MAP\s*=\s*\{',
        r'INDICATOR_MAP\s*=\s*\{',
    ]

    for pattern in marker_patterns:
        m = re.search(pattern, target_content)
        if m:
            # Trouver la } fermante correspondante
            start = m.end()
            depth = 1
            pos   = start
            while pos < len(target_content) and depth > 0:
                c = target_content[pos]
                if c == '{':
                    depth += 1
                elif c == '}':
                    depth -= 1
                pos += 1
            # Insérer avant la } finale
            return pos - 1

    # Fallback : fin de fichier
    return len(target_content)


def merge_wb_patches(target_path: Path, patch_paths: list[Path],
                     dry_run: bool) -> int:
    """
    Fusionne les patches wb_indicator_map dans le fichier cible.
    Retourne le nombre de nouveaux indicateurs ajoutés.
    """
    target_content = target_path.read_text(encoding="utf-8", errors="ignore")
    total_added    = 0
    new_blocks_all = []

    for patch_path in patch_paths:
        if not patch_path.exists():
            log.warning(f"    Patch introuvable : {patch_path.name}")
            continue

        log.info(f"  Analyse : {patch_path.name}")
        new_blocks = extract_new_codes(patch_path, target_content)

        if not new_blocks:
            log.info(f"    → Tout déjà intégré.")
            continue

        for code, block in new_blocks:
            log.info(f"    + {code}")
            new_blocks_all.append((code, block))
            total_added += 1

    if not new_blocks_all:
        log.info(f"  Aucun nouvel indicateur à ajouter dans {target_path.name}")
        return 0

    if dry_run:
        log.info(f"  [DRY] Ajouterait {total_added} indicateur(s) dans {target_path.name}")
        return total_added

    # Backup
    backup(target_path)

    # Construire le bloc à insérer
    insertion = "\n\n    # ── Indicateurs ajoutés par merge_patches.py ──────────────\n"
    for code, block in new_blocks_all:
        insertion += f"    {block},\n"

    # Trouver le point d'insertion
    insert_pos = find_insertion_point(target_content)
    new_content = (
        target_content[:insert_pos]
        + insertion
        + target_content[insert_pos:]
    )

    target_path.write_text(new_content, encoding="utf-8")
    log.info(f"  ✅ {total_added} indicateur(s) ajouté(s) dans {target_path.name}")
    return total_added


def merge_imputer_patches(target_path: Path, patch_paths: list[Path],
                          dry_run: bool) -> int:
    """
    Pour les patches imputer, on signale les blocs à vérifier manuellement
    (les corrections d'imputation sont trop spécifiques pour être auto-mergées).
    """
    log.info(f"\n  Patches imputer — vérification manuelle requise :")
    total = 0
    for patch_path in patch_paths:
        if not patch_path.exists():
            log.warning(f"    Introuvable : {patch_path.name}")
            continue

        content = patch_path.read_text(encoding="utf-8", errors="ignore")
        # Chercher les fonctions définies dans le patch
        funcs = re.findall(r'^def (\w+)', content, re.MULTILINE)
        classes = re.findall(r'^class (\w+)', content, re.MULTILINE)

        log.info(f"  {patch_path.name} :")
        if funcs:
            log.info(f"    Fonctions : {', '.join(funcs)}")
        if classes:
            log.info(f"    Classes   : {', '.join(classes)}")
        log.info(f"    → Vérifiez si ces éléments sont dans {target_path.name}")
        log.info(f"    → Si non : copiez-collez manuellement avant d'archiver")
        total += 1
    return total


def check_imputer_duplicate(dry_run: bool) -> None:
    """
    Compare imputer.py et imputer_v3.py pour identifier lequel est plus récent.
    """
    p1 = COLLECTORS_DIR / "imputer.py"
    p2 = COLLECTORS_DIR / "imputer_v3.py"

    if not p1.exists() or not p2.exists():
        return

    lines1 = p1.read_text(encoding="utf-8", errors="ignore").splitlines()
    lines2 = p2.read_text(encoding="utf-8", errors="ignore").splitlines()

    log.info(f"\n  imputer.py    : {len(lines1)} lignes")
    log.info(f"  imputer_v3.py : {len(lines2)} lignes")

    if len(lines1) > len(lines2):
        log.warning(
            f"\n  ⚠  imputer.py ({len(lines1)} lignes) > imputer_v3.py ({len(lines2)} lignes)\n"
            f"     imputer.py semble plus récent.\n"
            f"     ACTION : diff manuel recommandé.\n"
            f"     Si imputer.py est bien la version finale :\n"
            f"       cp collectors/imputer.py collectors/imputer_v3.py\n"
            f"       puis archiver l'ancien imputer_v3.py"
        )
    elif len(lines1) == len(lines2):
        log.info("  Tailles identiques — vérifiez le contenu.")
    else:
        log.info(
            f"  imputer_v3.py semble plus récent ({len(lines2)} lignes).\n"
            f"  imputer.py peut être archivé après vérification."
        )


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Fusionne les patches dans leurs fichiers cibles"
    )
    parser.add_argument("--dry-run", action="store_true",
                        help="Simulation : affiche sans modifier")
    args = parser.parse_args()
    dry_run = args.dry_run

    log.info("=" * 60)
    log.info("  OSA — Fusion des patches collectors/")
    log.info(f"  Mode : {'DRY-RUN' if dry_run else 'RÉEL'}")
    log.info("=" * 60)

    total_added = 0

    for plan in MERGE_PLAN:
        target_path  = COLLECTORS_DIR / plan["target"]
        patch_paths  = [COLLECTORS_DIR / p for p in plan["patches"]]

        log.info(f"\n── {plan['description']}")
        log.info(f"   Cible : {plan['target']}")

        if not target_path.exists():
            log.error(f"   Fichier cible introuvable : {target_path}")
            continue

        if "wb_indicator_map" in plan["target"]:
            n = merge_wb_patches(target_path, patch_paths, dry_run)
        else:
            n = merge_imputer_patches(target_path, patch_paths, dry_run)

        total_added += n

    # Vérification doublon imputer
    log.info("\n── Vérification imputer.py vs imputer_v3.py")
    check_imputer_duplicate(dry_run)

    log.info("\n" + "=" * 60)
    if dry_run:
        log.info(f"  DRY-RUN terminé — {total_added} indicateur(s) à ajouter")
        log.info("  Relancez sans --dry-run pour appliquer.")
    else:
        log.info(f"  Fusion terminée — {total_added} indicateur(s) ajouté(s)")
        log.info("  Étape suivante : python collectors/archive_collectors.py")
    log.info("=" * 60)


if __name__ == "__main__":
    main()
