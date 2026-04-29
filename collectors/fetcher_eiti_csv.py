"""
============================================================
OSA Observatory
collectors/fetcher_eiti_csv.py — Fetcher EITI (Excel + CSV + API)
============================================================
Indicateurs couverts (pilier PMIN) :

  MIN_GOV   Score gouvernance minière EITI [0-100]
            Basé sur le statut de conformité EITI par pays/année
            Compliant=90 | Meaningful progress=70 | Candidate=50
            Suspended=20 | Non-member=0

  MIN_CERT  Membership EITI (1=membre actif, 0=non-membre)
            Indicateur binaire d'adhésion active

  MIN_TAX   Recettes fiscales extractives déclarées (USD→score)
            Agrégation taxes+redevances+dividendes depuis Excel EITI
            Normalisation log(1+x) intra-année [0,100]

  MIN_TECH  Score transparence données minières [0-100]
            Proxy capacité de reporting extractif

Sources :
  1. Excel EITI Data Query — fichier téléchargé manuellement
     https://eiti.org/data → Data Query Tool → Export Excel
     Placer dans : data/raw/pmin/eiti/EITI_revenue_data_query__version_1_.xlsx

  2. CSV EITI Compliance — optionnel
     https://eiti.org/countries → Export CSV
     Placer dans : data/raw/pmin/eiti/EITI_compliance.csv

  3. API EITI Summary — mode --api
     https://summary.eiti.org/api/v1/

  Sans fichiers CSV, les données de conformité 2024 intégrées
  sont utilisées pour générer MIN_GOV/MIN_CERT/MIN_TECH.

Usage :
  python collectors/fetcher_eiti_csv.py --dir data/raw/pmin/eiti --dry-run
  python collectors/fetcher_eiti_csv.py --dir data/raw/pmin/eiti
  python collectors/fetcher_eiti_csv.py --dir data/raw/pmin/eiti --indicator MIN_TAX
  python collectors/fetcher_eiti_csv.py --dir data/raw/pmin/eiti --api
  python collectors/fetcher_eiti_csv.py --dir data/raw/pmin/eiti --list-missing
============================================================
"""
from __future__ import annotations

import argparse
import csv
import logging
import math
import os
import sys
from pathlib import Path
from typing import Optional

import pandas as pd
from dotenv import load_dotenv

from fetcher_base import BaseFetcher, DataRecord, AFRICAN_ISO3

load_dotenv()

# ── Statuts EITI → score gouvernance ─────────────────────────────────────────
EITI_STATUS_SCORE: dict[str, float] = {
    "compliant":           90.0,
    "meaningful progress": 70.0,
    "candidate":           50.0,
    "suspended":           20.0,
    "delisted":            10.0,
    "non-member":           0.0,
}

EITI_STATUS_TRANSPARENCY: dict[str, float] = {
    "compliant":           85.0,
    "meaningful progress": 65.0,
    "candidate":           45.0,
    "suspended":           15.0,
    "delisted":             5.0,
    "non-member":           0.0,
}

# ── Pays africains membres EITI (statuts 2024) ────────────────────────────────
EITI_AFRICAN_MEMBERS: dict[str, dict] = {
    "DZA": {"status": "candidate",           "since": 2020},
    "AGO": {"status": "candidate",           "since": 2021},
    "BEN": {"status": "candidate",           "since": 2023},
    "BFA": {"status": "suspended",           "since": 2016},
    "CMR": {"status": "compliant",           "since": 2013},
    "CAF": {"status": "meaningful progress", "since": 2008},
    "TCD": {"status": "meaningful progress", "since": 2010},
    "COG": {"status": "compliant",           "since": 2013},
    "COD": {"status": "meaningful progress", "since": 2010},
    "CIV": {"status": "compliant",           "since": 2012},
    "EGY": {"status": "candidate",           "since": 2016},
    "ETH": {"status": "candidate",           "since": 2014},
    "GAB": {"status": "meaningful progress", "since": 2022},
    "GHA": {"status": "compliant",           "since": 2010},
    "GIN": {"status": "compliant",           "since": 2012},
    "GNB": {"status": "candidate",           "since": 2018},
    "KEN": {"status": "meaningful progress", "since": 2015},
    "LBR": {"status": "compliant",           "since": 2009},
    "MDG": {"status": "compliant",           "since": 2014},
    "MLI": {"status": "meaningful progress", "since": 2008},
    "MRT": {"status": "compliant",           "since": 2012},
    "MOZ": {"status": "meaningful progress", "since": 2009},
    "NAM": {"status": "meaningful progress", "since": 2022},
    "NER": {"status": "compliant",           "since": 2011},
    "NGA": {"status": "compliant",           "since": 2007},
    "RWA": {"status": "compliant",           "since": 2009},
    "SLE": {"status": "compliant",           "since": 2009},
    "SEN": {"status": "compliant",           "since": 2013},
    "TZA": {"status": "compliant",           "since": 2012},
    "TGO": {"status": "compliant",           "since": 2013},
    "UGA": {"status": "meaningful progress", "since": 2008},
    "ZMB": {"status": "meaningful progress", "since": 2009},
    "ZWE": {"status": "candidate",           "since": 2019},
}

