"""
============================================================
OSA / ISA OBSERVATORY
fetcher_imf_bop_csv.py — Fetcher IMF BOP (CSV)
============================================================
Indicateurs couverts : 1 (PMON — MON_DEP)
Source : IMF Balance of Payments Statistics
URL    : https://data.imf.org/?sk=7a51304b-6426-40c0-83dd-ca473ca1fd52

MON_DEP = dépendance aux devises étrangères
Seule source disponible pour cet indicateur — pas d'équivalent WB.
Mesure critique pour les pays pétroliers africains
(Angola, Gabon, Congo, Guinée équatoriale, Nigéria).

Téléchargement :
  1. Aller sur https://data.imf.org/?sk=7a51304b-6426-40c0-83dd-ca473ca1fd52
  2. Sélectionner : Annual → All African countries → Standard Components
  3. Télécharger CSV
  4. Placer dans data/imf/BOP_2024.csv

Usage :
  python fetcher_imf_bop_csv.py --file data/imf/BOP_2024.csv
  python fetcher_imf_bop_csv.py --file data/imf/BOP_2024.csv --dry-run
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

# ── Mapping indicateur OSA → code BOP ─────────────────────

BOP_INDICATOR_MAP: dict = {

    "MON_DEP": {
        "bop_code":   "NETCD_T.IN1.USD",
        "name_fr":    "Revenus primaires nets (USD)",
        "unit_code":  "USD",
        "direction":  "-",
        "multiplier": 1_000_000.0,   # BOP en millions USD → USD
        "notes":      """BOP — revenus primaires nets (dividendes, intérêts rapatriés).
                        Valeur négative = sortie nette de devises = dépendance élevée.
                        Critique pour pays pétroliers : AGO, GAB, COG, GNQ, NGA.""",
    },
    "MON_PAY": {
        "bop_code":   "NETCD_T.CAB.USD",
        "name_fr":    "Solde compte courant (USD)",
        "unit_code":  "USD",
        "direction":  "+",
        "multiplier": 1_000_000.0,
        "notes":      "BOP — solde compte courant en USD. Complément WEO pour pays non couverts.",
    },
    "ECO_FDI": {
        "bop_code":   "A_NFA_T.D_F.USD",
        "name_fr":    "IDE nets (USD)",
        "unit_code":  "USD",
        "direction":  "+",
        "multiplier": 1_000_000.0,
        "notes":      "BOP — investissements directs étrangers nets. Complément WB.",
    },
}


class IMFBOPCSVFetcher(BaseFetcher):

    PROVIDER_CODE = "IMF"
    ENDPOINT_CODE = "IMF_WEO_INDICATOR"
    INDICATOR_MAP = BOP_INDICATOR_MAP

    def __init__(self, csv_filepath: str = "data/imf/BOP.csv", dry_run: bool = False) -> None:
        super().__init__(dry_run=dry_run)
        self.csv_filepath = Path(csv_filepath)

    def fetch_indicator(
        self,
        osa_code:  str,
        config:    dict,
        year_from: int,
        year_to:   int,
    ) -> list[DataRecord]:
        return IMFCSVParser.parse_bop(
            self.csv_filepath,
            config["bop_code"],
            year_from,
            year_to,
        )


def main() -> None:
    parser = argparse.ArgumentParser(
        description="OSA Fetcher — IMF BOP CSV",
        epilog="""
Exemples :
  python fetcher_imf_bop_csv.py --file data/imf/BOP_2024.csv
  python fetcher_imf_bop_csv.py --file data/imf/BOP_2024.csv --dry-run
  python fetcher_imf_bop_csv.py --file data/imf/BOP_2024.csv --indicator MON_DEP

Téléchargement BOP :
  https://data.imf.org/?sk=7a51304b-6426-40c0-83dd-ca473ca1fd52
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

    fetcher = IMFBOPCSVFetcher(
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
