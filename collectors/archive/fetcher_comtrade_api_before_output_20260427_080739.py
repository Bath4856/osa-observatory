"""
============================================================
OSA / ISA OBSERVATORY 20260407
fetcher_comtrade_api.py — Fetcher UN Comtrade (API publique)
============================================================
Indicateurs couverts :
  - ECO_EXP : Exportations manufacturières (% exports totaux)
              Sections HS 5-8 / total exports
  - ECO_IMP : Dépendance aux importations (USD)
              Importations totales CIF
  - MIN_EXP : Exportations minières (USD)
              Section HS 26 (minerais, scories, cendres)

Source : UN Comtrade API publique (sans clé)
URL    : https://comtradeapi.un.org/public/v1/preview/C/A/HS

Validation terrain (avril 2026) :
  NGA (566) MIN_EXP 2022 → 107 M USD  ✓
  ZAF (710) MIN_EXP 2022 → 16 Md USD  ✓ (H6, isReported=false)
  COD (180) MIN_EXP 2022 → 139 M USD  ✓ (H4, isReported=false)
  NGA (566) ECO_IMP 2022 → 60 Md USD  ✓ (cifvalue)

Limites API publique (sans clé) :
  - 100 requêtes / heure
  - Max 500 lignes par requête
  - Données jusqu'en 2023

Usage :
  python fetcher_comtrade_api.py --from 2018 --to 2022 --sample --dry-run
  python fetcher_comtrade_api.py --from 2018 --to 2022 --sample
  python fetcher_comtrade_api.py --from 2010 --to 2022
============================================================
"""

from __future__ import annotations

import argparse
import logging
import os
import sys
import time

from dotenv import load_dotenv

from fetcher_base import (
    BaseFetcher, DataRecord,
    AFRICAN_ISO3, SAMPLE_ISO3,
    PAUSE_BETWEEN_CALLS,
)

load_dotenv()

logging.basicConfig(
    level=os.getenv("OSA_LOG_LEVEL", "INFO"),
    format="%(asctime)s | %(levelname)-8s | %(message)s",
)

log = logging.getLogger("fetcher_comtrade_api")

# ── Constantes Comtrade ────────────────────────────────────────────────────

COMTRADE_BASE = "https://comtradeapi.un.org/public/v1/preview/C/A/HS"

# Sections HS manufacturières pour ECO_EXP
# S5=Chimie, S6=Plastiques/métaux, S7=Machines/électronique, S8=Divers manuf.
MANUFACTURED_HS_SECTIONS = ["5", "6", "7", "8"]

# Section HS 26 = Minerais, scories et cendres → MIN_EXP
MINING_HS_SECTION = "26"

# Pause entre requêtes pour respecter 100 req/h
COMTRADE_PAUSE = 37.0

# Mapping ISO-3 → code numérique Comtrade (M49)
ISO3_TO_M49: dict[str, str] = {
    "DZA":"12",  "EGY":"818","LBY":"434","MAR":"504","MRT":"478",
    "SDN":"729", "TUN":"788","BEN":"204","BFA":"854","CIV":"384",
    "CPV":"132", "GMB":"270","GHA":"288","GIN":"324","GNB":"624",
    "LBR":"430", "MLI":"466","NER":"562","NGA":"566","SLE":"694",
    "SEN":"686", "TGO":"768","BDI":"108","COM":"174","DJI":"262",
    "ERI":"232", "ETH":"231","KEN":"404","MDG":"450","MWI":"454",
    "MUS":"480", "MOZ":"508","RWA":"646","SYC":"690","SOM":"706",
    "SSD":"728", "TZA":"834","UGA":"800","ZMB":"894","ZWE":"716",
    "AGO":"24",  "CMR":"120","CAF":"140","TCD":"148","COG":"178",
    "COD":"180", "GNQ":"226","GAB":"266","STP":"678","BWA":"72",
    "SWZ":"748", "LSO":"426","NAM":"516","ZAF":"710",
}


# ── Mapping indicateurs OSA → config Comtrade ─────────────────────────────

