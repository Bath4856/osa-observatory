"""
============================================================
OSA / ISA OBSERVATORY
fetcher_acled_api.py — Fetcher ACLED (API REST)
============================================================
Couvre : 4 indicateurs piliers PGEO + PMIL
Source : Armed Conflict Location & Event Data Project
URL    : https://acleddata.com
API    : https://api.acleddata.com/acled/read

ACLED est LA référence mondiale pour les données de conflits.
API REST bien documentée — clé gratuite sur inscription.
Couvre l'Afrique depuis 1997, mise à jour hebdomadaire.

Clé API :
  1. S'inscrire sur https://developer.acleddata.com
  2. Récupérer votre clé API et email
  3. Ajouter dans .env :
     ACLED_API_KEY=votre_clé
     ACLED_EMAIL=votre_email@exemple.com

Indicateurs couverts :
  GEO_CON   Conflits frontaliers actifs (NB événements)
  GEO_RSK   Risque géopolitique (fatalities pour 100k hab)
  MIL_TER   Risque terroriste (événements terrorisme)
  MIL_SEC   Sécurité intérieure (indice composite ACLED)

Usage :
  python fetcher_acled_api.py --year 2022
  python fetcher_acled_api.py --from 2010 --to 2022
  python fetcher_acled_api.py --year 2022 --dry-run
  python fetcher_acled_api.py --year 2022 --indicator GEO_CON
============================================================
"""

from __future__ import annotations

import argparse
import logging
import os
import sys
import time
from typing import Optional

from dotenv import load_dotenv

from fetcher_base import BaseFetcher, DataRecord, AFRICAN_ISO3, ISO3_TO_ISO2

load_dotenv()

logging.basicConfig(
    level=os.getenv("OSA_LOG_LEVEL", "INFO"),
    format="%(asctime)s | %(levelname)-8s | %(message)s",
)

# ── Mapping indicateurs OSA → config ACLED ────────────────

ACLED_INDICATOR_MAP: dict = {

    "GEO_CON": {
        "event_types": ["Battles", "Explosions/Remote violence"],
        "metric":      "event_count",
        "name_fr":     "Conflits armés actifs (nb événements/an)",
        "unit_code":   "NB",
        "direction":   "-",
        "multiplier":  1.0,
        "notes":       """ACLED — nombre d'événements de type Battles et explosions.
                         Direction négative : plus d'événements = moins souverain.
                         Normalisé par population dans le pipeline L3.""",
    },
    "GEO_RSK": {
        "event_types": ["Battles", "Explosions/Remote violence",
                        "Violence against civilians", "Riots"],
        "metric":      "fatalities",
        "name_fr":     "Fatalities conflits (nb décès/an)",
        "unit_code":   "PERSONS",
        "direction":   "-",
        "multiplier":  1.0,
        "notes":       """ACLED — nombre total de décès liés aux conflits par an.
                         Proxy risque géopolitique réel. À normaliser par population.""",
    },
    "MIL_TER": {
        "event_types": ["Explosions/Remote violence",
                        "Strategic developments"],
        "metric":      "event_count",
        "name_fr":     "Événements terrorisme/violence (nb/an)",
        "unit_code":   "NB",
        "direction":   "-",
        "multiplier":  1.0,
        "notes":       """ACLED — explosions, attentats, attaques ciblées.
                         Proxy risque terroriste. Complète WGI PV.EST avec données factuelles.""",
    },
    "MIL_SEC": {
        "event_types": ["Violence against civilians"],
        "metric":      "event_count",
        "name_fr":     "Violence contre civils (nb événements/an)",
        "unit_code":   "NB",
        "direction":   "-",
        "multiplier":  1.0,
        "notes":       """ACLED — violence contre les civils.
                         Proxy sécurité intérieure. Un État ne protégeant pas ses civils
                         a une souveraineté militaire affaiblie.""",
    },
}

# ── Mapping ISO-3 → code pays ACLED ───────────────────────
# ACLED utilise des noms de pays — on passe par ISO-2 → nom

