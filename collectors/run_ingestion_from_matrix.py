"""
============================================================
OSA / ISA OBSERVATORY
run_ingestion_from_matrix.py — Orchestration par matrice GO/PILOT/NO_GO
============================================================
Corrections v2 :
  #1  FETCHER_REGISTRY remplace l'import depuis run_collect_all
  #2  supported_ids construit dynamiquement
  #3  preview_fallback correctement raccordé
  #4  --print-plan stoppe sans nécessiter --dry-run
"""

from __future__ import annotations

import argparse
import glob
import importlib
import inspect
import logging
import os
import shutil
import sys
import time
from typing import Optional

import psycopg2
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(
    level=os.getenv("OSA_LOG_LEVEL", "INFO"),
    format="%(asctime)s | %(levelname)-8s | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger("run_ingestion_from_matrix")

COLLECTORS_DIR = os.path.dirname(os.path.abspath(__file__))
if COLLECTORS_DIR not in sys.path:
    sys.path.insert(0, COLLECTORS_DIR)

FETCHER_REGISTRY: dict[str, str] = {
    "WB":       "fetcher_wb",
    "WHO":      "fetcher_who",
    "ITU":      "fetcher_itu",
    "UNESCO":   "fetcher_unesco",
    "IMF":      "fetcher_imf_weo_csv",
    "IMF_WEO":  "fetcher_imf_weo_csv",
    "IMF_DOTS": "fetcher_imf_dots_csv",
    "IMF_BOP":  "fetcher_imf_bop_csv",
    "FAO":      "fetcher_fao_csv",
    "UNDP":     "fetcher_undp_csv",
    "EITI":     "fetcher_eiti_csv",
    "SIPRI":    "fetcher_sipri_csv",
    "USGS":     "fetcher_usgs_csv",
    "ACLED":    "fetcher_acled_api",
    "UNCTAD":   "fetcher_unctad_csv",    # ECO_FDI — CSV bulk sans clé
    "COMTRADE": "fetcher_comtrade_api",  # ECO_EXP — API publique PILOT
    "UNPK":     "fetcher_unpk_csv",      # MIL_MIS + GEO_PEA — IPI CSV PILOT
}


def _load_fetcher_class(module_name: str):
    from fetcher_base import BaseFetcher
    mod = importlib.import_module(module_name)
    for _, obj in inspect.getmembers(mod, inspect.isclass):
        if issubclass(obj, BaseFetcher) and obj is not BaseFetcher:
            return obj
    raise ImportError(f"Aucune sous-classe de BaseFetcher dans {module_name}.py")


def connect_db():
    return psycopg2.connect(
        host=os.getenv("OSA_DB_HOST", "localhost"),
        port=int(os.getenv("OSA_DB_PORT", "5432")),
        dbname=os.getenv("OSA_DB_NAME", "osa_db"),
        user=os.getenv("OSA_DB_USER", "postgres"),
        password=os.getenv("OSA_DB_PASS", ""),
        connect_timeout=10,
    )


def build_execution_plan(
    conn,
    year_from: int,
    year_to: int,
    include_pilot: bool,
    requested_by: str,
) -> list[dict]:
    supported_ids = list(FETCHER_REGISTRY.keys())
    log.info("Providers supportés : %s", ", ".join(sorted(supported_ids)))

    with conn.cursor() as cur:
        try:
            cur.execute(
                """
                SELECT *
                FROM collect.run_ingestion_from_matrix(%s, %s, %s, %s, %s)
                """,
                (year_from, year_to, include_pilot, requested_by, supported_ids),
            )
        except psycopg2.errors.UndefinedFunction:
            conn.rollback()
            log.warning("Fonction SQL sans paramètre supported_ids — filtrage Python activé")
            cur.execute(
                """
                SELECT *
                FROM collect.run_ingestion_from_matrix(%s, %s, %s, %s)
                """,
                (year_from, year_to, include_pilot, requested_by),
            )
        rows = cur.fetchall()

    plan = []
    for row in rows:
        run_id, source_id, status, priority, supported, decision, reason = row
        python_supported = source_id in FETCHER_REGISTRY
        plan.append({
            "run_id":    run_id,
            "source_id": source_id,
            "status":    status,
            "priority":  priority,
            "supported": python_supported,
            "decision":  decision if python_supported else "UNSUPPORTED",
            "reason":    reason,
        })
    return plan


def execute_plan(
    plan: list[dict],
    year_from: int,
    year_to: int,
    dry_run: bool,
) -> dict[str, list]:
    executable = [
        p for p in plan
        if p["decision"] == "EXECUTE" and p["supported"]
    ]
    summary: dict[str, list] = {"ok": [], "failed": [], "skipped": []}

    if not executable:
        log.warning("Aucun provider exécutable dans le plan matrice.")
        return summary

    skipped = [p["source_id"] for p in plan if p["decision"] != "EXECUTE"]
    if skipped:
        log.info("Ignorés : %s", ", ".join(skipped))
        summary["skipped"] = skipped

    for step in executable:
        source_id = step["source_id"]
        module_name = FETCHER_REGISTRY[source_id]
        t0 = time.monotonic()

        log.info(
            "Provider %-12s | status=%-6s | priority=%-3s | reason=%s",
            source_id, step["status"], step["priority"], step["reason"],
        )

        try:
            FetcherClass = _load_fetcher_class(module_name)
        except ImportError as exc:
            log.error("Import échoué %s : %s", source_id, exc)
            summary["failed"].append(source_id)
            continue

        fetcher = FetcherClass(dry_run=dry_run)
        try:
            fetcher.connect()
            result = fetcher.run(year_from, year_to)
            duration = round(time.monotonic() - t0, 1)
            failed_ind = result.get("failed", [])
            log.info(
                "Done %-12s | +%d -%d | echecs=%d | %.1fs",
                source_id,
                result.get("inserted", 0),
                result.get("rejected", 0),
                len(failed_ind),
                duration,
            )
            if failed_ind:
                summary["failed"].append(source_id)
            else:
                summary["ok"].append(source_id)
        except Exception as exc:
            log.error("Erreur fatale %s : %s", source_id, exc)
            summary["failed"].append(source_id)
        finally:
            fetcher.disconnect()

    return summary


def preview_fallback(
    conn,
    indicator_code: str,
    year: int,
    include_pilot: bool,
    limit: int = 20,
) -> None:
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT
                country_iso3,
                selected_source_code,
                resolved_value,
                used_fallback,
                candidate_sources,
                fallback_chain
            FROM collect.resolve_indicator_fallback_set(%s, %s, %s, 1)
            WHERE resolved_value IS NOT NULL
            ORDER BY country_iso3
            LIMIT %s
            """,
            (indicator_code, year, include_pilot, limit),
        )
        rows = cur.fetchall()

    if not rows:
        log.warning(
            "Aucune valeur résolue pour %s / %d — vérifier que les données sont chargées.",
            indicator_code, year,
        )
        return

    log.info("=== Fallback preview | indicateur=%s | année=%d | %d pays ===",
             indicator_code, year, len(rows))
    fallback_used = sum(1 for r in rows if r[3])
    log.info("  Fallback utilisé : %d / %d pays", fallback_used, len(rows))
    log.info("  %-6s  %-12s  %12s  %8s  %s",
             "Pays", "Source", "Valeur", "Fallback", "Chaîne")
    log.info("  " + "-" * 64)
    for iso3, source, value, used_fb, candidates, chain in rows:
        log.info("  %-6s  %-12s  %12.4f  %8s  %s",
                 iso3, source or "?",
                 float(value) if value is not None else 0.0,
                 "oui" if used_fb else "-",
                 (chain or "")[:40])


def print_coverage_report(year: int) -> None:
    try:
        from run_collect_all import print_coverage_report as _report
        _report(year)
    except ImportError:
        log.warning("run_collect_all introuvable — rapport de couverture ignoré")



# Fichiers CSV à conserver même après nettoyage (données non re-téléchargeables)
CSV_KEEP = {
    "data/unpk/Country_Level_data.csv",  # IPI 1990-2018 — série arrêtée
}

# Dossiers CSV temporaires à nettoyer après collecte réussie
CSV_CLEANUP_DIRS = [
    "data/imf",
    "data/fao",
    "data/undp",
    "data/unctad",
    "data/sipri",
    "data/eiti",
    "data/usgs",
]


def cleanup_csv_files(project_dir: str, dry_run: bool = False) -> None:
    """
    Supprime les fichiers CSV temporaires après une collecte réussie.
    Les données sont déjà en base — les CSV ne sont plus nécessaires.
    Conserve les fichiers listés dans CSV_KEEP (séries arrêtées).
    """
    deleted = 0
    kept    = 0
    total   = 0

    for data_dir in CSV_CLEANUP_DIRS:
        full_dir = os.path.join(project_dir, data_dir)
        if not os.path.exists(full_dir):
            continue

        for filepath in glob.glob(os.path.join(full_dir, "*.csv")) +                         glob.glob(os.path.join(full_dir, "*.xlsx")) +                         glob.glob(os.path.join(full_dir, "*.xls")):

            total += 1
            rel_path = os.path.relpath(filepath, project_dir)

            if rel_path in CSV_KEEP:
                log.info("  CONSERVÉ  %s (série arrêtée)", rel_path)
                kept += 1
                continue

            if dry_run:
                log.info("  [DRY-RUN] Supprimerait : %s (%.1f Mo)",
                         rel_path, os.path.getsize(filepath) / 1_048_576)
            else:
                size_mb = os.path.getsize(filepath) / 1_048_576
                os.remove(filepath)
                log.info("  SUPPRIMÉ  %s (%.1f Mo libérés)", rel_path, size_mb)
            deleted += 1

    log.info("Nettoyage CSV — %d supprimés, %d conservés, %d total",
             deleted, kept, total)

def main() -> None:
    parser = argparse.ArgumentParser(description="OSA — Ingestion pilotée par matrice")
    parser.add_argument("--from",             dest="year_from",   type=int, default=2010)
    parser.add_argument("--to",               dest="year_to",     type=int, default=2024)
    parser.add_argument("--include-pilot",    action="store_true")
    parser.add_argument("--requested-by",     type=str,           default="OPS")
    parser.add_argument("--dry-run",          action="store_true")
    parser.add_argument("--print-plan",       action="store_true",
                        help="Afficher le plan d'exécution sans lancer les fetchers")
    parser.add_argument("--coverage-report",  action="store_true")
    parser.add_argument("--fallback-indicator", type=str, default=None)
    parser.add_argument("--fallback-year",    type=int, default=None)
    parser.add_argument(
        "--cleanup",
        action="store_true",
        help="Supprimer les CSV après collecte réussie (libère de la place)",
    )
    args = parser.parse_args()

    if args.fallback_indicator:
        conn = connect_db()
        try:
            preview_fallback(
                conn=conn,
                indicator_code=args.fallback_indicator,
                year=args.fallback_year or args.year_to,
                include_pilot=args.include_pilot,
            )
        finally:
            conn.close()
        return

    conn = connect_db()
    try:
        plan = build_execution_plan(
            conn=conn,
            year_from=args.year_from,
            year_to=args.year_to,
            include_pilot=args.include_pilot,
            requested_by=args.requested_by,
        )
    finally:
        conn.close()

    if args.print_plan:
        log.info("=== Plan d'exécution ===")
        for step in sorted(plan, key=lambda p: p["priority"]):
            log.info(
                "  run=%-4s  source=%-12s  status=%-6s  "
                "priority=%-3s  supported=%-5s  decision=%-12s  %s",
                step["run_id"], step["source_id"], step["status"],
                step["priority"], step["supported"],
                step["decision"], step["reason"],
            )
        return   # stoppe toujours après affichage du plan

    summary = execute_plan(
        plan=plan,
        year_from=args.year_from,
        year_to=args.year_to,
        dry_run=args.dry_run,
    )

    log.info("=== Résumé ===")
    log.info("  OK      : %s", ", ".join(summary["ok"])      or "—")
    log.info("  ECHECS  : %s", ", ".join(summary["failed"])  or "aucun")
    log.info("  IGNORÉS : %s", ", ".join(summary["skipped"]) or "aucun")

    if args.coverage_report and not args.dry_run:
        print_coverage_report(args.year_to)

    if args.cleanup and not args.dry_run:
        project_dir = os.path.dirname(COLLECTORS_DIR)
        log.info("Nettoyage des fichiers CSV temporaires...")
        cleanup_csv_files(project_dir, dry_run=False)
    elif args.cleanup and args.dry_run:
        project_dir = os.path.dirname(COLLECTORS_DIR)
        log.info("[DRY-RUN] Simulation nettoyage CSV :")
        cleanup_csv_files(project_dir, dry_run=True)


if __name__ == "__main__":
    main()
