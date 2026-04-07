"""
============================================================
OSA / ISA OBSERVATORY
fetcher_usgs_csv.py — Fetcher USGS Minerals (CSV)
============================================================
Couvre : 6 indicateurs pilier PMIN (souveraineté minière)
Source : U.S. Geological Survey — National Minerals Information Center
URL    : https://www.usgs.gov/centers/national-minerals-information-center/

USGS publie chaque année le "Minerals Yearbook" et le
"Mineral Commodity Summaries" — référence mondiale pour
les données de production minière par pays et par minerai.

Datasets USGS nécessaires :
  MCS  → Mineral Commodity Summaries (annuel, gratuit)
         Production, réserves, valeur par pays
  MYB  → Minerals Yearbook (détaillé, par minerai)
         Emploi, investissements, exportations

Téléchargement :
  MCS  : https://www.usgs.gov/publications/mineral-commodity-summaries-2024
         → Télécharger les tableaux Excel/CSV "World Mine Production and Reserves"
         → Placer dans data/usgs/MCS_2024.csv

  MYB  : https://www.usgs.gov/centers/national-minerals-information-center/minerals-yearbook-metals-and
         → Par minerai → Tables de production par pays
         → Consolider dans data/usgs/MYB_production.csv

  COUNTRY : https://www.usgs.gov/centers/national-minerals-information-center/country-chapter
            → Chapitres par pays (Afrique)
            → Consolider dans data/usgs/USGS_country.csv

Note SNCTM :
  MIN_LOC, MIN_TRAC, MIN_SEC sont des indicateurs souverains
  qui nécessitent des données nationales SNCTM.
  Un template d'import manuel est fourni : SNCTM_template.csv

Usage :
  python fetcher_usgs_csv.py --dir data/usgs/
  python fetcher_usgs_csv.py --dir data/usgs/ --dry-run
  python fetcher_usgs_csv.py --dir data/usgs/ --indicator MIN_RES
  python fetcher_usgs_csv.py --dir data/usgs/ --list-missing
  python fetcher_usgs_csv.py --dir data/usgs/ --snctm data/snctm/SNCTM_2024.csv
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

# ── Mapping noms de pays USGS → ISO-3 ─────────────────────
# USGS utilise des noms anglais sans standardisation ISO

USGS_COUNTRY_TO_ISO3: dict[str, str] = {
    "Algeria":                    "DZA",
    "Egypt":                      "EGY",
    "Libya":                      "LBY",
    "Morocco":                    "MAR",
    "Mauritania":                 "MRT",
    "Sudan":                      "SDN",
    "Tunisia":                    "TUN",
    "Benin":                      "BEN",
    "Burkina Faso":               "BFA",
    "Côte d'Ivoire":              "CIV",
    "Cote d'Ivoire":              "CIV",
    "Ivory Coast":                "CIV",
    "Cape Verde":                 "CPV",
    "Cabo Verde":                 "CPV",
    "Gambia":                     "GMB",
    "Ghana":                      "GHA",
    "Guinea":                     "GIN",
    "Guinea-Bissau":              "GNB",
    "Liberia":                    "LBR",
    "Mali":                       "MLI",
    "Niger":                      "NER",
    "Nigeria":                    "NGA",
    "Sierra Leone":               "SLE",
    "Senegal":                    "SEN",
    "Togo":                       "TGO",
    "Burundi":                    "BDI",
    "Comoros":                    "COM",
    "Djibouti":                   "DJI",
    "Eritrea":                    "ERI",
    "Ethiopia":                   "ETH",
    "Kenya":                      "KEN",
    "Madagascar":                 "MDG",
    "Malawi":                     "MWI",
    "Mauritius":                  "MUS",
    "Mozambique":                 "MOZ",
    "Rwanda":                     "RWA",
    "Seychelles":                 "SYC",
    "Somalia":                    "SOM",
    "South Sudan":                "SSD",
    "Tanzania":                   "TZA",
    "Uganda":                     "UGA",
    "Zambia":                     "ZMB",
    "Zimbabwe":                   "ZWE",
    "Angola":                     "AGO",
    "Cameroon":                   "CMR",
    "Central African Republic":   "CAF",
    "Chad":                       "TCD",
    "Congo, Republic of the":     "COG",
    "Congo (Brazzaville)":        "COG",
    "Congo":                      "COG",
    "Congo, Democratic Republic": "COD",
    "Congo (Kinshasa)":           "COD",
    "DRC":                        "COD",
    "Zaire":                      "COD",
    "Equatorial Guinea":          "GNQ",
    "Gabon":                      "GAB",
    "Sao Tome and Principe":      "STP",
    "Botswana":                   "BWA",
    "Eswatini":                   "SWZ",
    "Swaziland":                  "SWZ",
    "Lesotho":                    "LSO",
    "Namibia":                    "NAM",
    "South Africa":               "ZAF",
}

# ── Mapping indicateurs OSA → config USGS ─────────────────

USGS_INDICATOR_MAP: dict = {

    "MIN_RES": {
        "dataset":    "MCS",
        "column":     "reserves_mt",
        "name_fr":    "Réserves minières (millions de tonnes)",
        "unit_code":  "TONNES",
        "direction":  "+",
        "multiplier": 1_000_000.0,   # Mt → tonnes
        "notes":      """USGS MCS — réserves minières prouvées en millions de tonnes.
                        Agrégat de tous les minerais principaux par pays.
                        Mis à jour annuellement dans Mineral Commodity Summaries.""",
    },
    "MIN_EXP": {
        "dataset":    "MCS",
        "column":     "exports_usd",
        "name_fr":    "Exportations minières (USD)",
        "unit_code":  "USD",
        "direction":  "+",
        "multiplier": 1_000_000.0,   # millions USD → USD
        "notes":      """USGS MCS — valeur des exportations de minerais en USD.
                        Couvre les principaux minerais : or, diamant, cuivre, cobalt, etc.""",
    },
    "MIN_EMP": {
        "dataset":    "MYB",
        "column":     "employment",
        "name_fr":    "Emplois secteur minier (personnes)",
        "unit_code":  "PERSONS",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      """USGS MYB — emplois directs dans le secteur minier.
                        Disponible dans les country chapters du Minerals Yearbook.""",
    },
    "MIN_INV": {
        "dataset":    "MYB",
        "column":     "investment_usd",
        "name_fr":    "Investissements miniers (USD)",
        "unit_code":  "USD",
        "direction":  "+",
        "multiplier": 1_000_000.0,
        "notes":      """USGS MYB — investissements dans le secteur minier (IDE + national).
                        Donnée partielle — bonne couverture pour grands producteurs africains.""",
    },
    "MIN_DIV": {
        "dataset":    "MCS",
        "column":     "commodity_count",
        "name_fr":    "Nombre de minerais exploités (diversification)",
        "unit_code":  "NB",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      """USGS MCS — nombre de minerais différents extraits commercialement.
                        Proxy diversification minière — un pays avec plusieurs minerais
                        est moins vulnérable aux chocs de prix d'une seule commodité.""",
    },
    "MIN_ENV": {
        "dataset":    "MCS",
        "column":     "production_mt",
        "name_fr":    "Production minière totale (Mt — proxy impact env.)",
        "unit_code":  "TONNES",
        "direction":  "-",
        "multiplier": 1_000_000.0,
        "notes":      """USGS MCS — production totale en Mt.
                        Proxy impact environnemental minier — direction négative :
                        plus la production est haute, plus l'impact potentiel est élevé.
                        À affiner avec données SNCTM sur la réhabilitation des sites.""",
    },
}