# ── Secteurs extractifs retenus pour MIN_TAX ─────────────────────────────────
EXTRACTIVE_SECTORS = {
    "Mining", "Oil & Gas", "Oil", "Gas", "Coal",
    "Mining/Oil/Gas", "Mining/Oil and Gas/Agriculture",
    "Pétrolier", "Petrolier", "Transport Pétrolier",
    "Raffinerie", "Carrières", "Salt",
    "Горная добыча",
}

# ── Mapping indicateurs OSA ───────────────────────────────────────────────────
EITI_INDICATOR_MAP: dict = {
    "MIN_GOV": {
        "dataset":   "COMPLIANCE",
        "metric":    "governance_score",
        "name_fr":   "Score gouvernance minière EITI (0-100)",
        "direction": "+",
    },
    "MIN_CERT": {
        "dataset":   "COMPLIANCE",
        "metric":    "is_member",
        "name_fr":   "Membership EITI (1=membre actif, 0=non-membre)",
        "direction": "+",
    },
    "MIN_TAX": {
        "dataset":   "REVENUES",
        "metric":    "total_revenues_usd",
        "name_fr":   "Recettes extractives déclarées EITI (USD→score)",
        "direction": "+",
    },
    "MIN_TECH": {
        "dataset":   "COMPLIANCE",
        "metric":    "transparency_score",
        "name_fr":   "Score transparence données minières EITI",
        "direction": "+",
    },
}

# ── Nom du fichier Excel EITI ─────────────────────────────────────────────────
EITI_XLSX_FILENAME = "EITI_revenue_data_query__version_1_.xlsx"


