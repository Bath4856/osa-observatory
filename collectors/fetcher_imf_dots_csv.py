"""
============================================================
OSA / ISA OBSERVATORY
fetcher_imf_dots_csv.py — Fetcher IMF DOTS (CSV)
============================================================
Indicateurs couverts : 4 (PECO — commerce et IDE)
Source : IMF Direction of Trade Statistics
URL    : https://data.imf.org/?sk=9d6028d4-f14a-464c-a2f2-59b2cd424b85

Téléchargement :
  1. Aller sur https://data.imf.org/?sk=9d6028d4-f14a-464c-a2f2-59b2cd424b85
  2. Sélectionner : Annual Data → Reporters: African countries → All indicators
  3. Télécharger CSV
  4. Placer dans data/imf/DOTS_2024.csv

Usage :
  python fetcher_imf_dots_csv.py --file data/imf/DOTS_2024.csv
  python fetcher_imf_dots_csv.py --file data/imf/DOTS_2024.csv --dry-run
============================================================
"""

from __future__ import annotations

import argparse
import logging
import os
import sys
from pathlib import Path

from dotenv import load_dotenv

from fetcher_base import BaseFetcher, DataRecord
from imf_csv_parser import IMFCSVParser

load_dotenv()

logging.basicConfig(
    level=os.getenv("OSA_LOG_LEVEL", "INFO"),
    format="%(asctime)s | %(levelname)-8s | %(message)s",
)

# ── Mapping indicateurs OSA → codes DOTS ──────────────────

DOTS_INDICATOR_MAP: dict = {

    "ECO_EXP": {
        "dots_code":  "TXG_FOB_USD",
        "name_fr":    "Exportations de biens FOB (USD)",
        "unit_code":  "USD",
        "direction":  "+",
        "multiplier": 1_000_000.0,   # DOTS en millions USD → USD
        "notes":      "DOTS — exportations totales de biens FOB. W00 = monde entier.",
    },
    "ECO_IMP": {
        "dots_code":  "TMG_CIF_USD",
        "name_fr":    "Importations de biens CIF (USD)",
        "unit_code":  "USD",
        "direction":  "-",
        "multiplier": 1_000_000.0,
        "notes":      "DOTS — importations totales de biens CIF.",
    },
    "ECO_COM": {
        "dots_code":  "TXG_FOB_USD_AF",
        "name_fr":    "Exportations intra-africaines (USD)",
        "unit_code":  "USD",
        "direction":  "+",
        "multiplier": 1_000_000.0,
        "notes":      "DOTS — exports vers partenaires africains. Proxy AfCFTA.",
    },
    "ECO_DIV": {
        "dots_code":  "TBAL_USD",
        "name_fr":    "Balance commerciale (USD)",
        "unit_code":  "USD",
        "direction":  "+",
        "multiplier": 1_000_000.0,
        "notes":      "DOTS — solde commercial biens. Positif = excédent.",
    },
}


class IMFDOTSCSVFetcher(BaseFetcher):

    PROVIDER_CODE = "IMF"
    ENDPOINT_CODE = "IMF_WEO_INDICATOR"
    INDICATOR_MAP = DOTS_INDICATOR_MAP

    def __init__(self, csv_filepath: str = "data/imf/DOTS.csv", dry_run: bool = False) -> None:
        super().__init__(dry_run=dry_run)
        self.csv_filepath = Path(csv_filepath)

    def fetch_indicator(
        self,
        osa_code:  str,
        config:    dict,
        year_from: int,
        year_to:   int,
    ) -> list[DataRecord]:
        return IMFCSVParser.parse_dots(
            self.csv_filepath,
            config["dots_code"],
            year_from,
            year_to,
        )


def main() -> None:
    parser = argparse.ArgumentParser(
        description="OSA Fetcher — IMF DOTS CSV",
        epilog="""
Exemples :
  python fetcher_imf_dots_csv.py --file data/imf/DOTS_2024.csv
  python fetcher_imf_dots_csv.py --file data/imf/DOTS_2024.csv --dry-run
  python fetcher_imf_dots_csv.py --file data/imf/DOTS_2024.csv --indicator ECO_EXP

Téléchargement DOTS :
  https://data.imf.org/?sk=9d6028d4-f14a-464c-a2f2-59b2cd424b85
        """,
    )
    parser.add_argument("--file",      type=str, required=True)
    parser.add_argument("--from",      type=int, dest="year_from", default=2010)
    parser.add_argument("--to",        type=int, dest="year_to",   default=2024)
    parser.add_argument("--indicator", type=str, default=None)
    parser.add_argument("--dry-run",   action="store_true")
    parser.add_argument("--detect",    action="store_true",
                        help="Afficher les colonnes du CSV")
    args = parser.parse_args()

    if args.detect:
        IMFCSVParser.detect_columns(args.file)
        return

    fetcher = IMFDOTSCSVFetcher(
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
