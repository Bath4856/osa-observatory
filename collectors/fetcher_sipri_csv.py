"""
============================================================
OSA / ISA OBSERVATORY
fetcher_sipri_csv.py -- Fetcher SIPRI (CSV annuel)
============================================================
Couvre : 3 indicateurs pilier PMIL (souverainete militaire)
Source : Stockholm International Peace Research Institute
URL    : https://www.sipri.org/databases

SIPRI est LA reference mondiale pour les donnees militaires.
Pas d'API publique -- uniquement CSV/Excel telechargeable.
Mise a jour annuelle (avril-mai de chaque annee).

Fichiers CSV SIPRI disponibles (format reel) :
  Separateur      : ; (point-virgule)
  En-tete         : ligne commencant par "Country;Notes;..."
  Valeurs         : virgules decimales europeennes (1,57)
                    "..." = donnee manquante
                    "xxx" = pays inexistant cette annee
  Lignes a ignorer: sous-regions (Africa, North Africa, etc.)

Datasets utilises :
  DEP_GDP.csv          -> MIL_EXP_PCT (depenses militaires % PIB)
  EXp_Current_USD.csv  -> MIL_EXP     (depenses militaires USD courant)
  DEP_Per_capita.csv   -> MIL_EXP_PC  (depenses militaires USD/habitant)

Datasets non disponibles (ignored avec warning) :
  SIPRI_ARMS_IMPORTS.csv -> MIL_DEP
  SIPRI_ARMS_EXPORTS.csv -> MIL_IND
  SIPRI_PKO.csv          -> MIL_MIS (couvert par UNPK)

Telechargement :
  1. MILEX : https://www.sipri.org/databases/milex
     -> "Download SIPRI Military Expenditure Database"
     -> Placer dans data/sipri/

Usage :
  python fetcher_sipri_csv.py --dir data/sipri/
  python fetcher_sipri_csv.py --dir data/sipri/ --dry-run
  python fetcher_sipri_csv.py --dir data/sipri/ --indicator MIL_EXP
  python fetcher_sipri_csv.py --dir data/sipri/ --indicator MIL_EXP_PCT
  python fetcher_sipri_csv.py --dir data/sipri/ --list-missing
  python fetcher_sipri_csv.py --dir data/sipri/ --detect DEP_GDP.csv
============================================================
"""

from __future__ import annotations

import argparse
import csv
import io
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

# ── Lignes de sous-regions SIPRI a ignorer ────────────────
SIPRI_REGION_LABELS = {
    "africa", "north africa", "sub-saharan africa",
    "central africa", "east africa", "west africa",
    "southern africa", "middle east", "europe",
    "north america", "latin america", "asia & oceania",
    "asia and oceania", "central asia and south asia",
    "east asia", "south asia", "southeast asia", "oceania",
    "caribbean", "central america", "south america",
    "nato", "non-nato",
}

# ── Mapping noms de pays SIPRI -> ISO-3 ───────────────────
SIPRI_COUNTRY_TO_ISO3: dict[str, str] = {
    # Afrique du Nord
    "Algeria": "DZA", "Egypt": "EGY", "Libya": "LBY",
    "Morocco": "MAR", "Mauritania": "MRT", "Sudan": "SDN",
    "Tunisia": "TUN",
    # Afrique de l'Ouest
    "Benin": "BEN", "Burkina Faso": "BFA",
    "Cote d'Ivoire": "CIV", "Côte d'Ivoire": "CIV", "Ivory Coast": "CIV",
    "Cabo Verde": "CPV", "Cape Verde": "CPV",
    "Gambia": "GMB", "Ghana": "GHA", "Guinea": "GIN",
    "Guinea-Bissau": "GNB", "Liberia": "LBR", "Mali": "MLI",
    "Niger": "NER", "Nigeria": "NGA", "Sierra Leone": "SLE",
    "Senegal": "SEN", "Togo": "TGO",
    # Afrique de l'Est
    "Burundi": "BDI", "Comoros": "COM", "Djibouti": "DJI",
    "Eritrea": "ERI", "Ethiopia": "ETH", "Kenya": "KEN",
    "Madagascar": "MDG", "Malawi": "MWI", "Mauritius": "MUS",
    "Mozambique": "MOZ", "Rwanda": "RWA", "Seychelles": "SYC",
    "Somalia": "SOM", "South Sudan": "SSD", "Tanzania": "TZA",
    "Uganda": "UGA", "Zambia": "ZMB", "Zimbabwe": "ZWE",
    # Afrique Centrale
    "Angola": "AGO", "Cameroon": "CMR",
    "Central African Republic": "CAF", "Chad": "TCD",
    "Congo": "COG", "DR Congo": "COD", "DRC": "COD",
    "Equatorial Guinea": "GNQ", "Gabon": "GAB",
    "Sao Tome and Principe": "STP",
    # Afrique Australe
    "Botswana": "BWA", "Eswatini": "SWZ", "Swaziland": "SWZ",
    "Lesotho": "LSO", "Namibia": "NAM", "South Africa": "ZAF",
}

