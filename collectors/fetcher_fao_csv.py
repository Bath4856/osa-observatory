"""
============================================================
OSA / ISA OBSERVATORY
fetcher_fao_csv.py -- Fetcher FAO FAOSTAT (CSV bulk)
============================================================
Couvre : 10 indicateurs piliers PENV + PHUM + PECO
Source : FAOSTAT -- Food and Agriculture Organization
URL    : https://www.fao.org/faostat/en/#data

FAOSTAT publie des CSV bulk telechargeable sans cle API.
Format reel des fichiers bulk FAOSTAT :
  Separateur  : virgule
  Colonnes    : Area Code | Area Code (M49) | Area | Item Code | Item |
                Element Code | Element | Unit | Y1950 | Y1951 | ... | Y2024
  Valeurs     : format large, une colonne par annee (Y2010, Y2011...)
  Pays        : code FAO numerique dans "Area Code"

Fichiers necessaires dans --dir :
  GF.csv   Forestry_E_Africa.csv          -> ENV_FOR (forets)
  RL.csv   Inputs_LandUse_E_Africa.csv    -> ENV_LAN, ENV_ECO, ENV_PRO, ENV_WAT
  FBS.csv  FoodBalanceSheets_E_Africa.csv -> ENV_FIS
  FS.csv   Food_Security_Data_E_Africa.csv-> HUM_FOO
  QCL.csv  Production_Crops_Livestock_E_Africa.csv -> ECO_AGR
  OA.csv   Population_E_Africa.csv        -> HUM_POP
  GT.csv   Emissions_Totals_E_Africa.csv  -> ENV_CO2

Telechargement bulk (sans cle API) :
  python fetcher_fao_csv.py --download --dir data/fao/

Usage :
  python fetcher_fao_csv.py --dir data/fao/
  python fetcher_fao_csv.py --dir data/fao/ --dry-run
  python fetcher_fao_csv.py --dir data/fao/ --indicator ENV_FOR
  python fetcher_fao_csv.py --dir data/fao/ --list-missing
  python fetcher_fao_csv.py --dir data/fao/ --detect GF.csv
============================================================
"""

from __future__ import annotations

import argparse
import csv
import logging
import os
import sys
import urllib.request
import zipfile
from pathlib import Path
from typing import Optional

from dotenv import load_dotenv

from fetcher_base import BaseFetcher, DataRecord, AFRICAN_ISO3

load_dotenv()

logging.basicConfig(
    level=os.getenv("OSA_LOG_LEVEL", "INFO"),
    format="%(asctime)s | %(levelname)-8s | %(message)s",
)

# ── Mapping code FAO -> ISO-3 ─────────────────────────────
# Source : FAOSTAT AreaCodes (code FAO numerique, pas M49)
FAO_AREA_TO_ISO3: dict[str, str] = {
    "4":   "DZA",  "59":  "EGY",  "124": "LBY",  "143": "MAR",
    "144": "MRT",  "206": "SDN",  "249": "TUN",  "23":  "BEN",
    "233": "BFA",  "107": "CIV",  "35":  "CPV",  "74":  "GMB",
    "81":  "GHA",  "86":  "GIN",  "175": "GNB",  "122": "LBR",
    "132": "MLI",  "158": "NER",  "159": "NGA",  "220": "SLE",
    "195": "SEN",  "243": "TGO",  "29":  "BDI",  "45":  "COM",
    "72":  "DJI",  "178": "ERI",  "238": "ETH",  "114": "KEN",
    "129": "MDG",  "130": "MWI",  "146": "MUS",  "149": "MOZ",
    "184": "RWA",  "196": "SYC",  "201": "SOM",  "277": "SSD",
    "215": "TZA",  "253": "UGA",  "260": "ZMB",  "181": "ZWE",
    "7":   "AGO",  "32":  "CMR",  "37":  "CAF",  "39":  "TCD",
    "46":  "COG",  "250": "COD",  "61":  "GNQ",  "68":  "GAB",
    "193": "STP",  "20":  "BWA",  "209": "SWZ",  "119": "LSO",
    "153": "NAM",  "202": "ZAF",
}

