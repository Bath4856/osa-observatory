"""
============================================================
OSA Observatory — collectors/fetcher_wb_ptra.py
Sprint 6 — Mai 2026
============================================================
Fetcher WB dédié — 8 indicateurs PTRA via API World Bank

Modes de sortie (--output) :
  csv   → data/raw/ptra/{osa_code}_{year_min}_{year_max}.csv
  db    → insertion directe PostgreSQL (ma.indicator_values)
  both  → CSV + DB (défaut)

Gestion erreurs réseau :
  Toute erreur API WB produit un DataFrame vide pour cet
  indicateur + log warning, et continue sur les suivants.
  Un rapport final récapitule les indicateurs en succès vs
  en échec. Exit code 1 si tous les indicateurs échouent.

Indicateurs couverts (8 sur 10 du pilier PTRA) :
  Routier    : IS.ROD.DNST.K2, IS.ROD.PAVE.ZS
  Aérien     : IS.AIR.PSGR, IS.AIR.GOOD.MT.K1, IS.AIR.DPRT
  Maritime   : IS.SHP.GOOD.TU, IS.SHP.GCNW.XQ
  Logistique : IQ.CPA.TRAN.XQ

Non couverts ici (fetchers dédiés) :
  LP.LPI.OVRL.XQ → fetcher_lpi.py
  LSCI UNCTAD    → fetcher_unctad.py

Usage :
  python collectors/fetcher_wb_ptra.py --dry-run
  python collectors/fetcher_wb_ptra.py --output csv
  python collectors/fetcher_wb_ptra.py --output both --skip-lsci
  python collectors/fetcher_wb_ptra.py --indicator IS.ROD.DNST.K2 --output db
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
log = logging.getLogger("fetcher_wb_ptra")

# ── Constantes ────────────────────────────────────────────
LAYER_RAW    = 1
YEAR_MIN     = 2010
YEAR_MAX     = 2024
BATCH_SIZE   = 500
MAX_RETRIES  = 3
RETRY_DELAY  = 5
WB_API_BASE  = "https://api.worldbank.org/v2"
REQUEST_DELAY = 0.25   # secondes entre appels API (rate limiting)

# Pays africains enclavés — indicateurs portuaires = 0 réel
LANDLOCKED_AFRICA = {
    "BFA", "BDI", "CAF", "TCD", "ETH", "LSO", "MWI",
    "MLI", "NER", "RWA", "SSD", "SWZ", "UGA", "ZMB", "ZWE", "BWA",
}

# Répertoire de sortie CSV
CSV_OUTPUT_DIR = Path(os.getenv("OSA_DATA_DIR", "data/raw/ptra"))

# ── Mapping complet des 8 indicateurs WB PTRA ────────────
WB_PTRA_MAP = {

    # ── ROUTIER ──────────────────────────────────────────
    "IS.ROD.DNST.K2": {
        "osa_code":             "PTRA_RD_DENSITY",
        "name_fr":              "Densité du réseau routier (km/km²)",
        "unit":                 "KM_KM2",
        "direction":            "+",
        "multiplier":           1.0,
        "has_structural_zeros": False,
        "is_proxy":             False,
        "min_valid":            0.0,
        "max_valid":            500.0,    # km/km² — max plausible Rwanda ~1.6
        "quality_notes":        "Source IRF via WB. Fréquence irrégulière. "
                                "Sous-estimation connue ~134% vs OSM (acceptable intra-Afrique).",
    },

    "IS.ROD.PAVE.ZS": {
        "osa_code":             "PTRA_RD_PAVED",
        "name_fr":              "Routes pavées (% du réseau total)",
        "unit":                 "PCT_RD",
        "direction":            "+",
        "multiplier":           1.0,
        "has_structural_zeros": False,
        "is_proxy":             False,
        "min_valid":            0.0,
        "max_valid":            100.0,
        "quality_notes":        "Source IRF via WB. Fréquence irrégulière.",
    },

    # ── AÉRIEN ───────────────────────────────────────────
    "IS.AIR.PSGR": {
        "osa_code":             "PTRA_AIR_PASSENGERS",
        "name_fr":              "Passagers aériens transportés (total)",
        "unit":                 "PAX",
        "direction":            "+",
        "multiplier":           1.0,
        "has_structural_zeros": False,
        "is_proxy":             False,
        "min_valid":            0.0,
        "max_valid":            1e9,      # max plausible : ~100M pour ZAF
        "quality_notes":        "Source ICAO via WB. Annuel continu. "
                                "NaN = pays sans compagnie enregistrée (non zéro).",
    },

    "IS.AIR.GOOD.MT.K1": {
        "osa_code":             "PTRA_AIR_CARGO",
        "name_fr":              "Fret aérien (millions de tonnes-km)",
        "unit":                 "TONNES_MT_KM",
        "direction":            "+",
        "multiplier":           1.0,
        "has_structural_zeros": False,
        "is_proxy":             False,
        "min_valid":            0.0,
        "max_valid":            5000.0,   # millions t-km — max Afrique ~1000
        "quality_notes":        "Source ICAO via WB. Annuel. "
                                "Discontinuités pour pays à faible trafic.",
    },

    "IS.AIR.DPRT": {
        "osa_code":             "PTRA_AIR_AIRPORTS",
        "name_fr":              "Départs de vols enregistrés (proxy activité aéroportuaire)",
        "unit":                 "COUNT_DEPARTURES",
        "direction":            "+",
        "multiplier":           1.0,
        "has_structural_zeros": False,
        "is_proxy":             True,
        "proxy_note":           "Départs ≠ nombre physique d'aéroports. "
                                "Mesure l'activité aéroportuaire effective. "
                                "Confiance d'imputation réduite (0.70) vs indicateurs directs.",
        "min_valid":            0.0,
        "max_valid":            1e7,
        "quality_notes":        "Source ICAO via WB. Annuel. ~44 pays africains.",
    },

    # ── MARITIME & PORTUAIRE ─────────────────────────────
    "IS.SHP.GOOD.TU": {
        "osa_code":             "PTRA_PORT_CAP",
        "name_fr":              "Containers portuaires traités (TEU)",
        "unit":                 "COUNT_TEU",
        "direction":            "+",
        "multiplier":           1.0,
        "has_structural_zeros": True,
        "zero_for_landlocked":  True,
        "zero_confidence":      0.95,
        "is_proxy":             False,
        "min_valid":            0.0,
        "max_valid":            1.5e7,    # max Afrique ~12M TEU (Port Said)
        "quality_notes":        "Source WB. ~35 pays côtiers + 15 zéros enclavés. "
                                "Annuel 2000–2022.",
    },

    "IS.SHP.GCNW.XQ": {
        "osa_code":             "PTRA_PORT_CONNECT",
        "name_fr":              "Connectivité maritime LSCI (via WB — fallback UNCTAD)",
        "unit":                 "SCORE_LSCI",
        "direction":            "+",
        "multiplier":           1.0,
        "has_structural_zeros": True,
        "zero_for_landlocked":  True,
        "zero_confidence":      0.95,
        "is_proxy":             False,
        "min_valid":            0.0,
        "max_valid":            200.0,    # LSCI — max mondial ~120 (pré-révision)
        "quality_notes":        "Source UNCTAD via WB. "
                                "Utiliser fetcher_unctad.py pour données natives + gestion rupture 2024. "
                                "Ce fetcher insère la version WB en fallback si fetcher_unctad.py non exécuté.",
        "prefer_unctad":        True,     # signal : ce fetcher est le fallback
    },

    # ── LOGISTIQUE ───────────────────────────────────────
    "IQ.CPA.TRAN.XQ": {
        "osa_code":             "PTRA_RD_QUALITY",
        "name_fr":              "Qualité des politiques de transport (CPIA 2.1)",
        "unit":                 "SCORE_1_6",
        "direction":            "+",
        "multiplier":           20.0,     # [1,6] → ×20 → [20,120] (normaliser [0,100] dans scorer)
        "has_structural_zeros": False,
        "is_proxy":             False,
        "conceptual_caveat":    True,
        "caveat_note":          "CPIA mesure la qualité des POLITIQUES de transport, "
                                "pas les infrastructures physiques. "
                                "Inclus comme indicateur institutionnel avec réserve documentée.",
        "min_valid":            1.0,
        "max_valid":            6.0,
        "coverage_note":        "Limité aux pays éligibles IDA (~39 pays africains). "
                                "Non disponible pour ZAF, EGY, MAR, DZA, TUN en général.",
        "quality_notes":        "Source WB CPIA. Annuel 2005–2023.",
    },
}


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
    retries: int = MAX_RETRIES,
) -> list | dict | None:
    """
    GET avec retry et backoff exponentiel.
    Retourne None en cas d'échec définitif (jamais d'exception levée).
    Le caller décide comment gérer un résultat None.
    """
    for attempt in range(1, retries + 1):
        try:
            resp = requests.get(url, timeout=30)
            resp.raise_for_status()
            return resp.json()
        except requests.exceptions.RequestException as e:
            wait = RETRY_DELAY * (2 ** (attempt - 1))
            if attempt == retries:
                log.warning(
                    "Source indisponible après %d tentatives : %s — %s\n"
                    "  → Indicateur ignoré, rapport généré sans ces données.",
                    retries, url, e
                )
                return None
            log.warning("Tentative %d/%d — retry dans %ds (%s)",
                        attempt, retries, wait, e)
            time.sleep(wait)


# ── Téléchargement d'un indicateur WB ────────────────────
def fetch_wb_indicator(wb_code: str, year_min: int, year_max: int) -> pd.DataFrame:
    """
    Télécharge un indicateur WB pour tous pays, fenêtre année_min–année_max.
    Gère la pagination automatiquement.
    """
    url = (
        f"{WB_API_BASE}/country/all/indicator/{wb_code}"
        f"?date={year_min}:{year_max}&format=json&per_page=500"
    )

    records = []
    page    = 1

    while True:
        data = fetch_with_retry(f"{url}&page={page}")

        if data is None:
            log.warning("  [%s] API indisponible — arrêt pagination page %d",
                        wb_code, page)
            break

        if not isinstance(data, list) or len(data) < 2:
            log.warning("  [%s] Réponse inattendue page %d", wb_code, page)
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
            if year < year_min or year > year_max:
                continue
            try:
                records.append({
                    "country_iso3": iso3,
                    "year":         year,
                    "raw_value":    float(row["value"]),
                })
            except (ValueError, TypeError):
                continue

        total_pages = meta.get("pages", 1)
        if page >= total_pages:
            break
        page += 1
        time.sleep(REQUEST_DELAY)

    return pd.DataFrame(records) if records else pd.DataFrame(
        columns=["country_iso3", "year", "raw_value"]
    )


# ── Validation par indicateur ─────────────────────────────
def validate_indicator(df: pd.DataFrame, wb_code: str, meta: dict) -> pd.DataFrame:
    """
    Valide les valeurs selon les bornes définies dans WB_PTRA_MAP.
    Log les anomalies, supprime les valeurs manifestement erronées.
    """
    if df.empty:
        return df

    min_v = meta.get("min_valid", 0.0)
    max_v = meta.get("max_valid", float("inf"))

    mask_invalid = (df["raw_value"] < min_v) | (df["raw_value"] > max_v)
    n_invalid = mask_invalid.sum()

    if n_invalid > 0:
        examples = df[mask_invalid].head(3)
        for _, row in examples.iterrows():
            log.warning("  [%s] Valeur hors bornes [%.1f, %.1f] : %s %d → %.4f",
                        wb_code, min_v, max_v,
                        row["country_iso3"], row["year"], row["raw_value"])
        if n_invalid > 3:
            log.warning("  [%s] ... et %d autres valeurs hors bornes", wb_code, n_invalid - 3)
        df = df[~mask_invalid].copy()

    return df


# ── Ajout des zéros structurels (pays enclavés) ───────────
def add_structural_zeros(
    df: pd.DataFrame,
    wb_code: str,
    meta: dict,
    conn,
    year_min: int,
    year_max: int,
) -> pd.DataFrame:
    """
    Pour IS.SHP.GOOD.TU et IS.SHP.GCNW.XQ :
    ajoute les valeurs 0 réelles pour les pays enclavés
    sans accord portuaire actif.
    """
    if not meta.get("zero_for_landlocked", False):
        return df

    # Vérifier si fetcher_unctad.py a déjà inséré les zéros LSCI
    if wb_code == "IS.SHP.GCNW.XQ" and meta.get("prefer_unctad", False):
        try:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT COUNT(*) FROM ma.indicator_values
                    WHERE indicator_code = 'PTRA_PORT_CONNECT'
                      AND layer_id = %s
                      AND value_status = 'OBSERVED'
                """, (LAYER_RAW,))
                n_existing = cur.fetchone()[0]
            if n_existing > 0:
                log.info("  [%s] Zéros LSCI déjà insérés par fetcher_unctad.py — skip", wb_code)
                return df
        except Exception:
            pass

    # Charger les accords portuaires
    try:
        df_accords = pd.read_sql("""
            SELECT DISTINCT landlocked_iso3, valid_from, valid_to
            FROM rf.port_agreements
        """, conn)
        has_agreements = True
    except Exception:
        df_accords   = pd.DataFrame()
        has_agreements = False

    existing_keys = set(zip(df["country_iso3"], df["year"]))
    rows = []

    for iso3 in LANDLOCKED_AFRICA:
        for year in range(year_min, year_max + 1):
            # Vérifier accord actif
            if has_agreements and not df_accords.empty:
                mask = (
                    (df_accords["landlocked_iso3"] == iso3) &
                    (df_accords["valid_from"] <= year) &
                    ((df_accords["valid_to"].isna()) | (df_accords["valid_to"] >= year))
                )
                if mask.any():
                    continue   # accord actif → imputer gère le proxy

            if (iso3, year) in existing_keys:
                continue

            rows.append({
                "country_iso3":   iso3,
                "year":           year,
                "raw_value":      0.0,
                "is_zero_ll":     True,
                "zero_confidence": meta.get("zero_confidence", 0.95),
            })

    if rows:
        df_zeros = pd.DataFrame(rows)
        n = len(df_zeros)
        log.info("  [%s] %d zéros réels pays enclavés ajoutés", wb_code, n)
        df = pd.concat([df, df_zeros], ignore_index=True)

    return df


