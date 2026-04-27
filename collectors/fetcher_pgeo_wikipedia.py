"""
============================================================
OSA / ISA OBSERVATORY
collectors/fetcher_pgeo_wikipedia.py
============================================================
Collecte PGEO — Sites miniers africains via Wikipedia

Spécificité de ce fetcher vs les autres :
  Les données PGEO sont des propriétés spatiales (sites),
  pas des séries temporelles (pays × année × valeur).

  Ce fetcher produit donc deux sorties :
    1. PostgreSQL → osa.pgeo_site (upsert des sites)
    2. CSV + GeoJSON → data/output/ (pour usage SIG / QGIS)

  Il n'insère PAS dans ma.indicator_values (pas de valeur temporelle).
  Il insère dans osa.pgeo_site via _insert_sites().

Pipeline :
  1. Vérifier si pgeo_site est déjà peuplé → skip si suffisant
  2. Scraper Wikipedia : "List of mines in {country}"
  3. Détecter la ressource (mots-clés dans le texte de la page)
  4. Géocoder via Nominatim (OpenStreetMap)
  5. Upsert dans osa.pgeo_site
  6. Exporter CSV + GeoJSON

Indicateurs OSA produits :
  PGEO_MINE_COUNT  — nombre de sites par pays × année (proxy)
  PGEO_MINE_COORD  — présence d'une coordonnée (qualité géoloc)

Usage :
  python collectors/fetcher_pgeo_wikipedia.py --dry-run
  python collectors/fetcher_pgeo_wikipedia.py
  python collectors/fetcher_pgeo_wikipedia.py --output csv
  python collectors/fetcher_pgeo_wikipedia.py --output db
  python collectors/fetcher_pgeo_wikipedia.py --output both
============================================================
"""

from __future__ import annotations

import argparse
import json
import logging
import os
import re
import time
from pathlib import Path
from typing import Optional

import pandas as pd
import psycopg2
import requests
from bs4 import BeautifulSoup
from dotenv import load_dotenv

load_dotenv()

# ── Logging ────────────────────────────────────────────────────────────────────

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s — %(message)s",
)
log = logging.getLogger("fetcher_pgeo")

# ── Configuration ──────────────────────────────────────────────────────────────

DB_CONN_PARAMS = dict(
    host     = os.getenv("OSA_DB_HOST",  "localhost"),
    port     = int(os.getenv("OSA_DB_PORT", "5432")),
    dbname   = os.getenv("OSA_DB_NAME",  "osa_db"),
    user     = os.getenv("OSA_DB_USER",  "postgres"),
    password = os.getenv("OSA_DB_PASS",  ""),
    connect_timeout = 10,
)

DIR_OUT = Path(os.getenv("OSA_DIR_OUT", "data/output"))
DIR_OUT.mkdir(parents=True, exist_ok=True)

HTTP_TIMEOUT  = 30
HTTP_RETRIES  = 3
SLEEP_WIKI    = 1.2    # secondes entre requêtes Wikipedia
SLEEP_GEOCODE = 1.1    # secondes entre requêtes Nominatim (politique OSM)

# ── Pays africains ────────────────────────────────────────────────────────────

AFRICA_COUNTRIES_EN: list[tuple[str, str]] = [
    # (nom Wikipedia, ISO3)
    ("Algeria",                          "DZA"),
    ("Angola",                           "AGO"),
    ("Benin",                            "BEN"),
    ("Botswana",                         "BWA"),
    ("Burkina Faso",                     "BFA"),
    ("Burundi",                          "BDI"),
    ("Cameroon",                         "CMR"),
    ("Cape Verde",                       "CPV"),
    ("Central African Republic",         "CAF"),
    ("Chad",                             "TCD"),
    ("Comoros",                          "COM"),
    ("Democratic Republic of the Congo", "COD"),
    ("Djibouti",                         "DJI"),
    ("Egypt",                            "EGY"),
    ("Equatorial Guinea",                "GNQ"),
    ("Eritrea",                          "ERI"),
    ("Eswatini",                         "SWZ"),
    ("Ethiopia",                         "ETH"),
    ("Gabon",                            "GAB"),
    ("Gambia",                           "GMB"),
    ("Ghana",                            "GHA"),
    ("Guinea",                           "GIN"),
    ("Guinea-Bissau",                    "GNB"),
    ("Ivory Coast",                      "CIV"),
    ("Kenya",                            "KEN"),
    ("Lesotho",                          "LSO"),
    ("Liberia",                          "LBR"),
    ("Libya",                            "LBY"),
    ("Madagascar",                       "MDG"),
    ("Malawi",                           "MWI"),
    ("Mali",                             "MLI"),
    ("Mauritania",                       "MRT"),
    ("Mauritius",                        "MUS"),
    ("Morocco",                          "MAR"),
    ("Mozambique",                       "MOZ"),
    ("Namibia",                          "NAM"),
    ("Niger",                            "NER"),
    ("Nigeria",                          "NGA"),
    ("Republic of the Congo",            "COG"),
    ("Rwanda",                           "RWA"),
    ("Sao Tome and Principe",            "STP"),
    ("Senegal",                          "SEN"),
    ("Seychelles",                       "SYC"),
    ("Sierra Leone",                     "SLE"),
    ("Somalia",                          "SOM"),
    ("South Africa",                     "ZAF"),
    ("South Sudan",                      "SSD"),
    ("Sudan",                            "SDN"),
    ("Tanzania",                         "TZA"),
    ("Togo",                             "TGO"),
    ("Tunisia",                          "TUN"),
    ("Uganda",                           "UGA"),
    ("Zambia",                           "ZMB"),
    ("Zimbabwe",                         "ZWE"),
]