# ── URLs bulk FAOSTAT ─────────────────────────────────────
FAO_BULK_URLS: dict[str, str] = {
    "GF":  "https://bulks-faostat.fao.org/production/Forestry_E_Africa.zip",
    "RL":  "https://bulks-faostat.fao.org/production/Inputs_LandUse_E_Africa.zip",
    "FBS": "https://bulks-faostat.fao.org/production/FoodBalanceSheets_E_Africa.zip",
    "FS":  "https://bulks-faostat.fao.org/production/Food_Security_Data_E_Africa.zip",
    "QCL": "https://bulks-faostat.fao.org/production/Production_Crops_Livestock_E_Africa.zip",
    "OA":  "https://bulks-faostat.fao.org/production/Population_E_Africa.zip",
    "GT":  "https://bulks-faostat.fao.org/production/Emissions_Totals_E_Africa.zip",
}

# Nom du fichier CSV principal dans chaque ZIP
FAO_BULK_CSV: dict[str, str] = {
    "GF":  "Forestry_E_Africa.csv",
    "RL":  "Inputs_LandUse_E_Africa.csv",
    "FBS": "FoodBalanceSheets_E_Africa.csv",
    "FS":  "Food_Security_Data_E_Africa.csv",
    "QCL": "Production_Crops_Livestock_E_Africa.csv",
    "OA":  "Population_E_Africa.csv",
    "GT":  "Emissions_Totals_E_Africa.csv",
}

# ── Mapping indicateurs OSA -> config FAOSTAT ─────────────
FAO_INDICATOR_MAP: dict = {
    "ENV_FOR": {
        "dataset":      "RL",
        "element_code": "5110",
        "item_code":    "6646",    # Forest land (1000 ha)
        "name_fr":      "Superficie forestiere (1000 ha)",
        "unit_code":    "INDEX",
        "direction":    "+",
        "multiplier":   1.0,
        "agg":          "sum",
        "notes":        "GF -- superficie forets. Ramener a superficie totale pour %.",
    },
    "ENV_LAN": {
        "dataset":      "RL",
        "element_code": "5110",
        "item_code":    "6655",    # Arable land
        "name_fr":      "Terres arables (1000 ha)",
        "unit_code":    "INDEX",
        "direction":    "+",
        "multiplier":   1.0,
        "agg":          "sum",
        "notes":        "RL -- terres arables disponibles",
    },
    "ENV_ECO": {
        "dataset":      "RL",
        "element_code": "5110",
        "item_code":    "6650",    # Permanent crops
        "name_fr":      "Cultures permanentes (1000 ha)",
        "unit_code":    "INDEX",
        "direction":    "+",
        "multiplier":   1.0,
        "agg":          "sum",
        "notes":        "RL -- proxy soutenabilite agro-ecologique",
    },
    "ENV_PRO": {
        "dataset":      "RL",
        "element_code": "5110",
        "item_code":    "6670",    # Permanent meadows
        "name_fr":      "Prairies permanentes (1000 ha)",
        "unit_code":    "PERCENT",
        "direction":    "+",
        "multiplier":   1.0,
        "agg":          "sum",
        "notes":        "RL -- prairies et paturages permanents",
    },
    "ENV_WAT": {
        "dataset":      "RL",
        "element_code": "5110",
        "item_code":    "6690",    # Irrigated land
        "name_fr":      "Terres irriguees (1000 ha)",
        "unit_code":    "INDEX",
        "direction":    "+",
        "multiplier":   1.0,
        "agg":          "sum",
        "notes":        "RL -- terres irriguees, proxy securite hydrique agricole",
    },
    "ENV_FIS": {
        "dataset":      "FBS",
        "element_code": "5142",
        "item_code":    "2761",    # Fish and seafood
        "name_fr":      "Disponibilite alimentaire poisson (kg/cap/an)",
        "unit_code":    "INDEX",
        "direction":    "+",
        "multiplier":   1.0,
        "agg":          "first",
        "notes":        "FBS -- consommation poisson kg/habitant/an",
    },
    "HUM_FOO": {
        "dataset":      "FS",
        "year_format":  "3yr",
        "element_code": "6121",
        "item_code":    "21010",   # Prevalence of undernourishment
        "name_fr":      "Prevalence sous-alimentation (%)",
        "unit_code":    "PERCENT",
        "direction":    "-",
        "multiplier":   1.0,
        "agg":          "first",
        "notes":        "FS -- % population sous-alimentee. Direction negative.",
    },
    "ECO_AGR": {
        "dataset":      "QCL",
        "element_code": "5312",
        "item_code":    "56",    # Cereals total
        "name_fr":      "Production cereales (tonnes)",
        "unit_code":    "TONNES",
        "direction":    "+",
        "multiplier":   1.0,
        "agg":          "sum",
        "notes":        "QCL -- production cereales totale en tonnes",
    },
    "HUM_POP": {
        "dataset":      "OA",
        "element_code": "511",
        "item_code":    "3010",    # Total population
        "name_fr":      "Population totale (milliers)",
        "unit_code":    "PERSONS",
        "direction":    "+",
        "multiplier":   1000.0,    # milliers -> personnes
        "agg":          "first",
        "notes":        "OA -- population totale estimee et projetee",
    },
    "ENV_CO2": {
        "dataset":      "GT",
        "element_code": "723113",
        "item_code":    "1711",    # Agriculture total
        "name_fr":      "Emissions agriculture (Gg CO2 eq)",
        "unit_code":    "TONNES",
        "direction":    "-",
        "multiplier":   1.0,
        "agg":          "sum",
        "notes":        "GT -- emissions totales agriculture en Gigagrammes CO2 equivalent",
    },
}