# ── Mapping indicateurs OSA -> config SIPRI ───────────────
SIPRI_INDICATOR_MAP: dict = {
    "MIL_EXP": {
        "file":       "DEP_GDP.csv",
        "name_fr":    "Depenses militaires (% PIB)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "SIPRI MILEX -- depenses militaires en % du PIB.",
    },
    "MIL_EXP_PCT": {
        "file":       "DEP_GDP.csv",
        "name_fr":    "Depenses militaires (% PIB)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "SIPRI MILEX -- depenses militaires en % du PIB. "
                      "Indicateur effort defense -- comparable entre pays.",
    },
    "MIL_EXP_PC": {
        "file":       "DEP_Per_capita.csv",
        "name_fr":    "Depenses militaires par habitant (USD courant)",
        "unit_code":  "USD",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "SIPRI MILEX -- depenses militaires USD courant par habitant.",
    },
}


class SIPRICSVFetcher(BaseFetcher):

    PROVIDER_CODE = "SIPRI"
    ENDPOINT_CODE = "WB_COUNTRY_INDICATOR"
    INDICATOR_MAP = SIPRI_INDICATOR_MAP

    def __init__(self, data_dir: str = "data/sipri", dry_run: bool = False) -> None:
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
        """Parse le CSV SIPRI pour un indicateur donne."""
        filename = config["file"]
        csv_path = self.data_dir / filename

        if not csv_path.exists():
            self.log.warning(
                "%s manquant -- telecharger sur sipri.org/databases/milex",
                filename,
            )
            return []

        rows = self._load_csv(csv_path)
        if not rows:
            return []

        records: list[DataRecord] = []
        for row in rows:
            iso3 = self._resolve_iso3(row)
            if not iso3:
                continue

            for year in range(year_from, year_to + 1):
                raw   = row.get(str(year), "").strip()
                value = self._parse_sipri_value(raw)
                records.append({"iso3": iso3, "year": year, "value": value})

        self.log.info(
            "SIPRI %s -> %d enregistrements (%d pays)",
            osa_code, len(records),
            len({r["iso3"] for r in records if r.get("value") is not None}),
        )
        return records

    def _load_csv(self, csv_path: Path) -> list[dict]:
        """
        Charge un CSV SIPRI en memoire.

        Format reel SIPRI :
        - Separateur : ; (point-virgule)
        - 5-6 lignes d'en-tete a ignorer
        - Ligne d'en-tete : commence par "Country;Notes;1949;..."
        - Valeurs : virgules decimales europeennes (1,57 -> 1.57)
        - Lignes de sous-regions a ignorer (Africa, North Africa, etc.)
        """
        key = str(csv_path)
        if key in self._cache:
            return self._cache[key]

        rows: list[dict] = []

        try:
            with open(csv_path, encoding="utf-8-sig", errors="replace") as f:
                lines = f.readlines()

            # Trouver la ligne d'en-tete (commence exactement par Country;)
            header_idx = None
            for idx, line in enumerate(lines):
                stripped = line.strip()
                if stripped.startswith("Country;") or stripped.startswith("Country,"):
                    header_idx = idx
                    break

            if header_idx is None:
                self.log.error("En-tete non trouve dans %s", csv_path.name)
                return []

            # Parser le contenu depuis la ligne d'en-tete
            content = "".join(lines[header_idx:])
            sample  = content[:1024]
            delim   = ";" if ";" in sample else ("\t" if "\t" in sample else ",")

            reader = csv.DictReader(io.StringIO(content), delimiter=delim)

            for row in reader:
                # Ignorer les lignes vides et sous-regions
                country_raw = list(row.values())[0].strip() if row else ""
                if not country_raw:
                    continue
                if country_raw.lower() in SIPRI_REGION_LABELS:
                    continue
                # Ignorer les lignes qui ne sont pas des pays
                if country_raw.lower() in ("country", "notes", ""):
                    continue
                rows.append(dict(row))

            self.log.info(
                "SIPRI %s charge -- %d pays", csv_path.name, len(rows)
            )

        except Exception as exc:
            self.log.error("Erreur parsing %s : %s", csv_path.name, exc)

        self._cache[key] = rows
        return rows

    def _resolve_iso3(self, row: dict) -> Optional[str]:
        """Resout le code ISO-3 depuis une ligne SIPRI."""
        country_raw = list(row.values())[0].strip() if row else ""
        if not country_raw:
            return None

        # Lookup direct
        iso3 = SIPRI_COUNTRY_TO_ISO3.get(country_raw)
        if iso3 and iso3 in AFRICAN_ISO3:
            return iso3

        # Lookup partiel (cas "Congo, Dem. Rep." etc.)
        for name, code in SIPRI_COUNTRY_TO_ISO3.items():
            if name.lower() in country_raw.lower() or country_raw.lower() in name.lower():
                if code in AFRICAN_ISO3:
                    return code

        return None

    @staticmethod
    def _parse_sipri_value(raw: str) -> Optional[float]:
        """
        Convertit une cellule SIPRI en float.
        Gere :
          - "..." = donnee manquante
          - "xxx" = pays inexistant
          - "1,57" = virgule decimale europeenne
          - "1,234" = separateur de milliers anglo-saxon
          - "1.57%" = pourcentage
        """
        if not raw:
            return None
        cleaned = raw.strip()
        if cleaned.lower() in ("...", "xxx", "na", "n/a", "", "-", ".", ".."):
            return None

        # Supprimer symbole %
        cleaned = cleaned.replace("%", "").strip()

        # Virgule decimale europeenne : "1,57" -> "1.57"
        # vs separateur milliers : "1,234" -> "1234"
        if "," in cleaned and "." not in cleaned:
            # Compter les chiffres apres la virgule
            parts = cleaned.split(",")
            if len(parts) == 2 and len(parts[1]) <= 2:
                # 1 ou 2 decimales -> virgule decimale
                cleaned = cleaned.replace(",", ".")
            else:
                # Separateur de milliers -> supprimer
                cleaned = cleaned.replace(",", "")
        elif "," in cleaned and "." in cleaned:
            # Format mixte : "1,234.56" -> supprimer virgule
            cleaned = cleaned.replace(",", "")

        try:
            return float(cleaned)
        except ValueError:
            return None

    @staticmethod
    def detect_columns(filepath: str | Path, max_rows: int = 5) -> None:
        """Utilitaire debug - affiche la structure du CSV SIPRI."""
        filepath = Path(filepath)
        with open(filepath, encoding="utf-8-sig", errors="replace") as f:
            lines = f.readlines()

        print(f"\nFichier : {filepath.name} ({len(lines)} lignes)")
        print("\nPremiers enregistrements :")
        for idx, line in enumerate(lines):
            stripped = line.strip()
            if stripped.startswith("Country;") or stripped.startswith("Country,"):
                delim = ";" if ";" in stripped else ","
                reader = csv.DictReader(
                    io.StringIO("".join(lines[idx:])), delimiter=delim
                )
                print(f"En-tete a la ligne {idx + 1}")
                print("Colonnes annees disponibles : ", end="")
                fields = reader.fieldnames or []
                years = [f for f in fields if f.isdigit()]
                if years:
                    print(f"{years[0]} -> {years[-1]} ({len(years)} annees)")
                print(f"\nPremiers pays ({max_rows}) :")
                for i, row in enumerate(reader):
                    if i >= max_rows:
                        break
                    country = list(row.values())[0].strip()
                    year_2023 = row.get("2023", row.get("2022", "N/A")).strip()
                    print(f"  {country:35} 2023={year_2023}")
                break


