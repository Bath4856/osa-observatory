"""
============================================================
OSA / ISA OBSERVATORY 20260407
fetcher_itu.py — Fetcher UIT (ITU Datahub)
============================================================
Couvre : 10 indicateurs pilier PNUM (souveraineté numérique)
         + MIL_CYB (alias GCI — même source que NUM_CYB)
API    : ITU Datahub REST JSON

Particularités ITU :
  - L'API Datahub accepte plusieurs indicateurs et pays en batch
  - Les codes pays sont en ISO-3
  - Certains indicateurs ICT ne commencent qu'en 2000 ou 2005
  - L'indice de cybersécurité GCI n'est disponible que depuis 2017
  - La réponse peut inclure des estimations (EstimationMethod)
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

# ── Mapping indicateurs OSA → codes ITU ───────────────────

ITU_INDICATOR_MAP: dict = {

    "NUM_INT": {
        "itu_code":   "i99H",
        "name_fr":    "Utilisateurs internet (% population)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "ITU — individus utilisant internet. Série longue depuis 2000.",
    },
    "NUM_MOB": {
        "itu_code":   "i271",
        "name_fr":    "Abonnements mobiles pour 100 habitants",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "ITU — abonnements mobiles actifs pour 100 habitants",
    },
    "NUM_CYB": {
        "itu_code":   "GCI",
        "name_fr":    "Indice mondial de cybersécurité (GCI)",
        "unit_code":  "SCORE_0_100",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "ITU GCI — disponible depuis 2017 uniquement",
    },
    "MIL_CYB": {
        "itu_code":   "GCI",
        "name_fr":    "Cyberdéfense nationale (GCI)",
        "unit_code":  "SCORE_0_100",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "ITU GCI — même source que NUM_CYB. "
                      "Mesure la cybersécurité nationale au sens large "
                      "(légal, technique, organisationnel, coopération).",
    },
    "NUM_GOV": {
        "itu_code":   "EGDI",
        "name_fr":    "Indice de développement e-gouvernement",
        "unit_code":  "SCORE_0_100",
        "direction":  "+",
        "multiplier": 100.0,  # EGDI natif sur 1 → ramené à 100
        "notes":      "UNDESA EGDI — récupéré via ITU Datahub. Enquête biennale.",
    },
    "NUM_FIB": {
        "itu_code":   "i4213",
        "name_fr":    "Abonnements fibre fixe (pour 100 hab.)",
        "unit_code":  "INDEX",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "ITU — abonnements haut débit fixe par fibre",
    },
    "NUM_DAT": {
        "itu_code":   "i271E",
        "name_fr":    "Abonnements internet fixe (pour 100 hab.)",
        "unit_code":  "INDEX",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "ITU — proxy infrastructure numérique fixe.",
    },
    "NUM_DIG": {
        "itu_code":   "IDI",
        "name_fr":    "Indice de développement TIC (IDI)",
        "unit_code":  "SCORE_0_100",
        "direction":  "+",
        "multiplier": 10.0,  # IDI sur 10 → 100
        "notes":      "ITU ICT Development Index — composante principale PNUM",
    },
    "NUM_STU": {
        "itu_code":   "i271S",
        "name_fr":    "Abonnements mobile haut débit (pour 100 hab.)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "ITU — proxy accès formation numérique mobile",
    },
    "NUM_FIN": {
        "itu_code":   "i4259",
        "name_fr":    "Utilisateurs internet mobile (pour 100 hab.)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "ITU — proxy fintech et paiements mobiles",
    },
    "NUM_RES": {
        "itu_code":   "i226",
        "name_fr":    "Abonnements téléphonie fixe (pour 100 hab.)",
        "unit_code":  "INDEX",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "ITU — proxy résilience réseau fixe national",
    },
}


# ── Fetcher ITU ────────────────────────────────────────────

class ITUFetcher(BaseFetcher):

    PROVIDER_CODE = "ITU"
    ENDPOINT_CODE = "ITU_INDICATOR"
    INDICATOR_MAP = ITU_INDICATOR_MAP

    ITU_BASE = "https://datahub.itu.int/api/data/"

    def fetch_indicator(
        self,
        osa_code:  str,
        config:    dict,
        year_from: int,
        year_to:   int,
    ) -> list[DataRecord]:
        """
        Appelle l'API ITU Datahub.
        Batch : tous les pays africains en une requête.

        Note MIL_CYB : utilise le même code ITU que NUM_CYB (GCI).
        Les données sont identiques — l'indicateur est dupliqué
        pour alimenter à la fois le pilier PNUM et PMIL.
        """
        itu_code    = config["itu_code"]
        countries   = ";".join(AFRICAN_ISO3)
        time_period = f"{year_from}-{year_to}"

        url    = self.ITU_BASE
        params = {
            "indicator":    itu_code,
            "e":            countries,
            "timePeriod":   time_period,
            "outputFormat": "json",
        }

        data = self.http_get(url, params=params)
        if not data:
            return []

        records: list[DataRecord] = []

        try:
            rows = data.get("data") or data.get("DataSeries") or []

            if isinstance(rows, dict):
                rows = rows.get("Series", [])

            for row in rows:
                iso3      = (row.get("areaCode") or row.get("AreaCode") or "").upper()
                year_raw  = row.get("year") or row.get("timePeriod") or row.get("Year")
                value_raw = row.get("value") or row.get("Value") or row.get("obsValue")

                if iso3 not in AFRICAN_ISO3:
                    continue
                if year_raw is None:
                    continue

                try:
                    year = int(str(year_raw)[:4])
                    if not (year_from <= year <= year_to):
                        continue
                except (ValueError, TypeError):
                    continue

                try:
                    v = float(value_raw) if value_raw not in (None, "", "NA", "..") else None
                except (ValueError, TypeError):
                    v = None

                records.append({"iso3": iso3, "year": year, "value": v})

        except (AttributeError, KeyError, TypeError) as exc:
            self.log.error("Parsing ITU %s : %s", itu_code, exc)
            return []

        self.log.debug("ITU %s → %d enregistrements", itu_code, len(records))
        return records


# ── CLI ────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(description="OSA Fetcher — ITU Datahub")
    parser.add_argument("--year",      type=int)
    parser.add_argument("--from",      type=int, dest="year_from", default=2010)
    parser.add_argument("--to",        type=int, dest="year_to",   default=2022)
    parser.add_argument("--indicator", type=str, default=None)
    parser.add_argument("--dry-run",   action="store_true")
    parser.add_argument("--output", choices=["csv", "db", "both"], default="both", help="Mode de sortie (ignoré — compatibilité orchestrateur)")
    args = parser.parse_args()

    year_from = year_to = args.year if args.year else args.year_from
    year_to   = args.year if args.year else args.year_to

    fetcher = ITUFetcher(dry_run=args.dry_run)
    try:
        fetcher.connect()
        result = fetcher.run(year_from, year_to, args.indicator)
        sys.exit(0 if not result["failed"] else 1)
    finally:
        fetcher.disconnect()


if __name__ == "__main__":
    main()