"""
============================================================
OSA / ISA OBSERVATORY
imf_csv_parser.py — Parseur CSV commun aux datasets IMF
============================================================
Gère les 3 formats CSV IMF :
  - WEO  (World Economic Outlook)
  - DOTS (Direction of Trade Statistics)
  - BOP  (Balance of Payments)

Tous les CSV IMF ont une structure similaire mais avec
des variantes mineures — ce parseur les normalise en un
format unique : List[{"iso3", "year", "value"}]

Usage :
  from imf_csv_parser import IMFCSVParser
  records = IMFCSVParser.parse_weo("data/imf/WEO_2026.csv", "PCPIPCH")
  records = IMFCSVParser.parse_dots("data/imf/DOTS_2024.csv", "TXG_FOB_USD")
  records = IMFCSVParser.parse_bop("data/imf/BOP_2024.csv", "BCA_USD")
============================================================
"""

from __future__ import annotations

import csv
import logging
import os
from pathlib import Path
from typing import Optional

log = logging.getLogger("imf_csv_parser")

# ── Mapping ISO-2 → ISO-3 (pour convertir les codes IMF) ──

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

# Codes numériques IMF (ISO M49) → ISO-3
# Utilisés dans certains exports WEO et DOTS
IMF_NUMERIC_TO_ISO3: dict[str, str] = {
    "612":"DZA","469":"EGY","672":"LBY","686":"MAR","682":"MRT",
    "732":"SDN","744":"TUN","638":"BEN","748":"BFA","662":"CIV",
    "624":"CPV","648":"GMB","652":"GHA","656":"GIN","654":"GNB",
    "668":"LBR","678":"MLI","692":"NER","694":"NGA","724":"SLE",
    "722":"SEN","742":"TGO","618":"BDI","632":"COM","611":"DJI",
    "643":"ERI","644":"ETH","664":"KEN","674":"MDG","676":"MWI",
    "684":"MUS","688":"MOZ","714":"RWA","718":"SYC","726":"SOM",
    "728":"SSD","738":"TZA","746":"UGA","754":"ZMB","698":"ZWE",
    "614":"AGO","622":"CMR","626":"CAF","628":"TCD","634":"COG",
    "636":"COD","642":"GNQ","646":"GAB","716":"STP","616":"BWA",
    "734":"SWZ","666":"LSO","728":"NAM","199":"ZAF",
}

AFRICAN_ISO3: set[str] = set(ISO2_TO_ISO3.values())


