"""
============================================================
OSA / ISA OBSERVATORY
fetcher_fao_csv.py — Fetcher FAO (CSV direct)
============================================================
Remplace fetcher_fao.py — l'API FAOSTAT retourne régulièrement
des erreurs 521 (serveur hors ligne). Le CSV direct est fiable.

Indicateurs couverts : 10 (PENV + PHUM)
Source : FAOSTAT — Food and Agriculture Organization
URL    : https://www.fao.org/faostat/en/#data

Téléchargement par dataset :
  Chaque indicateur FAO appartient à un dataset différent.
  Procédure pour chaque dataset :
  1. Aller sur https://www.fao.org/faostat/en/#data
  2. Choisir le dataset (ex: "Land Use")
  3. Sélectionner : Countries → Africa / All African countries
  4. Sélectionner : Elements et Items nécessaires
  5. Télécharger CSV (All years)
  6. Placer dans data/fao/{DATASET}.csv

Datasets nécessaires :
  RL  → Land Use           → data/fao/RL.csv
  QCL → Crops Production   → data/fao/QCL.csv
  FS  → Food Security      → data/fao/FS.csv
  GF  → Forest Resources   → data/fao/GF.csv
  OA  → Population         → data/fao/OA.csv
  FBS → Food Balance Sheets→ data/fao/FBS.csv

Usage :
  python fetcher_fao_csv.py --dir data/fao/
  python fetcher_fao_csv.py --dir data/fao/ --dry-run
  python fetcher_fao_csv.py --dir data/fao/ --indicator ENV_FOR
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

from fetcher_base import BaseFetcher, DataRecord, AFRICAN_ISO3

load_dotenv()

logging.basicConfig(
    level=os.getenv("OSA_LOG_LEVEL", "INFO"),
    format="%(asctime)s | %(levelname)-8s | %(message)s",
)

# ── Mapping codes numériques FAO → ISO-3 ──────────────────

FAO_AREA_TO_ISO3: dict[str, str] = {
    "4":"DZA",  "59":"EGY",  "124":"LBY", "143":"MAR", "144":"MRT",
    "238":"SDN","249":"TUN", "23":"BEN",  "233":"BFA", "107":"CIV",
    "35":"CPV", "74":"GMB",  "81":"GHA",  "86":"GIN",  "175":"GNB",
    "122":"LBR","132":"MLI", "158":"NER", "159":"NGA", "220":"SLE",
    "195":"SEN","243":"TGO", "29":"BDI",  "45":"COM",  "72":"DJI",
    "178":"ERI","238":"ETH", "114":"KEN", "129":"MDG", "130":"MWI",
    "146":"MUS","149":"MOZ", "184":"RWA", "196":"SYC", "201":"SOM",
    "277":"SSD","215":"TZA", "253":"UGA", "260":"ZMB", "181":"ZWE",
    "7":"AGO",  "32":"CMR",  "37":"CAF",  "39":"TCD",  "46":"COG",
    "250":"COD","61":"GNQ",  "74":"GAB",  "193":"STP", "20":"BWA",
    "209":"SWZ","119":"LSO", "153":"NAM", "202":"ZAF",
}

# ── Mapping indicateurs OSA → config FAOSTAT ──────────────

FAO_INDICATOR_MAP: dict = {

    # ── PENV — Environnemental ─────────────────────────────
    "ENV_FOR": {
        "dataset":    "GF",
        "element_code": "5110",
        "item_code":  "6646",
        "name_fr":    "Superficie forestière (1000 ha)",
        "unit_code":  "INDEX",
        "direction":  "+",
        "multiplier": 1.0,
        "agg":        "sum",
        "notes":      "GF — superficie forêts. Ramener à superficie totale pour %.",
    },
    "ENV_LAN": {
        "dataset":    "RL",
        "element_code": "5110",
        "item_code":  "6655",
        "name_fr":    "Terres arables (1000 ha)",
        "unit_code":  "INDEX",
        "direction":  "+",
        "multiplier": 1.0,
        "agg":        "sum",
        "notes":      "RL — terres arables disponibles",
    },
    "ENV_ECO": {
        "dataset":    "RL",
        "element_code": "5110",
        "item_code":  "6725",
        "name_fr":    "Cultures permanentes (1000 ha)",
        "unit_code":  "INDEX",
        "direction":  "+",
        "multiplier": 1.0,
        "agg":        "sum",
        "notes":      "RL — proxy soutenabilité agro-écologique",
    },
    "ENV_PRO": {
        "dataset":    "RL",
        "element_code": "5110",
        "item_code":  "6670",
        "name_fr":    "Prairies permanentes (1000 ha)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "agg":        "sum",
        "notes":      "RL — proxy aires protégées agropastorales",
    },
    "ENV_WAT": {
        "dataset":    "RL",
        "element_code": "5110",
        "item_code":  "4551",
        "name_fr":    "Terres irriguées (1000 ha)",
        "unit_code":  "INDEX",
        "direction":  "+",
        "multiplier": 1.0,
        "agg":        "sum",
        "notes":      "RL — proxy gestion ressources eau agricoles",
    },
    "ENV_FIS": {
        "dataset":    "FBS",
        "element_code": "5142",
        "item_code":  "2761",
        "name_fr":    "Disponibilité alimentaire poisson (kg/hab/an)",
        "unit_code":  "INDEX",
        "direction":  "+",
        "multiplier": 1.0,
        "agg":        "first",
        "notes":      "FBS — proxy stocks halieutiques disponibles",
    },

    # ── PHUM — Humain ──────────────────────────────────────
    "HUM_FOO": {
        "dataset":    "FS",
        "element_code": "6121",
        "item_code":  "21010",
        "name_fr":    "Prévalence sous-alimentation (%)",
        "unit_code":  "PERCENT",
        "direction":  "-",
        "multiplier": 1.0,
        "agg":        "first",
        "notes":      "FS — SDG 2.1.1. Fréquence triennale — interpolation appliquée.",
    },
    "ECO_AGR": {
        "dataset":    "QCL",
        "element_code": "5510",
        "item_code":  "2041",
        "name_fr":    "Production céréales totale (tonnes)",
        "unit_code":  "TONNES",
        "direction":  "+",
        "multiplier": 1.0,
        "agg":        "sum",
        "notes":      "QCL — production céréalière totale",
    },
    "HUM_POP": {
        "dataset":    "OA",
        "element_code": "511",
        "item_code":  "3010",
        "name_fr":    "Population totale (milliers)",
        "unit_code":  "PERSONS",
        "direction":  "+",
        "multiplier": 1000.0,   # milliers → personnes
        "agg":        "first",
        "notes":      "OA — population totale FAO. Cohérent avec WB.",
    },
    "ENV_CO2": {
        "dataset":    "GT",
        "element_code": "7231",
        "item_code":  "1711",
        "name_fr":    "Émissions CO2 agriculture (Gg CO2 eq)",
        "unit_code":  "TONNES",
        "direction":  "-",
        "multiplier": 1000.0,   # Gg → tonnes
        "agg":        "sum",
        "notes":      "GT — émissions secteur agricole. Complète WB ENV_CO2.",
    },
}


class FAOCSVFetcher(BaseFetcher):

    PROVIDER_CODE = "FAO"
    ENDPOINT_CODE = "FAO_INDICATOR"
    INDICATOR_MAP = FAO_INDICATOR_MAP

    def __init__(self, data_dir: str = "data/fao", dry_run: bool = False) -> None:
        super().__init__(dry_run=dry_run)
        self.data_dir = Path(data_dir)

    def fetch_indicator(
        self,
        osa_code:  str,
        config:    dict,
        year_from: int,
        year_to:   int,
    ) -> list[DataRecord]:
        """Parse le CSV FAOSTAT local pour un dataset/element/item."""
        dataset      = config["dataset"]
        element_code = str(config["element_code"])
        item_code    = str(config["item_code"])
        agg_mode     = config.get("agg", "first")

        csv_path = self.data_dir / f"{dataset}.csv"
        if not csv_path.exists():
            self.log.warning(
                "Fichier FAO manquant : %s — télécharger depuis fao.org/faostat",
                csv_path,
            )
            return []

        raw_records: dict[tuple, list[float]] = {}

        try:
            with open(csv_path, encoding="utf-8-sig", errors="replace") as f:
                reader = csv.DictReader(f)
                for row in reader:
                    # Filtre element et item
                    elem = str(row.get("Element Code", row.get("element_code", ""))).strip()
                    item = str(row.get("Item Code", row.get("item_code", ""))).strip()

                    if elem != element_code or item != item_code:
                        continue

                    # Résolution pays
                    area_code = str(row.get("Area Code", row.get("area_code", ""))).strip()
                    iso3 = FAO_AREA_TO_ISO3.get(area_code)
                    if not iso3 or iso3 not in AFRICAN_ISO3:
                        continue

                    # Année et valeur
                    year_raw  = row.get("Year", row.get("year", "")).strip()
                    value_raw = row.get("Value", row.get("value", "")).strip()

                    try:
                        year = int(year_raw)
                        if not (year_from <= year <= year_to):
                            continue
                    except (ValueError, TypeError):
                        continue

                    try:
                        v = float(str(value_raw).replace(",", "")) \
                            if value_raw not in ("", "NA", "n/a", "...") else None
                    except (ValueError, TypeError):
                        v = None

                    key = (iso3, year)
                    if key not in raw_records:
                        raw_records[key] = []
                    if v is not None:
                        raw_records[key].append(v)

        except Exception as exc:
            self.log.error("Erreur parsing FAO %s/%s : %s", dataset, item_code, exc)
            return []

        # Agrégation
        records: list[DataRecord] = []
        for (iso3, year), values in raw_records.items():
            if not values:
                records.append({"iso3": iso3, "year": year, "value": None})
            elif agg_mode == "sum":
                records.append({"iso3": iso3, "year": year, "value": sum(values)})
            else:
                records.append({"iso3": iso3, "year": year, "value": values[0]})

        self.log.debug("FAO %s/%s → %d enregistrements", dataset, item_code, len(records))
        return records


def main() -> None:
    parser = argparse.ArgumentParser(
        description="OSA Fetcher — FAO CSV",
        epilog="""