# ── Mots-clés ressources ──────────────────────────────────────────────────────

MINE_RESOURCES: dict[str, str] = {
    "gold":           "Gold",       "auriferous":   "Gold",
    "diamond":        "Diamonds",   "kimberlite":   "Diamonds",
    "copper":         "Copper",     "cobalt":       "Cobalt",
    "copper-cobalt":  "Copper",
    "iron ore":       "Iron",       "iron":         "Iron",
    "bauxite":        "Bauxite",    "nickel":       "Nickel",
    "manganese":      "Manganese",  "platinum":     "Platinum",
    "palladium":      "Platinum",   "uranium":      "Uranium",
    "lithium":        "Lithium",    "tin":          "Tin",
    "zinc":           "Zinc",       "lead":         "Lead",
    "rare earth":     "RareEarth",  "chromite":     "Chromium",
    "coltan":         "NiobiumTantalum",
    "phosphate":      "Phosphate",  "coal":         "Coal",
    "oil":            "CrudeOil",   "natural gas":  "NaturalGas",
}


# ══════════════════════════════════════════════════════════════════════════════
#  FETCHER PGEO WIKIPEDIA
# ══════════════════════════════════════════════════════════════════════════════

class PGEOWikipediaFetcher:
    """
    Scrape Wikipedia pour lister les mines africaines,
    détecte leur ressource, les géocode, puis insère dans osa.pgeo_site.

    Compatible avec l'architecture BaseFetcher d'OSA :
      - même connexion DB via variables d'environnement OSA_DB_*
      - même table de log collect.ingestion_registry
      - même mode dry_run
    """

    PROVIDER_CODE = "WIKIPEDIA"
    ENDPOINT_CODE = "WIKIPEDIA_PGEO"

    def __init__(self, dry_run: bool = False, output: str = "both") -> None:
        self.dry_run = dry_run
        self.output  = output   # "csv" | "db" | "both"
        self.conn: Optional[psycopg2.extensions.connection] = None
        self.endpoint_id: Optional[int] = None

    # ── Connexion ─────────────────────────────────────────────────────────────

    def connect(self) -> bool:
        try:
            self.conn = psycopg2.connect(**DB_CONN_PARAMS)
            with self.conn.cursor() as cur:
                cur.execute(
                    "SELECT id FROM collect.provider_endpoints "
                    "WHERE endpoint_code = %s",
                    (self.ENDPOINT_CODE,),
                )
                row = cur.fetchone()
                self.endpoint_id = row[0] if row else None
            log.info("DB OK — endpoint_id: %s", self.endpoint_id)
            return True
        except Exception as e:
            log.warning("DB connexion échouée : %s — mode CSV uniquement.", e)
            self.conn = None
            return False

    def disconnect(self) -> None:
        if self.conn:
            self.conn.close()
            self.conn = None

    # ── Point d'entrée principal ──────────────────────────────────────────────

    def run(self) -> dict:
        log.info("=" * 55)
        log.info("PGEO Wikipedia — démarrage")
        log.info("  Dry-run : %s | Output : %s", self.dry_run, self.output)
        log.info("=" * 55)

        t0 = time.monotonic()

        # Étape 1 : vérifier si la DB est déjà peuplée
        if self.conn and self._db_already_populated():
            log.info("osa.pgeo_site déjà peuplé — skip scraping.")
            return {"status": "SKIPPED", "reason": "already_populated"}

        # Étape 2 : scraper Wikipedia
        sites_df = self._scrape_all_countries()
        if sites_df.empty:
            log.error("Aucun site extrait.")
            return {"status": "FAILED", "sites": 0}

        # Étape 3 : détecter les ressources
        sites_df = self._enrich_resources(sites_df)

        # Étape 4 : géocoder
        sites_df = self._geocode(sites_df)

        # Étape 5 : exporter
        inserted_db  = 0
        inserted_csv = 0

        if self.output in ("db", "both") and self.conn:
            inserted_db = self._insert_sites(sites_df)

        if self.output in ("csv", "both"):
            inserted_csv = self._export_csv_geojson(sites_df)

        duration = int((time.monotonic() - t0) * 1000)
        self._log_ingestion(len(sites_df), inserted_db, duration)

        log.info("=" * 55)
        log.info("PGEO terminé — %d sites | DB: %d | CSV: %d | %dms",
                 len(sites_df), inserted_db, inserted_csv, duration)
        log.info("=" * 55)

        return {
            "status":       "SUCCESS",
            "sites_total":  len(sites_df),
            "inserted_db":  inserted_db,
            "inserted_csv": inserted_csv,
            "duration_ms":  duration,
        }

    # ── Étape 1 : vérification DB ─────────────────────────────────────────────

    def _db_already_populated(self) -> bool:
        """Retourne True si osa.pgeo_site a déjà > 50 sites africains."""
        try:
            with self.conn.cursor() as cur:
                cur.execute(
                    "SELECT COUNT(*) FROM osa.pgeo_site "
                    "WHERE source = 'WIKIPEDIA'"
                )
                count = cur.fetchone()[0]
                log.info("osa.pgeo_site (WIKIPEDIA) : %d sites existants", count)
                return count > 50
        except Exception as e:
            log.warning("Vérification pgeo_site : %s", e)
            return False

    # ── Étape 2 : scraping Wikipedia ─────────────────────────────────────────

    def _scrape_all_countries(self) -> pd.DataFrame:
        log.info("Scraping Wikipedia — %d pays", len(AFRICA_COUNTRIES_EN))
        rows = []

        for country_name, iso3 in AFRICA_COUNTRIES_EN:
            found = self._scrape_country(country_name, iso3, rows)
            log.info("  %-40s %s : %d mines", country_name, iso3, found)
            time.sleep(SLEEP_WIKI)

        df = pd.DataFrame(rows).drop_duplicates(subset=["name", "iso3"])
        log.info("Total sites extraits : %d", len(df))
        return df

    def _scrape_country(
        self, country_name: str, iso3: str, rows: list
    ) -> int:
        urls = [
            f"https://en.wikipedia.org/wiki/List_of_mines_in_{country_name.replace(chr(32), chr(95))}",
            f"https://en.wikipedia.org/wiki/Mining_in_{country_name.replace(chr(32), chr(95))}",
            f"https://en.wikipedia.org/wiki/Mining_in_the_{country_name.replace(chr(32), chr(95))}",
        ]
        resp = None
        for url in urls:
            resp = self._http_get_html(url)
            if resp:
                break
            time.sleep(0.5)
        if resp is None:
            return 0

        soup  = BeautifulSoup(resp, "lxml")
        found = 0

        # Tableaux wikitable (format structuré)
        for table in soup.find_all("table", {"class": "wikitable"}):
            for row in table.find_all("tr")[1:]:
                cols = row.find_all(["td", "th"])
                if not cols:
                    continue
                name     = cols[0].get_text(strip=True)
                resource = cols[1].get_text(strip=True) if len(cols) > 1 else ""
                location = cols[2].get_text(strip=True) if len(cols) > 2 else ""
                if name:
                    rows.append({
                        "name":     name,
                        "resource": resource,
                        "location": location,
                        "country":  country_name,
                        "iso3":     iso3,
                    })
                    found += 1

        # Listes <ul> fallback (pages sans tableau)
        if found == 0:
            for li in soup.find_all("li"):
                text = li.get_text(strip=True)
                if re.search(r"\bmine\b", text, re.IGNORECASE) and len(text) < 120:
                    rows.append({
                        "name":     text,
                        "resource": "",
                        "location": "",
                        "country":  country_name,
                        "iso3":     iso3,
                    })
                    found += 1

        return found

    # ── Étape 3 : détection ressource ────────────────────────────────────────

    def _enrich_resources(self, df: pd.DataFrame) -> pd.DataFrame:
        log.info("Enrichissement ressources (%d sites)...", len(df))
        detected = []

        for _, row in df.iterrows():
            existing = str(row.get("resource", "")).strip()
            if existing and existing.lower() not in ("", "nan"):
                # Normaliser la ressource déjà connue
                detected.append(self._normalize_resource(existing))
                continue

            # Chercher la page Wikipedia de la mine
            mine    = str(row.get("name", ""))
            country = str(row.get("country", ""))
            html    = None

            for query in [mine, f"{mine} mine", f"{mine} {country}"]:
                resp = self._http_get_html(
                    f"https://en.wikipedia.org/wiki/{query.replace(' ', '_')}"
                )
                if resp:
                    html = resp
                    break
                time.sleep(0.5)

            res = self._detect_resource_from_html(html)
            detected.append(res or "Unknown")
            time.sleep(SLEEP_WIKI)

        df = df.copy()
        df["resource_detected"] = detected
        return df

    def _detect_resource_from_html(self, html: Optional[str]) -> Optional[str]:
        if not html:
            return None
        soup = BeautifulSoup(html, "lxml")
        text = soup.get_text(" ", strip=True).lower()
        for keyword, label in MINE_RESOURCES.items():
            if re.search(r'\b' + re.escape(keyword) + r'\b', text):
                return label
        return None

    def _normalize_resource(self, raw: str) -> str:
        """Normalise un libellé de ressource brut vers les codes OSA."""
        raw_lower = raw.lower().strip()
        for keyword, label in MINE_RESOURCES.items():
            if keyword in raw_lower:
                return label
        return raw.title() if raw else "Unknown"

    # ── Étape 4 : géocodage Nominatim ────────────────────────────────────────

    def _geocode(self, df: pd.DataFrame) -> pd.DataFrame:
        log.info("Géocodage Nominatim (%d sites)...", len(df))
        lats, lons = [], []

        for _, row in df.iterrows():
            name    = str(row.get("name", ""))
            country = str(row.get("country", ""))
            lat, lon = self._geocode_one(name, country)
            lats.append(lat)
            lons.append(lon)
            time.sleep(SLEEP_GEOCODE)

        df = df.copy()
        df["lat"] = lats
        df["lon"] = lons
        geocoded = df["lat"].notna().sum()
        log.info("Géocodage : %d/%d sites localisés (%.0f%%)",
                 geocoded, len(df), 100 * geocoded / max(len(df), 1))
        return df

    def _geocode_one(
        self, name: str, country: str
    ) -> tuple[Optional[float], Optional[float]]:
        query = f"{name}, {country}".strip(", ")
        try:
            resp = requests.get(
                "https://nominatim.openstreetmap.org/search",
                params={"q": query, "format": "json", "limit": 1},
                headers={"User-Agent": "OSA-Observatory/1.0"},
                timeout=20,
            )
            resp.raise_for_status()
            results = resp.json()
            if results:
                return float(results[0]["lat"]), float(results[0]["lon"])
        except Exception as e:
            log.debug("Géocodage '%s' : %s", query, e)
        return None, None

    # ── Étape 5a : insertion PostgreSQL ──────────────────────────────────────

    def _insert_sites(self, df: pd.DataFrame) -> int:
        """
        Upsert dans osa.pgeo_site.
        Génère un site_code : {ISO3}_WIKI_{index:04d}
        Retourne le nombre de lignes insérées/mises à jour.
        """
        if self.dry_run:
            log.info("[DRY-RUN] %d sites (non insérés)", len(df))
            return len(df)

        inserted = 0
        with self.conn.cursor() as cur:

            # Récupérer les country_id
            cur.execute("SELECT iso3, id FROM ref.country WHERE iso3 = ANY(%s)",
                        (list(df["iso3"].unique()),))
            country_map = {row[0]: row[1] for row in cur.fetchall()}

            # Récupérer les resource_id
            cur.execute("SELECT code, id FROM osa.mineral_resource")
            resource_map = {row[0]: row[1] for row in cur.fetchall()}

            for i, (_, row) in enumerate(df.iterrows()):
                iso3       = row["iso3"]
                site_code  = f"{iso3}_WIKI_{i:04d}"
                name       = row.get("name", "")[:200]
                resource   = row.get("resource_detected", "Unknown")
                lat        = row.get("lat")
                lon        = row.get("lon")
                country_id = country_map.get(iso3)
                resource_id = resource_map.get(resource)

                if not country_id:
                    log.debug("Pays inconnu : %s — site ignoré.", iso3)
                    continue

                try:
                    cur.execute("""
                        INSERT INTO osa.pgeo_site
                            (site_code, name, country_id, resource_id,
                             latitude, longitude, source, metadata)
                        VALUES (%s, %s, %s, %s, %s, %s, 'WIKIPEDIA',
                                %s::jsonb)
                        ON CONFLICT (site_code) DO UPDATE SET
                            name        = EXCLUDED.name,
                            resource_id = EXCLUDED.resource_id,
                            latitude    = EXCLUDED.latitude,
                            longitude   = EXCLUDED.longitude,
                            source      = EXCLUDED.source
                    """, (
                        site_code, name, country_id, resource_id,
                        lat if lat else None,
                        lon if lon else None,
                        json.dumps({
                            "country":  row.get("country", ""),
                            "location": row.get("location", ""),
                        }),
                    ))
                    inserted += 1
                except psycopg2.Error as e:
                    log.warning("Insert site %s : %s", site_code, e)
                    self.conn.rollback()
                    continue

        self.conn.commit()
        log.info("osa.pgeo_site : %d sites insérés/mis à jour", inserted)
        return inserted

    # ── Étape 5b : export CSV + GeoJSON ──────────────────────────────────────

    def _export_csv_geojson(self, df: pd.DataFrame) -> int:
        if self.dry_run:
            log.info("[DRY-RUN] Export CSV/GeoJSON ignoré.")
            return 0

        # CSV
        csv_path = DIR_OUT / "pgeo_mines_wikipedia.csv"
        df.to_csv(csv_path, index=False, encoding="utf-8")
        log.info("CSV  : %s (%d lignes)", csv_path, len(df))

        # GeoJSON
        features = []
        for _, row in df.iterrows():
            lat = row.get("lat")
            lon = row.get("lon")
            if lat is None or lon is None:
                continue
            try:
                features.append({
                    "type": "Feature",
                    "geometry": {
                        "type":        "Point",
                        "coordinates": [float(lon), float(lat)],
                    },
                    "properties": {
                        "site_code":  f"{row['iso3']}_WIKI",
                        "name":       row.get("name", ""),
                        "iso3":       row.get("iso3", ""),
                        "country":    row.get("country", ""),
                        "resource":   row.get("resource_detected", ""),
                        "location":   row.get("location", ""),
                    },
                })
            except (TypeError, ValueError):
                continue

        geojson_path = DIR_OUT / "pgeo_mines_wikipedia.geojson"
        with open(geojson_path, "w", encoding="utf-8") as f:
            json.dump({"type": "FeatureCollection", "features": features},
                      f, ensure_ascii=False, indent=2)
        log.info("GeoJSON : %s (%d features)", geojson_path, len(features))
        return len(df)

    # ── Log ingestion ─────────────────────────────────────────────────────────

    def _log_ingestion(
        self, total: int, inserted: int, duration_ms: int
    ) -> None:
        if self.dry_run or not self.conn or not self.endpoint_id:
            return
        try:
            with self.conn.cursor() as cur:
                cur.execute("""
                    INSERT INTO collect.ingestion_registry
                        (endpoint_id, indicator_code, year,
                         execution_date, status,
                         records_inserted, records_rejected,
                         duration_ms, message)
                    VALUES (%s, %s, NULL, now(), %s, %s, %s, %s, %s)
                """, (
                    self.endpoint_id,
                    "PGEO_WIKIPEDIA",
                    "SUCCESS" if inserted > 0 else "PARTIAL",
                    inserted,
                    total - inserted,
                    duration_ms,
                    f"Wikipedia scraping — {total} sites, {inserted} insérés",
                ))
            self.conn.commit()
        except Exception as e:
            log.warning("Log ingestion : %s", e)

    # ── HTTP helper ───────────────────────────────────────────────────────────

    def _http_get_html(self, url: str) -> Optional[str]:
        for attempt in range(1, HTTP_RETRIES + 1):
            try:
                r = requests.get(
                    url,
                    headers={"User-Agent": "OSA-Observatory/1.0"},
                    timeout=HTTP_TIMEOUT,
                )
                if r.status_code == 404:
                    return None
                r.raise_for_status()
                return r.text
            except requests.exceptions.RequestException as e:
                log.debug("[%d/%d] %s : %s", attempt, HTTP_RETRIES, url[:60], e)
                if attempt < HTTP_RETRIES:
                    time.sleep(2 * attempt)
        return None


# ── CLI ────────────────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(
        description="OSA — Collecte PGEO via Wikipedia"
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Simulation sans écriture"
    )
    parser.add_argument(
        "--output", choices=["csv", "db", "both"], default="both",
        help="Mode de sortie (défaut: both)"
    )
    args = parser.parse_args()

    fetcher = PGEOWikipediaFetcher(dry_run=args.dry_run, output=args.output)
    fetcher.connect()

    try:
        result = fetcher.run()
        print(f"\nRésultat : {result}")
    finally:
        fetcher.disconnect()


if __name__ == "__main__":
    main()
