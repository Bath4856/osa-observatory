"""
============================================================
OSA Observatory — collectors/fetcher_lpi.py
Sprint 6 — Mai 2026
============================================================
Fetcher LPI — Logistics Performance Index (Banque Mondiale)
Indicateur : PTRA_LOG_LPI · Code WB : LP.LPI.OVRL.XQ

Particularités :
  - Publication biannuelle : 7 éditions sur 2007–2023
    (2007, 2010, 2012, 2014, 2016, 2018, 2023)
  - Gap 2019–2022 : COVID-19 + refonte méthodologique
  - Score natif [1, 5] → multiplié par 20 → [20, 100]
  - Migration PECO (ECO_LOG) → PTRA au Sprint 5
  - L'imputer gère l'interpolation inter-éditions (conf 0.75)

Modes de sortie (--output) :
  csv   → data/raw/ptra/lpi_{edition}.csv (une ligne par édition)
  db    → insertion directe PostgreSQL
  both  → CSV + DB (défaut)

Gestion erreurs réseau :
  Toute erreur API WB produit un DataFrame vide et un rapport
  dry-run complet. Exit code 1 si aucune donnée disponible.

Couverture : ~139 pays (toutes éditions) / ~54 africains

Usage :
  python collectors/fetcher_lpi.py --dry-run
  python collectors/fetcher_lpi.py --output csv
  python collectors/fetcher_lpi.py --output both --edition 2023
  python collectors/fetcher_lpi.py --output db
============================================================
"""

from __future__ import annotations

import argparse
import logging
import os
import sys
import time
from pathlib import Path
from typing import Literal, Optional

import pandas as pd
import psycopg2
import requests
from dotenv import load_dotenv
from psycopg2.extras import execute_batch

load_dotenv()

logging.basicConfig(
    level=os.getenv("OSA_LOG_LEVEL", "INFO"),
    format="%(asctime)s | %(levelname)-8s | %(message)s",
)
log = logging.getLogger("fetcher_lpi")

# ── Constantes ────────────────────────────────────────────
INDICATOR_CODE  = "PTRA_LOG_LPI"
WB_CODE         = "LP.LPI.OVRL.XQ"
LAYER_RAW       = 1
BATCH_SIZE      = 500
MAX_RETRIES     = 3
RETRY_DELAY     = 5

# Éditions publiées du LPI
LPI_EDITIONS    = [2007, 2010, 2012, 2014, 2016, 2018, 2023]
LPI_EDITIONS_IN_WINDOW = [y for y in LPI_EDITIONS if 2010 <= y <= 2024]

# Score LPI natif [1, 5] → ISA [20, 100]
LPI_MULTIPLIER  = 20.0

YEAR_MIN        = 2010
YEAR_MAX        = 2024

# URL dataset complet LPI (fallback Excel)
LPI_DATASET_URL = "https://lpi.worldbank.org/international/global"

# Répertoire de sortie CSV
CSV_OUTPUT_DIR  = Path(os.getenv("OSA_DATA_DIR", "data/raw/ptra"))

# Confiance pour données LPI publiées (observées)
CONFIDENCE_OBSERVED = 1.00


# ── Connexion PostgreSQL ──────────────────────────────────
def get_pg_conn():
    return psycopg2.connect(
        host=os.getenv("OSA_DB_HOST", "localhost"),
        port=int(os.getenv("OSA_DB_PORT", 5432)),
        dbname=os.getenv("OSA_DB_NAME", "osa_db"),
        user=os.getenv("OSA_DB_USER", "osa_user"),
        password=os.getenv("OSA_DB_PASS", ""),
    )


