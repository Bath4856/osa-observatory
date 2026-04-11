"""
============================================================
OSA / ISA OBSERVATORY
imf_csv_parser.py -- Parseur CSV commun aux datasets IMF
============================================================
Gere les 3 formats CSV IMF (nouveau format 2024+) :
  - WEO  (World Economic Outlook)        -- 26 Mo
  - DOTS (Direction of Trade Statistics) -- 2.1 Go
  - BOP  (Balance of Payments)           -- 1.3 Go

Nouveau format unifie IMF (depuis ~2024) :
  SERIES_CODE = {ISO3}.{INDICATOR_CODE}.{FREQ}
    ex: DZA.PCPIPCH.A    (WEO : Algerie, inflation, annuel)
    ex: DZA.BCA_NGDPD.A  (WEO : Algerie, balance courante, annuel)
    ex: DZA.BCA.A        (BOP : Algerie, balance courante, annuel)
  COUNTRY    = nom complet du pays
  FREQUENCY  = "Annual" | "Quarterly" | "Monthly"
  Colonnes annees : "2010", "2011"... (sans suffixe = annuel)
                    "2010-Q1"...      (trimestriel)
                    "2010-M01"...     (mensuel)

Tous les CSV IMF sont normalises en :
  List[{"iso3": str, "year": int, "value": float | None}]

Usage :
  from imf_csv_parser import IMFCSVParser
  records = IMFCSVParser.parse_weo("data/imf/WEO.csv", "PCPIPCH")
  records = IMFCSVParser.parse_dots("data/imf/DOTS.csv", "TXG_FOB_USD")
  records = IMFCSVParser.parse_bop("data/imf/BOP.csv", "BCA")
============================================================
"""

from __future__ import annotations

import csv
import logging
import os
from pathlib import Path
from typing import Optional

log = logging.getLogger("imf_csv_parser")

# ── Mapping ISO-3 africains (utilise pour filtrer) ────────
AFRICAN_ISO3: set[str] = {
    "DZA","EGY","LBY","MAR","MRT","SDN","TUN",  # Afrique du Nord
    "BEN","BFA","CIV","CPV","GMB","GHA","GIN","GNB",
    "LBR","MLI","NER","NGA","SLE","SEN","TGO",  # Afrique de l'Ouest
    "BDI","COM","DJI","ERI","ETH","KEN","MDG","MWI",
    "MUS","MOZ","RWA","SYC","SOM","SSD","TZA","UGA","ZMB","ZWE",  # Afrique de l'Est
    "AGO","CMR","CAF","TCD","COG","COD","GNQ","GAB","STP",  # Afrique centrale
    "BWA","SWZ","LSO","NAM","ZAF",  # Afrique australe
}

# ── Mapping ISO-2 -> ISO-3 (fallback ancien format) ───────
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

# Codes numeriques IMF M49 -> ISO-3 (fallback ancien format WEO)
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


def _parse_value(raw: str) -> Optional[float]:
    """Convertit une cellule CSV IMF en float."""
    if not raw:
        return None
    cleaned = raw.replace(",", "").replace(" ", "").strip()
    if cleaned.lower() in ("n/a", "na", "--", "...", "..", "", "nan"):
        return None
    try:
        return float(cleaned)
    except ValueError:
        return None


def _resolve_iso3(series_code: str) -> Optional[str]:
    """
    Extrait le code ISO-3 depuis SERIES_CODE.
    Nouveau format : ISO3 est toujours le premier segment avant le premier point.
    ex: DZA.PCPIPCH.A -> DZA
    ex: DZA.BCA_T.R_F11A.USD.A -> DZA
    """
    if not series_code:
        return None
    iso3 = series_code.split(".")[0].strip().upper()
    if len(iso3) == 3 and iso3 in AFRICAN_ISO3:
        return iso3
    return None


def _resolve_indicator(series_code: str) -> str:
    """
    Extrait le code indicateur depuis SERIES_CODE.
    Pour WEO : format court -> DZA.PCPIPCH.A -> PCPIPCH
    Pour BOP/DOTS : format long -> DZA.BCA_T.R_F11A.USD.A -> BCA_T.R_F11A.USD
    On retourne tout ce qui est entre le premier et dernier segment.
    """
    parts = series_code.split(".")
    if len(parts) < 3:
        return parts[1] if len(parts) >= 2 else ""
    # Le dernier segment est la frequence (A, Q, M...)
    # Le premier est ISO3
    # Tout le milieu est le code indicateur
    return ".".join(parts[1:-1]).upper()