COMTRADE_INDICATOR_MAP: dict = {
    "ECO_EXP": {
        "name_fr":    "Exportations manufacturières (% exports totaux)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "Comtrade — sections HS 5-8 / exports totaux",
    },
    "ECO_IMP": {
        "name_fr":    "Importations totales (USD CIF)",
        "unit_code":  "USD",
        "direction":  "-",
        "multiplier": 1.0,
        "notes":      "Comtrade — importations totales CIF en USD",
    },
    "MIN_EXP": {
        "name_fr":    "Exportations minières (USD FOB)",
        "unit_code":  "USD",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "Comtrade — section HS 26 (minerais, scories, cendres) FOB",
    },
}


class COMTRADEAPIFetcher(BaseFetcher):

    PROVIDER_CODE = "COMTRADE"
    ENDPOINT_CODE = "COMTRADE_TRADE"
    INDICATOR_MAP = COMTRADE_INDICATOR_MAP

    def fetch_indicator(
        self,
        osa_code:  str,
        config:    dict,
        year_from: int,
        year_to:   int,
    ) -> list[DataRecord]:
        if osa_code == "ECO_EXP":
            return self._fetch_manufactured_exports(year_from, year_to)
        elif osa_code == "ECO_IMP":
            return self._fetch_total_imports(year_from, year_to)
        elif osa_code == "MIN_EXP":
            return self._fetch_mining_exports(year_from, year_to)
        else:
            self.log.error("Indicateur non supporté : %s", osa_code)
            return []

    # ── ECO_IMP — importations totales ────────────────────────────────────

    def _fetch_total_imports(
        self,
        year_from: int,
        year_to:   int,
    ) -> list[DataRecord]:
        """Importations totales CIF par pays et par année."""
        records: list[DataRecord] = []

        for iso3 in list(AFRICAN_ISO3):
            m49 = ISO3_TO_M49.get(iso3)
            if not m49:
                continue
            for year in range(year_from, year_to + 1):
                val = self._call_api(m49, year, flow="M", cmd="TOTAL")
                time.sleep(COMTRADE_PAUSE)
                records.append({"iso3": iso3, "year": year, "value": val})
                self.log.debug("%s %d ECO_IMP → %s", iso3, year, val)

        return records

    # ── MIN_EXP — exportations minières HS 26 ─────────────────────────────

    def _fetch_mining_exports(
        self,
        year_from: int,
        year_to:   int,
    ) -> list[DataRecord]:
        """Exportations section HS 26 (minerais) FOB par pays et par année."""
        records: list[DataRecord] = []

        for iso3 in list(AFRICAN_ISO3):
            m49 = ISO3_TO_M49.get(iso3)
            if not m49:
                continue
            for year in range(year_from, year_to + 1):
                val = self._call_api(m49, year, flow="X", cmd=MINING_HS_SECTION)
                time.sleep(COMTRADE_PAUSE)
                records.append({"iso3": iso3, "year": year, "value": val})
                self.log.debug("%s %d MIN_EXP → %s", iso3, year, val)

        return records

    # ── ECO_EXP — exportations manufacturières ────────────────────────────

    def _fetch_manufactured_exports(
        self,
        year_from: int,
        year_to:   int,
    ) -> list[DataRecord]:
        """
        Ratio exports sections HS 5-8 / exports totaux.
        Nécessite 2 appels par (pays, année) :
          1. exports totaux
          2. exports sections manufacturières (somme HS 5+6+7+8)
        """
        records: list[DataRecord] = []

        for iso3 in list(AFRICAN_ISO3):
            m49 = ISO3_TO_M49.get(iso3)
            if not m49:
                continue
            for year in range(year_from, year_to + 1):

                # Exports totaux
                total = self._call_api(m49, year, flow="X", cmd="TOTAL")
                time.sleep(COMTRADE_PAUSE)

                if total is None or total == 0:
                    records.append({"iso3": iso3, "year": year, "value": None})
                    continue

                # Exports manufacturiers — somme sections HS 5 à 8
                manuf = 0.0
                found = False
                for section in MANUFACTURED_HS_SECTIONS:
                    val = self._call_api(m49, year, flow="X", cmd=section)
                    time.sleep(COMTRADE_PAUSE / 4)
                    if val is not None:
                        manuf += val
                        found  = True

                if not found:
                    records.append({"iso3": iso3, "year": year, "value": None})
                    continue

                ratio = round(manuf / total * 100, 4)
                records.append({"iso3": iso3, "year": year, "value": ratio})
                self.log.debug(
                    "%s %d ECO_EXP — total=%.0f manuf=%.0f ratio=%.2f%%",
                    iso3, year, total, manuf, ratio,
                )

        return records

    # ── Appel API commun ───────────────────────────────────────────────────

    def _call_api(
        self,
        m49:  str,
        year: int,
        flow: str,   # "X" = export, "M" = import
        cmd:  str,   # "TOTAL", "26", "5", "6"…
    ) -> float | None:
        """Un appel API Comtrade — retourne primaryValue ou None."""
        params = {
            "reporterCode": m49,
            "period":       str(year),
            "flowCode":     flow,
            "cmdCode":      cmd,
            "partnerCode":  "0",
            "partner2Code": "0",
            "customsCode":  "C00",
            "motCode":      "0",
        }
        data = self.http_get(COMTRADE_BASE, params=params)
        return self._extract_value(data)

    @staticmethod
    def _extract_value(data: dict | list | None) -> float | None:
        """
        Extrait primaryValue depuis une réponse Comtrade.
        Pour exports  → fobvalue     est renseigné
        Pour imports  → cifvalue     est renseigné
        primaryValue  = l'un ou l'autre selon le flux — toujours présent.
        """
        if not data:
            return None
        try:
            rows = data.get("data", []) if isinstance(data, dict) else data
            if not rows:
                return None
            row = rows[0]
            val = row.get("primaryValue")
            if val is not None:
                return float(val)
            # Fallback explicite
            for key in ("fobvalue", "cifvalue"):
                if row.get(key) is not None:
                    return float(row[key])
        except (KeyError, IndexError, TypeError, ValueError):
            pass
        return None


