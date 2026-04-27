"""
============================================================
OSA / ISA OBSERVATORY
fetcher_imf_dots_csv.py -- Fetcher IMF IMTS (CSV)
============================================================
Indicateurs couverts : 4 (PECO -- commerce exterieur)
Source : IMF International Merchandise Trade Statistics (IMTS)
Dataset : IMF.STA:IMTS
URL    : https://data.imf.org/?sk=9d6028d4-f14a-464c-a2f2-59b2cd424b85

Format reel du fichier :
  SERIES_CODE = {ISO3}.{INDICATOR}.{PARTNER}.{FREQ}
  ex: DZA.XG_FOB_USD.FRA.A  (exports Algerie vers France, annuel)

  Pas de code "World" total -- le fetcher somme tous les partenaires
  individuels par (pays, annee) pour obtenir le total mondial.
  Les agregats regionaux (TX598, TX799...) sont exclus.

  SCALE = Millions USD -> multiplier par 1_000_000 dans la config.

Telechargement :
  1. data.imf.org -> IMTS (International Merchandise Trade Statistics)
  2. Selectionner : Annual | All African countries | All indicators
  3. Telecharger CSV (~ 2-3 Go)
  4. Placer dans data/imf/DOTS.csv

Usage :
  python fetcher_imf_dots_csv.py --file data/imf/DOTS.csv
  python fetcher_imf_dots_csv.py --file data/imf/DOTS.csv --dry-run
  python fetcher_imf_dots_csv.py --file data/imf/DOTS.csv --indicator ECO_EXP
  python fetcher_imf_dots_csv.py --file data/imf/DOTS.csv --detect
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

# ── Mapping indicateurs OSA -> codes IMTS ─────────────────
#
# Format fichier IMTS : une ligne par paire (pays, partenaire)
# Le fetcher somme tous les partenaires pour obtenir le total mondial.
# SCALE = Millions USD -> multiplier = 1_000_000

DOTS_INDICATOR_MAP: dict = {

    "ECO_EXP": {
        "dots_code":    "XG_FOB_USD",
        "africa_only":  False,
        "name_fr":      "Exportations de biens FOB (USD)",
        "unit_code":    "USD",
        "direction":    "+",
        "multiplier":   1_000_000.0,
        "notes":        "IMTS -- exportations totales de biens FOB. Somme tous partenaires.",
    },
    "ECO_IMP": {
        "dots_code":    "MG_CIF_USD",
        "africa_only":  False,
        "name_fr":      "Importations de biens CIF (USD)",
        "unit_code":    "USD",
        "direction":    "-",
        "multiplier":   1_000_000.0,
        "notes":        "IMTS -- importations totales de biens CIF. Somme tous partenaires.",
    },
    "ECO_DIV": {
        "dots_code":    "TBG_USD",
        "africa_only":  False,
        "name_fr":      "Balance commerciale biens (USD)",
        "unit_code":    "USD",
        "direction":    "+",
        "multiplier":   1_000_000.0,
        "notes":        "IMTS -- solde commercial biens. Positif = excedent.",
    },
    "ECO_COM": {
        "dots_code":    "XG_FOB_USD",
        "africa_only":  True,
        "name_fr":      "Exportations intra-africaines FOB (USD)",
        "unit_code":    "USD",
        "direction":    "+",
        "multiplier":   1_000_000.0,
        "notes":        "IMTS -- exports vers partenaires africains uniquement. Proxy AfCFTA.",
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
            africa_only=config.get("africa_only", False),
        )


def main() -> None:
    parser = argparse.ArgumentParser(
        description="OSA Fetcher -- IMF IMTS CSV (Commerce exterieur)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Indicateurs :
  ECO_EXP  Exportations totales FOB (USD)
  ECO_IMP  Importations totales CIF (USD)
  ECO_DIV  Balance commerciale (USD)
  ECO_COM  Exportations intra-africaines FOB (USD)

Note : le fichier IMTS est volumineux (~2-3 Go).
L'ingestion complete prend 10-30 minutes selon le materiel.

Exemples :
  python fetcher_imf_dots_csv.py --file data/imf/DOTS.csv --dry-run
  python fetcher_imf_dots_csv.py --file data/imf/DOTS.csv
  python fetcher_imf_dots_csv.py --file data/imf/DOTS.csv --indicator ECO_EXP
  python fetcher_imf_dots_csv.py --file data/imf/DOTS.csv --detect

Telechargement IMTS :
  https://data.imf.org/?sk=9d6028d4-f14a-464c-a2f2-59b2cd424b85
        """,
    )
    parser.add_argument("--file",      type=str, required=True)
    parser.add_argument("--from",      type=int, dest="year_from", default=2010)
    parser.add_argument("--to",        type=int, dest="year_to",   default=2024)
    parser.add_argument("--indicator", type=str, default=None)
    parser.add_argument("--dry-run",   action="store_true")
    parser.add_argument("--detect",    action="store_true",
                        help="Afficher la structure du CSV")
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