class FAOCSVFetcher(BaseFetcher):

    PROVIDER_CODE = "FAO"
    ENDPOINT_CODE = "WB_COUNTRY_INDICATOR"
    INDICATOR_MAP = FAO_INDICATOR_MAP

    def __init__(self, data_dir: str = "data/fao", dry_run: bool = False) -> None:
        super().__init__(dry_run=dry_run)
        self.data_dir = Path(data_dir)
        self._cache: dict[str, list[dict]] = {}

    def fetch_indicator(
        self,
        osa_code:  str,
        config:    dict,
        year_from: int,
        year_to:   int,
    ) -> list[DataRecord]:
        """Parse le CSV FAO bulk pour un indicateur donne."""
        dataset      = config["dataset"]
        element_code = str(config["element_code"])
        item_code    = str(config["item_code"])
        agg_mode     = config.get("agg", "sum")

        csv_path = self.data_dir / f"{dataset}.csv"
        if not csv_path.exists():
            self.log.warning(
                "%s.csv manquant -- lancer : python fetcher_fao_csv.py --download --dir %s",
                dataset, self.data_dir,
            )
            return []

        rows = self._load_csv(csv_path)
        if not rows:
            return []

        # Detecter le format : large (Y2010), triannuel (Y20102012) ou long (Year/Value)
        fields     = list(rows[0].keys()) if rows else []
        year_fmt   = config.get("year_format", "annual")
        if year_fmt == "3yr":
            year_cols = {year: f"Y{year}{year+2}" for year in range(year_from, year_to + 1)
                        if f"Y{year}{year+2}" in fields}
        else:
            year_cols = {year: f"Y{year}" for year in range(year_from, year_to + 1)
                        if f"Y{year}" in fields}
        has_year_col = "Year" in fields or "year" in fields

        raw_records: dict[tuple, list[float]] = {}

        for row in rows:
            # Filtre element et item
            elem = str(row.get("Element Code", row.get("element_code", ""))).strip()
            item = str(row.get("Item Code", row.get("item_code", ""))).strip()
            if elem != element_code or item != item_code:
                continue

            # Resolution pays
            area_code = str(row.get("Area Code", row.get("Area Code (M49)", ""))).strip().lstrip("'")
            iso3 = FAO_AREA_TO_ISO3.get(area_code)
            if not iso3 or iso3 not in AFRICAN_ISO3:
                continue

            if year_cols:
                # Format large : Y2010, Y2011...
                for year, col in year_cols.items():
                    raw = row.get(col, "").strip()
                    v   = self._parse_fao_value(raw)
                    key = (iso3, year)
                    if key not in raw_records:
                        raw_records[key] = []
                    if v is not None:
                        raw_records[key].append(v)
            elif has_year_col:
                # Format long : colonnes Year et Value
                year_raw  = row.get("Year", row.get("year", "")).strip()
                value_raw = row.get("Value", row.get("value", "")).strip()
                try:
                    year = int(year_raw)
                    if not (year_from <= year <= year_to):
                        continue
                except (ValueError, TypeError):
                    continue
                v   = self._parse_fao_value(value_raw)
                key = (iso3, year)
                if key not in raw_records:
                    raw_records[key] = []
                if v is not None:
                    raw_records[key].append(v)

        # Agregation
        records: list[DataRecord] = []
        for (iso3, year), values in raw_records.items():
            if not values:
                records.append({"iso3": iso3, "year": year, "value": None})
            elif agg_mode == "sum":
                records.append({"iso3": iso3, "year": year, "value": sum(values)})
            else:
                records.append({"iso3": iso3, "year": year, "value": values[0]})

        self.log.info(
            "FAO %s/%s -> %d enregistrements (%d pays)",
            dataset, item_code, len(records),
            len({r["iso3"] for r in records if r.get("value") is not None}),
        )
        return records

    def _load_csv(self, csv_path: Path) -> list[dict]:
        """Charge et met en cache un CSV FAO bulk."""
        key = str(csv_path)
        if key in self._cache:
            return self._cache[key]

        rows = []
        try:
            with open(csv_path, encoding="utf-8-sig", errors="replace") as f:
                reader = csv.DictReader(f)
                rows   = list(reader)
            self.log.info("FAO %s charge -- %d lignes", csv_path.name, len(rows))
        except Exception as exc:
            self.log.error("Erreur chargement %s : %s", csv_path.name, exc)

        self._cache[key] = rows
        return rows

    @staticmethod
    def _parse_fao_value(raw: str) -> Optional[float]:
        """Convertit une cellule FAO en float."""
        if not raw:
            return None
        cleaned = raw.strip()
        if cleaned.lower() in ("", "na", "n/a", "...", "..", "-", "nan"):
            return None
        cleaned = cleaned.replace(",", "")
        try:
            return float(cleaned)
        except ValueError:
            return None

    @staticmethod
    def detect_columns(filepath: str | Path, max_rows: int = 3) -> None:
        """Utilitaire debug - affiche la structure du CSV FAO bulk."""
        filepath = Path(filepath)
        with open(filepath, encoding="utf-8-sig", errors="replace") as f:
            reader = csv.DictReader(f)
            fields = reader.fieldnames or []
            year_cols = [f for f in fields if f.startswith("Y") and f[1:].isdigit()]
            print(f"\nFichier : {filepath.name}")
            print(f"Colonnes metadata : {fields[:8]}")
            if year_cols:
                print(f"Colonnes annees   : {year_cols[0]} -> {year_cols[-1]} ({len(year_cols)} annees)")
            print(f"\nPremieres {max_rows} lignes :")
            for i, row in enumerate(reader):
                if i >= max_rows:
                    break
                area    = row.get("Area", "?")
                elem    = row.get("Element Code", "?")
                item    = row.get("Item Code", "?")
                val2020 = row.get("Y2020", row.get("Value", "?"))
                print(f"  {area:30} elem={elem} item={item} Y2020={val2020}")


