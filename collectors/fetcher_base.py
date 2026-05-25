"""
============================================================
OSA / ISA OBSERVATORY
fetcher_base.py — Classe de base commune à tous les fetchers
============================================================
Responsabilités partagées :
  - Connexion PostgreSQL (depuis .env)
  - Insertion dans collect.raw_data + ma.indicator_values (L1)
  - Journalisation dans collect.ingestion_registry
  - Retry HTTP avec backoff exponentiel
  - Rapport final standardisé

Chaque fetcher hérite de BaseFetcher et implémente :
  - PROVIDER_CODE      : str   ("IMF", "WHO", "ITU", "FAO"…)
  - INDICATOR_MAP      : dict  (mapping OSA_CODE → config API)
  - fetch_indicator()  : méthode de collecte spécifique au provider
============================================================
"""

from __future__ import annotations

import logging
import os
import time
from abc import ABC, abstractmethod
from datetime import datetime, timezone
from typing import Optional

import psycopg2
import psycopg2.extras
import requests
from dotenv import load_dotenv

load_dotenv()

log = logging.getLogger("fetcher_base")

# ── Types ──────────────────────────────────────────────────

DataRecord = dict  # {"iso3": str, "year": int, "value": float | None}

# ── Constantes réseau ──────────────────────────────────────

HTTP_TIMEOUT   = 30
HTTP_MAX_RETRY = 3
HTTP_RETRY_WAIT = 5   # secondes — doublé à chaque tentative
PAUSE_BETWEEN_CALLS = 0.5  # politesse entre requêtes

# ── 54 pays africains (ISO-3) ─────────────────────────────

AFRICAN_ISO3_FALLBACK: list[str] = [
    "DZA","EGY","LBY","MAR","MRT","SDN","TUN",
    "BEN","BFA","CIV","CPV","GMB","GHA","GIN","GNB","LBR",
    "MLI","NER","NGA","SEN","SLE","TGO",
    "BDI","COM","DJI","ERI","ETH","KEN","MDG","MWI","MUS",
    "MOZ","RWA","SYC","SOM","SSD","TZA","UGA","ZMB","ZWE",
    "AGO","CMR","CAF","TCD","COG","COD","GNQ","GAB","STP",
    "BWA","LSO","NAM","ZAF","SWZ",
]

def _load_african_iso3() -> list:
    """Charge la liste des pays OSA actifs depuis rf.countries.
    Fallback sur liste locale si DB inaccessible.
    Doctrine OSA : rf.countries est la source de verite unique.
    Ajouter un pays = 1 INSERT dans rf.countries WHERE is_active=TRUE.
    """
    try:
        import psycopg2, os
        from dotenv import load_dotenv
        load_dotenv()
        conn = psycopg2.connect(
            host=os.getenv("OSA_DB_HOST", "127.0.0.1"),
            port=int(os.getenv("OSA_DB_PORT", 5432)),
            dbname=os.getenv("OSA_DB_NAME", "osa_db"),
            user=os.getenv("OSA_DB_USER", "postgres"),
            password=os.getenv("OSA_DB_PASS", ""),
        )
        with conn.cursor() as cur:
            cur.execute(
                "SELECT iso3 FROM rf.countries WHERE is_active = TRUE ORDER BY iso3"
            )
            iso3_list = [row[0] for row in cur.fetchall()]
        conn.close()
        if len(iso3_list) >= 50:
            return iso3_list
        return AFRICAN_ISO3_FALLBACK
    except Exception as e:
        import logging
        logging.getLogger(__name__).warning(
            "rf.countries inaccessible (%s) -- fallback liste locale", e
        )
        return AFRICAN_ISO3_FALLBACK

AFRICAN_ISO3: list[str] = _load_african_iso3()

# ── Échantillon 10 pays représentatifs (1 par région + Sahel) ────
SAMPLE_ISO3: list[str] = [
    "MAR",  # Afrique du Nord — UMA
    "EGY",  # Afrique du Nord — COMESA
    "NGA",  # Afrique de l'Ouest — CEDEAO
    "CIV",  # Afrique de l'Ouest — CEDEAO
    "MLI",  # Sahel — AES
    "CMR",  # Afrique Centrale — CEMAC
    "COD",  # Afrique Centrale — SADC
    "KEN",  # Afrique de l'Est — EAC
    "ETH",  # Afrique de l'Est — IGAD
    "ZAF",  # Afrique Australe — SADC
]

