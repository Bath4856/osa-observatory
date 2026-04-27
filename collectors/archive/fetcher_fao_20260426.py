"""
============================================================
OSA / ISA OBSERVATORY
fetcher_fao.py — Fetcher FAO (FAOSTAT API)
============================================================
Couvre : 10 indicateurs piliers PENV + PHUM
API    : FAOSTAT REST JSON

Particularités FAO :
  - Chaque indicateur FAO est dans un "dataset" différent
    (QCL pour production, FS pour sécurité alimentaire, etc.)
  - Les requêtes FAO utilisent des codes numériques pour les pays
    (AreaCode) et des codes Item/Element propres à FAO
  - On pré-mappe ISO-3 → code numérique FAO
  - La réponse peut être volumineuse — on filtre par pays et année
  - Certains datasets ont une fréquence triennale (FS notamment)
============================================================
"""

from __future__ import annotations

import argparse
import logging
import os
import sys

from fetcher_base import AFRICAN_ISO3, BaseFetcher, DataRecord

logging.basicConfig(
    level=os.getenv("OSA_LOG_LEVEL", "INFO"),
    format="%(asctime)s | %(levelname)-8s | %(message)s",
)

# ── Codes numériques FAO pour les 54 pays africains ────────
# Source : FAOSTAT area codes (M49 / FAO Area Code)

FAO_AREA_CODE: dict[str, int] = {
    "DZA": 4,   "EGY": 59,  "LBY": 124, "MAR": 143, "MRT": 144,
    "SDN": 206, "TUN": 249, "BEN": 23,  "BFA": 233, "CIV": 107,
    "CPV": 35,  "GMB": 17,  "GHA": 81,  "GIN": 86,  "GNB": 175,
    "LBR": 122, "MLI": 132, "NER": 158, "NGA": 159, "SLE": 220,
    "SEN": 195, "TGO": 243, "BDI": 29,  "COM": 45,  "DJI": 72,
    "ERI": 178, "ETH": 238, "KEN": 114, "MDG": 129, "MWI": 130,
    "MUS": 146, "MOZ": 149, "RWA": 184, "SYC": 196, "SOM": 201,
    "SSD": 277, "TZA": 215, "UGA": 253, "ZMB": 260, "ZWE": 181,
    "AGO": 7,   "CMR": 32,  "CAF": 37,  "TCD": 39,  "COG": 46,
    "COD": 250, "GNQ": 61,  "GAB": 74,  "STP": 193, "BWA": 20,
    "SWZ": 209, "LSO": 119, "NAM": 153, "ZAF": 202,
}

# ── Mapping indicateurs OSA → paramètres FAOSTAT ──────────

FAO_INDICATOR_MAP: dict = {

    # ── PENV : Environnemental ─────────────────────────────
    "ENV_FOR": {
        "dataset":    "GF",           # Global Forest Resources Assessment
        "element":    "5110",         # Area (1000 ha)
        "item":       "6646",         # Forest
        "name_fr":    "Superficie forestière (1000 ha)",
        "unit_code":  "INDEX",
        "direction":  "+",
        "multiplier": 1.0,
        "agg":        "sum",
        "notes":      "FAOSTAT GF — superficie forestière. À rapporter à la superficie totale.",
    },
    "ENV_CO2": {
        "dataset":    "GT",           # Emissions - Agriculture Total
        "element":    "7231",         # Emissions (Gigagrams CO2 eq)
        "item":       "1711",         # Agriculture total
        "name_fr":    "Émissions CO2 agriculture (Gg CO2 eq)",
        "unit_code":  "TONNES",
        "direction":  "-",
        "multiplier": 1000.0,         # Gg → tonnes
        "agg":        "sum",
        "notes":      "FAOSTAT GT — émissions CO2 secteur agricole. Complète WB pour ENV_CO2.",
    },
    "ENV_WAT": {
        "dataset":    "AW",           # Aquastat — Water resources
        "element":    "4551",         # Total renewable freshwater resources (10^9 m3/year)
        "item":       "4551",
        "name_fr":    "Ressources eau douce renouvelables (10^9 m3/an)",
        "unit_code":  "INDEX",
        "direction":  "+",
        "multiplier": 1.0,
        "agg":        "first",
        "notes":      "FAOSTAT Aquastat — fréquence quinquennale — interpolation nécessaire",
    },
    "ENV_LAN": {
        "dataset":    "RL",           # Land use
        "element":    "5110",         # Area (1000 ha)
        "item":       "6655",         # Arable land
        "name_fr":    "Terres arables (1000 ha)",
        "unit_code":  "INDEX",
        "direction":  "+",
        "multiplier": 1.0,
        "agg":        "sum",
        "notes":      "FAOSTAT RL — terres arables. Proxy santé des terres cultivables.",
    },
    "ENV_ECO": {
        "dataset":    "RL",
        "element":    "5110",
        "item":       "6725",         # Permanent crops
        "name_fr":    "Cultures permanentes (1000 ha)",
        "unit_code":  "INDEX",
        "direction":  "+",
        "multiplier": 1.0,
        "agg":        "sum",
        "notes":      "FAOSTAT RL — cultures permanentes. Proxy soutenabilité agro.",
    },

    # ── PHUM : Humain ──────────────────────────────────────
    "HUM_FOO": {
        "dataset":    "FS",           # Food Security Indicators
        "element":    "6121",         # Value
        "item":       "21010",        # Prevalence of undernourishment (%)
        "name_fr":    "Prévalence de sous-alimentation (%)",
        "unit_code":  "PERCENT",
        "direction":  "-",
        "multiplier": 1.0,
        "agg":        "first",
        "notes":      "FAOSTAT FS — SDG 2.1.1. Fréquence triennale, valeur centrale.",
    },
    "ECO_AGR": {
        "dataset":    "QCL",          # Crops and livestock products
        "element":    "5510",         # Production (tonnes)
        "item":       "2041",         # Cereals, Total
        "name_fr":    "Production céréales totale (tonnes)",
        "unit_code":  "TONNES",
        "direction":  "+",
        "multiplier": 1.0,
        "agg":        "sum",
        "notes":      "FAOSTAT QCL — production céréalière totale. Proxy sécurité alimentaire.",
    },
    "ENV_PRO": {
        "dataset":    "RL",
        "element":    "5110",
        "item":       "6670",         # Land under perm. meadows and pastures
        "name_fr":    "Prairies permanentes (1000 ha)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "agg":        "sum",
        "notes":      "FAOSTAT RL — proxy aires protégées et biodiversité agropastorale.",
    },
    "HUM_POP": {
        "dataset":    "OA",           # Annual population
        "element":    "511",          # Total population (1000)
        "item":       "3010",         # Population, total
        "name_fr":    "Population totale (milliers)",
        "unit_code":  "PERSONS",
        "direction":  "+",
        "multiplier": 1000.0,         # milliers → personnes
        "agg":        "first",
        "notes":      "FAOSTAT OA — population totale. Cohérent avec WB pour les calculs per capita.",
    },
    "ENV_FIS": {
        "dataset":    "FBS",          # Food Balance Sheets
        "element":    "5142",         # Food supply (kg/capita/yr)
        "item":       "2761",         # Fish, Seafood
        "name_fr":    "Disponibilité alimentaire poisson (kg/hab/an)",
        "unit_code":  "INDEX",
        "direction":  "+",
        "multiplier": 1.0,
        "agg":        "first",
        "notes":      "FAOSTAT FBS — proxy stocks halieutiques disponibles",
    },
}


