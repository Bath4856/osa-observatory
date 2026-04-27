"""
============================================================
OSA / ISA OBSERVATORY
fetcher_unctad_csv.py -- Fetcher UNCTADstat (CSV)
============================================================
Indicateurs couverts :
  - ECO_FDI : Flux d'IDE nets entrants (millions USD)

Source : UNCTADstat -- telechargement CSV sans cle API
URL    : https://unctadstat.unctad.org/datacentre/

Format reel du CSV UNCTAD (FDI_flows.csv) :
  Separateur     : virgule
  Colonne pays   : Economy_Label (noms en FRANCAIS)
  Colonnes data  : {annee}_EU_aux_prix_courants_en_millions_Value
  Valeurs        : millions USD, negatifs possibles
  Lignes a ignorer : agregats regionaux (Monde, Afrique, etc.)

Telechargement manuel :
  1. Aller sur https://unctadstat.unctad.org/datacentre/dataviewer/US.FdiFlows
  2. Selectionner : Economy = All African countries
                    Variable = Inward FDI flows
                    Year = 1990-2024
  3. Telecharger en CSV
  4. Placer dans data/unctad/FDI_flows.csv

Usage :
  python fetcher_unctad_csv.py --file data/unctad/FDI_flows.csv
  python fetcher_unctad_csv.py --file data/unctad/FDI_flows.csv --dry-run
  python fetcher_unctad_csv.py --file data/unctad/FDI_flows.csv --from 2010 --to 2024
  python fetcher_unctad_csv.py --file data/unctad/FDI_flows.csv --detect
============================================================
"""

from __future__ import annotations

import argparse
import csv
import logging
import os
import re
import sys
from pathlib import Path

from dotenv import load_dotenv

from fetcher_base import BaseFetcher, DataRecord, AFRICAN_ISO3

load_dotenv()

logging.basicConfig(
    level=os.getenv("OSA_LOG_LEVEL", "INFO"),
    format="%(asctime)s | %(levelname)-8s | %(message)s",
)

# ── Agregats regionaux UNCTAD a ignorer ───────────────────
UNCTAD_AGGREGATES = {
    "monde", "afrique", "afrique septentrionale", "afrique subsaharienne",
    "afrique orientale", "afrique centrale", "afrique australe",
    "afrique occidentale", "amerique latine et caraibes", "asie",
    "europe", "oceanie", "pays developpes", "pays en developpement",
    "pays les moins avances",
}

# ── Mapping noms UNCTAD (francais) -> ISO-3 ───────────────
UNCTAD_FR_TO_ISO3: dict[str, str] = {
    # Afrique du Nord
    "Algerie":                      "DZA",
    "Egypte":                       "EGY",
    "Libye":                        "LBY",
    "Maroc":                        "MAR",
    "Mauritanie":                   "MRT",
    "Soudan":                       "SDN",
    "Soudan (...2011)":             "SDN",
    "Tunisie":                      "TUN",
    # Afrique de l'Ouest
    "Benin":                        "BEN",
    "Burkina Faso":                 "BFA",
    "Cote d'Ivoire":                "CIV",
    "Cabo Verde":                   "CPV",
    "Gambie":                       "GMB",
    "Ghana":                        "GHA",
    "Guinee":                       "GIN",
    "Guinee-Bissau":                "GNB",
    "Liberia":                      "LBR",
    "Mali":                         "MLI",
    "Niger":                        "NER",
    "Nigeria":                      "NGA",
    "Sierra Leone":                 "SLE",
    "Senegal":                      "SEN",
    "Togo":                         "TGO",
    # Afrique de l'Est
    "Burundi":                      "BDI",
    "Comores":                      "COM",
    "Djibouti":                     "DJI",
    "Erythree":                     "ERI",
    "Ethiopie":                     "ETH",
    "Ethiopie (...1991)":           "ETH",
    "Kenya":                        "KEN",
    "Madagascar":                   "MDG",
    "Malawi":                       "MWI",
    "Maurice":                      "MUS",
    "Mozambique":                   "MOZ",
    "Rwanda":                       "RWA",
    "Seychelles":                   "SYC",
    "Somalie":                      "SOM",
    "Soudan du Sud":                "SSD",
    "Tanzanie":                     "TZA",
    "Ouganda":                      "UGA",
    "Zambie":                       "ZMB",
    "Zimbabwe":                     "ZWE",
    # Afrique Centrale
    "Angola":                       "AGO",
    "Cameroun":                     "CMR",
    "Rep. centrafricaine":          "CAF",
    "Tchad":                        "TCD",
    "Congo":                        "COG",
    "Rep. dem. du Congo":           "COD",
    "Guinee equatoriale":           "GNQ",
    "Gabon":                        "GAB",
    "Sao Tome-et-Principe":         "STP",
    # Afrique Australe
    "Botswana":                     "BWA",
    "Eswatini":                     "SWZ",
    "Lesotho":                      "LSO",
    "Namibie":                      "NAM",
    "Afrique du Sud":               "ZAF",
}

