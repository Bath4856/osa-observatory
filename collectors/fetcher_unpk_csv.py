"""
============================================================
OSA / ISA OBSERVATORY 20260407
fetcher_unpk_csv.py — Fetcher ONU Peacekeeping (IPI CSV)
============================================================
Indicateurs couverts :
  - MIL_MIS : Missions internationales — total personnel
              uniformisé par pays (troupes + police + experts)
  - GEO_PEA : Participation opérations de paix — moyenne
              annuelle du personnel déployé

Source : IPI Peacekeeping Database (International Peace Institute)
         via Humanitarian Data Exchange
URL    : https://data.humdata.org/dataset/ipi-peacekeeping-database
CSV    : https://data.humdata.org/dataset/6fc8e7be-63da-4660-8557-
         b1c5d3501805/resource/0b5f1dd5-4d6d-45ab-928a-322cb0e4ad28/
         download/Country_Level_data.csv

Couverture : 1990-2018 (limite IPI)
             Pour 2019+ : télécharger les PDF ONU et compléter manuellement

Téléchargement :
  1. Aller sur https://data.humdata.org/dataset/ipi-peacekeeping-database
  2. Télécharger "Country_Level_data.csv"
  3. Placer dans data/unpk/Country_Level_data.csv

Usage :
  python fetcher_unpk_csv.py --file data/unpk/Country_Level_data.csv
  python fetcher_unpk_csv.py --file data/unpk/Country_Level_data.csv --dry-run
  python fetcher_unpk_csv.py --file data/unpk/Country_Level_data.csv --detect
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

log = logging.getLogger("fetcher_unpk_csv")

# ── Mapping noms de pays IPI → ISO-3 ──────────────────────────────────────
# IPI utilise les noms anglais officiels ONU

IPI_NAME_TO_ISO3: dict[str, str] = {
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
    "Botswana":"BWA","Eswatini":"SWZ","Swaziland":"SWZ",
    "Lesotho":"LSO","Namibia":"NAM","South Africa":"ZAF",
}

# ── Mapping indicateurs OSA ────────────────────────────────────────────────

UNPK_INDICATOR_MAP: dict = {
    "MIL_MIS": {
        "name_fr":    "Missions internationales — personnel total",
        "unit_code":  "PERSONS",
        "direction":  "+",
        "multiplier": 1.0,
        "ipi_column": "total_troops",   # colonne IPI pour le total
        "notes":      "IPI — total personnel uniformisé (troupes+police+experts) "
                      "déployé en opérations ONU. Moyenne annuelle.",
    },
    "GEO_PEA": {
        "name_fr":    "Participation opérations de paix ONU",
        "unit_code":  "PERSONS",
        "direction":  "+",
        "multiplier": 1.0,
        "ipi_column": "total_personnel",  # colonne IPI pour tout le personnel
        "notes":      "IPI — total uniformed personnel (troops + police + experts) "
                      "en opérations de maintien de la paix. Moyenne annuelle.",
    },
}


class UNPKCSVFetcher(BaseFetcher):

    PROVIDER_CODE = "UNPK"
    ENDPOINT_CODE = "UNPK_IPI"
    INDICATOR_MAP = UNPK_INDICATOR_MAP

    def __init__(
        self,
        csv_filepath: str = "data/unpk/Country_Level_data.csv",
        dry_run: bool = False,
    ) -> None:
        super().__init__(dry_run=dry_run)
        self.csv_filepath = Path(csv_filepath)
        self._cache: dict | None = None   # cache du CSV parsé

    def fetch_indicator(
        self,
        osa_code:  str,
        config:    dict,
        year_from: int,
        year_to:   int,
    ) -> list[DataRecord]:
        """Parse le CSV IPI — aucun appel réseau."""
        if self._cache is None:
            self._cache = self._load_csv()

        ipi_column = config.get("ipi_column", "total_personnel")
        records: list[DataRecord] = []

        for (iso3, year), row in self._cache.items():
            if not (year_from <= year <= year_to):
                continue
            if iso3 not in AFRICAN_ISO3:
                continue

            # Essayer la colonne configurée, puis les alternatives
            value = self._get_value(row, ipi_column)
            records.append({"iso3": iso3, "year": year, "value": value})

        self.log.info(
            "UNPK %s → %d enregistrements (%d pays)",
            osa_code, len(records),
            len({r["iso3"] for r in records if r.get("value") is not None}),
        )
        return records

    def _load_csv(self) -> dict:
        """
        Charge le CSV IPI en mémoire.
        Format IPI Country_Level_data.csv :
          iso | country | year | troops | police | experts | total | ...

        Retourne un dict {(iso3, year): row}
        """
        cache = {}

        if not self.csv_filepath.exists():
            self.log.error("Fichier IPI introuvable : %s", self.csv_filepath)
            return cache

        try:
            with open(self.csv_filepath, encoding="utf-8-sig", errors="replace") as f:
                sample = f.read(2048)
                f.seek(0)
                delimiter = "\t" if "\t" in sample else ","
                reader = csv.DictReader(f, delimiter=delimiter)

                self.log.info(
                    "Colonnes IPI : %s",
                    ", ".join(reader.fieldnames or [])
                )

                for row in reader:
                    iso3 = self._resolve_iso3(row)
                    year = self._resolve_year(row)

                    if not iso3 or not year:
                        continue

                    cache[(iso3, year)] = row

        except Exception as exc:
            self.log.error("Erreur parsing IPI %s : %s",
                           self.csv_filepath.name, exc)

        self.log.info("IPI chargé — %d entrées (pays × année)", len(cache))
        return cache

    def _resolve_iso3(self, row: dict) -> str | None:
        """Résout ISO-3 depuis une ligne IPI."""
        # Essai 1 — colonne ISO directe
        for col in ("iso", "ISO", "iso3", "ISO3", "country_iso"):
            val = row.get(col, "").strip().upper()
            if len(val) == 3 and val in AFRICAN_ISO3:
                return val

        # Essai 2 — nom du pays
        for col in ("country", "Country", "country_name", "name"):
            name = row.get(col, "").strip()
            iso3 = IPI_NAME_TO_ISO3.get(name)
            if iso3:
                return iso3
            # correspondance partielle
            for ipi_name, code in IPI_NAME_TO_ISO3.items():
                if ipi_name.lower() in name.lower():
                    return code

        return None

    @staticmethod
    def _resolve_year(row: dict) -> int | None:
        """Résout l'année depuis une ligne IPI."""
        for col in ("year", "Year", "YEAR", "date", "period"):
            val = row.get(col, "").strip()
            if val and val.isdigit():
                return int(val)
            # Format YYYY-MM ou YYYY/MM
            if val and len(val) >= 4 and val[:4].isdigit():
                return int(val[:4])
        return None

    @staticmethod
    def _get_value(row: dict, preferred_col: str) -> float | None:
        """
        Extrait la valeur numérique depuis une ligne.
        Essaie la colonne préférée, puis les colonnes standard IPI.
        """
        candidates = [
            preferred_col,
            "total_personnel", "total_troops", "total",
            "troops", "Troops", "personnel", "Personnel",
            "uniformed_personnel",
        ]
        for col in candidates:
            raw = row.get(col, "").strip()
            if raw and raw not in ("", "NA", "N/A", ".", ".."):
                try:
                    return float(raw.replace(",", ""))
                except ValueError:
                    continue
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
        description="OSA Fetcher — ONU Peacekeeping (IPI CSV)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Indicateurs :
  MIL_MIS — missions internationales (troupes déployées)
  GEO_PEA — participation opérations de paix (total personnel)