# ── HTTP avec retry ───────────────────────────────────────
def fetch_with_retry(
    url: str,
    params: dict = None,
    retries: int = MAX_RETRIES,
) -> list | dict | None:
    """
    GET avec retry et backoff exponentiel.
    Retourne None en cas d'échec définitif (jamais d'exception levée).
    """
    for attempt in range(1, retries + 1):
        try:
            resp = requests.get(url, params=params, timeout=30)
            resp.raise_for_status()
            return resp.json()
        except requests.exceptions.RequestException as e:
            wait = RETRY_DELAY * (2 ** (attempt - 1))
            if attempt == retries:
                log.warning(
                    "Source indisponible après %d tentatives : %s — %s\n"
                    "  → Mode dégradé : rapport sans données réelles.",
                    retries, url, e
                )
                return None
            log.warning("Tentative %d/%d — retry dans %ds (%s)",
                        attempt, retries, wait, e)
            time.sleep(wait)


# ── Téléchargement LPI via API WB ─────────────────────────
def fetch_lpi_from_wb(editions: list[int]) -> pd.DataFrame:
    """
    Télécharge les scores LPI via API WB.
    L'API WB retourne uniquement les années avec données publiées —
    les années inter-éditions ne sont pas retournées (NULL implicite).
    """
    log.info("Téléchargement LPI via API WB — éditions %s...", editions)

    # Construire la plage d'années (WB API accepte date=2010:2024)
    year_range = f"{min(editions)}:{max(editions)}"
    url = (
        f"https://api.worldbank.org/v2/country/all/indicator/{WB_CODE}"
        f"?date={year_range}&format=json&per_page=1000"
    )

    records = []
    page = 1

    while True:
        data = fetch_with_retry(f"{url}&page={page}")
        if data is None:
            log.warning("  API WB LPI indisponible — arrêt pagination")
            break

        if not isinstance(data, list) or len(data) < 2:
            break

        meta, rows = data[0], data[1]
        if not rows:
            break

        for row in rows:
            if row.get("value") is None:
                continue

            iso3 = row.get("countryiso3code", "")
            year = int(row.get("date", 0))

            if not iso3 or not year:
                continue
            if year not in LPI_EDITIONS:
                continue   # garder uniquement les années d'éditions publiées

            raw_value    = float(row["value"])
            scaled_value = round(raw_value * LPI_MULTIPLIER, 4)

            records.append({
                "country_iso3": iso3,
                "year":         year,
                "lpi_raw":      raw_value,       # score natif [1,5]
                "lpi_scaled":   scaled_value,    # score ISA [20,100]
                "edition_year": year,
            })

        total_pages = meta.get("pages", 1)
        if page >= total_pages:
            break
        page += 1
        time.sleep(0.2)

    df = pd.DataFrame(records) if records else pd.DataFrame(
        columns=["country_iso3", "year", "lpi_raw", "lpi_scaled", "edition_year"]
    )

    if df.empty:
        log.warning("API WB LPI retourne 0 lignes")
    else:
        log.info("  WB API : %d lignes | %d pays | éditions : %s",
                 len(df), df["country_iso3"].nunique(),
                 sorted(df["year"].unique().tolist()))

    return df


# ── Validation des données LPI ────────────────────────────
def validate_lpi(df: pd.DataFrame) -> pd.DataFrame:
    """
    Valide les scores LPI :
      - Score natif attendu dans [1, 5]
      - Score hors plage → log warning, valeur conservée mais flaggée
    """
    if df.empty:
        return df

    mask_invalid = (df["lpi_raw"] < 1.0) | (df["lpi_raw"] > 5.0)
    n_invalid = mask_invalid.sum()

    if n_invalid > 0:
        invalid_cases = df[mask_invalid][["country_iso3", "year", "lpi_raw"]].to_dict("records")
        for case in invalid_cases[:5]:   # logger max 5 cas
            log.warning("  Score LPI hors plage [1,5] : %s %d → %.3f",
                        case["country_iso3"], case["year"], case["lpi_raw"])
        if n_invalid > 5:
            log.warning("  ... et %d autres cas", n_invalid - 5)

    # Filtrer les scores manifestement erronés (hors [0.5, 5.5])
    df = df[(df["lpi_raw"] >= 0.5) & (df["lpi_raw"] <= 5.5)].copy()

    log.info("Validation LPI : %d lignes valides (sur %d + %d invalides exclus)",
             len(df), len(df), n_invalid)
    return df