# ── Mapping indicateurs OSA ───────────────────────────────
UNCTAD_INDICATOR_MAP: dict = {
    "ECO_FDI": {
        "col_pattern": r"^\d{4}_EU_aux_prix_courants_en_millions_Value$",
        "name_fr":     "Flux d'IDE nets entrants (millions USD)",
        "unit_code":   "USD",
        "direction":   "+",
        "multiplier":  1_000_000.0,   # millions USD -> USD
        "notes":       "UNCTADstat -- investissements directs etrangers entrants nets.",
    },
}


class UNCTADCSVFetcher(BaseFetcher):

    PROVIDER_CODE = "UNCTAD"
    ENDPOINT_CODE = "UNCTAD_FDI"
    INDICATOR_MAP = UNCTAD_INDICATOR_MAP

    def __init__(
        self,
        csv_filepath: str = "data/unctad/FDI_flows.csv",
        dry_run: bool = False,
    ) -> None:
        super().__init__(dry_run=dry_run)
        self.csv_filepath = Path(csv_filepath)

    def fetch_indicator(
        self,
        osa_code:  str,
        config:    dict,
        year_from: int,
        year_to:   int,
    ) -> list[DataRecord]:
        """Parse le CSV UNCTAD -- aucun appel reseau."""
        return self._parse_unctad_csv(config, year_from, year_to)

    def _parse_unctad_csv(
        self,
        config:    dict,
        year_from: int,
        year_to:   int,
    ) -> list[DataRecord]:
        """
        Parse FDI_flows.csv au format reel UNCTAD.

        Format reel :
          Economy_Label | {year}_EU_aux_prix_courants_en_millions_Value | ...

        Une ligne par pays, colonnes = annees.
        Noms de pays en francais.
        """
        records: list[DataRecord] = []

        if not self.csv_filepath.exists():
            self.log.error("Fichier UNCTAD introuvable : %s", self.csv_filepath)
            return []

        col_pattern = re.compile(config["col_pattern"])

        try:
            with open(self.csv_filepath, encoding="utf-8-sig", errors="replace") as f:
                sample    = f.read(2048)
                f.seek(0)
                delimiter = "\t" if "\t" in sample else ","
                reader    = csv.DictReader(f, delimiter=delimiter)
                headers   = reader.fieldnames or []

                # Identifier les colonnes annees correspondant au pattern
                year_col_map: dict[int, str] = {}
                for col in headers:
                    m = re.match(r"^(\d{4})_", col.strip())
                    if m and col_pattern.match(col.strip()):
                        year = int(m.group(1))
                        if year_from <= year <= year_to:
                            year_col_map[year] = col

                if not year_col_map:
                    self.log.warning(
                        "Aucune colonne annee trouvee dans %s "
                        "(pattern: %s, annees: %d-%d)",
                        self.csv_filepath.name, config["col_pattern"],
                        year_from, year_to,
                    )
                    return []

                self.log.info(
                    "Colonnes annees trouvees : %d-%d (%d colonnes)",
                    min(year_col_map), max(year_col_map), len(year_col_map),
                )

                skipped_aggregates = 0
                skipped_unknown    = 0

                for row in reader:
                    name = row.get("Economy_Label", "").strip()
                    if not name:
                        continue

                    # Ignorer les agregats regionaux
                    if name.lower() in UNCTAD_AGGREGATES:
                        skipped_aggregates += 1
                        continue

                    iso3 = self._resolve_iso3(name)
                    if not iso3:
                        skipped_unknown += 1
                        self.log.debug("Pays non resolu : %r", name)
                        continue

                    for year, col in year_col_map.items():
                        raw   = row.get(col, "").strip()
                        value = self._parse_value(raw)
                        records.append({"iso3": iso3, "year": year, "value": value})

                if skipped_unknown > 0:
                    self.log.warning(
                        "%d pays non resolus (agregats ignores : %d)",
                        skipped_unknown, skipped_aggregates,
                    )

        except Exception as exc:
            self.log.error("Erreur parsing UNCTAD %s : %s",
                           self.csv_filepath.name, exc)

        self.log.info(
            "UNCTAD ECO_FDI -> %d enregistrements (%d pays avec valeur)",
            len(records),
            len({r["iso3"] for r in records if r.get("value") is not None}),
        )
        return records

    @staticmethod
    def _resolve_iso3(name: str) -> str | None:
        """Resout le code ISO-3 depuis un nom de pays UNCTAD (francais)."""
        # Lookup direct
        iso3 = UNCTAD_FR_TO_ISO3.get(name)
        if iso3:
            return iso3

        # Lookup insensible a la casse
        name_lower = name.lower()
        for fr_name, code in UNCTAD_FR_TO_ISO3.items():
            if fr_name.lower() == name_lower:
                return code

        # Lookup partiel
        for fr_name, code in UNCTAD_FR_TO_ISO3.items():
            if fr_name.lower() in name_lower or name_lower in fr_name.lower():
                return code

        return None

    @staticmethod
    def _parse_value(raw: str) -> float | None:
        """Convertit une cellule CSV UNCTAD en float. Gere les negatifs."""
        if not raw:
            return None
        cleaned = raw.replace(" ", "").strip()
        if cleaned.lower() in ("n/a", "na", "..", "...", "--", "", "-"):
            return None
        # Valeurs negatives entre parentheses : (123.4) -> -123.4
        if cleaned.startswith("(") and cleaned.endswith(")"):
            cleaned = "-" + cleaned[1:-1]
        # Supprimer separateurs de milliers
        cleaned = cleaned.replace(",", "")
        try:
            return float(cleaned)
        except ValueError:
            return None

    @staticmethod
    def detect_columns(filepath: str | Path, max_rows: int = 3) -> None:
        """Utilitaire debug - affiche la structure du CSV."""
        filepath = Path(filepath)
        with open(filepath, encoding="utf-8-sig", errors="replace") as f:
            sample    = f.read(2048)
            f.seek(0)
            delimiter = "\t" if "\t" in sample else ","
            reader    = csv.DictReader(f, delimiter=delimiter)
            headers   = reader.fieldnames or []
            print(f"\nColonnes de {filepath.name} ({len(headers)} colonnes) :")
            # Afficher les 5 premieres et les 3 dernieres
            preview = headers[:5] + ["..."] + headers[-3:] if len(headers) > 8 else headers
            print("  " + " | ".join(preview))
            # Identifier les colonnes annees
            year_cols = [h for h in headers if re.match(r"^\d{4}_", h.strip())]
            if year_cols:
                years = sorted({int(re.match(r"^(\d{4})_", h).group(1)) for h in year_cols})
                print(f"\nAnnees disponibles : {years[0]}-{years[-1]} ({len(years)} annees)")
            print(f"\nPremieres {max_rows} lignes :")
            for i, row in enumerate(reader):
                if i >= max_rows:
                    break
                name = row.get("Economy_Label", "?")
                val_2023 = ""
                for col in headers:
                    if col.startswith("2023_") and "Value" in col:
                        val_2023 = row.get(col, "")
                        break
                print(f"  {name:40} | 2023={val_2023}")