def download_fao_bulk(data_dir: Path, datasets: list[str] | None = None) -> None:
    """Telecharge les fichiers FAO bulk depuis FAOSTAT."""
    data_dir.mkdir(parents=True, exist_ok=True)
    targets = datasets or list(FAO_BULK_URLS.keys())

    for code in targets:
        url      = FAO_BULK_URLS.get(code)
        csv_name = FAO_BULK_CSV.get(code)
        if not url or not csv_name:
            continue

        dest = data_dir / f"{code}.csv"
        print(f"  Telechargement {code}... ", end="", flush=True)
        try:
            zip_path = data_dir / f"_tmp_{code}.zip"
            urllib.request.urlretrieve(url, zip_path)
            with zipfile.ZipFile(zip_path, "r") as z:
                # Trouver le CSV principal dans le ZIP
                csv_files = [n for n in z.namelist() if n.endswith("_Africa.csv") and "NOFLAG" not in n]
                if csv_files:
                    with z.open(csv_files[0]) as src, open(dest, "wb") as dst:
                        dst.write(src.read())
                    print(f"OK ({dest.stat().st_size // 1024}K)")
                else:
                    print(f"ERREUR - CSV non trouve dans ZIP")
            zip_path.unlink(missing_ok=True)
        except Exception as exc:
            print(f"ERREUR - {exc}")