# ── Export CSV ────────────────────────────────────────────
def export_csv(
    df: pd.DataFrame,
    wb_code: str,
    meta: dict,
    year_min: int,
    year_max: int,
) -> Path:
    """
    Exporte vers data/raw/ptra/{osa_code}_{year_min}_{year_max}.csv
    Une ligne par (country_iso3, year) avec raw_value avant scaling.
    """
    CSV_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    osa_code = meta["osa_code"]
    path = CSV_OUTPUT_DIR / f"{osa_code.lower()}_{year_min}_{year_max}.csv"

    df_export = df[["country_iso3", "year", "raw_value"]].copy()
    df_export.insert(0, "indicator_code", osa_code)
    df_export.insert(0, "wb_code", wb_code)

    # Ajouter flag zéro enclavé si présent
    if "is_zero_ll" in df.columns:
        df_export["is_zero_landlocked"] = df["is_zero_ll"].fillna(False)

    df_export.sort_values(["country_iso3", "year"]).to_csv(path, index=False)
    log.info("  [%s] CSV → %s (%d lignes)", wb_code, path, len(df_export))
    return path


# ── Récupération method_version_id ────────────────────────
def get_method_version_id(conn, osa_code: str) -> int:
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT id FROM rf.method_versions
                WHERE indicator_code = %s
                ORDER BY created_at DESC LIMIT 1
            """, (osa_code,))
            row = cur.fetchone()
            return int(row[0]) if row else 1
    except Exception:
        return 1


# ── Insertion batch ───────────────────────────────────────
def insert_indicator(
    conn,
    df: pd.DataFrame,
    wb_code: str,
    meta: dict,
    dry_run: bool = False,
) -> int:
    """Insère les valeurs d'un indicateur en ma.indicator_values."""
    if df.empty:
        log.info("  [%s] Aucune valeur à insérer", wb_code)
        return 0

    osa_code   = meta["osa_code"]
    multiplier = meta.get("multiplier", 1.0)

    if dry_run:
        log.info("  [DRY-RUN] [%s → %s] %d valeurs préparées",
                 wb_code, osa_code, len(df))
        if not df.empty and "raw_value" in df.columns:
            valid = df[df["raw_value"] > 0]["raw_value"]
            if not valid.empty:
                log.info("    Statistiques : min=%.4f, max=%.4f, moy=%.4f",
                         valid.min(), valid.max(), valid.mean())
        return len(df)

    # Colonnes disponibles
    with conn.cursor() as cur:
        cur.execute("""
            SELECT column_name FROM information_schema.columns
            WHERE table_schema = 'ma' AND table_name = 'indicator_values'
        """)
        db_cols = {r[0] for r in cur.fetchall()}

    has_confidence = "confidence_score" in db_cols
    has_status     = "value_status"     in db_cols
    mvid           = get_method_version_id(conn, osa_code)

    batch_data = []
    for _, row in df.iterrows():
        iso3      = row["country_iso3"]
        year      = int(row["year"])
        raw_val   = float(row["raw_value"])
        scaled    = round(raw_val * multiplier, 6)

        # Confidence et status
        if row.get("is_zero_ll", False):
            confidence   = float(row.get("zero_confidence", 0.95))
            value_status = "OBSERVED"
            quality_flag = "OK"
        else:
            confidence   = 1.00
            value_status = "OBSERVED"
            quality_flag = "OK"

        if has_confidence and has_status:
            batch_data.append((
                osa_code, iso3, year, LAYER_RAW,
                scaled, None, mvid, quality_flag, confidence, value_status
            ))
        elif has_confidence:
            batch_data.append((
                osa_code, iso3, year, LAYER_RAW,
                scaled, None, mvid, quality_flag, confidence
            ))
        else:
            batch_data.append((
                osa_code, iso3, year, LAYER_RAW,
                scaled, None, mvid, quality_flag
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
                (osa_code, LAYER_RAW)
            )
            before = cur.fetchone()[0]

        with conn.cursor() as cur:
            execute_batch(cur, sql, batch_data, page_size=BATCH_SIZE)
        conn.commit()

        with conn.cursor() as cur:
            cur.execute(
                "SELECT COUNT(*) FROM ma.indicator_values "
                "WHERE indicator_code = %s AND layer_id = %s",
                (osa_code, LAYER_RAW)
            )
            after = cur.fetchone()[0]

        inserted = after - before
        log.info("  [%s → %s] %d insérés (préparés=%d)",
                 wb_code, osa_code, inserted, len(batch_data))
        return inserted

    except Exception as e:
        log.error("  [%s] Erreur insertion : %s", wb_code, e)
        conn.rollback()
        return 0


# ── Rapport final ─────────────────────────────────────────
def print_report(
    results: dict,
    dry_run: bool,
    output_mode: str = "both",
    failed: list = None,
) -> None:
    print("\n" + "=" * 65)
    print("RAPPORT FETCHER WB PTRA — Sprint 6")
    print("=" * 65)

    failed = failed or []
    n_ok   = sum(1 for n in results.values() if n > 0)
    n_skip = sum(1 for n in results.values() if n == 0 and
                 list(results.keys())[list(results.values()).index(n)]
                 not in failed)

    print(f"\nMode sortie      : {output_mode.upper()}")
    print(f"Indicateurs OK   : {n_ok} / {len(WB_PTRA_MAP)}")
    if failed:
        print(f"Indicateurs KO   : {len(failed)} (source réseau indisponible)")

    total = sum(v for v in results.values() if v > 0)
    if output_mode in ("db", "both") and not dry_run:
        print(f"Total DB insérés : {total:>6}")
    if output_mode in ("csv", "both") and not dry_run:
        print(f"CSV écrits dans  : {CSV_OUTPUT_DIR}/")

    print(f"\n{'Code WB':<25} {'Code OSA':<25} {'Lignes':>7}  {'Statut'}")
    print("-" * 68)
    for wb_code, n in results.items():
        osa    = WB_PTRA_MAP.get(wb_code, {}).get("osa_code", "?")
        if wb_code in failed:
            status = "KO — source indisponible"
        elif dry_run:
            status = f"[DRY-RUN] {n} prêtes"
        elif n > 0:
            status = "OK"
        else:
            status = "SKIP"
        print(f"  {wb_code:<23} {osa:<25} {n:>7}  {status}")

    if failed:
        print(f"\n⚠  Indicateurs en échec réseau : {', '.join(failed)}")
        print("   Relancer avec --indicator <CODE> une fois la connexion rétablie.")

    print("\nVérification recommandée :")
    print("  SELECT indicator_code, COUNT(*), MIN(year), MAX(year),")
    print("         ROUND(AVG(confidence_score)::numeric, 3) AS conf")
    print("  FROM ma.indicator_values")
    print("  WHERE indicator_code LIKE 'PTRA_%' AND layer_id = 1")
    print("  GROUP BY indicator_code ORDER BY indicator_code;")
    print("=" * 65)


# ── Orchestrateur ─────────────────────────────────────────
def run(
    indicator_filter: Optional[str] = None,
    dry_run: bool = False,
    year_min: int = YEAR_MIN,
    year_max: int = YEAR_MAX,
    skip_lsci: bool = False,
    output_mode: Literal["csv", "db", "both"] = "both",
) -> int:
    """
    Retourne le nombre total de lignes traitées (CSV ou DB selon mode).
    Exit code 1 si TOUS les indicateurs sont en échec réseau.
    """
    log.info("=" * 65)
    log.info("OSA Fetcher WB PTRA — %d indicateurs · %d–%d · Output : %s",
             len(WB_PTRA_MAP), year_min, year_max, output_mode.upper())
    if dry_run:
        log.info("MODE DRY-RUN — aucune écriture (ni CSV ni DB)")

    conn = get_pg_conn()
    results: dict[str, int] = {}
    failed:  list[str]      = []

    try:
        for wb_code, meta in WB_PTRA_MAP.items():
            if indicator_filter and wb_code != indicator_filter:
                continue
            if skip_lsci and wb_code == "IS.SHP.GCNW.XQ":
                log.info("  [IS.SHP.GCNW.XQ] Skip — géré par fetcher_unctad.py")
                results[wb_code] = 0
                continue

            osa_code = meta["osa_code"]
            log.info("─" * 50)
            log.info("Traitement : %s → %s", wb_code, osa_code)

            if meta.get("prefer_unctad") and not skip_lsci:
                log.info("  Note : fetcher_unctad.py recommandé. "
                         "Ajouter --skip-lsci pour éviter ce fallback WB.")

            # 1. Téléchargement
            df = fetch_wb_indicator(wb_code, year_min, year_max)

            if df.empty:
                log.warning("  [%s] Aucune donnée — indicateur ignoré", wb_code)
                results[wb_code] = 0
                failed.append(wb_code)
                continue

            log.info("  Téléchargé : %d lignes / %d pays",
                     len(df), df["country_iso3"].nunique())

            # 2. Validation
            df = validate_indicator(df, wb_code, meta)

            # 3. Zéros structurels (pays enclavés)
            df = add_structural_zeros(df, wb_code, meta, conn, year_min, year_max)

            # 4a. Export CSV
            if not dry_run and output_mode in ("csv", "both"):
                export_csv(df, wb_code, meta, year_min, year_max)

            # 4b. Insertion DB
            if not dry_run and output_mode in ("db", "both"):
                n = insert_indicator(conn, df, wb_code, meta, dry_run=False)
            elif dry_run:
                n = insert_indicator(conn, df, wb_code, meta, dry_run=True)
            else:
                n = len(df)   # mode csv uniquement — compter les lignes exportées

            results[wb_code] = n
            time.sleep(REQUEST_DELAY)

    finally:
        conn.close()

    print_report(results, dry_run=dry_run, output_mode=output_mode, failed=failed)

    # Exit code 1 seulement si TOUS les indicateurs demandés ont échoué
    n_attempted = len([k for k in results if not (skip_lsci and k == "IS.SHP.GCNW.XQ")])
    all_failed  = len(failed) == n_attempted and n_attempted > 0
    return -1 if all_failed else sum(results.values())


# ── CLI ───────────────────────────────────────────────────
def main():
    codes_list = list(WB_PTRA_MAP.keys())
    parser = argparse.ArgumentParser(
        description="OSA — Fetcher WB dédié pilier PTRA (8 indicateurs)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=f"""
Indicateurs couverts : {codes_list}

Modes de sortie :
  --output csv   → data/raw/ptra/{{osa_code}}_{{year_min}}_{{year_max}}.csv
  --output db    → ma.indicator_values layer_id=1
  --output both  → CSV + DB (défaut)
  --dry-run      → rapport seul, aucune écriture

Gestion erreurs réseau :
  Un indicateur indisponible est loggé et ignoré — les autres
  continuent. Rapport final distingue OK / KO / SKIP.
  Relancer avec --indicator <CODE> pour réessayer un indicateur.

Ordre recommandé :
  1. python fetcher_unctad.py --output both
  2. python fetcher_lpi.py --output both
  3. python fetcher_wb_ptra.py --output both --skip-lsci
        """
    )
    parser.add_argument("--dry-run",    action="store_true",
                        help="Rapport sans écriture (ni CSV ni DB)")
    parser.add_argument("--output",     choices=["csv", "db", "both"], default="both",
                        help="Mode de sortie (défaut: both)")
    parser.add_argument("--indicator",  type=str, default=None,
                        choices=codes_list,
                        help="Traiter uniquement cet indicateur WB")
    parser.add_argument("--year-min",   type=int, default=YEAR_MIN)
    parser.add_argument("--year-max",   type=int, default=YEAR_MAX)
    parser.add_argument("--skip-lsci",  action="store_true",
                        help="Ignorer IS.SHP.GCNW.XQ (géré par fetcher_unctad.py)")

    args = parser.parse_args()
    result = run(
        indicator_filter=args.indicator,
        dry_run=args.dry_run,
        year_min=args.year_min,
        year_max=args.year_max,
        skip_lsci=args.skip_lsci,
        output_mode=args.output,
    )
    sys.exit(0 if result >= 0 else 1)


if __name__ == "__main__":
    main()