# ── Fetcher FAO ────────────────────────────────────────────

class FAOFetcher(BaseFetcher):

    PROVIDER_CODE = "FAO"
    ENDPOINT_CODE = "FAO_INDICATOR"
    INDICATOR_MAP = FAO_INDICATOR_MAP

    FAO_BASE = "https://fenixservices.fao.org/faostat/api/v1/en/data"

    def fetch_indicator(
        self,
        osa_code:  str,
        config:    dict,
        year_from: int,
        year_to:   int,
    ) -> list[DataRecord]:
        """
        Appelle l'API FAOSTAT pour un dataset/élément/item.
        Itère par blocs de pays (FAO n'accepte pas toujours le batch complet).
        """
        dataset  = config["dataset"]
        element  = config["element"]
        item     = config["item"]
        agg_mode = config.get("agg", "first")

        # Codes FAO pour les pays africains disponibles
        area_codes = [
            str(FAO_AREA_CODE[iso3])
            for iso3 in AFRICAN_ISO3
            if iso3 in FAO_AREA_CODE
        ]
        area_param = ",".join(area_codes)

        url    = f"{self.FAO_BASE}/{dataset}/"
        params = {
            "area":        area_param,
            "element":     element,
            "item":        item,
            "year":        ",".join(str(y) for y in range(year_from, year_to + 1)),
            "output_type": "json",
        }

        data = self.http_get(url, params=params)
        if not data:
            return []

        # Inverser le mapping FAO area code → ISO-3
        fao_to_iso3 = {str(v): k for k, v in FAO_AREA_CODE.items()}
        raw_records: dict[tuple, list[float]] = {}  # (iso3, year) → [values]

        try:
            rows = data.get("data", [])
            for row in rows:
                area_code = str(row.get("Area Code") or row.get("area_code") or "")
                year_raw  = row.get("Year") or row.get("year")
                value_raw = row.get("Value") or row.get("value")

                iso3 = fao_to_iso3.get(area_code)
                if not iso3:
                    continue
                if year_raw is None:
                    continue

                try:
                    year = int(year_raw)
                    if not (year_from <= year <= year_to):
                        continue
                except (ValueError, TypeError):
                    continue

                try:
                    v = float(str(value_raw).replace(",", "")) if value_raw not in (None, "") else None
                except (ValueError, TypeError):
                    v = None

                key = (iso3, year)
                if key not in raw_records:
                    raw_records[key] = []
                if v is not None:
                    raw_records[key].append(v)

        except (AttributeError, KeyError) as exc:
            self.log.error("Parsing FAO %s/%s : %s", dataset, item, exc)
            return []

        # Agrégation (sum ou first selon le type d'indicateur)
        records: list[DataRecord] = []
        for (iso3, year), values in raw_records.items():
            if not values:
                records.append({"iso3": iso3, "year": year, "value": None})
            elif agg_mode == "sum":
                records.append({"iso3": iso3, "year": year, "value": sum(values)})
            else:
                records.append({"iso3": iso3, "year": year, "value": values[0]})

        self.log.debug("FAO %s/%s → %d enregistrements", dataset, item, len(records))
        return records


# ── CLI ────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(description="OSA Fetcher — FAO FAOSTAT")
    parser.add_argument("--year",      type=int)
    parser.add_argument("--from",      type=int, dest="year_from", default=2010)
    parser.add_argument("--to",        type=int, dest="year_to",   default=2022)
    parser.add_argument("--indicator", type=str, default=None)
    parser.add_argument("--dry-run",   action="store_true")
    args = parser.parse_args()

    year_from = year_to = args.year if args.year else args.year_from
    year_to   = args.year if args.year else args.year_to

    fetcher = FAOFetcher(dry_run=args.dry_run)
    try:
        fetcher.connect()
        result = fetcher.run(year_from, year_to, args.indicator)
        sys.exit(0 if not result["failed"] else 1)
    finally:
        fetcher.disconnect()


if __name__ == "__main__":
    main()
