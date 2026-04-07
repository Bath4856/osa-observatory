"""
============================================================
OSA / ISA OBSERVATORY
run_collect_all.py — Lanceur global de tous les fetchers
============================================================
Lance séquentiellement WB → IMF → WHO → ITU → FAO
avec rapport de couverture final par pilier.

Usage :
  # Collecte historique complète
  python run_collect_all.py --from 2010 --to 2022

  # Collecte d'une année (mise à jour annuelle)
  python run_collect_all.py --year 2023

  # Test sans écriture
  python run_collect_all.py --year 2022 --dry-run

  # Un seul provider (WB, IMF, WHO, ITU, FAO)
  python run_collect_all.py --year 2022 --provider WB

  # Rapport de couverture uniquement (sans collecte)
  python run_collect_all.py --coverage-only
============================================================
"""

from __future__ import annotations

import argparse
import logging
import os
import sys
import time
from datetime import datetime

import psycopg2
from dotenv import load_dotenv

# Import fetcher WB depuis sprint 2 (doit être dans le même répertoire ou PYTHONPATH)
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from fetcher_base import AFRICAN_ISO3, SAMPLE_ISO3
from fetcher_wb   import WBFetcher
from fetcher_imf  import IMFFetcher
from fetcher_who  import WHOFetcher
from fetcher_itu  import ITUFetcher
from fetcher_fao  import FAOFetcher
from fetcher_undp import UNDPFetcher
from fetcher_unesco import UNESCOFetcher

load_dotenv()