ISO3_TO_ACLED_COUNTRY: dict[str, str] = {
    "DZA": "Algeria",          "EGY": "Egypt",
    "LBY": "Libya",            "MAR": "Morocco",
    "MRT": "Mauritania",       "SDN": "Sudan",
    "TUN": "Tunisia",          "BEN": "Benin",
    "BFA": "Burkina Faso",     "CIV": "Cote d'Ivoire",
    "CPV": "Cape Verde",       "GMB": "Gambia",
    "GHA": "Ghana",            "GIN": "Guinea",
    "GNB": "Guinea-Bissau",    "LBR": "Liberia",
    "MLI": "Mali",             "NER": "Niger",
    "NGA": "Nigeria",          "SLE": "Sierra Leone",
    "SEN": "Senegal",          "TGO": "Togo",
    "BDI": "Burundi",          "COM": "Comoros",
    "DJI": "Djibouti",         "ERI": "Eritrea",
    "ETH": "Ethiopia",         "KEN": "Kenya",
    "MDG": "Madagascar",       "MWI": "Malawi",
    "MUS": "Mauritius",        "MOZ": "Mozambique",
    "RWA": "Rwanda",           "SYC": "Seychelles",
    "SOM": "Somalia",          "SSD": "South Sudan",
    "TZA": "Tanzania",         "UGA": "Uganda",
    "ZMB": "Zambia",           "ZWE": "Zimbabwe",
    "AGO": "Angola",           "CMR": "Cameroon",
    "CAF": "Central African Republic",
    "TCD": "Chad",             "COG": "Republic of Congo",
    "COD": "Democratic Republic of Congo",
    "GNQ": "Equatorial Guinea","GAB": "Gabon",
    "STP": "Sao Tome and Principe",
    "BWA": "Botswana",         "SWZ": "Eswatini",
    "LSO": "Lesotho",          "NAM": "Namibia",
    "ZAF": "South Africa",
}

ACLED_BASE_URL = "https://api.acleddata.com/acled/read"
ACLED_PAGE_SIZE = 5000


class ACLEDFetcher(BaseFetcher):

    PROVIDER_CODE = "ACLED"
    ENDPOINT_CODE = "WB_COUNTRY_INDICATOR"   # Réutilise endpoint existant
    INDICATOR_MAP = ACLED_INDICATOR_MAP

    def __init__(self, dry_run: bool = False) -> None:
        super().__init__(dry_run=dry_run)
        self.api_key = os.getenv("ACLED_API_KEY", "")
        self.email   = os.getenv("ACLED_EMAIL", "")

        if not self.api_key or not self.email:
            self.log.warning(
                "ACLED_API_KEY ou ACLED_EMAIL non définis dans .env\n"
                "  Inscription gratuite sur https://developer.acleddata.com\n"
                "  Ajouter dans .env :\n"
                "    ACLED_API_KEY=votre_clé\n"
                "    ACLED_EMAIL=votre_email"
            )

    def fetch_indicator(
        self,
        osa_code:  str,
        config:    dict,
        year_from: int,
        year_to:   int,
    ) -> list[DataRecord]:
        """
        Appelle l'API ACLED pour un type d'événement.
        Agrège par pays et par année.
        """
        if not self.api_key or not self.email:
            self.log.error("Clé API ACLED manquante — skip %s", osa_code)
            return []

        event_types = config["event_types"]
        metric      = config["metric"]

        # Agrégation : (iso3, year) → valeur
        aggregated: dict[tuple, float] = {}

        for iso3 in AFRICAN_ISO3:
            country_name = ISO3_TO_ACLED_COUNTRY.get(iso3)
            if not country_name:
                continue

            records_country = self._fetch_country_year(
                country_name, iso3,
                event_types, metric,
                year_from, year_to,
            )

            for rec in records_country:
                key = (rec["iso3"], rec["year"])
                val = rec.get("value")
                if val is not None:
                    aggregated[key] = aggregated.get(key, 0.0) + val

            # Pause courtoise entre pays
            time.sleep(0.3)

        records: list[DataRecord] = [
            {"iso3": iso3, "year": year, "value": value}
            for (iso3, year), value in aggregated.items()
        ]

        self.log.info(
            "ACLED %s → %d enregistrements (%d pays)",
            osa_code, len(records),
            len({r["iso3"] for r in records}),
        )
        return records

    def _fetch_country_year(
        self,
        country_name: str,
        iso3:         str,
        event_types:  list[str],
        metric:       str,
        year_from:    int,
        year_to:      int,
    ) -> list[DataRecord]:
        """
        Appelle ACLED pour un pays, agrège par année.

        L'API ACLED retourne des événements individuels.
        On agrège soit en comptant (event_count) soit en sommant (fatalities).
        """
        results: dict[int, float] = {y: 0.0 for y in range(year_from, year_to + 1)}

        for event_type in event_types:
            page  = 1
            total = 0

            while True:
                params = {
                    "key":         self.api_key,
                    "email":       self.email,
                    "country":     country_name,
                    "event_type":  event_type,
                    "year":        f"{year_from}:{year_to}",
                    "fields":      "event_date,year,fatalities,event_type",
                    "limit":       ACLED_PAGE_SIZE,
                    "page":        page,
                    "export_type": "json",
                }

                data = self.http_get(ACLED_BASE_URL, params=params)
                if not data:
                    break

                # Vérification structure réponse ACLED
                if data.get("status") != 200:
                    msg = data.get("message", "Erreur inconnue")
                    self.log.warning("ACLED API erreur %s/%s : %s",
                                     country_name, event_type, msg)
                    break

                rows = data.get("data", [])
                if not rows:
                    break

                for row in rows:
                    try:
                        year = int(str(row.get("year", ""))[:4])
                        if not (year_from <= year <= year_to):
                            continue

                        if metric == "fatalities":
                            val = float(row.get("fatalities", 0) or 0)
                        else:
                            val = 1.0   # event_count — un événement = 1

                        results[year] = results.get(year, 0.0) + val
                        total += 1

                    except (ValueError, TypeError, KeyError):
                        continue

                # Pagination
                count_all = int(data.get("count", 0))
                if len(rows) < ACLED_PAGE_SIZE or total >= count_all:
                    break
                page += 1

        return [
            {"iso3": iso3, "year": year, "value": value if value > 0 else None}
            for year, value in results.items()
        ]