class EITIFetcher(BaseFetcher):

    PROVIDER_CODE = "EITI"
    ENDPOINT_CODE = "WB_COUNTRY_INDICATOR"
    INDICATOR_MAP = EITI_INDICATOR_MAP

    SUMMARY_API_BASE = "https://summary.eiti.org/api/v1"

    def __init__(
        self,
        data_dir: str = "data/raw/pmin/eiti",
        use_api:  bool = False,
        dry_run:  bool = False,
    ) -> None:
        super().__init__(dry_run=dry_run)
        self.data_dir = Path(data_dir)
        self.use_api  = use_api

    # ── Dispatch principal ────────────────────────────────────────────────────

    def fetch_indicator(
        self,
        osa_code:  str,
        config:    dict,
        year_from: int,
        year_to:   int,
    ) -> list[DataRecord]:
        dataset = config["dataset"]
        metric  = config["metric"]

        if dataset == "COMPLIANCE":
            return self._fetch_compliance(metric, year_from, year_to)
        elif dataset == "REVENUES":
            return self._fetch_revenues(year_from, year_to)
        else:
            self.log.error("Dataset EITI inconnu : %s", dataset)
            return []

    # ── COMPLIANCE ────────────────────────────────────────────────────────────

    def _fetch_compliance(
        self, metric: str, year_from: int, year_to: int
    ) -> list[DataRecord]:
        """
        Priorité :
        1. EITI_compliance.csv si présent (données historiques)
        2. Données intégrées 2024 (fallback)
        """
        csv_path = self.data_dir / "EITI_compliance.csv"
        if csv_path.exists():
            self.log.info("Compliance depuis CSV : %s", csv_path)
            return self._parse_compliance_csv(csv_path, metric, year_from, year_to)
        else:
            self.log.info(
                "EITI_compliance.csv absent — utilisation données intégrées 2024\n"
                "  Pour données historiques : https://eiti.org/countries → Export CSV"
            )
            return self._generate_compliance_builtin(metric, year_from, year_to)

    def _parse_compliance_csv(
        self, csv_path: Path, metric: str, year_from: int, year_to: int
    ) -> list[DataRecord]:
        records: list[DataRecord] = []
        try:
            with open(csv_path, encoding="utf-8-sig", errors="replace") as f:
                sample = f.read(1024); f.seek(0)
                delimiter = "\t" if "\t" in sample else ","
                reader = csv.DictReader(f, delimiter=delimiter)
                for row in reader:
                    iso3 = (
                        row.get("iso3") or row.get("ISO3") or
                        row.get("country_code") or ""
                    ).strip().upper()
                    if iso3 not in AFRICAN_ISO3:
                        continue
                    status = (
                        row.get("status") or row.get("eiti_status") or
                        row.get("Status") or "non-member"
                    ).strip().lower()
                    try:
                        year = int((row.get("year") or row.get("Year") or "").strip())
                    except (ValueError, TypeError):
                        year = 2024
                    if not (year_from <= year <= year_to):
                        continue
                    value = self._status_to_metric(status, metric)
                    records.append({"iso3": iso3, "year": year, "value": value})
        except Exception as exc:
            self.log.error("Erreur parsing compliance CSV : %s", exc)
        self.log.info("Compliance CSV → %d enregistrements", len(records))
        return records

    def _generate_compliance_builtin(
        self, metric: str, year_from: int, year_to: int
    ) -> list[DataRecord]:
        """Génère les scores depuis EITI_AFRICAN_MEMBERS pour toutes les années."""
        records: list[DataRecord] = []
        for iso3 in AFRICAN_ISO3:
            info   = EITI_AFRICAN_MEMBERS.get(iso3)
            status = info["status"] if info else "non-member"
            since  = info["since"]  if info else 9999
            for year in range(year_from, year_to + 1):
                effective = status if year >= since else "non-member"
                value = self._status_to_metric(effective, metric)
                records.append({"iso3": iso3, "year": year, "value": value})
        self.log.info(
            "Compliance intégré → %d enregistrements (%d pays)",
            len(records), len(set(r["iso3"] for r in records))
        )
        return records

    def _status_to_metric(self, status: str, metric: str) -> Optional[float]:
        s = status.lower()
        if metric == "governance_score":
            return EITI_STATUS_SCORE.get(s, 0.0)
        elif metric == "is_member":
            return 1.0 if s in ("compliant", "meaningful progress", "candidate") else 0.0
        elif metric == "transparency_score":
            return EITI_STATUS_TRANSPARENCY.get(s, 0.0)
        return None

    # ── REVENUES ──────────────────────────────────────────────────────────────

    def _fetch_revenues(self, year_from: int, year_to: int) -> list[DataRecord]:
        """
        Priorité :
        1. Excel EITI Data Query (format v1 — le plus complet)
        2. CSV EITI revenues (format summary.eiti.org)
        3. API EITI Summary (si --api)
        """
        xlsx_path = self.data_dir / EITI_XLSX_FILENAME
        csv_path  = self.data_dir / "EITI_revenues.csv"

        if xlsx_path.exists():
            self.log.info("Revenues depuis Excel : %s", xlsx_path)
            raw = self._parse_revenues_xlsx(xlsx_path, year_from, year_to)
        elif csv_path.exists():
            self.log.info("Revenues depuis CSV : %s", csv_path)
            raw = self._parse_revenues_csv(csv_path, year_from, year_to)
        elif self.use_api:
            self.log.info("Revenues depuis API EITI Summary")
            raw = self._fetch_revenues_api(year_from, year_to)
        else:
            self.log.warning(
                "Aucune source revenue EITI disponible.\n"
                "  Excel  : data/raw/pmin/eiti/%s\n"
                "  CSV    : data/raw/pmin/eiti/EITI_revenues.csv\n"
                "  API    : relancer avec --api",
                EITI_XLSX_FILENAME,
            )
            return []

        return self._normalize_revenues(raw, year_from, year_to)

    def _parse_revenues_xlsx(
        self, xlsx_path: Path, year_from: int, year_to: int
    ) -> dict[tuple, float]:
        """
        Parse le fichier Excel EITI Data Query v1.
        Feuilles : 'revenues' (données) + 'Region' (mapping ISO3)
        """
        try:
            revenues = pd.read_excel(xlsx_path, sheet_name="revenues", engine="openpyxl")
            regions  = pd.read_excel(xlsx_path, sheet_name="Region",   engine="openpyxl")
        except Exception as e:
            self.log.error("Erreur lecture Excel EITI : %s", e)
            return {}

        iso3_map = dict(zip(
            regions["Country"].str.strip(),
            regions["ISO3"].str.strip()
        ))

        revenues["iso3"]    = revenues["summary_data.label"].map(iso3_map)
        revenues["year"]    = pd.to_numeric(revenues["summary_data.year"], errors="coerce")
        revenues["revenue"] = pd.to_numeric(
            revenues["Revenue falue format fixed"], errors="coerce"
        ).fillna(0)

        # Filtres
        df = revenues[
            revenues["iso3"].isin(set(AFRICAN_ISO3)) &
            revenues["year"].between(year_from, year_to) &
            (revenues["revenue"] > 0)
        ].copy()

        # Filtre secteurs extractifs (NaN = inclus par défaut)
        sector_mask = (
            df["sector"].isna() |
            df["sector"].isin(EXTRACTIVE_SECTORS) |
            df["sector"].str.contains(
                "Mining|Oil|Gas|Coal|Mineral", case=False, na=False
            )
        )
        df = df[sector_mask]

        # Agrégation pays × année
        agg = df.groupby(["iso3", "year"])["revenue"].sum()
        result = {
            (str(iso3), int(year)): float(total)
            for (iso3, year), total in agg.items()
        }

        self.log.info(
            "Excel EITI → %d paires pays/année | %d pays | %d-%d",
            len(result),
            len(set(k[0] for k in result)),
            year_from, year_to,
        )
        return result

    def _parse_revenues_csv(
        self, csv_path: Path, year_from: int, year_to: int
    ) -> dict[tuple, float]:
        aggregated: dict[tuple, float] = {}
        try:
            with open(csv_path, encoding="utf-8-sig", errors="replace") as f:
                sample = f.read(1024); f.seek(0)
                delimiter = "\t" if "\t" in sample else ","
                reader = csv.DictReader(f, delimiter=delimiter)
                for row in reader:
                    iso3 = (
                        row.get("iso3") or row.get("ISO3") or
                        row.get("country_code") or ""
                    ).strip().upper()
                    if iso3 not in AFRICAN_ISO3:
                        continue
                    try:
                        year = int((row.get("year") or row.get("Year") or "").strip())
                        if not (year_from <= year <= year_to):
                            continue
                    except (ValueError, TypeError):
                        continue
                    rev_raw = (
                        row.get("total_revenues_usd") or
                        row.get("revenues_usd") or
                        row.get("amount_usd") or "0"
                    ).strip()
                    try:
                        rev = float(rev_raw.replace(",", ""))
                    except ValueError:
                        rev = 0.0
                    if rev > 0:
                        key = (iso3, year)
                        aggregated[key] = aggregated.get(key, 0.0) + rev
        except Exception as exc:
            self.log.error("Erreur parsing CSV revenues : %s", exc)
        self.log.info("CSV revenues → %d paires pays/année", len(aggregated))
        return aggregated

    def _fetch_revenues_api(
        self, year_from: int, year_to: int
    ) -> dict[tuple, float]:
        aggregated: dict[tuple, float] = {}
        for iso3, info in EITI_AFRICAN_MEMBERS.items():
            if iso3 not in AFRICAN_ISO3:
                continue
            for year in range(
                max(year_from, info.get("since", year_from)),
                year_to + 1,
            ):
                data = self.http_get(
                    f"{self.SUMMARY_API_BASE}/revenues/",
                    params={"country": iso3.lower(), "year": year, "format": "json"},
                )
                if not data:
                    continue
                try:
                    total = sum(
                        float(item.get("amount", 0) or 0)
                        for item in (data if isinstance(data, list) else [])
                    )
                    if total > 0:
                        aggregated[(iso3, year)] = total
                except (TypeError, ValueError):
                    continue
        self.log.info("API revenues → %d paires pays/année", len(aggregated))
        return aggregated

    def _normalize_revenues(
        self, raw: dict[tuple, float], year_from: int, year_to: int
    ) -> list[DataRecord]:
        """
        Normalisation log(1+x) intra-année [0,100].
        Retourne les DataRecords avec value = score normalisé.
        """
        if not raw:
            return []

        # Grouper par année pour normalisation intra-année
        by_year: dict[int, list[tuple]] = {}
        for (iso3, year), total in raw.items():
            by_year.setdefault(year, []).append((iso3, total))

        records: list[DataRecord] = []
        for year, items in sorted(by_year.items()):
            log_vals = [(iso3, math.log(1 + v)) for iso3, v in items]
            vmin = min(lv for _, lv in log_vals)
            vmax = max(lv for _, lv in log_vals)

            for iso3, lv in log_vals:
                if vmax == vmin:
                    score = 50.0
                else:
                    score = round((lv - vmin) / (vmax - vmin) * 100, 4)
                records.append({"iso3": iso3, "year": year, "value": score})

        self.log.info(
            "MIN_TAX normalisé → %d enregistrements (%d pays)",
            len(records), len(set(r["iso3"] for r in records))
        )
        return records

    # ── run() — hérite de BaseFetcher ────────────────────────────────────────

    def run(
        self,
        year_from:       int = 2010,
        year_to:         int = 2024,
        indicator_filter: Optional[str] = None,
    ) -> dict:
        results = {"ok": [], "failed": [], "skipped": []}
        t_start = __import__("time").time()

        indicators = (
            {indicator_filter: self.INDICATOR_MAP[indicator_filter]}
            if indicator_filter and indicator_filter in self.INDICATOR_MAP
            else self.INDICATOR_MAP
        )

        for osa_code, config in indicators.items():
            self.log.info("── %s (%s) ──", osa_code, config["name_fr"])
            try:
                records = self.fetch_indicator(osa_code, config, year_from, year_to)
                if not records:
                    self.log.warning("%s → 0 enregistrements", osa_code)
                    results["skipped"].append(osa_code)
                    continue

                inserted, rejected = self.insert_records(osa_code, records)
                self.log.info(
                    "%s → +%d insérés / %d rejetés", osa_code, inserted, rejected
                )
                results["ok"].append(osa_code)

                duration_ms = int((__import__("time").time() - t_start) * 1000)
                self.log_ingestion(
                    osa_code, year_to, "SUCCESS", inserted, rejected, duration_ms
                )

            except Exception as exc:
                self.log.error("%s → ERREUR : %s", osa_code, exc)
                results["failed"].append(osa_code)

        # Résumé
        self.log.info("=" * 55)
        self.log.info(
            "EITI terminé | OK:%d SKIP:%d FAIL:%d",
            len(results["ok"]), len(results["skipped"]), len(results["failed"])
        )
        if results["failed"]:
            self.log.warning("Échecs : %s", ", ".join(results["failed"]))
        self.log.info("=" * 55)
        return results


