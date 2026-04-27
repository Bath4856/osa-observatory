"""
collectors/archive_collectors.py
═══════════════════════════════════════════════════════════════════════════
Script d'archivage des fichiers obsolètes du dossier collectors/

Étapes :
  1. Vérifie que les patches wb_indicator_map sont intégrés dans wb_indicator_map.py
  2. Déplace les fichiers obsolètes dans collectors/archive/
  3. Supprime collector_v2/ (remplacé par le projet existant)
  4. Génère un rapport d'archivage horodaté

Usage :
  python collectors/archive_collectors.py --dry-run   ← simulation sans rien toucher
  python collectors/archive_collectors.py             ← exécution réelle
  python collectors/archive_collectors.py --force     ← sans confirmation interactive

IMPORTANT : lancez toujours --dry-run d'abord.
═══════════════════════════════════════════════════════════════════════════
"""

from __future__ import annotations

import argparse
import logging
import os
import shutil
import sys
from datetime import datetime
from pathlib import Path

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("archive")

# ── Racine du projet (à adapter si nécessaire) ────────────────────────────────
PROJECT_ROOT   = Path(__file__).resolve().parent
COLLECTORS_DIR = PROJECT_ROOT / "collectors"
ARCHIVE_DIR    = COLLECTORS_DIR / "archive"
COLLECTOR_V2   = PROJECT_ROOT / "collector_v2"   # dossier généré par la session Claude

# ── Fichiers à archiver avec leur raison ─────────────────────────────────────
#
# Format : (nom_fichier, raison)
#
# Règle d'archivage :
#   PATCH   → intégrable dans wb_indicator_map.py / imputer_v3.py (vérification auto)
#   ANCIEN  → remplacé par une version plus récente du même fetcher
#   INUTILE → doublons ou scripts de session Claude non intégrés
#
FILES_TO_ARCHIVE: list[tuple[str, str]] = [

    # ── Patches wb_indicator_map (à intégrer d'abord, voir merge_patches.py) ──
    ("wb_indicator_map_patch_wgi.py",        "PATCH — intégrer dans wb_indicator_map.py puis archiver"),
    ("wb_indicator_map_pmil_patch.py",       "PATCH — intégrer dans wb_indicator_map.py puis archiver"),
    ("wb_indicator_map_pnum_patch.py",       "PATCH — intégrer dans wb_indicator_map.py puis archiver"),
    ("wb_indicator_map_pres_patch.py",       "PATCH — intégrer dans wb_indicator_map.py puis archiver"),
    ("wb_indicator_map_ptra_patch.py",       "PATCH — remplacé par ptra_final_patch"),
    ("wb_indicator_map_ptra_final_patch.py", "PATCH — intégrer dans wb_indicator_map.py puis archiver"),

    # ── Patches imputer ────────────────────────────────────────────────────────
    ("imputer_ptra_patch.py",                "PATCH — intégrer dans imputer_v3.py puis archiver"),
    ("imputer_sprint6_patch.py",             "PATCH — intégrer dans imputer_v3.py puis archiver"),

    # ── Fetchers remplacés par une version plus récente ────────────────────────
    ("fetcher_imf_weo_csv.py",               "ANCIEN — remplacé par fetcher_imf_weo_v2.py (Sprint 7)"),
    ("fetcher_fao.py",                       "ANCIEN — remplacé par fetcher_fao_csv.py (CSV bulk, plus fiable)"),
    ("fetcher_undp.py",                      "ANCIEN — remplacé par fetcher_undp_csv.py"),

    # ── imputer.py : version ambiguë (vérification manuelle requise) ──────────
    # NE PAS archiver automatiquement — voir note ci-dessous
    # ("imputer.py", "VÉRIFIER — 845 lignes vs imputer_v3.py 835 lignes, diff manuel requis"),
]

# ── Fichiers collector_v2 à supprimer (remplacés par collectors/ existant) ────
COLLECTOR_V2_TO_DELETE = True   # supprimer tout collector_v2/

# ── Fichiers collector_v2 à récupérer avant suppression ───────────────────────
# Ces deux fichiers ont une valeur ajoutée absente du projet existant.
COLLECTOR_V2_TO_KEEP: list[tuple[str, str]] = [
    (
        "sources/auto/pgeo.py",
        "collectors/fetcher_pgeo_wikipedia.py",   # destination dans collectors/
    ),
    (
        "indicators/pmin.py",
        "collectors/compute_pmin_spatial.py",     # destination dans collectors/
    ),
]


# ═══════════════════════════════════════════════════════════════════════════════