def main() -> None:
    parser = argparse.ArgumentParser(
        description="OSA Fetcher — ACLED API",
        epilog="""
Prérequis :
  Clé API gratuite sur https://developer.acleddata.com
  Ajouter dans .env :
    ACLED_API_KEY=votre_clé
    ACLED_EMAIL=votre_email@exemple.com

Exemples :
  python fetcher_acled_api.py --year 2022
  python fetcher_acled_api.py --from 2010 --to 2022
  python fetcher_acled_api.py --year 2022 --dry-run
  python fetcher_acled_api.py --year 2022 --indicator GEO_CON

Notes :
  - L'API ACLED est gratuite mais limitée en débit
  - Une collecte complète 2010-2022 prend ~30-60 minutes
  - Les données sont mises à jour hebdomadairement
  - Couverture Afrique : excellente depuis 1997
        """,
    )
    parser.add_argument("--year",      type=int,
                        help="Année unique à collecter")
    parser.add_argument("--from",      type=int, dest="year_from", default=2010)
    parser.add_argument("--to",        type=int, dest="year_to",   default=2022)
    parser.add_argument("--indicator", type=str, default=None)
    parser.add_argument("--dry-run",   action="store_true")
    parser.add_argument("--test-api",  action="store_true",
                        help="Tester la connexion API ACLED sans importer")
    args = parser.parse_args()

    year_from = args.year or args.year_from
    year_to   = args.year or args.year_to

    if args.test_api:
        import requests
        api_key = os.getenv("ACLED_API_KEY", "")
        email   = os.getenv("ACLED_EMAIL", "")
        if not api_key or not email:
            print("ACLED_API_KEY et ACLED_EMAIL requis dans .env")
            sys.exit(1)
        resp = requests.get(
            ACLED_BASE_URL,
            params={
                "key": api_key, "email": email,
                "country": "Nigeria", "year": "2022",
                "limit": 1, "export_type": "json",
            },
            timeout=15,
        )
        data = resp.json()
        if data.get("status") == 200:
            print(f"✓ API ACLED opérationnelle — {data.get('count')} événements Nigeria 2022")
        else:
            print(f"✗ Erreur API : {data.get('message')}")
        return

    fetcher = ACLEDFetcher(dry_run=args.dry_run)
    try:
        fetcher.connect()
        result = fetcher.run(year_from, year_to, args.indicator)
        sys.exit(0 if not result["failed"] else 1)
    finally:
        fetcher.disconnect()


if __name__ == "__main__":
    main()