class IMFCSVParser:
    """Parseur statique pour les 3 formats CSV IMF (nouveau format 2024+)."""

    @staticmethod
    def _parse_generic(
        filepath:  str | Path,
        imf_code:  str,
        year_from: int,
        year_to:   int,
        dataset:   str,
    ) -> list[dict]:
        """
        Parseur generique pour WEO, DOTS et BOP.
        Tous les fichiers IMF utilisent desormais le meme format SERIES_CODE.

        Strategie de matching :
        - Exact  : le code extrait == imf_code
        - Prefixe : le code extrait commence par imf_code + "."
          (utile pour BOP/DOTS ou le code peut etre BCA_T.TOTAL)
        """
        records: list[dict] = []
        filepath = Path(filepath)

        if not filepath.exists():
            log.error("Fichier %s introuvable : %s", dataset, filepath)
            return []

        imf_code_upper = imf_code.upper()
        # Colonnes annees annuelles (sans suffixe -Qx ou -Mx ou -xx-xx)
        year_cols = {year: str(year) for year in range(year_from, year_to + 1)}

        try:
            with open(filepath, encoding="utf-8-sig", errors="replace") as f:
                sample = f.read(4096)
                f.seek(0)
                delimiter = "\t" if "\t" in sample else ","
                reader = csv.DictReader(f, delimiter=delimiter)

                for row in reader:
                    # Filtrer sur frequence annuelle
                    freq = row.get("FREQUENCY", "").strip()
                    if freq and freq.lower() not in ("annual", "a", "yearly"):
                        continue

                    series_code = row.get("SERIES_CODE", "").strip()
                    if not series_code:
                        # Fallback ancien format
                        iso3 = IMFCSVParser._fallback_iso3(row)
                        ind  = IMFCSVParser._fallback_indicator(row)
                    else:
                        iso3 = _resolve_iso3(series_code)
                        ind  = _resolve_indicator(series_code)

                    if not iso3 or iso3 not in AFRICAN_ISO3:
                        continue

                    # Matching indicateur : exact ou prefixe
                    if ind != imf_code_upper and not ind.startswith(imf_code_upper + "."):
                        continue

                    # Extraire valeurs annuelles
                    for year, col in year_cols.items():
                        raw = row.get(col, "").strip()
                        value = _parse_value(raw)
                        records.append({
                            "iso3":  iso3,
                            "year":  year,
                            "value": value,
                        })

        except Exception as exc:
            log.error("Erreur parsing %s %s : %s", dataset, filepath.name, exc)

        n_pays = len({r["iso3"] for r in records if r.get("value") is not None})
        log.info("%s %s -> %d enregistrements (%d pays)", dataset, imf_code, len(records), n_pays)
        return records

    @staticmethod
    def _fallback_iso3(row: dict) -> Optional[str]:
        """Fallback resolution ISO-3 pour l'ancien format WEO (sans SERIES_CODE)."""
        iso2 = (
            row.get("ISO", "") or
            row.get("ISO2", "") or
            row.get("Country Code", "")
        ).strip().upper()
        iso3 = ISO2_TO_ISO3.get(iso2)
        if not iso3:
            weo_num = row.get("WEO Country Code", "").strip()
            iso3 = IMF_NUMERIC_TO_ISO3.get(weo_num)
        return iso3

    @staticmethod
    def _fallback_indicator(row: dict) -> str:
        """Fallback code indicateur pour l'ancien format WEO."""
        return (
            row.get("WEO Subject Code", "") or
            row.get("Subject Code", "") or
            row.get("Indicator Code", "") or
            row.get("INDICATOR", "") or
            row.get("CONCEPT", "")
        ).strip().upper()

    # ── API publique ──────────────────────────────────────

    @staticmethod
    def parse_weo(
        filepath:  str | Path,
        imf_code:  str,
        year_from: int = 2010,
        year_to:   int = 2024,
    ) -> list[dict]:
        """
        Parse un fichier CSV WEO (World Economic Outlook).

        Format nouveau (2024+) :
          SERIES_CODE = {ISO3}.{WEO_CODE}.A
          ex: DZA.PCPIPCH.A, NGA.NGDP_RPCH.A

        Telecharger depuis :
          https://www.imf.org/en/Publications/WEO/weo-database/2026/April
          -> Download by Indicators -> CSV
        """
        return IMFCSVParser._parse_generic(filepath, imf_code, year_from, year_to, "WEO")

    @staticmethod
    def parse_dots(
        filepath:  str | Path,
        imf_code:  str,
        year_from: int = 2010,
        year_to:   int = 2024,
    ) -> list[dict]:
        """
        Parse un fichier CSV DOTS (Direction of Trade Statistics).

        Format nouveau (2024+) :
          SERIES_CODE = {ISO3}.{DOTS_CODE}.{PARTNER}.A
          ex: DZA.TXG_FOB_USD.W00.A  (exportations Algerie vers monde)
          Note : le code DOTS inclut souvent un code partenaire.
          Utiliser le code de base sans partenaire (matching prefixe).

        Telecharger depuis :
          https://data.imf.org/?sk=9d6028d4-f14a-464c-a2f2-59b2cd424b85
        """
        return IMFCSVParser._parse_generic(filepath, imf_code, year_from, year_to, "DOTS")

    @staticmethod
    def parse_bop(
        filepath:  str | Path,
        imf_code:  str,
        year_from: int = 2010,
        year_to:   int = 2024,
    ) -> list[dict]:
        """
        Parse un fichier CSV BOP (Balance of Payments).

        Format nouveau (2024+) :
          SERIES_CODE = {ISO3}.{BOP_CODE}.{UNIT}.A
          ex: DZA.BCA_T.USD.A  (balance courante Algerie en USD)

        Telecharger depuis :
          https://data.imf.org/?sk=7a51304b-6426-40c0-83dd-ca473ca1fd52
        """
        return IMFCSVParser._parse_generic(filepath, imf_code, year_from, year_to, "BOP")

    @staticmethod
    def detect_columns(filepath: str | Path, max_rows: int = 3) -> None:
        """
        Utilitaire debug -- affiche la structure d'un fichier CSV IMF.
        Usage : python fetcher_imf_weo_csv.py --file data/imf/WEO.csv --detect
        """
        filepath = Path(filepath)
        with open(filepath, encoding="utf-8-sig", errors="replace") as f:
            sample = f.read(4096)
            f.seek(0)
            delimiter = "\t" if "\t" in sample else ","
            reader = csv.DictReader(f, delimiter=delimiter)
            fields = reader.fieldnames or []

            # Detecter colonnes annees
            year_cols   = [c for c in fields if c.isdigit() and 1948 <= int(c) <= 2030]
            q_cols      = [c for c in fields if c[:4].isdigit() and "-Q" in c]
            m_cols      = [c for c in fields if c[:4].isdigit() and "-M" in c]
            meta_cols   = [c for c in fields if c not in year_cols + q_cols + m_cols]

            print(f"\nColonnes de {filepath.name} :")
            print("  " + ", ".join(meta_cols))
            if year_cols:
                print(f"  Annuelles : {year_cols[0]} -> {year_cols[-1]} ({len(year_cols)} annees)")
            if q_cols:
                print(f"  Trimestr. : {q_cols[0]} -> {q_cols[-1]} ({len(q_cols)})")
            if m_cols:
                print(f"  Mensuels  : {m_cols[0]} -> {m_cols[-1]} ({len(m_cols)})")

            print(f"\nPremieres {max_rows} lignes :")
            for i, row in enumerate(reader):
                if i >= max_rows:
                    break
                # Afficher seulement les colonnes metadata
                meta = {k: v for k, v in row.items() if k in meta_cols[:8]}
                print(f"  {meta}")

    @staticmethod
    def scan_codes(
        filepath:  str | Path,
        iso3:      str = "DZA",
        max_codes: int = 30,
    ) -> None:
        """
        Utilitaire -- liste les codes indicateurs disponibles pour un pays.
        Usage : IMFCSVParser.scan_codes("data/imf/WEO.csv", "DZA")
        """
        filepath = Path(filepath)
        codes: set[str] = set()
        iso3_upper = iso3.upper()

        with open(filepath, encoding="utf-8-sig", errors="replace") as f:
            sample = f.read(4096)
            f.seek(0)
            delimiter = "\t" if "\t" in sample else ","
            reader = csv.DictReader(f, delimiter=delimiter)
            for row in reader:
                sc = row.get("SERIES_CODE", "").strip()
                if not sc:
                    continue
                parts = sc.split(".")
                if parts[0].upper() != iso3_upper:
                    continue
                freq = row.get("FREQUENCY", "").strip().lower()
                if freq not in ("annual", "a", "yearly", ""):
                    continue
                ind = _resolve_indicator(sc)
                codes.add(ind)
                if len(codes) >= max_codes:
                    break

        print(f"\nCodes indicateurs disponibles pour {iso3} ({filepath.name}) :")
        for c in sorted(codes)[:max_codes]:
            print(f"  {c}")