def check_patches_integrated() -> list[str]:
    """
    Vérifie si les codes OSA des patches sont déjà dans wb_indicator_map.py.
    Retourne la liste des patches NON encore intégrés.
    """
    wb_map_path = COLLECTORS_DIR / "wb_indicator_map.py"
    if not wb_map_path.exists():
        log.warning("wb_indicator_map.py introuvable — vérification patches ignorée.")
        return []

    wb_content = wb_map_path.read_text(encoding="utf-8", errors="ignore")

    patch_codes = {
        "wb_indicator_map_pmil_patch.py":       ["PMIL_DEF_BUDGET_GDP", "PMIL_ARMED_FORCES"],
        "wb_indicator_map_pnum_patch.py":       ["PNUM_INTERNET_USERS", "PNUM_BROADBAND_FIXED"],
        "wb_indicator_map_ptra_final_patch.py": ["PTRA_RD_DENSITY", "PTRA_AIR_PASSENGERS"],
        "wb_indicator_map_pres_patch.py":       ["PRES_ENRG_USE_CAP", "PRES_RENEW_CAP_IRENA"],
        "wb_indicator_map_patch_wgi.py":        [],   # patch WGI — vérification manuelle
    }

    not_integrated = []
    for patch_file, codes in patch_codes.items():
        missing = [c for c in codes if c not in wb_content]
        if missing:
            not_integrated.append(patch_file)
            log.warning(
                f"  PATCH NON INTÉGRÉ : {patch_file}\n"
                f"    Codes manquants dans wb_indicator_map.py : {missing}\n"
                f"    → Exécutez merge_patches.py d'abord."
            )
    return not_integrated


def archive_file(src: Path, reason: str, dry_run: bool) -> bool:
    """Déplace un fichier vers archive/ avec horodatage."""
    if not src.exists():
        log.warning(f"  Introuvable (déjà archivé ?) : {src.name}")
        return False

    ts   = datetime.now().strftime("%Y%m%d")
    stem = src.stem
    ext  = src.suffix
    dst  = ARCHIVE_DIR / f"{stem}_{ts}{ext}"

    # Éviter les collisions
    counter = 1
    while dst.exists():
        dst = ARCHIVE_DIR / f"{stem}_{ts}_{counter}{ext}"
        counter += 1

    if dry_run:
        log.info(f"  [DRY] {src.name} → archive/{dst.name}  ({reason})")
        return True

    ARCHIVE_DIR.mkdir(exist_ok=True)
    shutil.move(str(src), str(dst))
    log.info(f"  ARCHIVÉ : {src.name} → archive/{dst.name}")
    return True


def recover_v2_file(rel_src: str, rel_dst: str, dry_run: bool) -> bool:
    """Copie un fichier utile de collector_v2 vers collectors/ avant suppression."""
    src = COLLECTOR_V2 / rel_src
    dst = COLLECTORS_DIR / rel_dst

    if not src.exists():
        log.warning(f"  collector_v2/{rel_src} introuvable — récupération ignorée.")
        return False

    if dry_run:
        log.info(f"  [DRY] RÉCUPÈRE collector_v2/{rel_src} → collectors/{rel_dst}")
        return True

    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(str(src), str(dst))
    log.info(f"  RÉCUPÉRÉ : collector_v2/{rel_src} → collectors/{rel_dst}")
    return True


def delete_collector_v2(dry_run: bool) -> None:
    """Supprime le dossier collector_v2/ entier."""
    if not COLLECTOR_V2.exists():
        log.info(f"  collector_v2/ absent — rien à supprimer.")
        return

    if dry_run:
        n = sum(1 for _ in COLLECTOR_V2.rglob("*") if _.is_file())
        log.info(f"  [DRY] SUPPRIMERAIT collector_v2/ ({n} fichiers)")
        return

    shutil.rmtree(str(COLLECTOR_V2))
    log.info(f"  SUPPRIMÉ : collector_v2/")


