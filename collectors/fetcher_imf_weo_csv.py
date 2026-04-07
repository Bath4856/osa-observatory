"""
============================================================
OSA / ISA OBSERVATORY
fetcher_imf_weo_csv.py — Fetcher IMF WEO (CSV)
============================================================
Remplace fetcher_imf.py pour les indicateurs WEO —
plus fiable, pas de timeout, couverture africaine complète.

Indicateurs couverts : 10 (PMON + PECO)
Source : IMF World Economic Outlook Database
URL    : https://www.imf.org/en/Publications/WEO/weo-database/

Téléchargement :
  1. Aller sur https://www.imf.org/en/Publications/WEO/weo-database/2026/April
  2. Cliquer "By Countries (all countries)"
  3. Sélectionner tous les pays / tous les sujets
  4. Télécharger au format CSV (tab-delimited)
  5. Placer dans data/imf/WEO_2026_Apr.csv

Usage :
  python fetcher_imf_weo_csv.py --file data/imf/WEO_2026_Apr.csv
  python fetcher_imf_weo_csv.py --file data/imf/WEO_2026_Apr.csv --dry-run
  python fetcher_imf_weo_csv.py --file data/imf/WEO_2026_Apr.csv --from 2010 --to 2024
============================================================
"""

from __future__ import annotations

import argparse
import logging
import os
import sys
from pathlib import Path

from dotenv import load_dotenv

from fetcher_base import BaseFetcher, DataRecord, AFRICAN_ISO3
from imf_csv_parser import IMFCSVParser

load_dotenv()

logging.basicConfig(
    level=os.getenv("OSA_LOG_LEVEL", "INFO"),
    format="%(asctime)s | %(levelname)-8s | %(message)s",
)

# ── Mapping indicateurs OSA → codes WEO ───────────────────

WEO_INDICATOR_MAP: dict = {

    # ── PMON — Souveraineté monétaire ─────────────────────
    "MON_INF": {
        "weo_code":   "PCPIPCH",
        "name_fr":    "Inflation (variation IPC %)",
        "unit_code":  "PERCENT",
        "direction":  "-",
        "multiplier": 1.0,
        "notes":      "WEO — variation annuelle IPC. Référence institutionnelle.",
    },
    "MON_EXT": {
        "weo_code":   "GGXWDG_NGDP",
        "name_fr":    "Dette brute secteur public (% PIB)",
        "unit_code":  "PERCENT",
        "direction":  "-",
        "multiplier": 1.0,
        "notes":      "WEO — dette brute administrations publiques / PIB",
    },
    "MON_PAY": {
        "weo_code":   "BCA_NGDPD",
        "name_fr":    "Balance courante (% PIB)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "WEO — solde transactions courantes / PIB",
    },
    "MON_DET": {
        "weo_code":   "GGXONLB_NGDP",
        "name_fr":    "Solde budgétaire primaire (% PIB)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "WEO — solde primaire hors intérêts / PIB",
    },
    "MON_AUT": {
        "weo_code":   "GGX_NGDP",
        "name_fr":    "Dépenses publiques totales (% PIB)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "WEO — proxy capacité budgétaire de l'État",
    },

    # ── PECO — Souveraineté économique ────────────────────
    "ECO_GDP": {
        "weo_code":   "NGDPDPC",
        "name_fr":    "PIB par habitant (USD courants)",
        "unit_code":  "USD",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "WEO — PIB par habitant USD courants. Complément WB.",
    },
    "ECO_GRW": {
        "weo_code":   "NGDP_RPCH",
        "name_fr":    "Croissance PIB réel (%)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "WEO — taux de croissance annuel du PIB réel",
    },
    "ECO_UNE": {
        "weo_code":   "LUR",
        "name_fr":    "Chômage (% population active)",
        "unit_code":  "PERCENT",
        "direction":  "-",
        "multiplier": 1.0,
        "notes":      "WEO — taux de chômage modélisé OIT",
    },
    "ECO_INF": {
        "weo_code":   "PCPIEPCH",
        "name_fr":    "Inflation fin de période (%)",
        "unit_code":  "PERCENT",
        "direction":  "-",
        "multiplier": 1.0,
        "notes":      "WEO — inflation mesurée fin de période",
    },
    "HUM_POP": {
        "weo_code":   "LP",
        "name_fr":    "Population totale (millions)",
        "unit_code":  "PERSONS",
        "direction":  "+",
        "multiplier": 1_000_000.0,   # millions → personnes
        "notes":      "WEO — population totale. Base pour calculs per capita.",
    },
}


class IMFWEOCSVFetcher(BaseFetcher):

    PROVIDER_CODE = "IMF"
    ENDPOINT_CODE = "IMF_WEO_INDICATOR"
    INDICATOR_MAP = WEO_INDICATOR_MAP

    def __init__(self, csv_filepath: str, dry_run: bool = False) -> None:
        super().__init__(dry_run=dry_run)
        self.csv_filepath = Path(csv_filepath)

    def fetch_indicator(
        self,
        osa_code:  str,
        config:    dict,
        year_from: int,
        year_to:   int,
    ) -> list[DataRecord]:
        """Lit le CSV WEO local — aucun appel réseau."""
        return IMFCSVParser.parse_weo(
            self.csv_filepath,
            config["weo_code"],
            year_from,
            year_to,
        )


def main() -> None:
    parser = argparse.ArgumentParser(
        description="OSA Fetcher — IMF WEO CSV",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Exemples :
  python fetcher_imf_weo_csv.py --file data/imf/WEO_2026_Apr.csv
  python fetcher_imf_weo_csv.py --file data/imf/WEO_2026_Apr.csv --dry-run
  python fetcher_imf_weo_csv.py --file data/imf/WEO_2026_Apr.csv --from 2010 --to 2024
  python fetcher_imf_weo_csv.py --file data/imf/WEO_2026_Apr.csv --indicator MON_INF

Téléchargement WEO :
  https://www.imf.org/en/Publications/WEO/weo-database/2026/April
        """,
    )
    parser.add_argument("--file",      type=str, required=True,
                        help="Chemin vers le fichier WEO CSV téléchargé")
    parser.add_argument("--from",      type=int, dest="year_from", default=2010)
    parser.add_argument("--to",        type=int, dest="year_to",   default=2024)
    parser.add_argument("--indicator", type=str, default=None,
                        help="Tester un seul indicateur (ex: MON_INF)")
    parser.add_argument("--dry-run",   action="store_true")
    parser.add_argument("--detect",    action="store_true",
                        help="Afficher les colonnes du CSV sans importer")
    args = parser.parse_args()

    if args.detect:
        IMFCSVParser.detect_columns(args.file)
        return

    fetcher = IMFWEOCSVFetcher(
        csv_filepath=args.file,
        dry_run=args.dry_run,
    )
    try:
        fetcher.connect()
        result = fetcher.run(args.year_from, args.year_to, args.indicator)
        sys.exit(0 if not result["failed"] else 1)
    finally:
        fetcher.disconnect()


if __name__ == "__main__":
    main()