# ── Indicateurs souverains SNCTM (import manuel) ──────────

SNCTM_INDICATOR_MAP: dict = {
    "MIN_LOC": {
        "name_fr": "Transformation locale des minerais (%)",
        "unit_code": "PERCENT",
        "direction": "+",
        "notes": "SNCTM — part des minerais transformés localement avant export.",
    },
    "MIN_TRAC": {
        "name_fr": "Traçabilité chaîne minière (indice SNCTM)",
        "unit_code": "SCORE_0_100",
        "direction": "+",
        "notes": "SNCTM — indice de traçabilité souveraine. Donnée nationale exclusive.",
    },
    "MIN_SEC": {
        "name_fr": "Sécurité sites miniers (indice SNCTM)",
        "unit_code": "SCORE_0_100",
        "direction": "+",
        "notes": "SNCTM — incidents de sécurité et contrôle des sites miniers.",
    },
}


class USGSCSVFetcher(BaseFetcher):

    PROVIDER_CODE = "USGS"
    ENDPOINT_CODE = "WB_COUNTRY_INDICATOR"
    INDICATOR_MAP = USGS_INDICATOR_MAP

    def __init__(
        self,
        data_dir:      str,
        snctm_file:    Optional[str] = None,
        dry_run:       bool = False,
    ) -> None:
        super().__init__(dry_run=dry_run)
        self.data_dir   = Path(data_dir)
        self.snctm_file = Path(snctm_file) if snctm_file else None

    def fetch_indicator(
        self,
        osa_code:  str,
        config:    dict,
        year_from: int,
        year_to:   int,
    ) -> list[DataRecord]:
        """Dispatch vers le bon parser selon le dataset."""
        dataset = config["dataset"]
        column  = config["column"]

        if dataset == "MCS":
            return self._parse_mcs(osa_code, column, year_from, year_to)
        elif dataset == "MYB":
            return self._parse_myb(osa_code, column, year_from, year_to)
        else:
            self.log.error("Dataset USGS inconnu : %s", dataset)
            return []

    # ── MCS ───────────────────────────────────────────────

    def _parse_mcs(
        self,
        osa_code:  str,
        column:    str,
        year_from: int,
        year_to:   int,
    ) -> list[DataRecord]:
        """
        Parse USGS Mineral Commodity Summaries.

        Format MCS attendu (CSV normalisé) :
        country | year | commodity | reserves_mt | production_mt |
        exports_usd | commodity_count | ...

        USGS publie par minerai — il faut consolider par pays.
        Le fichier MCS_2024.csv doit être pré-agrégé par pays et par année.

        Script de consolidation disponible : usgs_consolidate.py
        """
        csv_path = self.data_dir / "MCS_2024.csv"
        if not csv_path.exists():
            # Essayer nom générique
            candidates = list(self.data_dir.glob("MCS_*.csv"))
            if candidates:
                csv_path = sorted(candidates)[-1]
                self.log.info("MCS trouvé : %s", csv_path.name)
            else:
                self.log.warning(
                    "MCS_2024.csv manquant dans %s\n"
                    "  Télécharger : https://www.usgs.gov/publications/mineral-commodity-summaries-2024\n"
                    "  Puis consolider avec : python usgs_consolidate.py",
                    self.data_dir,
                )
                return []

        return self._parse_generic_csv(csv_path, column, year_from, year_to)

    # ── MYB ───────────────────────────────────────────────

    def _parse_myb(
        self,
        osa_code:  str,
        column:    str,
        year_from: int,
        year_to:   int,
    ) -> list[DataRecord]:
        """
        Parse USGS Minerals Yearbook (country chapters).

        Format MYB attendu :
        country | year | employment | investment_usd | ...
        """
        csv_path = self.data_dir / "MYB_production.csv"
        if not csv_path.exists():
            candidates = list(self.data_dir.glob("MYB_*.csv"))
            if candidates:
                csv_path = sorted(candidates)[-1]
            else:
                self.log.warning(
                    "MYB_production.csv manquant dans %s\n"
                    "  Télécharger : https://www.usgs.gov/centers/national-minerals-information-center/"
                    "minerals-yearbook-metals-and",
                    self.data_dir,
                )
                return []

        return self._parse_generic_csv(csv_path, column, year_from, year_to)

    # ── Parseur générique CSV USGS ─────────────────────────

    def _parse_generic_csv(
        self,
        csv_path:  Path,
        column:    str,
        year_from: int,
        year_to:   int,
    ) -> list[DataRecord]:
        """
        Parseur générique pour les CSV USGS normalisés.

        Supporte deux formats :
        - Format large  : country | 2010 | 2011 | ... (une colonne par année)
        - Format long   : country | year | value (une ligne par pays/année)
        """
        records: list[DataRecord] = []

        try:
            with open(csv_path, encoding="utf-8-sig", errors="replace") as f:
                sample    = f.read(2048)
                f.seek(0)
                delimiter = "\t" if "\t" in sample else ","
                reader    = csv.DictReader(f, delimiter=delimiter)
                fieldnames = reader.fieldnames or []

                # Détecter le format
                is_wide = any(str(y) in fieldnames for y in range(year_from, year_to + 1))
                is_long = "year" in [f.lower() for f in fieldnames] and \
                          "value" in [f.lower() for f in fieldnames]

                for row in reader:
                    # Filtrer sur la colonne indicateur si format multi-colonnes
                    if "indicator" in [f.lower() for f in fieldnames]:
                        ind = row.get("indicator", row.get("Indicator", "")).strip()
                        if ind and ind.lower() != column.lower():
                            continue

                    # Résolution pays
                    country_raw = (
                        row.get("country") or row.get("Country") or
                        row.get("area")    or row.get("Area") or
                        list(row.values())[0]
                    ).strip()
                    iso3 = USGS_COUNTRY_TO_ISO3.get(country_raw)
                    if not iso3 or iso3 not in AFRICAN_ISO3:
                        continue

                    if is_wide:
                        for year in range(year_from, year_to + 1):
                            raw = (
                                row.get(str(year)) or
                                row.get(f"{year}") or ""
                            ).strip()
                            value = self._parse_usgs_value(raw)
                            records.append({"iso3": iso3, "year": year, "value": value})

                    elif is_long:
                        year_raw = (row.get("year") or row.get("Year", "")).strip()
                        try:
                            year = int(year_raw)
                            if not (year_from <= year <= year_to):
                                continue
                        except (ValueError, TypeError):
                            continue
                        raw   = (row.get(column) or row.get("value") or "").strip()
                        value = self._parse_usgs_value(raw)
                        records.append({"iso3": iso3, "year": year, "value": value})

                    else:
                        # Format direct — colonne = indicateur
                        raw   = row.get(column, "").strip()
                        value = self._parse_usgs_value(raw)
                        year_raw = row.get("year", row.get("Year", "")).strip()
                        try:
                            year = int(year_raw)
                        except (ValueError, TypeError):
                            continue
                        if year_from <= year <= year_to:
                            records.append({"iso3": iso3, "year": year, "value": value})

        except Exception as exc:
            self.log.error("Erreur parsing USGS %s : %s", csv_path.name, exc)

        self.log.debug("USGS %s → %d enregistrements", column, len(records))
        return records

    # ── SNCTM import manuel ────────────────────────────────

    def run_snctm(
        self,
        year_from: int,
        year_to:   int,
    ) -> dict:
        """
        Importe les indicateurs souverains SNCTM depuis CSV manuel.

        Format SNCTM_template.csv :
        indicator_code | country_iso3 | year | value | source_note

        Utiliser le template : data/snctm/SNCTM_template.csv
        """
        if not self.snctm_file or not self.snctm_file.exists():
            self.log.warning(
                "Fichier SNCTM non fourni ou introuvable.\n"
                "  Template disponible dans : data/snctm/SNCTM_template.csv\n"
                "  Remplir avec les données nationales et relancer avec :\n"
                "  python fetcher_usgs_csv.py --dir data/usgs/ "
                "--snctm data/snctm/SNCTM_2024.csv"
            )
            return {"provider": "SNCTM", "inserted": 0, "rejected": 0, "failed": []}

        self.log.info("Import SNCTM depuis %s", self.snctm_file.name)
        total_inserted = 0
        total_rejected = 0
        failed: list[str] = []

        try:
            with open(self.snctm_file, encoding="utf-8-sig", errors="replace") as f:
                sample    = f.read(1024)
                f.seek(0)
                delimiter = "\t" if "\t" in sample else ","
                reader    = csv.DictReader(f, delimiter=delimiter)

                records_by_indicator: dict[str, list[DataRecord]] = {}

                for row in reader:
                    osa_code = row.get("indicator_code", "").strip().upper()
                    if osa_code not in SNCTM_INDICATOR_MAP:
                        continue

                    iso3 = row.get("country_iso3", "").strip().upper()
                    if iso3 not in AFRICAN_ISO3:
                        continue

                    try:
                        year = int(row.get("year", "").strip())
                        if not (year_from <= year <= year_to):
                            continue
                    except (ValueError, TypeError):
                        continue

                    raw   = row.get("value", "").strip()
                    value = self._parse_usgs_value(raw)

                    if osa_code not in records_by_indicator:
                        records_by_indicator[osa_code] = []
                    records_by_indicator[osa_code].append(
                        {"iso3": iso3, "year": year, "value": value}
                    )

                for osa_code, records in records_by_indicator.items():
                    config     = SNCTM_INDICATOR_MAP[osa_code]
                    multiplier = config.get("multiplier", 1.0)
                    ins, rej   = self.insert_records(osa_code, records, multiplier)
                    total_inserted += ins
                    total_rejected += rej
                    self.log.info("SNCTM %-12s → %d insérés", osa_code, ins)

        except Exception as exc:
            self.log.error("Erreur import SNCTM : %s", exc)
            failed.append("SNCTM")

        return {
            "provider":  "SNCTM",
            "inserted":  total_inserted,
            "rejected":  total_rejected,
            "failed":    failed,
        }

    @staticmethod
    def _parse_usgs_value(raw: str) -> Optional[float]:
        """Convertit une cellule USGS en float. Gère W, XX, e, r, --."""
        if not raw:
            return None
        # Supprimer notes USGS : W=withheld, XX=not applicable, e=estimate, r=revised
        cleaned = raw.replace(",", "").replace(" ", "")
        cleaned = cleaned.rstrip("eErRpPwW")
        cleaned = cleaned.strip("()")
        if cleaned.lower() in ("w", "xx", "--", "na", "n/a", "...", ""):
            return None
        try:
            return float(cleaned)
        except ValueError:
            return None

    @staticmethod
    def detect_columns(filepath: str | Path) -> None:
        filepath = Path(filepath)
        with open(filepath, encoding="utf-8-sig", errors="replace") as f:
            sample = f.read(2048)
            f.seek(0)
            delim  = "\t" if "\t" in sample else ","
            reader = csv.DictReader(f, delimiter=delim)
            print(f"\nColonnes ({filepath.name}) :")
            cols = reader.fieldnames or []
            for i in range(0, len(cols), 8):
                print("  " + " | ".join(cols[i:i+8]))
            print("\nPremière ligne :")
            for row in reader:
                print(f"  {dict(list(row.items())[:8])}")
                break