# ── Analyse de la couverture ──────────────────────────────
def analyze_coverage(df: pd.DataFrame) -> None:
    """Log un résumé de couverture par édition."""
    if df.empty:
        log.warning("Aucune donnée LPI — couverture nulle")
        return

    log.info("Couverture par édition LPI :")
    for edition in LPI_EDITIONS_IN_WINDOW:
        n = (df["year"] == edition).sum()
        log.info("  %d : %d pays", edition, n)

    # Années sans données (inter-éditions) dans la fenêtre ISA
    all_years = set(range(YEAR_MIN, YEAR_MAX + 1))
    edition_years = set(LPI_EDITIONS_IN_WINDOW)
    gap_years = sorted(all_years - edition_years)
    log.info("Années sans édition (à interpoler par imputer_v3.py) : %s", gap_years)


# ── Insertion en base ─────────────────────────────────────
def insert_to_db(
    conn,
    df: pd.DataFrame,
    dry_run: bool = False,
    edition_filter: Optional[int] = None,
) -> int:
    """
    Insère les scores LPI en ma.indicator_values (layer_id = 1).

    Seules les années d'éditions publiées sont insérées.
    Les années inter-éditions sont laissées NULL pour l'imputer.
    """
    df_insert = df[df["year"].isin(LPI_EDITIONS_IN_WINDOW)].copy()

    if edition_filter:
        if edition_filter not in LPI_EDITIONS:
            log.error("Édition %d inconnue. Éditions valides : %s",
                      edition_filter, LPI_EDITIONS)
            return 0
        df_insert = df_insert[df_insert["year"] == edition_filter]

    df_insert = df_insert[
        (df_insert["year"] >= YEAR_MIN) &
        (df_insert["year"] <= YEAR_MAX)
    ]

    if df_insert.empty:
        log.info("Aucune valeur à insérer")
        return 0

    log.info("Préparation insertion : %d lignes LPI...", len(df_insert))

    if dry_run:
        log.info("[DRY-RUN] %d valeurs préparées — aucune insertion", len(df_insert))
        by_edition = df_insert.groupby("year").size()
        for yr, n in by_edition.items():
            log.info("  Édition %d : %d pays", yr, n)
        lpi_mean = df_insert.groupby("year")["lpi_raw"].mean()
        log.info("  Scores LPI moyens par édition (Afrique) :")
        for yr, mean in lpi_mean.items():
            log.info("    %d : %.3f → %.1f (×20)", yr, mean, mean * 20)
        return len(df_insert)

    # Récupérer method_version_id
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT id FROM rf.method_versions
                WHERE indicator_code = %s
                ORDER BY created_at DESC LIMIT 1
            """, (INDICATOR_CODE,))
            row = cur.fetchone()
            mvid = int(row[0]) if row else 1
    except Exception:
        mvid = 1

    # Vérifier colonnes disponibles
    with conn.cursor() as cur:
        cur.execute("""
            SELECT column_name FROM information_schema.columns
            WHERE table_schema = 'ma' AND table_name = 'indicator_values'
        """)
        db_cols = {r[0] for r in cur.fetchall()}

    has_confidence = "confidence_score" in db_cols
    has_status     = "value_status"     in db_cols

    batch_data = []
    for _, row in df_insert.iterrows():
        iso3  = row["country_iso3"]
        year  = int(row["year"])
        value = float(row["lpi_scaled"])

        if has_confidence and has_status:
            batch_data.append((
                INDICATOR_CODE, iso3, year, LAYER_RAW,
                value, None, mvid, "OK", CONFIDENCE_OBSERVED, "OBSERVED"
            ))
        elif has_confidence:
            batch_data.append((
                INDICATOR_CODE, iso3, year, LAYER_RAW,
                value, None, mvid, "OK", CONFIDENCE_OBSERVED
            ))
        else:
            batch_data.append((
                INDICATOR_CODE, iso3, year, LAYER_RAW,
                value, None, mvid, "OK"
            ))

    if has_confidence and has_status:
        sql = """
            INSERT INTO ma.indicator_values
                (indicator_code, country_iso3, year, layer_id,
                 raw_value, processed_value, method_version_id,
                 quality_flag, confidence_score, value_status)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT DO NOTHING
        """
    elif has_confidence:
        sql = """
            INSERT INTO ma.indicator_values
                (indicator_code, country_iso3, year, layer_id,
                 raw_value, processed_value, method_version_id,
                 quality_flag, confidence_score)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT DO NOTHING
        """
    else:
        sql = """
            INSERT INTO ma.indicator_values
                (indicator_code, country_iso3, year, layer_id,
                 raw_value, processed_value, method_version_id, quality_flag)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT DO NOTHING
        """

    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT COUNT(*) FROM ma.indicator_values "
                "WHERE indicator_code = %s AND layer_id = %s",
                (INDICATOR_CODE, LAYER_RAW)
            )
            count_before = cur.fetchone()[0]

        with conn.cursor() as cur:
            execute_batch(cur, sql, batch_data, page_size=BATCH_SIZE)
        conn.commit()

        with conn.cursor() as cur:
            cur.execute(
                "SELECT COUNT(*) FROM ma.indicator_values "
                "WHERE indicator_code = %s AND layer_id = %s",
                (INDICATOR_CODE, LAYER_RAW)
            )
            count_after = cur.fetchone()[0]

        inserted = count_after - count_before
        log.info("  → %d insérés (préparés=%d)", inserted, len(batch_data))
        return inserted

    except Exception as e:
        log.error("Erreur insertion batch : %s", e)
        conn.rollback()
        return 0


# ── Rapport ───────────────────────────────────────────────
def print_report(
    df: pd.DataFrame,
    n_inserted: int,
    dry_run: bool,
    output_mode: str = "both",
) -> None:
    print("\n" + "=" * 60)
    print(f"RAPPORT FETCHER LPI — {INDICATOR_CODE}")
    print("=" * 60)

    if df.empty:
        print("\n  ⚠  Aucune donnée disponible (API WB indisponible).")
        print(f"     Téléchargement manuel : {LPI_DATASET_URL}")
        print("=" * 60)
        return

    print(f"\nLignes téléchargées  : {len(df):>8}")
    print(f"Pays couverts        : {df['country_iso3'].nunique():>8}")
    print(f"Mode sortie          : {output_mode.upper()}")
    if output_mode in ("db", "both"):
        label = "[DRY-RUN prévu]" if dry_run else "Insertions DB"
        print(f"{label:<21} : {n_inserted:>8}")

    print("\nScores LPI par édition (toutes pays, moyenne africaine estimée) :")
    for edition in LPI_EDITIONS_IN_WINDOW:
        sub = df[df["year"] == edition]
        if sub.empty:
            print(f"  {edition} : 0 pays — édition non téléchargée")
        else:
            mean_raw    = sub["lpi_raw"].mean()
            mean_scaled = sub["lpi_scaled"].mean()
            n_countries = len(sub)
            print(f"  {edition} : {n_countries:>3} pays | "
                  f"LPI moy. = {mean_raw:.3f} → {mean_scaled:.1f} (×20)")

    gap_years = [y for y in range(YEAR_MIN, YEAR_MAX + 1)
                 if y not in LPI_EDITIONS_IN_WINDOW]
    print(f"\nAnnées sans édition (à interpoler par imputer) : {gap_years}")
    print(f"  → Méthode : interpolation linéaire PTRA_INTERP, conf 0.75")

    if dry_run:
        print("\n[DRY-RUN] Aucune donnée insérée en base.")
    print("=" * 60)


# ── Export CSV ────────────────────────────────────────────
def export_csv(df: pd.DataFrame, edition_filter: Optional[int] = None) -> None:
    """Exporte vers data/raw/ptra/lpi_{edition|all}.csv"""
    CSV_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    suffix = str(edition_filter) if edition_filter else "all"
    path = CSV_OUTPUT_DIR / f"lpi_{suffix}.csv"

    df_export = df.copy()
    df_export["indicator_code"] = INDICATOR_CODE
    df_export.rename(columns={"lpi_scaled": "raw_value"}, inplace=True)

    cols = ["indicator_code", "country_iso3", "year", "raw_value", "lpi_raw"]
    df_export[cols].sort_values(["country_iso3", "year"]).to_csv(path, index=False)
    log.info("  CSV exporté → %s (%d lignes)", path, len(df_export))


# ── Orchestrateur ─────────────────────────────────────────
def run(
    edition_filter: Optional[int] = None,
    dry_run: bool = False,
    output_mode: Literal["csv", "db", "both"] = "both",
) -> int:
    """Retourne le nombre de lignes insérées, ou -1 si aucune donnée."""
    log.info("=" * 60)
    log.info("OSA Fetcher LPI — %s | Output : %s | Éditions : %s",
             INDICATOR_CODE, output_mode.upper(), LPI_EDITIONS_IN_WINDOW)
    if edition_filter:
        log.info("Filtre édition : %d", edition_filter)
    if dry_run:
        log.info("MODE DRY-RUN — aucune écriture")

    editions_to_fetch = [edition_filter] if edition_filter else LPI_EDITIONS_IN_WINDOW
    df = fetch_lpi_from_wb(editions_to_fetch)

    if df.empty:
        log.warning(
            "Aucune donnée LPI téléchargée.\n"
            "  → Téléchargement manuel : %s", LPI_DATASET_URL
        )
        print_report(df, 0, dry_run=True, output_mode=output_mode)
        return -1

    df = validate_lpi(df)
    analyze_coverage(df)

    conn = get_pg_conn()
    n_inserted = 0
    try:
        if not dry_run and output_mode in ("csv", "both"):
            export_csv(df, edition_filter)

        if not dry_run and output_mode in ("db", "both"):
            n_inserted = insert_to_db(conn, df, dry_run=False,
                                      edition_filter=edition_filter)
        elif dry_run:
            n_inserted = insert_to_db(conn, df, dry_run=True,
                                      edition_filter=edition_filter)

        print_report(df, n_inserted, dry_run=dry_run, output_mode=output_mode)
    finally:
        conn.close()

    return n_inserted


# ── CLI ───────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(
        description=f"OSA — Fetcher LPI Banque Mondiale ({INDICATOR_CODE})",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=f"""