# ── CLI ───────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(
        description="OSA Fetcher - UNCTADstat CSV",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Exemples :
  python fetcher_unctad_csv.py --file data/unctad/FDI_flows.csv --detect
  python fetcher_unctad_csv.py --file data/unctad/FDI_flows.csv --dry-run
  python fetcher_unctad_csv.py --file data/unctad/FDI_flows.csv
  python fetcher_unctad_csv.py --file data/unctad/FDI_flows.csv --from 2010 --to 2024

Telechargement UNCTAD FDI :
  https://unctadstat.unctad.org/datacentre/dataviewer/US.FdiFlows
  -> Selectionner All African countries + Inward FDI flows + 1990-2024
  -> Telecharger CSV -> placer dans data/unctad/FDI_flows.csv
        """,
    )
    parser.add_argument("--file",      type=str, required=True,
                        help="Chemin vers le fichier CSV UNCTAD")
    parser.add_argument("--from",      type=int, dest="year_from", default=2010)
    parser.add_argument("--to",        type=int, dest="year_to",   default=2024)
    parser.add_argument("--indicator", type=str, default=None)
    parser.add_argument("--dry-run",   action="store_true")
    parser.add_argument("--detect",    action="store_true",
                        help="Afficher les colonnes sans importer")
    args = parser.parse_args()

    if args.detect:
        UNCTADCSVFetcher.detect_columns(args.file)
        return

    fetcher = UNCTADCSVFetcher(csv_filepath=args.file, dry_run=args.dry_run)
    try:
        fetcher.connect()
        result = fetcher.run(args.year_from, args.year_to, args.indicator)
        sys.exit(0 if not result["failed"] else 1)
    finally:
        fetcher.disconnect()


if __name__ == "__main__":
    main()