# ── CLI ───────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(
        description="OSA Fetcher - FAO FAOSTAT CSV bulk",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Fichiers CSV FAO dans --dir :
  GF.csv   -> ENV_FOR (superficie forestiere)
  RL.csv   -> ENV_LAN, ENV_ECO, ENV_PRO, ENV_WAT (utilisation terres)
  FBS.csv  -> ENV_FIS (disponibilite poisson)
  FS.csv   -> HUM_FOO (sous-alimentation)
  QCL.csv  -> ECO_AGR (production cereales)
  OA.csv   -> HUM_POP (population)
  GT.csv   -> ENV_CO2 (emissions agriculture)

Telechargement automatique :
  python fetcher_fao_csv.py --download --dir data/fao/

Exemples :
  python fetcher_fao_csv.py --dir data/fao/ --list-missing
  python fetcher_fao_csv.py --dir data/fao/ --dry-run
  python fetcher_fao_csv.py --dir data/fao/ --indicator ENV_FOR
  python fetcher_fao_csv.py --dir data/fao/ --detect GF.csv
        """,
    )
    parser.add_argument("--dir",          type=str, required=True)
    parser.add_argument("--from",         type=int, dest="year_from", default=2010)
    parser.add_argument("--to",           type=int, dest="year_to",   default=2024)
    parser.add_argument("--indicator",    type=str, default=None)
    parser.add_argument("--dry-run",      action="store_true")
    parser.add_argument("--list-missing", action="store_true")
    parser.add_argument("--download",     action="store_true",
                        help="Telecharger les fichiers FAO bulk manquants")
    parser.add_argument("--detect",       type=str, default=None,
                        help="Afficher la structure d'un fichier CSV")
    args = parser.parse_args()

    data_dir = Path(args.dir)

    if args.download:
        print(f"\nTelechargement FAO bulk dans {data_dir} :")
        missing = [k for k, v in FAO_BULK_URLS.items()
                   if not (data_dir / f"{k}.csv").exists()]
        if not missing:
            print("  Tous les fichiers sont deja presents.")
        else:
            download_fao_bulk(data_dir, missing)
        return

    if args.detect:
        FAOCSVFetcher.detect_columns(data_dir / args.detect)
        return

    if args.list_missing:
        print(f"\nFichiers FAO necessaires dans {data_dir} :")
        for code, url in FAO_BULK_URLS.items():
            path   = data_dir / f"{code}.csv"
            status = "present" if path.exists() else "MANQUANT"
            size   = f"{path.stat().st_size // 1024}K" if path.exists() else "-"
            inds   = [k for k, v in FAO_INDICATOR_MAP.items() if v["dataset"] == code]
            print(f"  {code}.csv  {status:10} {size:8}  -> {', '.join(inds)}")
        return

    fetcher = FAOCSVFetcher(data_dir=str(data_dir), dry_run=args.dry_run)
    try:
        fetcher.connect()
        result = fetcher.run(args.year_from, args.year_to, args.indicator)
        sys.exit(0 if not result["failed"] else 1)
    finally:
        fetcher.disconnect()


if __name__ == "__main__":
    main()