Téléchargement IPI :
  https://data.humdata.org/dataset/ipi-peacekeeping-database
  → Country_Level_data.csv → placer dans data/unpk/

Exemples :
  python fetcher_unpk_csv.py --file data/unpk/Country_Level_data.csv --detect
  python fetcher_unpk_csv.py --file data/unpk/Country_Level_data.csv --dry-run
  python fetcher_unpk_csv.py --file data/unpk/Country_Level_data.csv --from 2000 --to 2018
  python fetcher_unpk_csv.py --file data/unpk/Country_Level_data.csv --indicator MIL_MIS
        """,
    )
    parser.add_argument("--file",      type=str,
                        default="data/unpk/Country_Level_data.csv",
                        help="Chemin vers Country_Level_data.csv")
    parser.add_argument("--from",      type=int, dest="year_from", default=2000)
    parser.add_argument("--to",        type=int, dest="year_to",   default=2018)
    parser.add_argument("--indicator", type=str, default=None,
                        help="MIL_MIS | GEO_PEA")
    parser.add_argument("--dry-run",   action="store_true")
    parser.add_argument("--detect",    action="store_true",
                        help="Afficher les colonnes sans importer")
    args = parser.parse_args()

    if args.detect:
        UNPKCSVFetcher.detect_columns(args.file)
        return

    fetcher = UNPKCSVFetcher(csv_filepath=args.file, dry_run=args.dry_run)
    try:
        fetcher.connect()
        result = fetcher.run(args.year_from, args.year_to, args.indicator)
        sys.exit(0 if not result["failed"] else 1)
    finally:
        fetcher.disconnect()


if __name__ == "__main__":
    main()
