"""
============================================================
OSA / ISA OBSERVATORY
sdmx_crawler.py — Découverte SDMX automatique (IMF + OECD)
============================================================
Objectif:
  - Découvrir dynamiquement les dataflows (datasets)
  - Extraire les dimensions et codelists associées
  - Versionner les structures détectées (hash)
  - Optionnel: persister en base collect.sdmx_*

IMPORTANT:
  - Ce module automatise la découverte technique.
  - Il ne valide PAS la pertinence métier des indicateurs.
============================================================
"""

from __future__ import annotations

import argparse
import hashlib
import json
import logging
import os
import re
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Optional
from xml.etree import ElementTree as ET

import psycopg2
import requests
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(
    level=os.getenv("OSA_LOG_LEVEL", "INFO"),
    format="%(asctime)s | %(levelname)-8s | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger("sdmx_crawler")

HTTP_TIMEOUT = 30


@dataclass
class ProviderConfig:
    code: str
    dataflow_url: str
    datastructure_url_tpl: str
    compact_data_url_tpl: Optional[str] = None


PROVIDERS: dict[str, ProviderConfig] = {
    "IMF": ProviderConfig(
        code="IMF",
        dataflow_url="https://dataservices.imf.org/REST/SDMX_XML.svc/Dataflow",
        datastructure_url_tpl="https://dataservices.imf.org/REST/SDMX_XML.svc/DataStructure/{dataset_id}",
        compact_data_url_tpl="https://dataservices.imf.org/REST/SDMX_JSON.svc/CompactData/{dataset_id}?startPeriod={start_year}&endPeriod={end_year}",
    ),
    "OECD": ProviderConfig(
        code="OECD",
        dataflow_url="https://sdmx.oecd.org/public/rest/dataflow/all/latest",
        datastructure_url_tpl="https://sdmx.oecd.org/public/rest/datastructure/OECD.SDD.STES/{dataset_id}/latest",
        compact_data_url_tpl="https://sdmx.oecd.org/public/rest/data/{dataset_id}/all?startPeriod={start_year}&endPeriod={end_year}",
    ),
}


def _safe_text(value: Optional[str]) -> str:
    return (value or "").strip()


class SDMXCrawler:
    def __init__(self, dry_run: bool = False, db_write: bool = False) -> None:
        self.dry_run = dry_run
        self.db_write = db_write
        self.conn = None

    def connect_db(self) -> None:
        if not self.db_write:
            return
        self.conn = psycopg2.connect(
            host=os.getenv("OSA_DB_HOST", "localhost"),
            port=int(os.getenv("OSA_DB_PORT", "5432")),
            dbname=os.getenv("OSA_DB_NAME", "osa_db"),
            user=os.getenv("OSA_DB_USER", "postgres"),
            password=os.getenv("OSA_DB_PASS", ""),
            connect_timeout=10,
        )

    def close_db(self) -> None:
        if self.conn:
            self.conn.close()
            self.conn = None

    def _http_get_text(self, url: str) -> Optional[str]:
        try:
            response = requests.get(
                url,
                timeout=HTTP_TIMEOUT,
                headers={"Accept": "application/xml, text/xml, application/json"},
            )
            response.raise_for_status()
            return response.text
        except requests.RequestException as exc:
            log.warning("HTTP erreur %s -> %s", url, exc)
            return None

    def _http_get_json(self, url: str) -> Optional[dict[str, Any]]:
        try:
            response = requests.get(
                url,
                timeout=HTTP_TIMEOUT,
                headers={"Accept": "application/json"},
            )
            response.raise_for_status()
            return response.json()
        except (requests.RequestException, ValueError) as exc:
            log.warning("HTTP/JSON erreur %s -> %s", url, exc)
            return None

    def discover_dataflows(self, provider_code: str) -> list[dict[str, Any]]:
        provider = PROVIDERS[provider_code]
        payload = self._http_get_text(provider.dataflow_url)
        if not payload:
            return []

        try:
            root = ET.fromstring(payload)
        except ET.ParseError as exc:
            log.error("XML invalide dataflow %s: %s", provider_code, exc)
            return []

        dataflows: list[dict[str, Any]] = []

        for elem in root.iter():
            if not elem.tag.endswith("Dataflow"):
                continue

            dataset_id = _safe_text(elem.attrib.get("id"))
            if not dataset_id:
                continue

            agency = _safe_text(
                elem.attrib.get("agencyID") or elem.attrib.get(
                    "agencyId") or elem.attrib.get("agency")
            )
            version = _safe_text(elem.attrib.get("version")) or "latest"

            name = ""
            for child in elem.iter():
                if child.tag.endswith("Name") and _safe_text(child.text):
                    name = _safe_text(child.text)
                    break

            dataflows.append(
                {
                    "provider_code": provider_code,
                    "dataset_id": dataset_id,
                    "dataset_name": name,
                    "agency": agency,
                    "version": version,
                    "source_url": provider.dataflow_url,
                }
            )

        dedup: dict[tuple[str, str], dict[str, Any]] = {}
        for row in dataflows:
            dedup[(row["dataset_id"], row["version"])] = row

        rows = sorted(dedup.values(), key=lambda r: (
            r["dataset_id"], r["version"]))
        log.info("%s — %d dataflows détectés", provider_code, len(rows))
        return rows

    def discover_structure(
        self,
        provider_code: str,
        dataset_id: str,
    ) -> tuple[list[dict[str, Any]], list[dict[str, Any]], str]:
        provider = PROVIDERS[provider_code]
        url = provider.datastructure_url_tpl.format(dataset_id=dataset_id)
        payload = self._http_get_text(url)
        if not payload:
            return [], [], ""

        try:
            root = ET.fromstring(payload)
        except ET.ParseError as exc:
            log.warning("XML invalide datastructure %s/%s: %s",
                        provider_code, dataset_id, exc)
            return [], [], ""

        dimensions: list[dict[str, Any]] = []
        codelists: list[dict[str, Any]] = []

        for elem in root.iter():
            if elem.tag.endswith("Dimension"):
                dim_id = _safe_text(elem.attrib.get("id"))
                if not dim_id:
                    continue
                concept_ref = _safe_text(
                    elem.attrib.get("conceptRef") or elem.attrib.get(
                        "concept") or elem.attrib.get("id")
                )
                codelist_id = ""

                for child in elem.iter():
                    if child.tag.endswith("Enumeration"):
                        ref = child.attrib.get("id") or child.attrib.get("ref")
                        if ref:
                            codelist_id = _safe_text(ref)
                            break

                dimensions.append(
                    {
                        "provider_code": provider_code,
                        "dataset_id": dataset_id,
                        "dimension_id": dim_id,
                        "concept_ref": concept_ref,
                        "codelist_id": codelist_id,
                    }
                )

            if elem.tag.endswith("Codelist"):
                codelist_id = _safe_text(elem.attrib.get("id"))
                if not codelist_id:
                    continue

                for code_elem in elem.iter():
                    if not code_elem.tag.endswith("Code"):
                        continue
                    code_value = _safe_text(code_elem.attrib.get("id"))
                    if not code_value:
                        continue

                    code_name = ""
                    for name_elem in code_elem.iter():
                        if name_elem.tag.endswith("Name") and _safe_text(name_elem.text):
                            code_name = _safe_text(name_elem.text)
                            break

                    codelists.append(
                        {
                            "provider_code": provider_code,
                            "dataset_id": dataset_id,
                            "codelist_id": codelist_id,
                            "code_value": code_value,
                            "code_name": code_name,
                        }
                    )

        signature_payload = {
            "dataset_id": dataset_id,
            "dimensions": sorted(dimensions, key=lambda d: d["dimension_id"]),
            "codelists": sorted(codelists, key=lambda c: (c["codelist_id"], c["code_value"])),
        }
        signature = hashlib.sha256(
            json.dumps(signature_payload, ensure_ascii=True,
                       sort_keys=True).encode("utf-8")
        ).hexdigest()

        return dimensions, codelists, signature

    def persist_discovery(
        self,
        provider_code: str,
        discovered: list[dict[str, Any]],
        structures: dict[str, tuple[list[dict[str, Any]], list[dict[str, Any]], str]],
    ) -> None:
        if not self.conn:
            return

        with self.conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO collect.sdmx_discovery_runs
                    (provider_code, run_type, started_at, status)
                VALUES (%s, %s, now(), 'RUNNING')
                RETURNING id
                """,
                (provider_code, "DISCOVERY"),
            )
            run_id = cur.fetchone()[0]

            for row in discovered:
                dataset_id = row["dataset_id"]
                dimensions, codelists, signature = structures.get(
                    dataset_id, ([], [], ""))

                cur.execute(
                    """
                    INSERT INTO collect.sdmx_datasets
                        (provider_code, dataset_id, dataset_name, agency, version,
                         source_url, structure_hash, last_seen_at, is_active)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, now(), TRUE)
                    ON CONFLICT (provider_code, dataset_id, version)
                    DO UPDATE SET
                        dataset_name   = EXCLUDED.dataset_name,
                        agency         = EXCLUDED.agency,
                        source_url     = EXCLUDED.source_url,
                        structure_hash = EXCLUDED.structure_hash,
                        last_seen_at   = now(),
                        is_active      = TRUE
                    """,
                    (
                        provider_code,
                        dataset_id,
                        row.get("dataset_name"),
                        row.get("agency"),
                        row.get("version") or "latest",
                        row.get("source_url"),
                        signature,
                    ),
                )

                cur.execute(
                    """
                    INSERT INTO collect.sdmx_dataset_versions
                        (provider_code, dataset_id, version, structure_hash, detected_at)
                    VALUES (%s, %s, %s, %s, now())
                    ON CONFLICT (provider_code, dataset_id, version, structure_hash)
                    DO NOTHING
                    """,
                    (provider_code, dataset_id, row.get(
                        "version") or "latest", signature),
                )

                cur.execute(
                    "DELETE FROM collect.sdmx_dimensions WHERE provider_code = %s AND dataset_id = %s",
                    (provider_code, dataset_id),
                )
                for d in dimensions:
                    cur.execute(
                        """
                        INSERT INTO collect.sdmx_dimensions
                            (provider_code, dataset_id, dimension_id, concept_ref, codelist_id)
                        VALUES (%s, %s, %s, %s, %s)
                        ON CONFLICT (provider_code, dataset_id, dimension_id)
                        DO UPDATE SET
                            concept_ref = EXCLUDED.concept_ref,
                            codelist_id = EXCLUDED.codelist_id
                        """,
                        (
                            d["provider_code"],
                            d["dataset_id"],
                            d["dimension_id"],
                            d.get("concept_ref"),
                            d.get("codelist_id"),
                        ),
                    )

                cur.execute(
                    "DELETE FROM collect.sdmx_codelist_codes WHERE provider_code = %s AND dataset_id = %s",
                    (provider_code, dataset_id),
                )
                for c in codelists:
                    cur.execute(
                        """
                        INSERT INTO collect.sdmx_codelist_codes
                            (provider_code, dataset_id, codelist_id, code_value, code_name)
                        VALUES (%s, %s, %s, %s, %s)
                        ON CONFLICT (provider_code, dataset_id, codelist_id, code_value)
                        DO UPDATE SET code_name = EXCLUDED.code_name
                        """,
                        (
                            c["provider_code"],
                            c["dataset_id"],
                            c["codelist_id"],
                            c["code_value"],
                            c.get("code_name"),
                        ),
                    )

            cur.execute(
                """
                UPDATE collect.sdmx_discovery_runs
                SET status = 'SUCCESS', completed_at = now(),
                    datasets_count = %s
                WHERE id = %s
                """,
                (len(discovered), run_id),
            )

        self.conn.commit()

    def run_discovery(
        self,
        provider_code: str,
        dataset_regex: Optional[str] = None,
        limit: Optional[int] = None,
    ) -> dict[str, Any]:
        rows = self.discover_dataflows(provider_code)

        if dataset_regex:
            pattern = re.compile(dataset_regex)
            rows = [r for r in rows if pattern.search(
                r["dataset_id"]) or pattern.search(r.get("dataset_name", ""))]

        if limit and limit > 0:
            rows = rows[:limit]

        structures: dict[str, tuple[list[dict[str, Any]],
                                    list[dict[str, Any]], str]] = {}
        for row in rows:
            dataset_id = row["dataset_id"]
            dims, codes, signature = self.discover_structure(
                provider_code, dataset_id)
            structures[dataset_id] = (dims, codes, signature)

        if self.db_write and not self.dry_run:
            self.persist_discovery(provider_code, rows, structures)

        total_dims = sum(len(v[0]) for v in structures.values())
        total_codes = sum(len(v[1]) for v in structures.values())

        return {
            "provider": provider_code,
            "datasets": len(rows),
            "dimensions": total_dims,
            "codes": total_codes,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }

    def ingest_raw_observations(
        self,
        provider_code: str,
        dataset_id: str,
        start_year: int,
        end_year: int,
        max_series: int = 100,
    ) -> dict[str, Any]:
        provider = PROVIDERS[provider_code]
        if not provider.compact_data_url_tpl:
            return {
                "provider": provider_code,
                "dataset_id": dataset_id,
                "inserted": 0,
                "series": 0,
                "observations": 0,
                "status": "UNSUPPORTED",
            }

        url = provider.compact_data_url_tpl.format(
            dataset_id=dataset_id,
            start_year=start_year,
            end_year=end_year,
        )

        data = self._http_get_json(url)
        if not data:
            return {
                "provider": provider_code,
                "dataset_id": dataset_id,
                "inserted": 0,
                "series": 0,
                "observations": 0,
                "status": "EMPTY",
            }

        series = data.get("CompactData", {}).get("DataSet", {}).get("Series")
        if not series:
            return {
                "provider": provider_code,
                "dataset_id": dataset_id,
                "inserted": 0,
                "series": 0,
                "observations": 0,
                "status": "NO_SERIES",
            }

        if isinstance(series, dict):
            series = [series]
        series = series[:max_series]

        inserted = 0
        observations = 0

        if self.conn and self.db_write and not self.dry_run:
            with self.conn.cursor() as cur:
                for serie in series:
                    series_key = {
                        k: v for k, v in serie.items()
                        if k.startswith("@")
                    }
                    obs_list = serie.get("Obs", [])
                    if isinstance(obs_list, dict):
                        obs_list = [obs_list]

                    for obs in obs_list:
                        period = _safe_text(obs.get("@TIME_PERIOD"))
                        raw_value = obs.get("@OBS_VALUE")
                        attrs = {
                            k: v for k, v in obs.items()
                            if k.startswith("@") and k not in ("@TIME_PERIOD", "@OBS_VALUE")
                        }

                        if not period:
                            continue

                        try:
                            value_num = float(raw_value) if raw_value not in (
                                None, "") else None
                        except (ValueError, TypeError):
                            value_num = None

                        cur.execute(
                            """
                            INSERT INTO collect.sdmx_raw_observations
                                (provider_code, dataset_id, series_key, period,
                                 value_raw, attrs, source_url)
                            VALUES (%s, %s, %s::jsonb, %s, %s, %s::jsonb, %s)
                            ON CONFLICT (provider_code, dataset_id, series_key, period)
                            DO UPDATE SET
                                value_raw = EXCLUDED.value_raw,
                                attrs = EXCLUDED.attrs,
                                source_url = EXCLUDED.source_url,
                                ingested_at = now()
                            """,
                            (
                                provider_code,
                                dataset_id,
                                json.dumps(
                                    series_key, ensure_ascii=True, sort_keys=True),
                                period,
                                value_num,
                                json.dumps(attrs, ensure_ascii=True,
                                           sort_keys=True),
                                url,
                            ),
                        )
                        inserted += 1
                        observations += 1

            self.conn.commit()
        else:
            for serie in series:
                obs_list = serie.get("Obs", [])
                if isinstance(obs_list, dict):
                    obs_list = [obs_list]
                observations += len(obs_list)

        return {
            "provider": provider_code,
            "dataset_id": dataset_id,
            "inserted": inserted,
            "series": len(series),
            "observations": observations,
            "status": "SUCCESS",
        }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="OSA — Crawler SDMX IMF + OECD")
    parser.add_argument("--provider", choices=["IMF", "OECD"], required=True)
    parser.add_argument("--dataset-regex", type=str, default=None)
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--ingest-dataset", type=str, default=None,
                        help="Dataset pour ingestion brute SDMX")
    parser.add_argument("--start-year", type=int, default=2018)
    parser.add_argument("--end-year", type=int, default=2024)
    parser.add_argument("--max-series", type=int, default=100)
    parser.add_argument("--db-write", action="store_true",
                        help="Persiste la découverte dans collect.sdmx_*")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    crawler = SDMXCrawler(dry_run=args.dry_run, db_write=args.db_write)
    try:
        crawler.connect_db()
        result = crawler.run_discovery(
            provider_code=args.provider,
            dataset_regex=args.dataset_regex,
            limit=args.limit,
        )
        log.info(
            "Résumé %s — datasets:%d dimensions:%d codes:%d",
            result["provider"],
            result["datasets"],
            result["dimensions"],
            result["codes"],
        )

        if args.ingest_dataset:
            ingest = crawler.ingest_raw_observations(
                provider_code=args.provider,
                dataset_id=args.ingest_dataset,
                start_year=args.start_year,
                end_year=args.end_year,
                max_series=args.max_series,
            )
            log.info(
                "Ingestion brute %s/%s — inserted:%d series:%d obs:%d status:%s",
                args.provider,
                args.ingest_dataset,
                ingest["inserted"],
                ingest["series"],
                ingest["observations"],
                ingest["status"],
            )
    finally:
        crawler.close_db()


if __name__ == "__main__":
    main()