ISO3_TO_ISO2: dict[str, str] = {
    "DZA":"DZ","EGY":"EG","LBY":"LY","MAR":"MA","MRT":"MR",
    "SDN":"SD","TUN":"TN","BEN":"BJ","BFA":"BF","CIV":"CI",
    "CPV":"CV","GMB":"GM","GHA":"GH","GIN":"GN","GNB":"GW",
    "LBR":"LR","MLI":"ML","NER":"NE","NGA":"NG","SLE":"SL",
    "SEN":"SN","TGO":"TG","BDI":"BI","COM":"KM","DJI":"DJ",
    "ERI":"ER","ETH":"ET","KEN":"KE","MDG":"MG","MWI":"MW",
    "MUS":"MU","MOZ":"MZ","RWA":"RW","SYC":"SC","SOM":"SO",
    "SSD":"SS","TZA":"TZ","UGA":"UG","ZMB":"ZM","ZWE":"ZW",
    "AGO":"AO","CMR":"CM","CAF":"CF","TCD":"TD","COG":"CG",
    "COD":"CD","GNQ":"GQ","GAB":"GA","STP":"ST","BWA":"BW",
    "SWZ":"SZ","LSO":"LS","NAM":"NA","ZAF":"ZA",
}


# ── Classe de base ─────────────────────────────────────────