# ── CLI ───────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(
        description="OSA Fetcher - SIPRI CSV",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Fichiers CSV SIPRI dans --dir :
  DEP_GDP.csv          -> MIL_EXP_PCT (% PIB)
  EXp_Current_USD.csv  -> MIL_EXP     (USD courant)
  DEP_Per_capita.csv   -> MIL_EXP_PC  (USD/habitant)

Telechargement SIPRI MILEX :
  https://www.sipri.org/databases/milex
  -> Download SIPRI Military Expenditure Database

Exemples :
  python fetcher_sipri_csv.py --dir data/sipri/ --list-missing
  python fetcher_sipri_csv.py --dir data/sipri/ --dry-run
  python fetcher_sipri_csv.py --dir data/sipri/ --indicator MIL_EXP
  python fetcher_sipri_csv.py --dir data/sipri/ --indicator MIL_EXP_PCT
  python fetcher_sipri_csv.py --dir data/sipri/ --detect DEP_GDP.csv
        """,
    )
    parser.add_argument("--dir",          type=str, required=True)
    parser.add_argument("--from",         type=int, dest="year_from", default=2010)
    parser.add_argument("--to",           type=int, dest="year_to",   default=2024)
    parser.add_argument("--indicator",    type=str, default=None)
    parser.add_argument("--dry-run",      action="store_true")
    parser.add_argument("--list-missing", action="store_true",
                        help="Lister les fichiers CSV disponibles et manquants")
    parser.add_argument("--detect",       type=str, default=None,
                        help="Afficher la structure d'un fichier CSV (ex: DEP_GDP.csv)")
    args = parser.parse_args()

    if args.detect:
        SIPRICSVFetcher.detect_columns(Path(args.dir) / args.detect)
        return

    if args.list_missing:
        data_dir = Path(args.dir)
        print(f"\nFichiers SIPRI dans {data_dir} :")
        for ind, cfg in SIPRI_INDICATOR_MAP.items():
            path   = data_dir / cfg["file"]
            status = "present" if path.exists() else "MANQUANT"
            size   = f"{path.stat().st_size // 1024}K" if path.exists() else "-"
            print(f"  {cfg['file']:30} {status:10} {size:6}  -> {ind}")
        return

    fetcher = SIPRICSVFetcher(data_dir=args.dir, dry_run=args.dry_run)
    try:
        fetcher.connect()
        result = fetcher.run(args.year_from, args.year_to, args.indicator)
        sys.exit(0 if not result["failed"] else 1)
    finally:
        fetcher.disconnect()


if __name__ == "__main__":
    main()