logging.basicConfig(
    level=os.getenv("OSA_LOG_LEVEL", "INFO"),
    format="%(asctime)s | %(levelname)-8s | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger("run_collect_all")

# Ordre de collecte : WB en tête (34 indicateurs, meilleure couverture),
# puis IMF, WHO, ITU, FAO pour compléter les piliers PMON, PHUM, PNUM, PENV.
FETCHER_CLASSES = {
    "WB":  WBFetcher,
    "IMF": IMFFetcher,
    "WHO": WHOFetcher,
    "ITU": ITUFetcher,
    "FAO": FAOFetcher,
    "UNDP": UNDPFetcher,
    "UNESCO": UNESCOFetcher,
}


# ── Rapport de couverture ──────────────────────────────────

def print_coverage_report(year: int) -> None:
    """
    Interroge la base et affiche la couverture des données
    par pilier et par provider pour l'année donnée.
    """
    try:
        conn = psycopg2.connect(
            host     = os.getenv("OSA_DB_HOST", "localhost"),
            port     = int(os.getenv("OSA_DB_PORT", "5432")),
            dbname   = os.getenv("OSA_DB_NAME", "osa_db"),
            user     = os.getenv("OSA_DB_USER", "postgres"),
            password = os.getenv("OSA_DB_PASS", ""),
        )
    except psycopg2.OperationalError as exc:
        log.error("Connexion DB impossible : %s", exc)
        return

    with conn.cursor() as cur:
        # Couverture par pilier
        cur.execute(
            """
            SELECT
                p.code                               AS pillar,
                p.name_fr                            AS pillar_name,
                COUNT(DISTINCT i.code)               AS total_indicators,
                COUNT(DISTINCT
                    CASE WHEN iv.raw_value IS NOT NULL
                    THEN i.code END)                 AS indicators_with_data,
                COUNT(DISTINCT iv.country_iso3)      AS countries_with_data,
                ROUND(
                    COUNT(DISTINCT
                        CASE WHEN iv.raw_value IS NOT NULL
                        THEN i.code END
                    ) * 100.0 /
                    NULLIF(COUNT(DISTINCT i.code), 0),
                    1
                )                                    AS indicator_coverage_pct,
                ROUND(
                    COUNT(DISTINCT iv.country_iso3) * 100.0 / 54,
                    1
                )                                    AS country_coverage_pct
            FROM rf.pillars p
            JOIN rf.indicators i ON i.pillar_code = p.code
            LEFT JOIN ma.indicator_values iv
                ON iv.indicator_code = i.code
               AND iv.year = %s
               AND iv.layer_id = 1
            GROUP BY p.code, p.name_fr, p.display_order
            ORDER BY p.display_order
            """,
            (year,),
        )
        rows = cur.fetchall()

    conn.close()

    log.info("=" * 70)
    log.info("RAPPORT DE COUVERTURE — année %d", year)
    log.info("=" * 70)
    log.info("%-6s %-30s %5s %5s %5s %7s %7s",
             "Pilier", "Nom", "Total", "Dispo", "Pays",
             "Ind.%", "Pays%")
    log.info("-" * 70)

    total_ind = total_dispo = 0
    for row in rows:
        pillar, name, total, dispo, countries, ind_pct, cty_pct = row
        total_ind   += total or 0
        total_dispo += dispo or 0
        status = "OK" if (ind_pct or 0) >= 50 else ("PARTIEL" if (ind_pct or 0) >= 20 else "MANQUE")
        log.info(
            "%-6s %-30s %5d %5d %5d %6.1f%% %6.1f%%  [%s]",
            pillar, name[:30], total, dispo or 0, countries or 0,
            ind_pct or 0, cty_pct or 0, status,
        )

    log.info("-" * 70)
    global_pct = round(total_dispo * 100.0 / max(total_ind, 1), 1)
    log.info("TOTAL  %-30s %5d %5d %24.1f%%",
             "", total_ind, total_dispo, global_pct)
    log.info("=" * 70)

    if global_pct < 50:
        log.warning("Couverture globale < 50%% — pipeline ML non recommandé")
    elif global_pct < 75:
        log.info("Couverture satisfaisante — interpolation nécessaire pour certains piliers")
    else:
        log.info("Bonne couverture — pipeline L3→L7 activable")


# ── Lanceur principal ──────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(
        description="OSA — Collecte globale tous providers",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--year",          type=int,  help="Année unique")
    parser.add_argument("--from",          type=int,  dest="year_from", default=2010)
    parser.add_argument("--to",            type=int,  dest="year_to",   default=2022)
    parser.add_argument("--dry-run",       action="store_true")
    parser.add_argument("--provider",      type=str,  default=None,
                        choices=list(FETCHER_CLASSES.keys()),
                        help="Lancer un seul provider")
    parser.add_argument("--coverage-only", action="store_true",
                        help="Afficher uniquement le rapport de couverture")
    parser.add_argument("--sample",        action="store_true",
                        help="Collecter uniquement les 10 pays representatifs")
    parser.add_argument("--probe",         action="store_true",
                        help="Sonder les bornes temporelles de chaque indicateur")
    args = parser.parse_args()

    # Sélection des pays selon le mode
    import fetcher_base as _fb
    _fb.AFRICAN_ISO3 = SAMPLE_ISO3 if args.sample else AFRICAN_ISO3
    if args.sample:
        log.info("Mode SAMPLE — 10 pays representatifs")


    year_from = args.year or args.year_from
    year_to   = args.year or args.year_to

    # Rapport uniquement
    if args.coverage_only:
        print_coverage_report(year_to)
        return

    # Mode sondage des bornes
    # Sélection des providers
    providers_to_run = (
        {args.provider: FETCHER_CLASSES[args.provider]}
        if args.provider
        else FETCHER_CLASSES
    )

    if args.probe:
        log.info("MODE PROBE — sondage des bornes temporelles")
        for provider_code, FetcherClass in providers_to_run.items():
            fetcher = FetcherClass(dry_run=False)
            try:
                fetcher.connect()
                results = fetcher.probe()
                saved = fetcher.save_bounds(results)
                log.info("%s — %d bornes sauvegardees", provider_code, saved)
            finally:
                fetcher.disconnect()
        log.info("Sondage termine — consulter collect.indicator_bounds")
        return


    log.info("=" * 60)
    log.info("OSA — COLLECTE GLOBALE")
    log.info("  Années    : %d → %d", year_from, year_to)
    log.info("  Providers : %s", ", ".join(providers_to_run.keys()))
    log.info("  Dry-run   : %s", args.dry_run)
    log.info("  Démarrage : %s", datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
    log.info("=" * 60)

    t_global = time.monotonic()
    summary: list[dict] = []

    for provider_code, FetcherClass in providers_to_run.items():
        log.info("")
        log.info("▶ Provider : %s", provider_code)
        t0 = time.monotonic()

        fetcher = FetcherClass(dry_run=args.dry_run)
        try:
            fetcher.connect()
            result = fetcher.run(year_from, year_to)
        except Exception as exc:
            log.error("Provider %s — erreur fatale : %s", provider_code, exc)
            result = {
                "provider": provider_code,
                "inserted": 0,
                "rejected": 0,
                "failed":   ["ERREUR FATALE"],
            }
        finally:
            fetcher.disconnect()

        result["duration_s"] = round(time.monotonic() - t0, 1)
        summary.append(result)

        # Pause entre providers
        time.sleep(2)

    # ── Rapport final ──────────────────────────────────────
    total_duration = round(time.monotonic() - t_global, 1)

    log.info("")
    log.info("=" * 60)
    log.info("RÉSUMÉ GLOBAL")
    log.info("=" * 60)
    log.info("%-8s %8s %8s %6s  %s",
             "Provider", "Insérés", "Rejetés", "Durée", "Échecs")
    log.info("-" * 60)

    grand_inserted = grand_rejected = 0
    all_failed: list[str] = []

    for r in summary:
        failed_str = ", ".join(r["failed"]) if r["failed"] else "-"
        log.info(
            "%-8s %8d %8d %5.1fs  %s",
            r["provider"], r["inserted"], r["rejected"],
            r["duration_s"], failed_str[:30],
        )
        grand_inserted += r["inserted"]
        grand_rejected += r["rejected"]
        all_failed.extend(r["failed"])

    log.info("-" * 60)
    log.info("%-8s %8d %8d %5.1fs", "TOTAL",
             grand_inserted, grand_rejected, total_duration)
    log.info("=" * 60)

    if not args.dry_run:
        log.info("")
        log.info("Rapport de couverture pour %d :", year_to)
        print_coverage_report(year_to)

    if not args.dry_run:
        log.info("")
        log.info("Prochaine étape : lancer le pipeline analytique")
        log.info("  CALL ma.run_pipeline_historical(2010, %d);", year_to)

    sys.exit(0 if not all_failed else 1)


if __name__ == "__main__":
    main()
