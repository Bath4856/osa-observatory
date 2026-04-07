"""
============================================================
OSA / ISA OBSERVATORY
fetcher_wb.py — Fetcher World Bank (WDI)
============================================================
Rôle   : appelle l'API World Bank, insère dans collect.raw_data
         et ma.indicator_values (layer_id=1), journalise dans
         collect.ingestion_registry

Usage  :
  # Collecte historique complète (2010 → 2022)
  python fetcher_wb.py --from 2010 --to 2022

  # Collecte d'une seule année
  python fetcher_wb.py --year 2023

  # Test sans écriture en base
  python fetcher_wb.py --year 2022 --dry-run

  # Un seul indicateur (debug)
  python fetcher_wb.py --year 2022 --indicator ECO_GDP

Variables d'environnement requises (fichier .env ou système) :
  OSA_DB_HOST, OSA_DB_PORT, OSA_DB_NAME, OSA_DB_USER, OSA_DB_PASS

Refactoring Sprint 3 : hérite désormais de BaseFetcher —
  connexion, insertion, journalisation et retry HTTP centralisés.
============================================================
"""

from __future__ import annotations

import argparse
import logging
import os
import sys
from datetime import datetime
from typing import Optional

from dotenv import load_dotenv

import fetcher_base as _fb
from fetcher_base import BaseFetcher, DataRecord
from wb_indicator_map import WB_INDICATOR_MAP

load_dotenv()

logging.basicConfig(
    level=os.getenv("OSA_LOG_LEVEL", "INFO"),
    format="%(asctime)s | %(levelname)-8s | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)

# Seuil de couverture minimum pour émettre un warning
MIN_COVERAGE_COUNTRIES = 30  # relevé de 10 → 30 (sur 54 pays)

WB_BASE_URL = "https://api.worldbank.org/v2"
WB_PER_PAGE = 5000


class WBFetcher(BaseFetcher):
    """
    Fetcher World Bank — API WDI batch multi-pays.
    Récupère tous les pays africains en une seule requête par indicateur.
    """

    PROVIDER_CODE = "WB"
    ENDPOINT_CODE = "WB_ALL_COUNTRIES"   # corrigé — était WB_COUNTRY_INDICATOR
    INDICATOR_MAP = WB_INDICATOR_MAP

    def fetch_indicator(
        self,
        osa_code:  str,
        config:    dict,
        year_from: int,
        year_to:   int,
    ) -> list[DataRecord]:
        """
        Appelle l'API WB pour un indicateur, tous les pays africains,
        sur la plage d'années demandée.

        L'API WB accepte une liste de pays séparés par ';' —
        on récupère les 54 pays en une seule requête.
        """
        wb_code = config["wb_code"]

        countries_param = ";".join(_fb.AFRICAN_ISO3)
        url = (
            f"{WB_BASE_URL}/country/{countries_param}"
            f"/indicator/{wb_code}"
            f"?format=json"
            f"&per_page={WB_PER_PAGE}"
            f"&date={year_from}:{year_to}"
        )

        data = self.http_get(url)
        if not data:
            return []

        # L'API WB retourne [metadata, [données]]
        if not isinstance(data, list) or len(data) < 2:
            self.log.warning("Réponse WB inattendue pour %s", wb_code)
            return []

        raw_records = data[1]
        if raw_records is None:
            self.log.warning("Aucune donnée WB pour %s", wb_code)
            return []

        records: list[DataRecord] = []
        for rec in raw_records:
            iso3     = (rec.get("countryiso3code") or "").upper()
            year_str = rec.get("date", "")
            value    = rec.get("value")

            if iso3 not in _fb.AFRICAN_ISO3:
                continue
            if not str(year_str).isdigit():
                continue

            records.append({
                "iso3":  iso3,
                "year":  int(year_str),
                "value": float(value) if value is not None else None,
            })

        # Avertissement couverture faible
        countries_ok = len({r["iso3"] for r in records if r.get("value") is not None})
        if countries_ok < MIN_COVERAGE_COUNTRIES:
            self.log.warning(
                "%s : seulement %d pays avec données (seuil %d)",
                osa_code, countries_ok, MIN_COVERAGE_COUNTRIES,
            )

        self.log.debug("WB %s → %d enregistrements, %d pays",
                       wb_code, len(records), countries_ok)
        return records


# ── Point d'entrée CLI ─────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(
        description="OSA Fetcher — World Bank WDI",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--year",      type=int, help="Année unique à collecter")
    parser.add_argument("--from",      type=int, dest="year_from", default=2010,
                        help="Année de début (défaut : 2010)")
    parser.add_argument("--to",        type=int, dest="year_to",
                        help="Année de fin (défaut : année courante - 2)")
    parser.add_argument("--indicator", type=str, default=None,
                        help="Collecter un seul indicateur OSA (ex: ECO_GDP)")
    parser.add_argument("--dry-run",   action="store_true",
                        help="Simulation : aucune écriture en base")
    args = parser.parse_args()

    # Résolution plage d'années
    if args.year:
        year_from = year_to = args.year
    else:
        year_from = args.year_from
        year_to   = args.year_to or (datetime.now().year - 2)

    if year_from > year_to:
        logging.error("--from (%d) > --to (%d)", year_from, year_to)
        sys.exit(1)

    # Validation indicateur
    if args.indicator and args.indicator not in WB_INDICATOR_MAP:
        logging.error("Indicateur inconnu : %s", args.indicator)
        logging.info("Disponibles : %s", ", ".join(sorted(WB_INDICATOR_MAP)))
        sys.exit(1)

    fetcher = WBFetcher(dry_run=args.dry_run)
    try:
        fetcher.connect()
        result = fetcher.run(year_from, year_to, args.indicator)
        sys.exit(0 if not result["failed"] else 1)
    finally:
        fetcher.disconnect()


if __name__ == "__main__":
    main()