class IMFCSVParser:
    """Parseur statique pour les 3 formats CSV IMF."""

    # ── WEO ──────────────────────────────────────────────────

    @staticmethod
    def parse_weo(
        filepath: str | Path,
        imf_code:  str,
        year_from: int = 2010,
        year_to:   int = 2024,
    ) -> list[dict]:
        """
        Parse un fichier CSV WEO (World Economic Outlook).

        Format WEO typique :
        WEO Country Code | ISO | Country | Subject Code | ... | 2010 | 2011 | ... | 2024

        Téléchargement : https://www.imf.org/en/Publications/WEO/weo-database/
        Choisir : "By Countries" → "All Countries" → format CSV
        """
        records: list[dict] = []
        filepath = Path(filepath)

        if not filepath.exists():
            log.error("Fichier WEO introuvable : %s", filepath)
            return []

        try:
            with open(filepath, encoding="utf-8-sig", errors="replace") as f:
                # Détection du séparateur (tab ou virgule selon version)
                sample = f.read(2048)
                f.seek(0)
                delimiter = "\t" if "\t" in sample else ","
                reader = csv.DictReader(f, delimiter=delimiter)

                for row in reader:
                    # Identifier la colonne du code indicateur
                    subject = (
                        row.get("WEO Subject Code", "") or
                        row.get("Subject Code", "") or
                        row.get("CONCEPT", "")
                    ).strip().upper()

                    if subject != imf_code.upper():
                        continue

                    # Identifier le pays
                    iso2 = (
                        row.get("ISO", "") or
                        row.get("ISO2", "") or
                        row.get("Country Code", "")
                    ).strip().upper()

                    iso3 = ISO2_TO_ISO3.get(iso2)
                    if not iso3:
                        # Essayer code numérique IMF
                        weo_num = row.get("WEO Country Code", "").strip()
                        iso3 = IMF_NUMERIC_TO_ISO3.get(weo_num)

                    if not iso3 or iso3 not in AFRICAN_ISO3:
                        continue

                    # Extraire les valeurs par année
                    for year in range(year_from, year_to + 1):
                        raw = row.get(str(year), "").strip()
                        value = IMFCSVParser._parse_value(raw)
                        records.append({
                            "iso3":  iso3,
                            "year":  year,
                            "value": value,
                        })

        except Exception as exc:
            log.error("Erreur parsing WEO %s : %s", filepath.name, exc)

        log.info("WEO %s → %d enregistrements (%d pays)",
                 imf_code, len(records),
                 len({r["iso3"] for r in records if r["value"] is not None}))
        return records

    # ── DOTS ─────────────────────────────────────────────────

    @staticmethod
    def parse_dots(
        filepath:  str | Path,
        imf_code:  str,
        year_from: int = 2010,
        year_to:   int = 2024,
    ) -> list[dict]:
        """
        Parse un fichier CSV DOTS (Direction of Trade Statistics).

        Format DOTS typique :
        Country Code | Indicator Code | Country Name | ... | 2010 | ... | 2024

        Téléchargement : https://data.imf.org/?sk=9d6028d4-f14a-464c-a2f2-59b2cd424b85
        Sélectionner : Annual Data → All Countries → CSV
        """
        records: list[dict] = []
        filepath = Path(filepath)

        if not filepath.exists():
            log.error("Fichier DOTS introuvable : %s", filepath)
            return []

        try:
            with open(filepath, encoding="utf-8-sig", errors="replace") as f:
                sample = f.read(2048)
                f.seek(0)
                delimiter = "\t" if "\t" in sample else ","
                reader = csv.DictReader(f, delimiter=delimiter)

                for row in reader:
                    indicator = (
                        row.get("Indicator Code", "") or
                        row.get("INDICATOR", "") or
                        row.get("Series Code", "")
                    ).strip().upper()

                    if indicator != imf_code.upper():
                        continue

                    country = (
                        row.get("Country Code", "") or
                        row.get("ISO", "") or
                        row.get("REF_AREA", "")
                    ).strip().upper()

                    # DOTS utilise souvent ISO-2
                    iso3 = ISO2_TO_ISO3.get(country) or \
                           (country if len(country) == 3 and country in AFRICAN_ISO3 else None)

                    if not iso3 or iso3 not in AFRICAN_ISO3:
                        continue

                    for year in range(year_from, year_to + 1):
                        raw = row.get(str(year), "").strip()
                        value = IMFCSVParser._parse_value(raw)
                        records.append({
                            "iso3":  iso3,
                            "year":  year,
                            "value": value,
                        })

        except Exception as exc:
            log.error("Erreur parsing DOTS %s : %s", filepath.name, exc)

        log.info("DOTS %s → %d enregistrements (%d pays)",
                 imf_code, len(records),
                 len({r["iso3"] for r in records if r["value"] is not None}))
        return records

    # ── BOP ──────────────────────────────────────────────────

    @staticmethod
    def parse_bop(
        filepath:  str | Path,
        imf_code:  str,
        year_from: int = 2010,
        year_to:   int = 2024,
    ) -> list[dict]:
        """
        Parse un fichier CSV BOP (Balance of Payments).

        Format BOP typique :
        Country | Indicator | Unit | Scale | 2010 | ... | 2024

        Téléchargement : https://data.imf.org/?sk=7a51304b-6426-40c0-83dd-ca473ca1fd52
        Sélectionner : Annual → All Countries → CSV
        """
        records: list[dict] = []
        filepath = Path(filepath)

        if not filepath.exists():
            log.error("Fichier BOP introuvable : %s", filepath)
            return []

        try:
            with open(filepath, encoding="utf-8-sig", errors="replace") as f:
                sample = f.read(2048)
                f.seek(0)
                delimiter = "\t" if "\t" in sample else ","
                reader = csv.DictReader(f, delimiter=delimiter)

                for row in reader:
                    indicator = (
                        row.get("Indicator Code", "") or
                        row.get("BOP_CODE", "") or
                        row.get("INDICATOR", "")
                    ).strip().upper()

                    if indicator != imf_code.upper():
                        continue

                    country = (
                        row.get("Country Code", "") or
                        row.get("ISO", "") or
                        row.get("REF_AREA", "")
                    ).strip().upper()

                    iso3 = ISO2_TO_ISO3.get(country) or \
                           (country if len(country) == 3 and country in AFRICAN_ISO3 else None)

                    if not iso3 or iso3 not in AFRICAN_ISO3:
                        continue

                    # BOP a parfois un facteur d'échelle (millions)
                    scale_raw = row.get("Scale", row.get("SCALE", "1")).strip()
                    try:
                        scale = float(scale_raw) if scale_raw else 1.0
                    except ValueError:
                        scale = 1.0

                    for year in range(year_from, year_to + 1):
                        raw = row.get(str(year), "").strip()
                        value = IMFCSVParser._parse_value(raw)
                        if value is not None:
                            value = value * scale
                        records.append({
                            "iso3":  iso3,
                            "year":  year,
                            "value": value,
                        })

        except Exception as exc:
            log.error("Erreur parsing BOP %s : %s", filepath.name, exc)

        log.info("BOP %s → %d enregistrements (%d pays)",
                 imf_code, len(records),
                 len({r["iso3"] for r in records if r["value"] is not None}))
        return records

    # ── Utilitaire ────────────────────────────────────────────

    @staticmethod
    def _parse_value(raw: str) -> Optional[float]:
        """
        Convertit une cellule CSV IMF en float.
        Gère : virgules de milliers, "n/a", "--", vide, "NA", espaces.
        """
        if not raw:
            return None
        cleaned = raw.replace(",", "").replace(" ", "").strip()
        if cleaned.lower() in ("n/a", "na", "--", "...", ""):
            return None
        try:
            return float(cleaned)
        except ValueError:
            return None

    @staticmethod
    def detect_columns(filepath: str | Path, max_rows: int = 3) -> None:
        """
        Utilitaire de debug — affiche les colonnes d'un fichier CSV IMF.
        Usage : IMFCSVParser.detect_columns("data/imf/WEO_2026.csv")
        """
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