def main() -> None:
    parser = argparse.ArgumentParser(
        description="OSA Fetcher — USGS CSV + SNCTM import",
        epilog="""
Fichiers nécessaires dans --dir :
  MCS_2024.csv         Mineral Commodity Summaries (agrégé par pays)
  MYB_production.csv   Minerals Yearbook (emploi, investissements)

Téléchargements USGS :
  MCS  : https://www.usgs.gov/publications/mineral-commodity-summaries-2024
  MYB  : https://www.usgs.gov/centers/national-minerals-information-center/
         minerals-yearbook-metals-and

Indicateurs souverains SNCTM (MIN_LOC, MIN_TRAC, MIN_SEC) :
  Utiliser le template : data/snctm/SNCTM_template.csv
  Remplir manuellement puis importer avec --snctm

Exemples :
  python fetcher_usgs_csv.py --dir data/usgs/
  python fetcher_usgs_csv.py --dir data/usgs/ --dry-run
  python fetcher_usgs_csv.py --dir data/usgs/ --indicator MIN_RES
  python fetcher_usgs_csv.py --dir data/usgs/ --list-missing
  python fetcher_usgs_csv.py --dir data/usgs/ --snctm data/snctm/SNCTM_2024.csv
  python fetcher_usgs_csv.py --dir data/usgs/ --detect MCS_2024.csv
        """,
    )
    parser.add_argument("--dir",          type=str, required=True)
    parser.add_argument("--from",         type=int, dest="year_from", default=2010)
    parser.add_argument("--to",           type=int, dest="year_to",   default=2024)
    parser.add_argument("--indicator",    type=str, default=None)
    parser.add_argument("--dry-run",      action="store_true")
    parser.add_argument("--snctm",        type=str, default=None,
                        help="Chemin vers le fichier SNCTM CSV")
    parser.add_argument("--list-missing", action="store_true")
    parser.add_argument("--detect",       type=str, default=None,
                        help="Afficher colonnes d'un fichier CSV (ex: MCS_2024.csv)")
    args = parser.parse_args()

    if args.detect:
        USGSCSVFetcher.detect_columns(Path(args.dir) / args.detect)
        return

    if args.list_missing:
        data_dir = Path(args.dir)
        needed = ["MCS_2024.csv", "MYB_production.csv"]
        print(f"\nFichiers USGS nécessaires dans {data_dir} :")
        for f in needed:
            path   = data_dir / f
            status = "✓ présent" if path.exists() else "✗ manquant"
            print(f"  {f} — {status}")
        print("\nIndicateurs souverains SNCTM (import manuel) :")
        for code, cfg in SNCTM_INDICATOR_MAP.items():
            print(f"  {code} — {cfg['name_fr']}")
        print(
            "\n  Template : data/snctm/SNCTM_template.csv\n"
            "  Colonnes : indicator_code | country_iso3 | year | value | source_note"
        )
        return

    fetcher = USGSCSVFetcher(
        data_dir=args.dir,
        snctm_file=args.snctm,
        dry_run=args.dry_run,
    )
    try:
        fetcher.connect()

        # USGS indicators
        result = fetcher.run(args.year_from, args.year_to, args.indicator)

        # SNCTM si fichier fourni
        if args.snctm and not args.indicator:
            snctm_result = fetcher.run_snctm(args.year_from, args.year_to)
            result["inserted"] += snctm_result["inserted"]
            result["rejected"] += snctm_result["rejected"]

        sys.exit(0 if not result["failed"] else 1)
    finally:
        fetcher.disconnect()


if __name__ == "__main__":
    main()
