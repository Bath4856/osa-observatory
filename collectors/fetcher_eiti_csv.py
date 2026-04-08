"""
============================================================
OSA / ISA OBSERVATORY
fetcher_eiti_csv.py — Fetcher EITI (CSV + API)
============================================================
Couvre : 4 indicateurs pilier PMIN (souveraineté minière)
Source : Extractive Industries Transparency Initiative
URL    : https://eiti.org / https://eiti.org/data

EITI est LA référence mondiale pour la gouvernance minière.
37 pays membres actifs dont 26 africains.
Publie chaque année des données de conformité et de recettes.

Accès données EITI :
  1. API REST : https://eiti.org/api/v1.0/ (données de conformité)
  2. CSV      : https://eiti.org/resources/data (téléchargement direct)
  3. Summary Data : https://summary.eiti.org/api/v1/ (agrégats)

Indicateurs couverts :
  MIN_GOV   Score gouvernance (statut conformité EITI)
  MIN_CERT  Conformité EITI (membre / candidat / non-membre)
  MIN_TAX   Recettes extractives déclarées (USD)
  MIN_TECH  Score transparence (ratio données publiées)

Téléchargement :
  Données conformité :
    https://eiti.org/countries → Export CSV
    Placer dans data/eiti/EITI_compliance.csv

  Données recettes :
    https://summary.eiti.org → Download → CSV
    Placer dans data/eiti/EITI_revenues.csv

Usage :
  python fetcher_eiti_csv.py --dir data/eiti/
  python fetcher_eiti_csv.py --dir data/eiti/ --dry-run
  python fetcher_eiti_csv.py --dir data/eiti/ --indicator MIN_GOV
  python fetcher_eiti_csv.py --dir data/eiti/ --api (mode API)
  python fetcher_eiti_csv.py --dir data/eiti/ --list-missing
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

# ── Mapping statuts EITI → score gouvernance ──────────────
# EITI classe les pays en 4 statuts de conformité

EITI_STATUS_SCORE: dict[str, float] = {
    "compliant":          90.0,   # Conforme — meilleure gouvernance
    "meaningful progress": 70.0,  # Progrès significatifs
    "candidate":          50.0,   # Pays candidat — en cours d'adhésion
    "suspended":          20.0,   # Suspendu — problèmes de conformité
    "delisted":           10.0,   # Retiré de l'EITI
    "non-member":          0.0,   # Non membre
}

# ── Pays africains membres EITI (2024) ────────────────────
# Source : https://eiti.org/countries

EITI_AFRICAN_MEMBERS: dict[str, dict] = {
    "DZA": {"status": "candidate",          "since": 2020},
    "AGO": {"status": "candidate",          "since": 2021},
    "BEN": {"status": "candidate",          "since": 2023},
    "BFA": {"status": "suspended",          "since": 2016},
    "CMR": {"status": "compliant",          "since": 2013},
    "CAF": {"status": "meaningful progress","since": 2008},
    "TCD": {"status": "meaningful progress","since": 2010},
    "COG": {"status": "compliant",          "since": 2013},
    "COD": {"status": "meaningful progress","since": 2010},
    "CIV": {"status": "compliant",          "since": 2012},
    "EGY": {"status": "candidate",          "since": 2016},
    "ETH": {"status": "candidate",          "since": 2014},
    "GAB": {"status": "meaningful progress","since": 2022},
    "GHA": {"status": "compliant",          "since": 2010},
    "GIN": {"status": "compliant",          "since": 2012},
    "GNB": {"status": "candidate",          "since": 2018},
    "KEN": {"status": "meaningful progress","since": 2015},
    "LBR": {"status": "compliant",          "since": 2009},
    "MDG": {"status": "compliant",          "since": 2014},
    "MLI": {"status": "meaningful progress","since": 2008},
    "MRT": {"status": "compliant",          "since": 2012},
    "MOZ": {"status": "meaningful progress","since": 2009},
    "NAM": {"status": "meaningful progress","since": 2022},
    "NER": {"status": "compliant",          "since": 2011},
    "NGA": {"status": "compliant",          "since": 2007},
    "RWA": {"status": "compliant",          "since": 2009},
    "SLE": {"status": "compliant",          "since": 2009},
    "SEN": {"status": "compliant",          "since": 2013},
    "TZA": {"status": "compliant",          "since": 2012},
    "TGO": {"status": "compliant",          "since": 2013},
    "UGA": {"status": "meaningful progress","since": 2008},
    "ZMB": {"status": "meaningful progress","since": 2009},
    "ZWE": {"status": "candidate",          "since": 2019},
}

# ── Mapping indicateurs OSA → config EITI ─────────────────

EITI_INDICATOR_MAP: dict = {

    "MIN_GOV": {
        "dataset":    "COMPLIANCE",
        "metric":     "governance_score",
        "name_fr":    "Score gouvernance minière EITI (0-100)",
        "unit_code":  "SCORE_0_100",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      """EITI — score calculé depuis le statut de conformité.
                        Compliant=90, Meaningful progress=70, Candidate=50,
                        Suspended=20, Non-member=0.
                        Proxy le plus fiable pour MIN_GOV disponible publiquement.""",
    },
    "MIN_CERT": {
        "dataset":    "COMPLIANCE",
        "metric":     "is_member",
        "name_fr":    "Membership EITI (1=membre actif, 0=non-membre)",
        "unit_code":  "RATIO",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      """EITI — indicateur binaire d'adhésion active.
                        1 = membre ou candidat actif
                        0 = non-membre, suspendu ou retiré.""",
    },
    "MIN_TAX": {
        "dataset":    "REVENUES",
        "metric":     "total_revenues_usd",
        "name_fr":    "Recettes extractives déclarées EITI (USD)",
        "unit_code":  "USD",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      """EITI Summary Data — recettes totales du secteur extractif
                        déclarées et réconciliées par les pays membres.
                        Couvre pétrole + gaz + mines selon les pays.""",
    },
    "MIN_TECH": {
        "dataset":    "COMPLIANCE",
        "metric":     "transparency_score",
        "name_fr":    "Score transparence données minières EITI",
        "unit_code":  "SCORE_0_100",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      """EITI — ratio données publiées / données attendues.
                        Proxy niveau technologique et capacité de reporting.
                        Un pays qui publie beaucoup de données a une industrie plus mature.""",
    },
}


class EITIFetcher(BaseFetcher):

    PROVIDER_CODE = "EITI"
    ENDPOINT_CODE = "WB_COUNTRY_INDICATOR"
    INDICATOR_MAP = EITI_INDICATOR_MAP

    EITI_API_BASE    = "https://eiti.org/api/v1.0"
    SUMMARY_API_BASE = "https://summary.eiti.org/api/v1"

    def __init__(
        self,
        data_dir: str = "data/eiti",
        use_api:  bool = False,
        dry_run:  bool = False,
    ) -> None:
        super().__init__(dry_run=dry_run)
        self.data_dir = Path(data_dir)
        self.use_api  = use_api

    def fetch_indicator(
        self,
        osa_code:  str,
        config:    dict,
        year_from: int,
        year_to:   int,
    ) -> list[DataRecord]:
        """Dispatch vers CSV ou API selon le dataset."""
        dataset = config["dataset"]
        metric  = config["metric"]

        if dataset == "COMPLIANCE":
            return self._fetch_compliance(metric, year_from, year_to)
        elif dataset == "REVENUES":
            if self.use_api:
                return self._fetch_revenues_api(year_from, year_to)
            else:
                return self._fetch_revenues_csv(year_from, year_to)
        else:
            self.log.error("Dataset EITI inconnu : %s", dataset)
            return []

    # ── COMPLIANCE ────────────────────────────────────────

    def _fetch_compliance(
        self,
        metric:    str,
        year_from: int,
        year_to:   int,
    ) -> list[DataRecord]:
        """
        Génère les scores de conformité EITI.

        Deux modes :
        1. CSV : lit EITI_compliance.csv si disponible
        2. Intégré : utilise EITI_AFRICAN_MEMBERS (données 2024 intégrées)
        """
        csv_path = self.data_dir / "EITI_compliance.csv"

        if csv_path.exists():
            return self._parse_compliance_csv(csv_path, metric, year_from, year_to)
        else:
            self.log.info(
                "EITI_compliance.csv absent — utilisation des données intégrées 2024\n"
                "  Pour données historiques : https://eiti.org/countries → Export CSV"
            )
            return self._generate_compliance_from_builtin(metric, year_from, year_to)

    def _parse_compliance_csv(
        self,
        csv_path:  Path,
        metric:    str,
        year_from: int,
        year_to:   int,
    ) -> list[DataRecord]:
        """Parse EITI_compliance.csv téléchargé depuis eiti.org/countries."""
        records: list[DataRecord] = []

        try:
            with open(csv_path, encoding="utf-8-sig", errors="replace") as f:
                sample    = f.read(1024)
                f.seek(0)
                delimiter = "\t" if "\t" in sample else ","
                reader    = csv.DictReader(f, delimiter=delimiter)

                for row in reader:
                    iso3 = (
                        row.get("iso3") or row.get("ISO3") or
                        row.get("country_code") or ""
                    ).strip().upper()

                    if iso3 not in AFRICAN_ISO3:
                        continue

                    status = (
                        row.get("status") or
                        row.get("eiti_status") or
                        row.get("Status") or "non-member"
                    ).strip().lower()

                    year_raw = (row.get("year") or row.get("Year") or "").strip()
                    try:
                        year = int(year_raw)
                    except (ValueError, TypeError):
                        year = 2024   # défaut si pas d'année

                    if not (year_from <= year <= year_to):
                        continue

                    value = self._compliance_to_metric(status, metric)
                    records.append({"iso3": iso3, "year": year, "value": value})

        except Exception as exc:
            self.log.error("Erreur parsing EITI compliance : %s", exc)

        return records

    def _generate_compliance_from_builtin(
        self,
        metric:    str,
        year_from: int,
        year_to:   int,
    ) -> list[DataRecord]:
        """
        Génère les scores depuis les données intégrées EITI_AFRICAN_MEMBERS.
        Applique le même score pour toutes les années (statut 2024).
        Les pays non-membres reçoivent 0.
        """
        records: list[DataRecord] = []

        for iso3 in AFRICAN_ISO3:
            member_info = EITI_AFRICAN_MEMBERS.get(iso3)
            status      = member_info["status"] if member_info else "non-member"
            since       = member_info["since"]  if member_info else 9999

            for year in range(year_from, year_to + 1):
                # Avant l'adhésion = non-membre
                effective_status = status if year >= since else "non-member"
                value = self._compliance_to_metric(effective_status, metric)
                records.append({"iso3": iso3, "year": year, "value": value})

        self.log.info(
            "EITI compliance (données intégrées) → %d enregistrements",
            len(records),
        )
        return records

    def _compliance_to_metric(self, status: str, metric: str) -> Optional[float]:
        """Convertit un statut EITI en valeur numérique selon la métrique."""
        if metric == "governance_score":
            return EITI_STATUS_SCORE.get(status.lower(), 0.0)
        elif metric == "is_member":
            return 1.0 if status.lower() in (
                "compliant", "meaningful progress", "candidate"
            ) else 0.0
        elif metric == "transparency_score":
            # Approximation — compliant = publie plus de données
            scores = {
                "compliant":           85.0,
                "meaningful progress": 65.0,
                "candidate":           45.0,
                "suspended":           15.0,
                "non-member":           0.0,
            }
            return scores.get(status.lower(), 0.0)
        return None

    # ── REVENUES CSV ──────────────────────────────────────

    def _fetch_revenues_csv(
        self,
        year_from: int,
        year_to:   int,
    ) -> list[DataRecord]:
        """
        Parse EITI_revenues.csv depuis summary.eiti.org.

        Format attendu :
        country | iso3 | year | total_revenues_usd | sector | ...
        """
        csv_path = self.data_dir / "EITI_revenues.csv"
        if not csv_path.exists():
            self.log.warning(
                "EITI_revenues.csv manquant\n"
                "  Télécharger : https://summary.eiti.org → Download → CSV\n"
                "  Ou utiliser l'API : --api"
            )
            return []

        records: list[DataRecord] = []

        try:
            with open(csv_path, encoding="utf-8-sig", errors="replace") as f:
                sample    = f.read(1024)
                f.seek(0)
                delimiter = "\t" if "\t" in sample else ","
                reader    = csv.DictReader(f, delimiter=delimiter)

                # Agrégation par pays/année (somme de tous les secteurs)
                aggregated: dict[tuple, float] = {}

                for row in reader:
                    iso3 = (
                        row.get("iso3") or row.get("ISO3") or
                        row.get("country_code") or ""
                    ).strip().upper()

                    if iso3 not in AFRICAN_ISO3:
                        continue

                    year_raw = (row.get("year") or row.get("Year") or "").strip()
                    try:
                        year = int(year_raw)
                        if not (year_from <= year <= year_to):
                            continue
                    except (ValueError, TypeError):
                        continue

                    rev_raw = (
                        row.get("total_revenues_usd") or
                        row.get("revenues_usd") or
                        row.get("amount_usd") or ""
                    ).strip()

                    try:
                        rev = float(rev_raw.replace(",", "")) if rev_raw else 0.0
                    except ValueError:
                        rev = 0.0

                    key = (iso3, year)
                    aggregated[key] = aggregated.get(key, 0.0) + rev

                records = [
                    {"iso3": iso3, "year": year, "value": value if value > 0 else None}
                    for (iso3, year), value in aggregated.items()
                ]

        except Exception as exc:
            self.log.error("Erreur parsing EITI revenues : %s", exc)

        return records

    # ── REVENUES API ──────────────────────────────────────

    def _fetch_revenues_api(
        self,
        year_from: int,
        year_to:   int,
    ) -> list[DataRecord]:
        """
        Collecte les recettes EITI via l'API summary.eiti.org.
        Itère par pays membre africain et par année.
        """
        records: list[DataRecord] = []

        for iso3, info in EITI_AFRICAN_MEMBERS.items():
            if iso3 not in AFRICAN_ISO3:
                continue

            for year in range(
                max(year_from, info.get("since", year_from)),
                year_to + 1,
            ):
                url  = f"{self.SUMMARY_API_BASE}/revenues/"
                params = {
                    "country": iso3.lower(),
                    "year":    year,
                    "format":  "json",
                }
                data = self.http_get(url, params=params)
                if not data:
                    continue

                try:
                    total = sum(
                        float(item.get("amount", 0) or 0)
                        for item in (data if isinstance(data, list) else [])
                    )
                    records.append({
                        "iso3":  iso3,
                        "year":  year,
                        "value": total if total > 0 else None,
                    })
                except (TypeError, ValueError):
                    continue

        return records


def main() -> None:
    parser = argparse.ArgumentParser(
        description="OSA Fetcher — EITI CSV + API",
        epilog="""