Datasets à télécharger sur https://www.fao.org/faostat/en/#data :
  GF  → Forest Resources Assessment
  RL  → Land Use
  QCL → Crops and Livestock Products
  FS  → Food Security Indicators
  OA  → Annual Population
  FBS → Food Balance Sheets
  GT  → Emissions Agriculture

Procédure :
  1. Choisir le dataset
  2. Sélectionner tous les pays africains
  3. Télécharger CSV (All years)
  4. Placer dans --dir (ex: data/fao/)

Exemples :
  python fetcher_fao_csv.py --dir data/fao/
  python fetcher_fao_csv.py --dir data/fao/ --dry-run
  python fetcher_fao_csv.py --dir data/fao/ --indicator ENV_FOR
  python fetcher_fao_csv.py --dir data/fao/ --list-missing
        """,
    )
    parser.add_argument("--dir",           type=str, required=True,
                        help="Dossier contenant les CSV FAO (ex: data/fao/)")
    parser.add_argument("--from",          type=int, dest="year_from", default=2010)
    parser.add_argument("--to",            type=int, dest="year_to",   default=2024)
    parser.add_argument("--indicator",     type=str, default=None)
    parser.add_argument("--dry-run",       action="store_true")
    parser.add_argument("--list-missing",  action="store_true",
                        help="Lister les fichiers CSV manquants dans --dir")
    args = parser.parse_args()

    if args.list_missing:
        data_dir = Path(args.dir)
        datasets_needed = {
            v["dataset"] for v in FAO_INDICATOR_MAP.values()
        }
        print(f"\nFichiers CSV nécessaires dans {data_dir} :")
        for ds in sorted(datasets_needed):
            path = data_dir / f"{ds}.csv"
            status = "✓ présent" if path.exists() else "✗ manquant"
            print(f"  {ds}.csv — {status}")
        return

    fetcher = FAOCSVFetcher(
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