# ── CLI ────────────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(
        description="OSA Fetcher — UN Comtrade API publique",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Indicateurs collectés :
  ECO_EXP — exportations manufacturières (% total)
  ECO_IMP — importations totales (USD CIF)
  MIN_EXP — exportations minières HS 26 (USD FOB)

Exemples :
  # Test rapide 10 pays (recommandé)
  python fetcher_comtrade_api.py --from 2020 --to 2022 --sample --dry-run

  # Collecte réelle échantillon
  python fetcher_comtrade_api.py --from 2018 --to 2022 --sample

  # Un seul indicateur
  python fetcher_comtrade_api.py --from 2020 --to 2022 --sample --indicator MIN_EXP

  # Collecte complète (~8h pour 54 pays × 5 ans × 3 indicateurs)
  python fetcher_comtrade_api.py --from 2010 --to 2022

Attention :
  API publique limitée à 100 req/h.
  Pour la production, envisagez une clé gratuite :
  https://comtradeapi.un.org/
        """,
    )
    parser.add_argument("--year",      type=int)
    parser.add_argument("--from",      type=int, dest="year_from", default=2018)
    parser.add_argument("--to",        type=int, dest="year_to",   default=2022)
    parser.add_argument("--indicator", type=str, default=None,
                        help="ECO_EXP | ECO_IMP | MIN_EXP")
    parser.add_argument("--dry-run",   action="store_true")
    parser.add_argument("--sample",    action="store_true",
                        help="10 pays représentatifs uniquement")
    args = parser.parse_args()

    year_from = args.year or args.year_from
    year_to   = args.year or args.year_to

    if args.sample:
        import fetcher_base as _fb
        _fb.AFRICAN_ISO3 = SAMPLE_ISO3
        log.info("Mode SAMPLE — 10 pays représentatifs")

    fetcher = COMTRADEAPIFetcher(dry_run=args.dry_run)
    try:
        fetcher.connect()
        result = fetcher.run(year_from, year_to, args.indicator)
        sys.exit(0 if not result["failed"] else 1)
    finally:
        fetcher.disconnect()


if __name__ == "__main__":
    main()