"""
============================================================
OSA / ISA OBSERVATORY
fetcher_sipri_csv.py — Fetcher SIPRI (CSV annuel)
============================================================
Couvre : 5 indicateurs pilier PMIL (souveraineté militaire)
Source : Stockholm International Peace Research Institute
URL    : https://www.sipri.org/databases

SIPRI est LA référence mondiale pour les données militaires.
Pas d'API publique — uniquement CSV/Excel téléchargeables.
Mise à jour annuelle (avril-mai de chaque année).

Datasets SIPRI nécessaires :
  MILEX  → Dépenses militaires
  ARMS   → Transferts d'armements (importations/exportations)
  PEACE  → Missions de maintien de la paix

Téléchargement :
  1. MILEX  : https://www.sipri.org/databases/milex
     → "Download SIPRI Military Expenditure Database"
     → Format Excel (.xlsx) ou CSV
     → Placer dans data/sipri/SIPRI_MILEX.csv

  2. ARMS transfers : https://www.sipri.org/databases/armstransfers
     → "Download TIV of arms imports"
     → Format CSV
     → Placer dans data/sipri/SIPRI_ARMS_IMPORTS.csv

  3. Peacekeeping : https://www.sipri.org/databases/pko
     → Télécharger PKO database
     → Placer dans data/sipri/SIPRI_PKO.csv

Usage :
  python fetcher_sipri_csv.py --dir data/sipri/
  python fetcher_sipri_csv.py --dir data/sipri/ --dry-run
  python fetcher_sipri_csv.py --dir data/sipri/ --indicator MIL_EXP
  python fetcher_sipri_csv.py --dir data/sipri/ --list-missing
============================================================
"""

from __future__ import annotations

import argparse
import csv
import logging
import os
import sys
from pathlib import Path
from typing import Optional

from dotenv import load_dotenv

from fetcher_base import BaseFetcher, DataRecord, AFRICAN_ISO3, ISO3_TO_ISO2

load_dotenv()

logging.basicConfig(
    level=os.getenv("OSA_LOG_LEVEL", "INFO"),
    format="%(asctime)s | %(levelname)-8s | %(message)s",
)

# ── Mapping noms de pays SIPRI → ISO-3 ────────────────────
# SIPRI utilise des noms en anglais, pas de codes ISO

SIPRI_COUNTRY_TO_ISO3: dict[str, str] = {
    # Afrique du Nord
    "Algeria":              "DZA",
    "Egypt":                "EGY",
    "Libya":                "LBY",
    "Morocco":              "MAR",
    "Mauritania":           "MRT",
    "Sudan":                "SDN",
    "Tunisia":              "TUN",
    # Afrique de l'Ouest
    "Benin":                "BEN",
    "Burkina Faso":         "BFA",
    "Côte d'Ivoire":        "CIV",
    "Cote d'Ivoire":        "CIV",
    "Cabo Verde":           "CPV",
    "Cape Verde":           "CPV",
    "Gambia":               "GMB",
    "Ghana":                "GHA",
    "Guinea":               "GIN",
    "Guinea-Bissau":        "GNB",
    "Liberia":              "LBR",
    "Mali":                 "MLI",
    "Niger":                "NER",
    "Nigeria":              "NGA",
    "Sierra Leone":         "SLE",
    "Senegal":              "SEN",
    "Togo":                 "TGO",
    # Afrique de l'Est
    "Burundi":              "BDI",
    "Comoros":              "COM",
    "Djibouti":             "DJI",
    "Eritrea":              "ERI",
    "Ethiopia":             "ETH",
    "Kenya":                "KEN",
    "Madagascar":           "MDG",
    "Malawi":               "MWI",
    "Mauritius":            "MUS",
    "Mozambique":           "MOZ",
    "Rwanda":               "RWA",
    "Seychelles":           "SYC",
    "Somalia":              "SOM",
    "South Sudan":          "SSD",
    "Tanzania":             "TZA",
    "Uganda":               "UGA",
    "Zambia":               "ZMB",
    "Zimbabwe":             "ZWE",
    # Afrique Centrale
    "Angola":               "AGO",
    "Cameroon":             "CMR",
    "Central African Republic": "CAF",
    "Chad":                 "TCD",
    "Congo":                "COG",
    "DR Congo":             "COD",
    "DRC":                  "COD",
    "Equatorial Guinea":    "GNQ",
    "Gabon":                "GAB",
    "Sao Tome and Principe": "STP",
    # Afrique Australe
    "Botswana":             "BWA",
    "Eswatini":             "SWZ",
    "Lesotho":              "LSO",
    "Namibia":              "NAM",
    "South Africa":         "ZAF",
}