Fichiers optionnels dans --dir :
  EITI_compliance.csv  Statuts conformité (sinon données intégrées 2024)
  EITI_revenues.csv    Recettes extractives (sinon utiliser --api)

Téléchargements EITI :
  Compliance : https://eiti.org/countries → Export CSV
  Revenues   : https://summary.eiti.org → Download → CSV

Note : sans fichiers CSV, le fetcher utilise les données de
       conformité 2024 intégrées pour les 33 pays africains EITI.

Exemples :
  python fetcher_eiti_csv.py --dir data/eiti/
  python fetcher_eiti_csv.py --dir data/eiti/ --dry-run
  python fetcher_eiti_csv.py --dir data/eiti/ --indicator MIN_GOV
  python fetcher_eiti_csv.py --dir data/eiti/ --api
  python fetcher_eiti_csv.py --dir data/eiti/ --list-missing
        """,
    )
    parser.add_argument("--dir",          type=str, required=True)
    parser.add_argument("--from",         type=int, dest="year_from", default=2010)
    parser.add_argument("--to",           type=int, dest="year_to",   default=2024)
    parser.add_argument("--indicator",    type=str, default=None)
    parser.add_argument("--dry-run",      action="store_true")
    parser.add_argument("--api",          action="store_true",
                        help="Utiliser l'API EITI pour les recettes")
    parser.add_argument("--list-missing", action="store_true")
    args = parser.parse_args()

    if args.list_missing:
        data_dir = Path(args.dir)
        files = ["EITI_compliance.csv", "EITI_revenues.csv"]
        print(f"\nFichiers EITI dans {data_dir} :")
        for f in files:
            path   = data_dir / f
            status = "✓ présent" if path.exists() else "○ optionnel (données intégrées disponibles)"
            print(f"  {f} — {status}")
        print(f"\n  Pays africains EITI intégrés : {len(EITI_AFRICAN_MEMBERS)}/54")
        compliant = sum(
            1 for v in EITI_AFRICAN_MEMBERS.values()
            if v["status"] == "compliant"
        )
        print(f"  Dont conformes : {compliant}")
        return

    fetcher = EITIFetcher(
        data_dir=args.dir,
        use_api=args.api,
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
