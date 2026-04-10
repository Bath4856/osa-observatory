"""
============================================================
OSA / ISA OBSERVATORY
fetcher_undp_csv.py — Fetcher UNDP HDR (CSV)
============================================================
Couvre : 5 indicateurs pilier PHUM (souveraineté humaine)
Source : UNDP Human Development Report Office
URL    : https://hdr.undp.org/data-center/documentation-and-downloads

UNDP publie chaque année le rapport sur le développement humain
avec une base de données complète en CSV — plus fiable que l'API
qui change de structure régulièrement.

Indicateurs couverts :
  HUM_EDU   IDH composante éducation
  HUM_HEA   IDH composante santé (espérance vie)
  HUM_RES   Indice de développement humain (IDH global)
  HUM_DIG   Indice d'inégalité de genre (GII)
  HUM_SOC   Coefficient de Gini (inégalités revenus)

Téléchargement :
  1. Aller sur https://hdr.undp.org/data-center/documentation-and-downloads
  2. Section "Human Development Data" → "Download all data"
  3. Télécharger le fichier CSV principal (HDR_*.csv)
  4. Placer dans data/undp/HDR_2024.csv

Usage :
  python fetcher_undp_csv.py --file data/undp/HDR_2024.csv
  python fetcher_undp_csv.py --file data/undp/HDR_2024.csv --dry-run
  python fetcher_undp_csv.py --file data/undp/HDR_2024.csv --detect
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

# ── Mapping indicateurs OSA → codes HDR ───────────────────
# Les codes HDR suivent la convention : INDICATEUR_ANNEE
# Le parseur reconstruit les colonnes dynamiquement

UNDP_INDICATOR_MAP: dict = {

    "HUM_RES": {
        "hdr_code":   "hdi",
        "name_fr":    "Indice de développement humain (IDH)",
        "unit_code":  "SCORE_0_1",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      """UNDP HDR — Human Development Index [0,1].
                        Composante clé de PHUM — mesure combinée santé, éducation, revenu.
                        Excellente couverture africaine 2010-2023.""",
    },
    "HUM_EDU": {
        "hdr_code":   "eys",
        "name_fr":    "Espérance de scolarisation (années)",
        "unit_code":  "YEARS",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      """UNDP HDR — Expected Years of Schooling.
                        Composante éducation de l'IDH. Nombre d'années de scolarisation
                        attendues pour un enfant entrant à l'école aujourd'hui.""",
    },
    "HUM_LIT": {
        "hdr_code":   "mys",
        "name_fr":    "Durée moyenne de scolarisation (années)",
        "unit_code":  "YEARS",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      """UNDP HDR — Mean Years of Schooling (adultes 25+).
                        Complète le taux d'alphabétisation WB avec une mesure plus précise.""",
    },
    "HUM_DIG": {
        "hdr_code":   "gii",
        "name_fr":    "Indice d'inégalité de genre (GII)",
        "unit_code":  "SCORE_0_1",
        "direction":  "-",
        "multiplier": 1.0,
        "notes":      """UNDP HDR — Gender Inequality Index [0,1].
                        0 = égalité parfaite, 1 = inégalité totale.
                        Direction négative : valeur haute = mauvais pour la souveraineté humaine.""",
    },
    "HUM_SOC": {
        "hdr_code":   "gnipc",
        "name_fr":    "RNB par habitant (USD PPA 2017)",
        "unit_code":  "USD_CONST",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      """UNDP HDR — Gross National Income per capita PPP 2017 USD.
                        Composante revenu de l'IDH. Différent du PIB/hab WB —
                        inclut les transferts internationaux, important pour l'Afrique.""",
    },
}