def write_report(archived: list, recovered: list, dry_run: bool) -> None:
    """Génère un rapport Markdown horodaté."""
    ts       = datetime.now().strftime("%Y-%m-%d %H:%M")
    filename = f"ARCHIVE_REPORT_{datetime.now().strftime('%Y%m%d_%H%M')}.md"
    path     = ARCHIVE_DIR / filename

    lines = [
        f"# Rapport d'archivage OSA collectors",
        f"**Date** : {ts}  ",
        f"**Mode** : {'DRY-RUN (simulation)' if dry_run else 'RÉEL'}  ",
        f"",
        f"## Fichiers archivés ({len(archived)})",
        "",
    ]
    for name, reason in archived:
        lines.append(f"- `{name}` — {reason}")

    lines += [
        "",
        f"## Fichiers récupérés de collector_v2 ({len(recovered)})",
        "",
    ]
    for src, dst in recovered:
        lines.append(f"- `collector_v2/{src}` → `collectors/{dst}`")

    lines += [
        "",
        "## Actions manuelles restantes",
        "",
        "1. Vérifier `imputer.py` vs `imputer_v3.py` (diff manuel) et archiver le plus ancien",
        "2. Exécuter `merge_patches.py` pour intégrer les patches dans `wb_indicator_map.py`",
        "3. Vérifier que `fetcher_wb_pres_pmil_pnum.py` importe bien depuis `wb_indicator_map.py`",
        "4. Tester la collecte après archivage : `python collectors/run_pipeline_sprint7.py --probe`",
        "",
        "## collector_v2",
        "- Dossier `collector_v2/` supprimé",
        "- Fichiers utiles récupérés dans `collectors/`",
    ]

    content = "\n".join(lines)

    if not dry_run:
        ARCHIVE_DIR.mkdir(exist_ok=True)
        path.write_text(content, encoding="utf-8")
        log.info(f"  Rapport : archive/{filename}")
    else:
        log.info(f"  [DRY] Rapport non écrit (dry-run)")


def confirm(msg: str) -> bool:
    """Demande confirmation interactive."""
    resp = input(f"\n{msg} [o/N] : ").strip().lower()
    return resp in ("o", "oui", "y", "yes")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Archive les fichiers obsolètes de collectors/"
    )
    parser.add_argument("--dry-run", action="store_true",
                        help="Simulation : affiche les actions sans les exécuter")
    parser.add_argument("--force", action="store_true",
                        help="Sans confirmation interactive")
    args = parser.parse_args()

    dry_run = args.dry_run
    force   = args.force

    log.info("=" * 60)
    log.info("  OSA — Archivage collectors/")
    log.info(f"  Mode : {'DRY-RUN' if dry_run else 'RÉEL'}")
    log.info("=" * 60)

    # ── Étape 1 : vérifier les patches ────────────────────────────────────────
    log.info("\n[1/4] Vérification des patches wb_indicator_map...")
    not_integrated = check_patches_integrated()

    if not_integrated and not dry_run:
        log.warning(
            f"\n  {len(not_integrated)} patch(es) NON intégré(s) dans wb_indicator_map.py.\n"
            f"  Exécutez d'abord : python collectors/merge_patches.py\n"
            f"  Puis relancez ce script.\n"
        )
        if not force and not confirm("Archiver quand même les patches (NON RECOMMANDÉ) ?"):
            log.info("  Annulé. Exécutez merge_patches.py d'abord.")
            sys.exit(0)

    # ── Étape 2 : récupérer les fichiers utiles de collector_v2 ───────────────
    log.info("\n[2/4] Récupération des fichiers utiles depuis collector_v2/...")
    recovered = []
    for rel_src, rel_dst in COLLECTOR_V2_TO_KEEP:
        if recover_v2_file(rel_src, rel_dst, dry_run):
            recovered.append((rel_src, rel_dst))

    # ── Étape 3 : archiver les fichiers obsolètes ─────────────────────────────
    log.info(f"\n[3/4] Archivage de {len(FILES_TO_ARCHIVE)} fichier(s)...")

    if not dry_run and not force:
        log.info("\n  Fichiers qui seront archivés :")
        for name, reason in FILES_TO_ARCHIVE:
            log.info(f"    {name}")
        if not confirm("Confirmer l'archivage ?"):
            log.info("  Annulé.")
            sys.exit(0)

    archived = []
    for name, reason in FILES_TO_ARCHIVE:
        src = COLLECTORS_DIR / name
        if archive_file(src, reason, dry_run):
            archived.append((name, reason))

    # ── Étape 4 : supprimer collector_v2/ ────────────────────────────────────
    if COLLECTOR_V2_TO_DELETE:
        log.info("\n[4/4] Suppression de collector_v2/...")
        if not dry_run and not force:
            if not confirm("Supprimer collector_v2/ entier ?"):
                log.info("  collector_v2/ conservé.")
            else:
                delete_collector_v2(dry_run)
        else:
            delete_collector_v2(dry_run)

    # ── Rapport ───────────────────────────────────────────────────────────────
    write_report(archived, recovered, dry_run)

    log.info("\n" + "=" * 60)
    log.info(f"  Archivé   : {len(archived)} fichier(s)")
    log.info(f"  Récupéré  : {len(recovered)} fichier(s)")
    if dry_run:
        log.info("  ⚠  DRY-RUN — aucune modification effectuée")
        log.info("  Relancez sans --dry-run pour appliquer.")
    log.info("=" * 60)


if __name__ == "__main__":
    main()