class BaseFetcher(ABC):
    """
    Classe abstraite — hériter et implémenter :
      PROVIDER_CODE   : code fournisseur (ex: "IMF")
      ENDPOINT_CODE   : code endpoint dans collect.provider_endpoints
      INDICATOR_MAP   : dict OSA_CODE → config
      fetch_indicator : logique d'appel API spécifique
    """

    PROVIDER_CODE:  str  = ""
    ENDPOINT_CODE:  str  = ""
    INDICATOR_MAP:  dict = {}

    def __init__(self, dry_run: bool = False) -> None:
        self.dry_run          = dry_run
        self.conn             = None
        self.endpoint_id:     Optional[int] = None
        self.source_id:       Optional[int] = None
        self.method_version_id: Optional[int] = None
        self._setup_logging()

    def _setup_logging(self) -> None:
        self.log = logging.getLogger(f"fetcher_{self.PROVIDER_CODE.lower()}")

    # ── Connexion ──────────────────────────────────────────

    def connect(self) -> None:
        self.conn = psycopg2.connect(
            host     = os.getenv("OSA_DB_HOST", "localhost"),
            port     = int(os.getenv("OSA_DB_PORT", "5432")),
            dbname   = os.getenv("OSA_DB_NAME", "osa_db"),
            user     = os.getenv("OSA_DB_USER", "postgres"),
            password = os.getenv("OSA_DB_PASS", ""),
            connect_timeout = 10,
        )
        with self.conn.cursor() as cur:
            self.endpoint_id       = self._get_endpoint_id(cur)
            self.source_id         = self._get_source_id(cur)
            self.method_version_id = self._get_method_version_id(cur)

        if not all([self.endpoint_id, self.source_id, self.method_version_id]):
            raise RuntimeError(
                f"IDs manquants [{self.PROVIDER_CODE}] — "
                f"endpoint:{self.endpoint_id} "
                f"source:{self.source_id} "
                f"method_version:{self.method_version_id}\n"
                "Vérifiez que OSA_DEPLOY_V1.sql a été exécuté."
            )
        self.log.info(
            "DB OK — endpoint:%d source:%d method_v:%d",
            self.endpoint_id, self.source_id, self.method_version_id,
        )

    def disconnect(self) -> None:
        if self.conn:
            self.conn.close()
            self.conn = None

    def _get_endpoint_id(self, cur) -> Optional[int]:
        cur.execute(
            "SELECT id FROM collect.provider_endpoints WHERE endpoint_code = %s",
            (self.ENDPOINT_CODE,),
        )
        row = cur.fetchone()
        return row[0] if row else None

    def _get_source_id(self, cur) -> Optional[int]:
        # Sprint 12 -- source_id depuis collect.data_providers (pas mm.source_origins)
        # Garantit que source_id reflete le vrai fournisseur PROVIDER_CODE
        cur.execute(
            "SELECT id FROM collect.data_providers WHERE code = %s",
            (self.PROVIDER_CODE,),
        )
        row = cur.fetchone()
        if row:
            return row[0]
        # Fallback mm.source_origins pour compatibilite ascendante
        cur.execute(
            "SELECT id FROM mm.source_origins WHERE code = %s",
            (self.PROVIDER_CODE,),
        )
        row = cur.fetchone()
        return row[0] if row else None

    def _get_method_version_id(self, cur) -> Optional[int]:
        cur.execute(
            """SELECT imv.id
               FROM ma.indicator_method_versions imv
               JOIN ma.indicator_methods im ON im.id = imv.method_id
               WHERE im.code = 'MINMAX_UP' AND imv.is_active = TRUE
               ORDER BY imv.version DESC LIMIT 1"""
        )
        row = cur.fetchone()
        return row[0] if row else None

    # ── HTTP avec retry ────────────────────────────────────

    def http_get(self, url: str, params: dict = None) -> Optional[dict | list]:
        """
        GET HTTP avec retry + backoff exponentiel.
        Retourne le JSON parsé ou None en cas d'échec définitif.
        """
        attempt = 0
        wait    = HTTP_RETRY_WAIT

        while attempt < HTTP_MAX_RETRY:
            attempt += 1
            try:
                self.log.debug("GET %s (tentative %d/%d)", url, attempt, HTTP_MAX_RETRY)
                resp = requests.get(url, params=params, timeout=HTTP_TIMEOUT)
                resp.raise_for_status()
                return resp.json()

            except requests.exceptions.Timeout:
                self.log.warning("Timeout (%s) tentative %d/%d", url[:60], attempt, HTTP_MAX_RETRY)
            except requests.exceptions.HTTPError as exc:
                code = exc.response.status_code
                self.log.warning("HTTP %d (%s) tentative %d/%d", code, url[:60], attempt, HTTP_MAX_RETRY)
                if code in (400, 404):
                    return None   # pas la peine de réessayer
            except requests.exceptions.RequestException as exc:
                self.log.warning("Réseau (%s) tentative %d/%d", exc, attempt, HTTP_MAX_RETRY)
            except ValueError as exc:
                self.log.error("JSON invalide (%s) : %s", url[:60], exc)
                return None

            if attempt < HTTP_MAX_RETRY:
                self.log.info("Attente %ds...", wait)
                time.sleep(wait)
                wait *= 2

        self.log.error("Échec définitif : %s", url[:80])
        return None

    # ── Insertion en base ──────────────────────────────────

    def insert_records(
        self,
        osa_code:   str,
        records:    list[DataRecord],
        multiplier: float = 1.0,
    ) -> tuple[int, int]:
        """
        Insère dans collect.raw_data ET ma.indicator_values (L1).
        Retourne (inserted, rejected).
        """
        if self.dry_run:
            self.log.info("[DRY-RUN] %-15s → %d enregistrements (skippés)", osa_code, len(records))
            return len(records), 0

        inserted = 0
        rejected = 0

        with self.conn.cursor() as cur:
            for rec in records:
                iso3  = rec["iso3"]
                year  = rec["year"]
                value = rec.get("value")

                value_conv = (
                    round(float(value) * multiplier, 6)
                    if value is not None
                    else None
                )
                flag = "OK" if value_conv is not None else "MISSING"
                conf = 0.88 if value_conv is not None else 0.0

                try:
                    cur.execute(
                        """INSERT INTO collect.raw_data
                               (endpoint_id, indicator_code, country_iso3,
                                year, value_raw, load_date)
                           VALUES (%s, %s, %s, %s, %s, now())
                           ON CONFLICT DO NOTHING""",
                        (self.endpoint_id, osa_code, iso3, year, value_conv),
                    )
                    cur.execute(
                        """INSERT INTO ma.indicator_values
                               (indicator_code, country_iso3, year,
                                layer_id, raw_value, processed_value,
                                method_version_id, source_id,
                                confidence_score, quality_flag)
                           VALUES (%s, %s, %s,
                                   1, %s, %s,
                                   %s, %s, %s, %s)
                           ON CONFLICT (indicator_code, country_iso3, year,
                                        layer_id, method_version_id)
                           DO UPDATE SET
                               raw_value       = EXCLUDED.raw_value,
                               processed_value = EXCLUDED.processed_value,
                               quality_flag    = EXCLUDED.quality_flag,
                               created_at      = now()""",
                        (osa_code, iso3, year,
                         value_conv, value_conv,
                         self.method_version_id, self.source_id,
                         conf, flag),
                    )
                    inserted += 1
                except psycopg2.Error as exc:
                    self.log.warning("Insert échoué %s/%s/%d : %s", osa_code, iso3, year, exc)
                    self.conn.rollback()
                    rejected += 1
                    continue

        self.conn.commit()
        return inserted, rejected

    def log_ingestion(
        self,
        osa_code:    str,
        year:        Optional[int],
        status:      str,
        inserted:    int,
        rejected:    int,
        duration_ms: int,
        message:     str = "",
    ) -> None:
        if self.dry_run or not self.conn:
            return
        with self.conn.cursor() as cur:
            cur.execute(
                """INSERT INTO collect.ingestion_registry
                       (endpoint_id, indicator_code, year,
                        execution_date, status,
                        records_inserted, records_rejected,
                        duration_ms, message)
                   VALUES (%s, %s, %s, now(), %s, %s, %s, %s, %s)""",
                (self.endpoint_id, osa_code, year,
                 status, inserted, rejected,
                 duration_ms, message[:500]),
            )
            self.conn.commit()

    # ── Interface abstraite ────────────────────────────────

    @abstractmethod
    def fetch_indicator(
        self,
        osa_code:  str,
        config:    dict,
        year_from: int,
        year_to:   int,
    ) -> list[DataRecord]:
        """
        Implémenter dans chaque fetcher.
        Retourne une liste de DataRecord :
          [{"iso3": "DZA", "year": 2020, "value": 3.14}, ...]
        """
        ...

    # ── Orchestration commune ──────────────────────────────

    def run(
        self,
        year_from:       int,
        year_to:         int,
        indicator_filter: Optional[str] = None,
    ) -> dict:
        """
        Lance la collecte pour tous les indicateurs du provider
        sur la plage d'années demandée.
        Retourne un résumé global.
        """
        indicators = (
            {indicator_filter: self.INDICATOR_MAP[indicator_filter]}
            if indicator_filter and indicator_filter in self.INDICATOR_MAP
            else self.INDICATOR_MAP
        )

        self.log.info("=" * 55)
        self.log.info("%s — démarrage", self.PROVIDER_CODE)
        self.log.info("  Années      : %d → %d", year_from, year_to)
        self.log.info("  Indicateurs : %d", len(indicators))
        self.log.info("  Dry-run     : %s", self.dry_run)
        self.log.info("=" * 55)

        total_inserted = 0
        total_rejected = 0
        failed: list[str] = []

        for i, (osa_code, config) in enumerate(indicators.items(), 1):
            self.log.info("[%d/%d] %s", i, len(indicators), osa_code)
            t0 = time.monotonic()

            try:
                records = self.fetch_indicator(osa_code, config, year_from, year_to)
            except Exception as exc:
                self.log.error("fetch_indicator échoué pour %s : %s", osa_code, exc)
                records = []

            if not records:
                duration_ms = int((time.monotonic() - t0) * 1000)
                self.log_ingestion(osa_code, None, "FAILED", 0, 0, duration_ms,
                                   "Aucune donnée retournée")
                failed.append(osa_code)
                continue

            multiplier = config.get("multiplier", 1.0)
            ins, rej = self.insert_records(osa_code, records, multiplier)

            duration_ms = int((time.monotonic() - t0) * 1000)
            status = "SUCCESS" if rej == 0 else "PARTIAL"
            countries_ok = len({r["iso3"] for r in records if r.get("value") is not None})

            self.log.info(
                "  %-15s → %3d insérés, %2d rejetés, %2d pays (%dms)",
                osa_code, ins, rej, countries_ok, duration_ms,
            )
            self.log_ingestion(
                osa_code, None, status, ins, rej, duration_ms,
                f"{self.PROVIDER_CODE} | {countries_ok} pays | {year_from}-{year_to}",
            )

            total_inserted += ins
            total_rejected += rej
            if status == "FAILED":
                failed.append(osa_code)

            time.sleep(PAUSE_BETWEEN_CALLS)

        self.log.info("=" * 55)
        self.log.info("%s — terminé | +%d -%d | échecs: %s",
                      self.PROVIDER_CODE, total_inserted, total_rejected,
                      ", ".join(failed) if failed else "aucun")

        return {
            "provider":  self.PROVIDER_CODE,
            "inserted":  total_inserted,
            "rejected":  total_rejected,
            "failed":    failed,
        }

    # ── Sondage des bornes temporelles ────────────────────
    def probe(self) -> list[dict]:
        """
        Sonde les bornes temporelles reelles de chaque indicateur.
        Retourne une liste de resultats pour insertion dans
        collect.indicator_bounds.
        """
        results = []
        self.log.info("%s — sondage des bornes...", self.PROVIDER_CODE)

        for osa_code, config in self.INDICATOR_MAP.items():
            try:
                # Sonder sur une fenetre large
                records = self.fetch_indicator(osa_code, config, 1990, 2024)
                if not records:
                    results.append({
                        "indicator_code": osa_code,
                        "provider_code":  self.PROVIDER_CODE,
                        "year_min":       None,
                        "year_max":       None,
                        "countries_count": 0,
                        "probe_status":   "UNAVAILABLE",
                    })
                    continue

                years = [r["year"] for r in records if r.get("value") is not None]
                countries = len({r["iso3"] for r in records if r.get("value") is not None})

                if not years:
                    probe_status = "PARTIAL"
                    year_min = year_max = None
                else:
                    probe_status = "OK"
                    year_min = min(years)
                    year_max = max(years)

                self.log.info("  %-15s %s → %s (%d pays)",
                    osa_code,
                    year_min or "?",
                    year_max or "?",
                    countries,
                )
                results.append({
                    "indicator_code":  osa_code,
                    "provider_code":   self.PROVIDER_CODE,
                    "year_min":        year_min,
                    "year_max":        year_max,
                    "countries_count": countries,
                    "probe_status":    probe_status,
                })
            except Exception as exc:
                self.log.error("probe echoue pour %s : %s", osa_code, exc)
                results.append({
                    "indicator_code": osa_code,
                    "provider_code":  self.PROVIDER_CODE,
                    "year_min":       None,
                    "year_max":       None,
                    "countries_count": 0,
                    "probe_status":   "UNAVAILABLE",
                })
        return results

    def save_bounds(self, results: list[dict]) -> int:
        """
        Insere ou met a jour les bornes dans collect.indicator_bounds.
        Retourne le nombre de lignes inserees/mises a jour.
        """
        if not self.conn or self.dry_run:
            return 0
        count = 0
        with self.conn.cursor() as cur:
            for r in results:
                if r["year_min"] is None:
                    continue
                cur.execute("""
                    INSERT INTO collect.indicator_bounds
                        (indicator_code, provider_code, year_min, year_max,
                         countries_count, probe_status, last_probed)
                    VALUES (%s, %s, %s, %s, %s, %s, NOW())
                    ON CONFLICT (indicator_code, provider_code) DO UPDATE SET
                        year_min        = EXCLUDED.year_min,
                        year_max        = EXCLUDED.year_max,
                        countries_count = EXCLUDED.countries_count,
                        probe_status    = EXCLUDED.probe_status,
                        last_probed     = NOW()
                """, (
                    r["indicator_code"],
                    r["provider_code"],
                    r["year_min"],
                    r["year_max"],
                    r["countries_count"],
                    r["probe_status"],
                ))
                count += 1
        self.conn.commit()
        self.log.info("%s — %d bornes sauvegardees", self.PROVIDER_CODE, count)
        return count
