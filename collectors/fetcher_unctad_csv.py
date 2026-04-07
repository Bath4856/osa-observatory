"""
============================================================
OSA / ISA OBSERVATORY 2060427
fetcher_unctad_csv.py — Fetcher UNCTADstat (CSV)
============================================================
Indicateurs couverts :
  - ECO_FDI : Flux d'IDE nets entrants (USD)

Source : UNCTADstat — téléchargement CSV sans clé API
URL    : https://unctadstat.unctad.org/datacentre/

Téléchargement manuel :
  1. Aller sur https://unctadstat.unctad.org/datacentre/dataviewer/US.FdiFlows
  2. Sélectionner : Economy = All African countries
                    Variable = Inward FDI flows
                    Year = 1990-2024
  3. Télécharger en CSV
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
import sys
from pathlib import Path

from dotenv import load_dotenv

from fetcher_base import BaseFetcher, DataRecord, AFRICAN_ISO3

load_dotenv()

logging.basicConfig(
    level=os.getenv("OSA_LOG_LEVEL", "INFO"),
    format="%(asctime)s | %(levelname)-8s | %(message)s",
)

log = logging.getLogger("fetcher_unctad_csv")

# ── Mapping ISO-2 → ISO-3 (UNCTAD utilise les noms de pays ou ISO-2) ──────

ISO2_TO_ISO3: dict[str, str] = {
    "DZ":"DZA","EG":"EGY","LY":"LBY","MA":"MAR","MR":"MRT",
    "SD":"SDN","TN":"TUN","BJ":"BEN","BF":"BFA","CI":"CIV",
    "CV":"CPV","GM":"GMB","GH":"GHA","GN":"GIN","GW":"GNB",
    "LR":"LBR","ML":"MLI","NE":"NER","NG":"NGA","SL":"SLE",
    "SN":"SEN","TG":"TGO","BI":"BDI","KM":"COM","DJ":"DJI",
    "ER":"ERI","ET":"ETH","KE":"KEN","MG":"MDG","MW":"MWI",
    "MU":"MUS","MZ":"MOZ","RW":"RWA","SC":"SYC","SO":"SOM",
    "SS":"SSD","TZ":"TZA","UG":"UGA","ZM":"ZMB","ZW":"ZWE",
    "AO":"AGO","CM":"CMR","CF":"CAF","TD":"TCD","CG":"COG",
    "CD":"COD","GQ":"GNQ","GA":"GAB","ST":"STP","BW":"BWA",
    "SZ":"SWZ","LS":"LSO","NA":"NAM","ZA":"ZAF",
}

# Mapping noms UNCTAD → ISO-3 (UNCTAD utilise souvent les noms en anglais)
UNCTAD_NAME_TO_ISO3: dict[str, str] = {
    "Algeria":"DZA","Egypt":"EGY","Libya":"LBY","Morocco":"MAR",
    "Mauritania":"MRT","Sudan":"SDN","Tunisia":"TUN",
    "Benin":"BEN","Burkina Faso":"BFA","Côte d'Ivoire":"CIV",
    "Cote d'Ivoire":"CIV","Cabo Verde":"CPV","Cape Verde":"CPV",
    "Gambia":"GMB","Ghana":"GHA","Guinea":"GIN","Guinea-Bissau":"GNB",
    "Liberia":"LBR","Mali":"MLI","Niger":"NER","Nigeria":"NGA",
    "Sierra Leone":"SLE","Senegal":"SEN","Togo":"TGO",
    "Burundi":"BDI","Comoros":"COM","Djibouti":"DJI","Eritrea":"ERI",
    "Ethiopia":"ETH","Kenya":"KEN","Madagascar":"MDG","Malawi":"MWI",
    "Mauritius":"MUS","Mozambique":"MOZ","Rwanda":"RWA",
    "Seychelles":"SYC","Somalia":"SOM","South Sudan":"SSD",
    "Tanzania":"TZA","Uganda":"UGA","Zambia":"ZMB","Zimbabwe":"ZWE",
    "Angola":"AGO","Cameroon":"CMR","Central African Republic":"CAF",
    "Chad":"TCD","Congo":"COG","Democratic Republic of the Congo":"COD",
    "DR Congo":"COD","Equatorial Guinea":"GNQ","Gabon":"GAB",
    "Sao Tome and Principe":"STP","São Tomé and Príncipe":"STP",
    "Botswana":"BWA","Eswatini":"SWZ","Lesotho":"LSO",
    "Namibia":"NAM","South Africa":"ZAF",
}


# ── Mapping indicateurs OSA → codes UNCTAD ────────────────────────────────

UNCTAD_INDICATOR_MAP: dict = {
    "ECO_FDI": {
        "unctad_variable": "Inward FDI flows",
        "unctad_variable_alt": ["FDI inflows", "Inflows", "FDI_INW"],
        "name_fr":    "Flux d'IDE nets entrants (USD)",
        "unit_code":  "USD",
        "direction":  "+",
        "multiplier": 1_000_000.0,   # UNCTAD publie en millions USD
        "notes":      "UNCTADstat — investissements directs étrangers entrants nets",
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
        """Parse le CSV UNCTAD — aucun appel réseau."""
        return self._parse_unctad_csv(config, year_from, year_to)

    def _parse_unctad_csv(
        self,
        config:    dict,
        year_from: int,
        year_to:   int,
    ) -> list[DataRecord]:
        """
        Parse un fichier CSV UNCTADstat.

        UNCTAD propose deux formats selon le mode d'export :

        Format A (pivot par année) :
          Economy | Economy ISO | Variable | 2010 | 2011 | ... | 2024

        Format B (long) :
          Economy | Year | Variable | Value

        Ce parseur détecte automatiquement les deux formats.
        """
        records: list[DataRecord] = []

        if not self.csv_filepath.exists():
            self.log.error("Fichier UNCTAD introuvable : %s", self.csv_filepath)
            return []

        target_variable = config["unctad_variable"]
        alt_variables   = config.get("unctad_variable_alt", [])
        all_variables   = [target_variable] + alt_variables

        try:
            with open(self.csv_filepath, encoding="utf-8-sig", errors="replace") as f:
                sample = f.read(4096)
                f.seek(0)
                delimiter = "\t" if "\t" in sample else ","
                reader    = csv.DictReader(f, delimiter=delimiter)
                headers   = reader.fieldnames or []

                # Détection du format
                year_cols = [h for h in headers if h.strip().isdigit()
                             and year_from <= int(h.strip()) <= year_to]

                if year_cols:
                    records = self._parse_wide(
                        reader, all_variables, year_cols, year_from, year_to
                    )
                else:
                    records = self._parse_long(
                        reader, all_variables, year_from, year_to
                    )

        except Exception as exc:
            self.log.error("Erreur parsing UNCTAD %s : %s",
                           self.csv_filepath.name, exc)

        self.log.info(
            "UNCTAD %s → %d enregistrements (%d pays)",
            target_variable, len(records),
            len({r["iso3"] for r in records if r.get("value") is not None}),
        )
        return records

    def _resolve_iso3(self, row: dict) -> str | None:
        """Résout le code ISO-3 depuis une ligne CSV UNCTAD."""
        # Essai 1 — colonne ISO directe
        for col in ("Economy ISO", "ISO", "iso3", "Country Code", "ISO3"):
            val = row.get(col, "").strip().upper()
            if len(val) == 3 and val in AFRICAN_ISO3:
                return val
            if len(val) == 2:
                iso3 = ISO2_TO_ISO3.get(val)
                if iso3:
                    return iso3

        # Essai 2 — nom du pays
        for col in ("Economy", "Country", "Country Name", "Reporter"):
            name = row.get(col, "").strip()
            iso3 = UNCTAD_NAME_TO_ISO3.get(name)
            if iso3:
                return iso3
            # Correspondance partielle (ex: "Tanzania, United Republic of")
            for unctad_name, code in UNCTAD_NAME_TO_ISO3.items():
                if unctad_name.lower() in name.lower():
                    return code

        return None

    def _parse_wide(
        self,
        reader,
        all_variables: list[str],
        year_cols:     list[str],
        year_from:     int,
        year_to:       int,
    ) -> list[DataRecord]:
        """Format A : colonnes = années."""
        records = []
        for row in reader:
            variable = (
                row.get("Variable", "") or
                row.get("Indicator", "") or
                row.get("Series", "")
            ).strip()

            if not any(v.lower() in variable.lower() for v in all_variables):
                continue

            iso3 = self._resolve_iso3(row)
            if not iso3:
                continue

            for col in year_cols:
                year = int(col.strip())
                raw  = row.get(col, "").strip()
                value = self._parse_value(raw)
                records.append({"iso3": iso3, "year": year, "value": value})

        return records

    def _parse_long(
        self,
        reader,
        all_variables: list[str],
        year_from:     int,
        year_to:       int,
    ) -> list[DataRecord]:
        """Format B : une ligne par (pays, année)."""
        records = []
        for row in reader:
            variable = (
                row.get("Variable", "") or
                row.get("Indicator", "") or
                row.get("Series", "")
            ).strip()

            if not any(v.lower() in variable.lower() for v in all_variables):
                continue

            year_str = (row.get("Year", "") or row.get("Period", "")).strip()
            if not year_str.isdigit():
                continue
            year = int(year_str)
            if not (year_from <= year <= year_to):
                continue

            iso3 = self._resolve_iso3(row)
            if not iso3:
                continue

            raw   = (row.get("Value", "") or row.get("Amount", "")).strip()
            value = self._parse_value(raw)
            records.append({"iso3": iso3, "year": year, "value": value})

        return records

    @staticmethod
    def _parse_value(raw: str) -> float | None:
        """Convertit une cellule CSV UNCTAD en float."""
        if not raw:
            return None
        cleaned = raw.replace(",", "").replace(" ", "").strip()
        if cleaned.lower() in ("n/a", "na", "..", "...", "--", "", "-"):
            return None
        # Gérer les valeurs négatives entre parenthèses : (123.4) → -123.4
        if cleaned.startswith("(") and cleaned.endswith(")"):
            cleaned = "-" + cleaned[1:-1]
        try:
            return float(cleaned)
        except ValueError:
            return None

    @staticmethod
    def detect_columns(filepath: str | Path, max_rows: int = 3) -> None:
        """Utilitaire debug — affiche la structure du CSV."""
        filepath = Path(filepath)
        with open(filepath, encoding="utf-8-sig", errors="replace") as f:
            sample = f.read(2048)
            f.seek(0)
            delimiter = "\t" if "\t" in sample else ","
            reader = csv.DictReader(f, delimiter=delimiter)
            print(f"\nColonnes de {filepath.name} :")
            print("  " + ", ".join(reader.fieldnames or []))
            print(f"\nPremières {max_rows} lignes :")
            for i, row in enumerate(reader):
                if i >= max_rows:
                    break
                print(f"  {dict(list(row.items())[:8])}")


# ── CLI ────────────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(
        description="OSA Fetcher — UNCTADstat CSV",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Exemples :
  python fetcher_unctad_csv.py --file data/unctad/FDI_flows.csv
  python fetcher_unctad_csv.py --file data/unctad/FDI_flows.csv --dry-run
  python fetcher_unctad_csv.py --file data/unctad/FDI_flows.csv --from 2010 --to 2024
  python fetcher_unctad_csv.py --file data/unctad/FDI_flows.csv --detect

Téléchargement UNCTAD FDI :
  https://unctadstat.unctad.org/datacentre/dataviewer/US.FdiFlows
  → Sélectionner All African countries + Inward FDI flows + 1990-2024
  → Télécharger CSV → placer dans data/unctad/FDI_flows.csv
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