class UNDPCSVFetcher(BaseFetcher):

    PROVIDER_CODE = "UNDP"
    ENDPOINT_CODE = "WB_COUNTRY_INDICATOR"  # Réutilise endpoint WB
    INDICATOR_MAP = UNDP_INDICATOR_MAP

    def __init__(self, csv_filepath: str = "data/undp/HDR.csv", dry_run: bool = False) -> None:
        super().__init__(dry_run=dry_run)
        self.csv_filepath = Path(csv_filepath)
        self._rows_cache: list[dict] | None = None

    def _load_csv(self) -> list[dict]:
        """
        Charge et met en cache le CSV HDR.

        Format HDR (CSV long) :
        iso3 | country | hdicode | region | ... | indicator | 2010 | ... | 2023

        OU format large :
        iso3 | country | hdi_2010 | hdi_2011 | ... | eys_2010 | ...

        Le parseur gère les deux formats.
        """
        if self._rows_cache is not None:
            return self._rows_cache

        if not self.csv_filepath.exists():
            self.log.error("Fichier HDR introuvable : %s", self.csv_filepath)
            return []

        rows: list[dict] = []
        try:
            with open(self.csv_filepath, encoding="utf-8-sig", errors="replace") as f:
                sample    = f.read(4096)
                f.seek(0)
                delimiter = "\t" if "\t" in sample else ","
                reader    = csv.DictReader(f, delimiter=delimiter)
                rows      = list(reader)
            self.log.info("HDR chargé — %d lignes, %d colonnes",
                          len(rows), len(rows[0]) if rows else 0)
        except Exception as exc:
            self.log.error("Erreur chargement HDR : %s", exc)

        self._rows_cache = rows
        return rows

    def fetch_indicator(
        self,
        osa_code:  str,
        config:    dict,
        year_from: int,
        year_to:   int,
    ) -> list[DataRecord]:
        """
        Extrait un indicateur HDR du CSV pour tous les pays africains.
        Supporte les deux formats HDR (large et long).
        """
        hdr_code = config["hdr_code"]
        rows     = self._load_csv()
        if not rows:
            return []

        records: list[DataRecord] = []
        fieldnames = list(rows[0].keys()) if rows else []

        # Détection du format
        # Format large : colonnes hdi_2010, hdi_2011, ...
        # Format long  : colonnes indicator, value, year
        is_wide = any(
            f"{hdr_code}_{year_from}" in col or
            f"{hdr_code.upper()}_{year_from}" in col
            for col in fieldnames
        )
        is_long = "indicator" in [f.lower() for f in fieldnames] or \
                  "indicatorcode" in [f.lower().replace(" ", "") for f in fieldnames]

        if is_wide:
            records = self._parse_wide(rows, hdr_code, year_from, year_to)
        elif is_long:
            records = self._parse_long(rows, hdr_code, year_from, year_to)
        else:
            # Tentative auto sur colonnes directes (certaines versions HDR)
            records = self._parse_direct(rows, hdr_code, year_from, year_to)

        return records

    def _parse_wide(
        self,
        rows:      list[dict],
        hdr_code:  str,
        year_from: int,
        year_to:   int,
    ) -> list[DataRecord]:
        """Format large : hdi_2010, hdi_2011, ... par ligne/pays."""
        records: list[DataRecord] = []

        for row in rows:
            iso3 = self._resolve_iso3(row)
            if not iso3:
                continue

            for year in range(year_from, year_to + 1):
                # Essayer plusieurs variantes de nom de colonne
                raw = (
                    row.get(f"{hdr_code}_{year}") or
                    row.get(f"{hdr_code.upper()}_{year}") or
                    row.get(f"{hdr_code.lower()}_{year}") or
                    ""
                ).strip()

                value = self._parse_hdr_value(raw)
                records.append({"iso3": iso3, "year": year, "value": value})

        return records

    def _parse_long(
        self,
        rows:      list[dict],
        hdr_code:  str,
        year_from: int,
        year_to:   int,
    ) -> list[DataRecord]:
        """Format long : une ligne par (pays, indicateur, année)."""
        records: list[DataRecord] = []

        for row in rows:
            # Trouver la colonne indicateur
            indicator = (
                row.get("indicator") or
                row.get("Indicator") or
                row.get("indicatorcode") or
                row.get("IndicatorCode") or
                ""
            ).strip().lower()

            if indicator != hdr_code.lower():
                continue

            iso3 = self._resolve_iso3(row)
            if not iso3:
                continue

            year_raw = (
                row.get("year") or
                row.get("Year") or
                ""
            ).strip()

            try:
                year = int(year_raw)
                if not (year_from <= year <= year_to):
                    continue
            except (ValueError, TypeError):
                continue

            value_raw = (
                row.get("value") or
                row.get("Value") or
                ""
            ).strip()
            value = self._parse_hdr_value(value_raw)
            records.append({"iso3": iso3, "year": year, "value": value})

        return records

    def _parse_direct(
        self,
        rows:      list[dict],
        hdr_code:  str,
        year_from: int,
        year_to:   int,
    ) -> list[DataRecord]:
        """
        Format direct : colonnes = années, lignes filtrées par indicateur.
        Essaie de trouver la colonne hdr_code directement.
        """
        records: list[DataRecord] = []
        fieldnames = list(rows[0].keys()) if rows else []

        # Chercher colonnes qui ressemblent à des années
        year_cols = [
            f for f in fieldnames
            if f.isdigit() and year_from <= int(f) <= year_to
        ]

        if not year_cols:
            self.log.warning(
                "Format HDR non reconnu pour %s — colonnes : %s",
                hdr_code, ", ".join(fieldnames[:10])
            )
            return []

        for row in rows:
            # Vérifier si cette ligne correspond à l'indicateur
            row_values = " ".join(str(v) for v in row.values()).lower()
            if hdr_code.lower() not in row_values:
                continue

            iso3 = self._resolve_iso3(row)
            if not iso3:
                continue

            for col in year_cols:
                raw   = row.get(col, "").strip()
                value = self._parse_hdr_value(raw)
                records.append({"iso3": iso3, "year": int(col), "value": value})

        return records

    def _resolve_iso3(self, row: dict) -> Optional[str]:
        """Résout le code ISO-3 depuis une ligne HDR."""
        iso3 = (
            row.get("iso3") or
            row.get("ISO3") or
            row.get("Country Code") or
            row.get("iso_a3") or
            ""
        ).strip().upper()

        if iso3 and len(iso3) == 3 and iso3 in AFRICAN_ISO3:
            return iso3
        return None

    @staticmethod
    def _parse_hdr_value(raw: str) -> Optional[float]:
        """Convertit une cellule HDR en float. Gère '..' et valeurs vides."""
        if not raw:
            return None
        cleaned = raw.replace(",", "").strip()
        if cleaned in ("..", "...", "NA", "n/a", "-", ""):
            return None
        try:
            return float(cleaned)
        except ValueError:
            return None

    @staticmethod
    def detect_columns(filepath: str | Path, max_rows: int = 2) -> None:
        """Debug — affiche colonnes et premières lignes du CSV HDR."""
        filepath = Path(filepath)
        with open(filepath, encoding="utf-8-sig", errors="replace") as f:
            sample = f.read(2048)
            f.seek(0)
            delim  = "\t" if "\t" in sample else ","
            reader = csv.DictReader(f, delimiter=delim)
            print(f"\nColonnes ({filepath.name}) :")
            cols = reader.fieldnames or []
            # Afficher par groupes de 10
            for i in range(0, len(cols), 10):
                print("  " + " | ".join(cols[i:i+10]))
            print(f"\nPremières {max_rows} lignes :")
            for j, row in enumerate(reader):
                if j >= max_rows:
                    break
                print(f"  {dict(list(row.items())[:8])}")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="OSA Fetcher — UNDP HDR CSV",
        epilog="""
Téléchargement :
  https://hdr.undp.org/data-center/documentation-and-downloads
  → "Download all data" → HDR_*.csv

Exemples :
  python fetcher_undp_csv.py --file data/undp/HDR_2024.csv
  python fetcher_undp_csv.py --file data/undp/HDR_2024.csv --dry-run
  python fetcher_undp_csv.py --file data/undp/HDR_2024.csv --detect
  python fetcher_undp_csv.py --file data/undp/HDR_2024.csv --indicator HUM_RES
        """,
    )
    parser.add_argument("--file",      type=str, required=True)
    parser.add_argument("--from",      type=int, dest="year_from", default=2010)
    parser.add_argument("--to",        type=int, dest="year_to",   default=2023)
    parser.add_argument("--indicator", type=str, default=None)
    parser.add_argument("--dry-run",   action="store_true")
    parser.add_argument("--detect",    action="store_true",
                        help="Afficher les colonnes du CSV HDR")
    args = parser.parse_args()

    if args.detect:
        UNDPCSVFetcher.detect_columns(args.file)
        return

    fetcher = UNDPCSVFetcher(
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