# ── Mapping indicateurs OSA → config SIPRI ────────────────

SIPRI_INDICATOR_MAP: dict = {

    "MIL_EXP": {
        "dataset":    "MILEX",
        "metric":     "expenditure_usd_const",
        "name_fr":    "Dépenses militaires (USD const. 2022)",
        "unit_code":  "USD_CONST",
        "direction":  "+",
        "multiplier": 1_000_000.0,   # SIPRI en millions USD → USD
        "notes":      """SIPRI MILEX — dépenses militaires USD constants 2022.
                        Série la plus fiable au monde pour cet indicateur.
                        Couvre 2010-2024 pour la quasi-totalité des pays africains.""",
    },
    "MIL_EXP_PCT": {
        "dataset":    "MILEX",
        "metric":     "expenditure_pct_gdp",
        "name_fr":    "Dépenses militaires (% PIB)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      """SIPRI MILEX — dépenses militaires en % du PIB.
                        Indicateur effort défense — comparable entre pays de tailles différentes.""",
    },
    "MIL_DEP": {
        "dataset":    "ARMS",
        "metric":     "imports_tiv",
        "name_fr":    "Importations armements (TIV SIPRI)",
        "unit_code":  "INDEX",
        "direction":  "-",
        "multiplier": 1.0,
        "notes":      """SIPRI Arms Transfers — Trend Indicator Value des importations.
                        Plus la valeur est haute, plus le pays dépend de l'armement étranger.
                        Direction négative : forte dépendance = mauvais pour la souveraineté.""",
    },
    "MIL_IND": {
        "dataset":    "ARMS",
        "metric":     "exports_tiv",
        "name_fr":    "Exportations armements (TIV SIPRI)",
        "unit_code":  "INDEX",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      """SIPRI Arms Transfers — TIV des exportations.
                        Un pays qui exporte des armements a une industrie de défense.
                        Proxy capacité industrielle défense.""",
    },
    "MIL_MIS": {
        "dataset":    "PKO",
        "metric":     "troops_contributed",
        "name_fr":    "Contribution missions de paix ONU (troupes)",
        "unit_code":  "PERSONS",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      """SIPRI PKO — nombre de troupes contribuées aux opérations ONU.
                        Proxy rayonnement international militaire et interopérabilité.""",
    },
}


class SIPRICSVFetcher(BaseFetcher):

    PROVIDER_CODE = "SIPRI"
    ENDPOINT_CODE = "WB_COUNTRY_INDICATOR"   # Réutilise endpoint WB — pas d'endpoint SIPRI en base
    INDICATOR_MAP = SIPRI_INDICATOR_MAP

    def __init__(self, data_dir: str = "data/sipri", dry_run: bool = False) -> None:
        super().__init__(dry_run=dry_run)
        self.data_dir = Path(data_dir)

    def fetch_indicator(
        self,
        osa_code:  str,
        config:    dict,
        year_from: int,
        year_to:   int,
    ) -> list[DataRecord]:
        """Dispatch vers le parser du bon dataset SIPRI."""
        dataset = config["dataset"]
        metric  = config["metric"]

        if dataset == "MILEX":
            return self._parse_milex(metric, year_from, year_to)
        elif dataset == "ARMS":
            return self._parse_arms(metric, year_from, year_to)
        elif dataset == "PKO":
            return self._parse_pko(metric, year_from, year_to)
        else:
            self.log.error("Dataset SIPRI inconnu : %s", dataset)
            return []

    # ── MILEX ─────────────────────────────────────────────

    def _parse_milex(
        self,
        metric:    str,
        year_from: int,
        year_to:   int,
    ) -> list[DataRecord]:
        """
        Parse SIPRI_MILEX.csv.

        Format SIPRI MILEX (CSV) :
        Country | Notes | 2010 | 2011 | ... | 2024

        La première colonne est le nom du pays en anglais.
        Les colonnes d'années contiennent les valeurs ou '...' si manquant.
        """
        csv_path = self.data_dir / "SIPRI_MILEX.csv"
        if not csv_path.exists():
            self.log.warning("SIPRI_MILEX.csv manquant — télécharger sur sipri.org/databases/milex")
            return []

        # Colonnes selon metric
        col_suffix = {
            "expenditure_usd_const": "",      # colonnes directes = USD const
            "expenditure_pct_gdp":   "_pct",  # suffixe si deux tableaux dans le CSV
        }.get(metric, "")

        records: list[DataRecord] = []

        try:
            with open(csv_path, encoding="utf-8-sig", errors="replace") as f:
                # Détecter et sauter les lignes d'en-tête SIPRI (souvent 5-6 lignes)
                lines = f.readlines()

            # Trouver la ligne d'en-tête avec les années
            header_line = None
            header_idx  = 0
            for idx, line in enumerate(lines):
                if "Country" in line or "country" in line:
                    header_line = line
                    header_idx  = idx
                    break

            if header_line is None:
                self.log.error("En-tête non trouvé dans SIPRI_MILEX.csv")
                return []

            # Parser depuis la ligne d'en-tête
            import io
            content = "".join(lines[header_idx:])
            sample  = content[:1024]
            delim   = "\t" if "\t" in sample else ","

            reader = csv.DictReader(io.StringIO(content), delimiter=delim)

            for row in reader:
                # Résolution pays
                country_raw = (
                    row.get("Country", "") or
                    row.get("country", "") or
                    list(row.values())[0]
                ).strip()

                iso3 = SIPRI_COUNTRY_TO_ISO3.get(country_raw)
                if not iso3 or iso3 not in AFRICAN_ISO3:
                    continue

                for year in range(year_from, year_to + 1):
                    col = str(year) + col_suffix
                    raw = row.get(col, row.get(str(year), "")).strip()
                    value = self._parse_sipri_value(raw)
                    records.append({"iso3": iso3, "year": year, "value": value})

        except Exception as exc:
            self.log.error("Erreur parsing SIPRI MILEX : %s", exc)

        self.log.debug("SIPRI MILEX %s → %d enregistrements", metric, len(records))
        return records

    # ── ARMS ──────────────────────────────────────────────

    def _parse_arms(
        self,
        metric:    str,
        year_from: int,
        year_to:   int,
    ) -> list[DataRecord]:
        """
        Parse SIPRI_ARMS_IMPORTS.csv ou SIPRI_ARMS_EXPORTS.csv.

        Format SIPRI Arms TIV :
        Recipient/Supplier | 2010 | 2011 | ... | 2024
        """
        filename = (
            "SIPRI_ARMS_IMPORTS.csv"
            if metric == "imports_tiv"
            else "SIPRI_ARMS_EXPORTS.csv"
        )
        csv_path = self.data_dir / filename

        if not csv_path.exists():
            self.log.warning(
                "%s manquant — télécharger sur sipri.org/databases/armstransfers",
                filename,
            )
            return []

        records: list[DataRecord] = []

        try:
            with open(csv_path, encoding="utf-8-sig", errors="replace") as f:
                lines = f.readlines()

            # Trouver en-tête
            header_idx = 0
            for idx, line in enumerate(lines):
                if any(str(y) in line for y in range(2010, 2025)):
                    header_idx = idx
                    break

            import io
            content = "".join(lines[header_idx:])
            delim   = "\t" if "\t" in content[:512] else ","
            reader  = csv.DictReader(io.StringIO(content), delimiter=delim)

            for row in reader:
                country_raw = list(row.values())[0].strip()
                iso3 = SIPRI_COUNTRY_TO_ISO3.get(country_raw)
                if not iso3 or iso3 not in AFRICAN_ISO3:
                    continue

                for year in range(year_from, year_to + 1):
                    raw   = row.get(str(year), "").strip()
                    value = self._parse_sipri_value(raw)
                    records.append({"iso3": iso3, "year": year, "value": value})

        except Exception as exc:
            self.log.error("Erreur parsing SIPRI ARMS : %s", exc)

        self.log.debug("SIPRI ARMS %s → %d enregistrements", metric, len(records))
        return records

    # ── PKO ───────────────────────────────────────────────

    def _parse_pko(
        self,
        metric:    str,
        year_from: int,
        year_to:   int,
    ) -> list[DataRecord]:
        """
        Parse SIPRI_PKO.csv.

        Format SIPRI PKO :
        Country | Mission | Year | Troops | Police | Observers | Total
        """
        csv_path = self.data_dir / "SIPRI_PKO.csv"
        if not csv_path.exists():
            self.log.warning(
                "SIPRI_PKO.csv manquant — télécharger sur sipri.org/databases/pko"
            )
            return []

        # Agrégation par pays/année (somme de toutes les missions)
        aggregated: dict[tuple, float] = {}

        try:
            with open(csv_path, encoding="utf-8-sig", errors="replace") as f:
                sample  = f.read(1024)
                f.seek(0)
                delim   = "\t" if "\t" in sample else ","
                reader  = csv.DictReader(f, delimiter=delim)

                for row in reader:
                    country_raw = (
                        row.get("Country", "") or
                        row.get("Contributing country", "")
                    ).strip()

                    iso3 = SIPRI_COUNTRY_TO_ISO3.get(country_raw)
                    if not iso3 or iso3 not in AFRICAN_ISO3:
                        continue

                    year_raw = row.get("Year", "").strip()
                    try:
                        year = int(year_raw)
                        if not (year_from <= year <= year_to):
                            continue
                    except (ValueError, TypeError):
                        continue

                    # Colonne troops
                    troops_raw = (
                        row.get("Troops", "") or
                        row.get("troops", "") or
                        row.get("Total", "")
                    ).strip()
                    troops = self._parse_sipri_value(troops_raw)

                    key = (iso3, year)
                    if troops is not None:
                        aggregated[key] = aggregated.get(key, 0.0) + troops

        except Exception as exc:
            self.log.error("Erreur parsing SIPRI PKO : %s", exc)
            return []

        records = [
            {"iso3": iso3, "year": year, "value": value}
            for (iso3, year), value in aggregated.items()
        ]

        self.log.debug("SIPRI PKO → %d enregistrements", len(records))
        return records

    # ── Utilitaire ────────────────────────────────────────

    @staticmethod
    def _parse_sipri_value(raw: str) -> Optional[float]:
        """
        Convertit une cellule SIPRI en float.
        SIPRI utilise : '...' pour données manquantes, 'xxx' pour confidentiel.
        """
        if not raw:
            return None
        cleaned = raw.replace(",", "").replace(" ", "").strip()
        if cleaned.lower() in ("...", "xxx", "na", "n/a", "", "-"):
            return None
        try:
            return float(cleaned)
        except ValueError:
            return None


def main() -> None:
    parser = argparse.ArgumentParser(
        description="OSA Fetcher — SIPRI CSV",
        epilog="""
Fichiers nécessaires dans --dir :
  SIPRI_MILEX.csv         Dépenses militaires
  SIPRI_ARMS_IMPORTS.csv  Importations armements TIV
  SIPRI_ARMS_EXPORTS.csv  Exportations armements TIV
  SIPRI_PKO.csv           Contributions missions de paix

Téléchargements :
  MILEX : https://www.sipri.org/databases/milex
  ARMS  : https://www.sipri.org/databases/armstransfers
  PKO   : https://www.sipri.org/databases/pko

Exemples :
  python fetcher_sipri_csv.py --dir data/sipri/
  python fetcher_sipri_csv.py --dir data/sipri/ --dry-run
  python fetcher_sipri_csv.py --dir data/sipri/ --indicator MIL_EXP
  python fetcher_sipri_csv.py --dir data/sipri/ --list-missing
        """,
    )
    parser.add_argument("--dir",          type=str, required=True)
    parser.add_argument("--from",         type=int, dest="year_from", default=2010)
    parser.add_argument("--to",           type=int, dest="year_to",   default=2024)
    parser.add_argument("--indicator",    type=str, default=None)
    parser.add_argument("--dry-run",      action="store_true")
    parser.add_argument("--list-missing", action="store_true",
                        help="Lister les fichiers CSV manquants")
    args = parser.parse_args()

    if args.list_missing:
        data_dir = Path(args.dir)
        needed = [
            "SIPRI_MILEX.csv",
            "SIPRI_ARMS_IMPORTS.csv",
            "SIPRI_ARMS_EXPORTS.csv",
            "SIPRI_PKO.csv",
        ]
        print(f"\nFichiers SIPRI nécessaires dans {data_dir} :")
        for f in needed:
            path   = data_dir / f
            status = "✓ présent" if path.exists() else "✗ manquant"
            print(f"  {f} — {status}")
        return

    fetcher = SIPRICSVFetcher(
        data_dir=args.dir,
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