Éditions dans fenêtre ISA (2010–2024) : {LPI_EDITIONS_IN_WINDOW}

Modes de sortie :
  --output csv   → data/raw/ptra/lpi_{{edition|all}}.csv
  --output db    → ma.indicator_values layer_id=1
  --output both  → CSV + DB (défaut)
  --dry-run      → rapport seul, aucune écriture

Exemples :
  python fetcher_lpi.py --dry-run
  python fetcher_lpi.py --output csv
  python fetcher_lpi.py --output both --edition 2023
  python fetcher_lpi.py --output db

Note : les années inter-éditions (2011, 2013, etc.) sont laissées
NULL en layer_id=1 — l'imputer_v3.py les comblera via interpolation
linéaire (PTRA_INTERP, confiance 0.75).

Dataset complet : {LPI_DATASET_URL}
        """
    )
    parser.add_argument("--dry-run",  action="store_true",
                        help="Rapport sans écriture (ni CSV ni DB)")
    parser.add_argument("--output",   choices=["csv", "db", "both"], default="both",
                        help="Mode de sortie (défaut: both)")
    parser.add_argument("--edition",  type=int, default=None,
                        help=f"Traiter une seule édition. Valeurs : {LPI_EDITIONS}")

    args = parser.parse_args()

    if args.edition and args.edition not in LPI_EDITIONS:
        parser.error(f"Édition {args.edition} inconnue. Valides : {LPI_EDITIONS}")

    result = run(
        edition_filter=args.edition,
        dry_run=args.dry_run,
        output_mode=args.output,
    )
    sys.exit(0 if result >= 0 else 1)


if __name__ == "__main__":
    main()