# ── Point d'entrée ────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(
        description="OSA Fetcher — EITI (Excel + CSV + API)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Indicateurs produits :
  MIN_GOV   Score gouvernance minière EITI [0-100]
  MIN_CERT  Membership EITI (0/1)
  MIN_TAX   Recettes extractives normalisées [0-100]
  MIN_TECH  Score transparence [0-100]

Sources (par priorité) :
  Excel : data/raw/pmin/eiti/EITI_revenue_data_query__version_1_.xlsx
  CSV   : data/raw/pmin/eiti/EITI_revenues.csv
  API   : --api (summary.eiti.org)

Exemples :
  python fetcher_eiti_csv.py --dir data/raw/pmin/eiti --dry-run
  python fetcher_eiti_csv.py --dir data/raw/pmin/eiti
  python fetcher_eiti_csv.py --dir data/raw/pmin/eiti --indicator MIN_TAX
  python fetcher_eiti_csv.py --dir data/raw/pmin/eiti --api
  python fetcher_eiti_csv.py --dir data/raw/pmin/eiti --list-missing
        """
    )
    parser.add_argument("--dir",          type=str, default="data/raw/pmin/eiti")
    parser.add_argument("--from",         type=int, dest="year_from", default=2010)
    parser.add_argument("--to",           type=int, dest="year_to",   default=2024)
    parser.add_argument("--indicator",    type=str, default=None)
    parser.add_argument("--dry-run",      action="store_true")
    parser.add_argument("--api",          action="store_true")
    parser.add_argument("--list-missing", action="store_true")
    args = parser.parse_args()

    if args.list_missing:
        data_dir = Path(args.dir)
        print(f"\nFichiers EITI dans {data_dir} :")
        files = [
            (EITI_XLSX_FILENAME,      "Excel Data Query (MIN_TAX) — recommandé"),
            ("EITI_revenues.csv",     "CSV revenues (MIN_TAX) — alternatif"),
            ("EITI_compliance.csv",   "CSV compliance (MIN_GOV/CERT/TECH) — optionnel"),
        ]
        for fname, desc in files:
            path   = data_dir / fname
            status = "✓ présent" if path.exists() else "○ absent"
            print(f"  {status}  {fname:50s} {desc}")
        print(f"\n  Membres EITI africains intégrés : {len(EITI_AFRICAN_MEMBERS)}/54")
        compliant = sum(1 for v in EITI_AFRICAN_MEMBERS.values() if v["status"] == "compliant")
        print(f"  Dont conformes (Compliant) : {compliant}")
        return

    logging.basicConfig(
        level=os.getenv("OSA_LOG_LEVEL", "INFO"),
        format="%(asctime)s | %(levelname)-8s | %(message)s",
    )

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
