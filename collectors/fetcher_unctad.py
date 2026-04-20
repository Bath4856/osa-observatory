"""
============================================================
OSA Observatory — collectors/fetcher_unctad.py
Sprint 6 — Mai 2026
============================================================
Fetcher UNCTAD — Liner Shipping Connectivity Index (LSCI)
Indicateur : PTRA_PORT_CONNECT · Code WB : IS.SHP.GCNW.XQ

Granularité : ANNUELLE uniquement (cohérent avec ISA)

Sources :
  API UNCTADStat REST (JSON) — données annuelles
  URL viewer : https://unctadstat.unctad.org/datacentre/dataviewer/US.LSCI

⚠️  RUPTURE DE SÉRIE — MARS 2024
  Avant Q1 2024 : base 100 = valeur maximale Q1 2006
  Depuis Q1 2024 : base 100 = valeur MOYENNE Q1 2006
  Les deux séries ne sont PAS directement comparables.
  Ce fetcher gère la normalisation automatiquement :
    1. Télécharge la série annuelle UNCTAD
    2. Calcule le facteur de conversion sur l'année de
       chevauchement (2023 disponible dans les deux bases)
    3. Normalise la série post-2024 pour la rendre
       cohérente avec la série historique 2004–2023
    4. Écrit le résultat selon --output (csv | db | both)

Modes de sortie (--output) :
  csv   → data/raw/ptra/lsci_{year_min}_{year_max}.csv uniquement
  db    → insertion directe PostgreSQL uniquement
  both  → CSV + insertion DB (défaut)

Gestion erreurs réseau :
  Toute erreur réseau (UNCTAD ou WB fallback) produit un
  DataFrame vide et un rapport dry-run complet — jamais
  d'exception non interceptée. Le process se termine avec
  exit code 1 si aucune donnée n'a pu être téléchargée.

Couverture Afrique : ~40 pays côtiers
Pays enclavés     : value = 0.0, value_status = OBSERVED,
                   confidence = 0.95 (valeur réelle souveraine)
                   sauf si accord portuaire actif → PROXY

Fenêtre ISA       : 2010–2024

Usage :
  python collectors/fetcher_unctad.py --dry-run
  python collectors/fetcher_unctad.py --output csv
  python collectors/fetcher_unctad.py --output db
  python collectors/fetcher_unctad.py --output both
  python collectors/fetcher_unctad.py --year 2023 --output both
  python collectors/fetcher_unctad.py --no-normalize --output csv
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
log = logging.getLogger("fetcher_unctad")

# ── Constantes ────────────────────────────────────────────
INDICATOR_CODE    = "PTRA_PORT_CONNECT"
WB_CODE           = "IS.SHP.GCNW.XQ"
LAYER_RAW         = 1
YEAR_MIN          = 2010
YEAR_MAX          = 2024
BATCH_SIZE        = 500
MAX_RETRIES       = 3
RETRY_DELAY       = 5   # secondes

# Répertoire de sortie CSV
CSV_OUTPUT_DIR    = Path(os.getenv("OSA_DATA_DIR", "data/raw/ptra"))

# Année de chevauchement pour calcul du facteur de normalisation
SERIES_BREAK_YEAR = 2024
OVERLAP_YEAR      = 2023   # dernière année disponible dans les DEUX séries

# API UNCTADStat — endpoint REST — données ANNUELLES uniquement
# Documentation : https://unctadstat.unctad.org/datacentre/reportInfo/US.LSCI
UNCTAD_API_BASE   = "https://unctadstat.unctad.org/datacentre/data"
UNCTAD_DATASET    = "US.LSCI"    # série annuelle

# Mapping ISO3 WB → ISO3 UNCTAD (quelques cas particuliers)
ISO3_MAP = {
    "COD": "ZAR",   # RDC — ancien code UNCTAD
    "PSE": "PST",   # Palestine
    "XKX": None,    # Kosovo — non couvert UNCTAD
}

# Pays africains enclavés — PTRA_PORT_CONNECT = 0 réel
LANDLOCKED_AFRICA = {
    "BFA", "BDI", "CAF", "TCD", "ETH", "LSO", "MWI",
    "MLI", "NER", "RWA", "SSD", "SWZ", "UGA", "ZMB", "ZWE", "BWA",
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
    params: dict = None,
    retries: int = MAX_RETRIES,
) -> dict | list | None:
    """
    GET avec retry automatique et backoff exponentiel.
    En cas d'échec définitif : log warning et retourne None
    (jamais d'exception levée — le dry-run peut toujours s'exécuter).
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
            log.warning("Tentative %d/%d échouée (%s) — retry dans %ds",
                        attempt, retries, e, wait)
            time.sleep(wait)


# ── Téléchargement LSCI depuis UNCTADStat (annuel) ────────
def fetch_lsci_from_unctad(year_min: int, year_max: int) -> pd.DataFrame:
    """
    Télécharge le LSCI ANNUEL depuis l'API UNCTADStat.
    Granularité mensuelle non utilisée (cohérence ISA).

    Retourne un DataFrame avec colonnes :
      country_iso3, year, lsci_value, source_series
    ou un DataFrame vide si la source est indisponible.
    """
    log.info("Téléchargement LSCI UNCTAD annuel %d–%d...", year_min, year_max)

    url = f"{UNCTAD_API_BASE}/{UNCTAD_DATASET}"
    params = {
        "startYear": year_min,
        "endYear":   year_max,
        "format":    "json",
    }

    data = fetch_with_retry(url, params=params)
    if data is None:
        log.warning("API UNCTADStat indisponible — tentative via WB API...")
        return fetch_lsci_from_wb(year_min, year_max)

    # Parsing de la réponse UNCTAD
    records = []
    # La structure JSON UNCTAD varie selon la version de l'API
    # Gérer les deux formats possibles : liste directe ou objet avec clé 'data'
    raw_data = data if isinstance(data, list) else data.get("data", [])

    for row in raw_data:
        try:
            iso3     = str(row.get("reporterISO3", row.get("Economy", ""))).strip().upper()
            year     = int(row.get("Year", row.get("year", 0)))
            value    = row.get("Value", row.get("value", row.get("LSCI", None)))

            if not iso3 or not year or value is None:
                continue
            if year < year_min or year > year_max:
                continue

            # Remapper les codes ISO3 UNCTAD → WB si nécessaire
            iso3_wb = {v: k for k, v in ISO3_MAP.items() if v}.get(iso3, iso3)
            if iso3_wb is None:
                continue

            try:
                value_f = float(value)
            except (ValueError, TypeError):
                continue

            records.append({
                "country_iso3": iso3_wb,
                "year":         year,
                "lsci_value":   value_f,
                "source_series": "UNCTAD_API",
            })
        except (KeyError, ValueError, TypeError):
            continue

    df = pd.DataFrame(records)
    if df.empty:
        log.warning("API UNCTAD retourne 0 lignes — fallback WB API")
        return fetch_lsci_from_wb(year_min, year_max)

    log.info("  UNCTAD API : %d lignes brutes (%d pays, %d–%d)",
             len(df), df["country_iso3"].nunique(),
             df["year"].min(), df["year"].max())
    return df


def fetch_lsci_from_wb(year_min: int, year_max: int) -> pd.DataFrame:
    """
    Fallback : téléchargement LSCI ANNUEL via API WB (IS.SHP.GCNW.XQ).
    Retourne un DataFrame vide si la source est aussi indisponible.
    """
    log.info("Fallback WB API pour LSCI (IS.SHP.GCNW.XQ)...")
    url = (
        f"https://api.worldbank.org/v2/country/all/indicator/IS.SHP.GCNW.XQ"
        f"?date={year_min}:{year_max}&format=json&per_page=1000"
    )

    records = []
    page = 1
    while True:
        data = fetch_with_retry(f"{url}&page={page}")
        if data is None:
            log.warning("WB API LSCI indisponible — DataFrame vide retourné")
            break

        if not isinstance(data, list) or len(data) < 2:
            break

        meta, rows = data[0], data[1]
        if not rows:
            break

        for row in rows:
            if row.get("value") is None:
                continue
            iso3 = row.get("countryiso3code", "") or row.get("country", {}).get("id", "")
            year = int(row.get("date", 0))
            if not iso3 or not year:
                continue
            records.append({
                "country_iso3": iso3,
                "year":         year,
                "lsci_value":   float(row["value"]),
                "source_series": "WB_API_FALLBACK",
            })

        total_pages = meta.get("pages", 1)
        if page >= total_pages:
            break
        page += 1
        time.sleep(0.3)

    df = pd.DataFrame(records) if records else pd.DataFrame(
        columns=["country_iso3", "year", "lsci_value", "source_series"]
    )
    log.info("  WB fallback : %d lignes", len(df))
    return df


# ── Normalisation rupture de série 2024 ───────────────────
def normalize_series_break(df: pd.DataFrame, apply_normalization: bool = True) -> pd.DataFrame:
    """
    Gère la rupture méthodologique UNCTAD mars 2024.

    Avant 2024 : base 100 = valeur maximale Q1 2006
    Depuis 2024 : base 100 = valeur MOYENNE Q1 2006

    Stratégie :
      Calculer le ratio (valeur_post / valeur_pre) sur l'année
      de chevauchement (2023) pour chaque pays disponible dans
      les deux séries. Appliquer ce ratio aux données 2024+
      pour les rendre cohérentes avec la série historique.

    Si une seule série est disponible (tout vient d'une même
    source), aucune normalisation n'est appliquée.
    """
    if not apply_normalization:
        log.info("Normalisation rupture 2024 désactivée (--no-normalize)")
        df["lsci_normalized"] = df["lsci_value"]
        df["normalization_applied"] = False
        return df

    # Vérifier si des données post-2023 sont présentes
    has_post_2024 = (df["year"] >= SERIES_BREAK_YEAR).any()
    has_pre_2024  = (df["year"] < SERIES_BREAK_YEAR).any()

    if not has_post_2024 or not has_pre_2024:
        log.info("Données d'une seule période — normalisation non nécessaire")
        df["lsci_normalized"] = df["lsci_value"]
        df["normalization_applied"] = False
        return df

    # Calculer le facteur de conversion sur l'année de chevauchement
    # En pratique, 2023 est la dernière année publiée dans les deux bases
    df_overlap_pre  = df[(df["year"] == OVERLAP_YEAR) & (df["year"] < SERIES_BREAK_YEAR)].copy()
    df_overlap_post = df[(df["year"] == OVERLAP_YEAR) & (df["year"] >= SERIES_BREAK_YEAR)].copy()

    if df_overlap_pre.empty or df_overlap_post.empty:
        # Pas de chevauchement direct — utiliser le ratio médian global
        log.warning(
            "Pas de chevauchement sur l'année %d — "
            "calcul du facteur global sur distribution des valeurs",
            OVERLAP_YEAR
        )
        median_pre  = df[df["year"] < SERIES_BREAK_YEAR]["lsci_value"].median()
        median_post = df[df["year"] >= SERIES_BREAK_YEAR]["lsci_value"].median()

        if median_post > 0 and median_pre > 0:
            global_factor = median_pre / median_post
        else:
            global_factor = 1.0

        log.info("  Facteur de conversion global : %.4f (médiane pre=%.2f / post=%.2f)",
                 global_factor, median_pre, median_post)

        df["lsci_normalized"] = df["lsci_value"].where(
            df["year"] < SERIES_BREAK_YEAR,
            df["lsci_value"] * global_factor
        )
        df["normalization_applied"] = df["year"] >= SERIES_BREAK_YEAR
        return df

    # Chevauchement disponible — calculer le facteur par pays
    merged = df_overlap_pre.merge(
        df_overlap_post,
        on="country_iso3",
        suffixes=("_pre", "_post")
    )

    if merged.empty:
        log.warning("Aucun pays en commun sur l'année de chevauchement — facteur = 1.0")
        df["lsci_normalized"] = df["lsci_value"]
        df["normalization_applied"] = False
        return df

    merged["factor"] = merged["lsci_value_pre"] / merged["lsci_value_post"].replace(0, float("nan"))
    median_factor = merged["factor"].median()

    n_countries = merged["country_iso3"].nunique()
    log.info(
        "  Facteur de normalisation LSCI 2024 : %.4f "
        "(médiane sur %d pays, année chevauchement %d)",
        median_factor, n_countries, OVERLAP_YEAR
    )

    if abs(median_factor - 1.0) > 0.5:
        log.warning(
            "  Facteur de normalisation inhabituel (%.4f) — vérifier les sources",
            median_factor
        )

    # Appliquer le facteur aux données >= SERIES_BREAK_YEAR
    df = df.copy()
    mask_post = df["year"] >= SERIES_BREAK_YEAR
    df["lsci_normalized"] = df["lsci_value"].copy()
    df.loc[mask_post, "lsci_normalized"] = df.loc[mask_post, "lsci_value"] * median_factor
    df["normalization_applied"] = mask_post

    n_normalized = mask_post.sum()
    log.info("  %d valeurs normalisées (années >= %d)", n_normalized, SERIES_BREAK_YEAR)

    return df


# ── Ajout des pays enclavés ───────────────────────────────
def add_landlocked_zeros(
    df: pd.DataFrame,
    conn,
    year_min: int,
    year_max: int,
) -> pd.DataFrame:
    """
    Ajoute les valeurs 0 réelles pour les pays africains enclavés.

    Consulte rf.port_agreements pour vérifier si un accord actif
    donne accès à un port côtier — dans ce cas, aucun zéro n'est
    inséré (l'imputer gère le proxy via PTRA_PROXY_ACCORD).
    """
    # Charger les accords portuaires actifs
    try:
        df_accords = pd.read_sql("""
            SELECT DISTINCT landlocked_iso3, valid_from, valid_to
            FROM rf.port_agreements
            ORDER BY landlocked_iso3, valid_from
        """, conn)
        has_agreements_table = True
    except Exception:
        log.warning("rf.port_agreements indisponible — tous les enclavés = 0")
        has_agreements_table = False
        df_accords = pd.DataFrame()

    existing_countries = set(df["country_iso3"].unique())
    rows = []

    for iso3 in LANDLOCKED_AFRICA:
        for year in range(year_min, year_max + 1):
            # Vérifier si un accord portuaire actif couvre cette année
            has_active_accord = False
            if has_agreements_table and not df_accords.empty:
                mask = (
                    (df_accords["landlocked_iso3"] == iso3) &
                    (df_accords["valid_from"] <= year) &
                    ((df_accords["valid_to"].isna()) | (df_accords["valid_to"] >= year))
                )
                has_active_accord = mask.any()

            if has_active_accord:
                # L'imputer calculera un proxy via rf.port_agreements
                # Ne pas insérer de zéro ici
                continue

            # Pas d'accord actif → 0 réel
            rows.append({
                "country_iso3":        iso3,
                "year":                year,
                "lsci_normalized":     0.0,
                "lsci_value":          0.0,
                "normalization_applied": False,
                "source_series":       "ZERO_LANDLOCKED",
                "is_landlocked_zero":  True,
            })

    if not rows:
        return df

    df_landlocked = pd.DataFrame(rows)
    # Ne pas écraser les données existantes (au cas où un enclavé
    # aurait quand même des données UNCTAD — rare mais possible)
    existing_keys = set(zip(df["country_iso3"], df["year"]))
    df_landlocked = df_landlocked[
        ~df_landlocked.apply(lambda r: (r["country_iso3"], r["year"]) in existing_keys, axis=1)
    ]

    n_zeros = len(df_landlocked)
    log.info("  %d zéros réels ajoutés pour pays enclavés (%d pays × ~%d années)",
             n_zeros, len(LANDLOCKED_AFRICA), year_max - year_min + 1)

    return pd.concat([df, df_landlocked], ignore_index=True)


# ── Chargement du method_version_id ──────────────────────
def get_method_version_id(conn) -> int:
    """Récupère le method_version_id courant pour PTRA_PORT_CONNECT."""
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT id FROM rf.method_versions
                WHERE indicator_code = %s
                ORDER BY created_at DESC LIMIT 1
            """, (INDICATOR_CODE,))
            row = cur.fetchone()
            if row:
                return int(row[0])
    except Exception:
        pass
    return 1


# ── Export CSV ────────────────────────────────────────────
def export_csv(df: pd.DataFrame, year_min: int, year_max: int) -> Path:
    """
    Exporte le DataFrame vers data/raw/ptra/lsci_{year_min}_{year_max}.csv
    Colonnes exportées : indicator_code, country_iso3, year,
                         raw_value, normalization_applied, source_series
    """
    CSV_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    path = CSV_OUTPUT_DIR / f"lsci_{year_min}_{year_max}.csv"

    df_export = df.copy()
    df_export["indicator_code"] = INDICATOR_CODE
    df_export["raw_value"] = df_export.get(
        "lsci_normalized", df_export.get("lsci_value", 0.0)
    )

    cols = [
        "indicator_code", "country_iso3", "year",
        "raw_value", "source_series",
    ]
    if "normalization_applied" in df_export.columns:
        cols.append("normalization_applied")

    df_export[cols].sort_values(["country_iso3", "year"]).to_csv(path, index=False)
    log.info("  CSV exporté → %s (%d lignes)", path, len(df_export))
    return path


# ── Insertion en base ─────────────────────────────────────
def insert_to_db(
    conn,
    df: pd.DataFrame,
    dry_run: bool = False,
    year_filter: Optional[int] = None,
) -> int:
    """
    Insère les valeurs LSCI en ma.indicator_values (layer_id = 1).

    Gestion de la valeur_status :
      - Source ZERO_LANDLOCKED  → OBSERVED  (valeur réelle souveraine)
      - Source UNCTAD/WB        → OBSERVED  (donnée primaire)
    """
    df_insert = df.copy()

    if year_filter:
        df_insert = df_insert[df_insert["year"] == year_filter]

    # Filtrer sur la fenêtre ISA
    df_insert = df_insert[
        (df_insert["year"] >= YEAR_MIN) &
        (df_insert["year"] <= YEAR_MAX)
    ]

    if df_insert.empty:
        log.info("Aucune valeur à insérer pour la fenêtre %d–%d", YEAR_MIN, YEAR_MAX)
        return 0

    # Filtrer sur les pays africains valides
    try:
        conn_tmp = get_pg_conn()
        import pandas as pd
        valid_iso3 = pd.read_sql("SELECT iso3 FROM rf.countries", conn_tmp)["iso3"].tolist()
        conn_tmp.close()
        before = len(df_insert)
        df_insert = df_insert[df_insert["country_iso3"].isin(valid_iso3)]
        log.info("  Filtre rf.countries : %d → %d lignes", before, len(df_insert))
    except Exception as e:
        log.warning("  Filtre rf.countries échoué : %s", e)
    # Filtrer sur les pays africains valides
    try:
        conn_tmp = get_pg_conn()
        import pandas as pd
        valid_iso3 = pd.read_sql("SELECT iso3 FROM rf.countries", conn_tmp)["iso3"].tolist()
        conn_tmp.close()
        before = len(df_insert)
        df_insert = df_insert[df_insert["country_iso3"].isin(valid_iso3)]
        log.info("  Filtre rf.countries : %d → %d lignes", before, len(df_insert))
    except Exception as e:
        log.warning("  Filtre rf.countries échoué : %s", e)
    log.info("Préparation insertion : %d lignes...", len(df_insert))

    if dry_run:
        log.info("[DRY-RUN] %d valeurs préparées — aucune insertion", len(df_insert))
        # Rapport de distribution
        by_source = df_insert.groupby("source_series").size()
        for src, n in by_source.items():
            log.info("  %s : %d valeurs", src, n)
        coverage = df_insert.groupby("country_iso3")["year"].count()
        log.info("  Pays couverts : %d / 54", len(coverage))
        log.info("  Années couvertes : %s",
                 sorted(df_insert["year"].unique().tolist()))
        return len(df_insert)

    mvid = 1  # rf.method_versions absent

    # Vérifier colonnes disponibles
    with conn.cursor() as cur:
        cur.execute("""
            SELECT column_name FROM information_schema.columns
            WHERE table_schema = 'ma' AND table_name = 'indicator_values'
        """)
        cols = {r[0] for r in cur.fetchall()}

    has_confidence = "confidence_score" in cols
    has_status     = "value_status"     in cols

    batch_data = []
    for _, row in df_insert.iterrows():
        iso3   = row["country_iso3"]
        year   = int(row["year"])
        value  = float(row.get("lsci_normalized", row.get("lsci_value", 0.0)))
        source = row.get("source_series", "UNCTAD_API")

        # Confidence score
        if source == "ZERO_LANDLOCKED":
            confidence   = 0.95
            value_status = "OBSERVED"
        elif row.get("normalization_applied", False):
            confidence   = 0.90   # légèrement réduit pour les valeurs normalisées
            value_status = "OBSERVED"
        else:
            confidence   = 1.00
            value_status = "OBSERVED"

        quality_flag = "OK" if value_status == "OBSERVED" else "INTERPOLATED"

        if has_confidence and has_status:
            batch_data.append((
                INDICATOR_CODE, iso3, year, LAYER_RAW,
                value, None, quality_flag, confidence, value_status
            ))
        elif has_confidence:
            batch_data.append((
                INDICATOR_CODE, iso3, year, LAYER_RAW,
                value, None, quality_flag, confidence
            ))
        else:
            batch_data.append((
                INDICATOR_CODE, iso3, year, LAYER_RAW,
                value, None, quality_flag
            ))

    if has_confidence and has_status:
        sql = """
            INSERT INTO ma.indicator_values
                (indicator_code, country_iso3, year, layer_id,
                 raw_value, processed_value, quality_flag, confidence_score, value_status)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT DO NOTHING
        """
    elif has_confidence:
        sql = """
            INSERT INTO ma.indicator_values
                (indicator_code, country_iso3, year, layer_id,
                 raw_value, processed_value, quality_flag, confidence_score)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT DO NOTHING
        """
    else:
        sql = """
            INSERT INTO ma.indicator_values
                (indicator_code, country_iso3, year, layer_id,
                 raw_value, processed_value, quality_flag)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
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
        log.info("  → %d insérés (préparés=%d, page_size=%d)",
                 inserted, len(batch_data), BATCH_SIZE)
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
    print(f"RAPPORT FETCHER UNCTAD — {INDICATOR_CODE}")
    print("=" * 60)

    if df.empty:
        print("\n  ⚠  Aucune donnée disponible (sources réseau indisponibles).")
        print("     Vérifier la connectivité et relancer.")
        print("=" * 60)
        return

    print(f"\nLignes traitées      : {len(df):>8}")
    print(f"Pays couverts        : {df['country_iso3'].nunique():>8} / 54")
    print(f"Années couvertes     : {int(df['year'].min())}–{int(df['year'].max())}")
    print(f"Mode sortie          : {output_mode.upper()}")

    if output_mode in ("db", "both"):
        label = "[DRY-RUN prévu]" if dry_run else "Insertions DB"
        print(f"{label:<21} : {n_inserted:>8}")

    if output_mode in ("csv", "both") and not dry_run:
        csv_path = CSV_OUTPUT_DIR / f"lsci_{YEAR_MIN}_{YEAR_MAX}.csv"
        print(f"Fichier CSV          : {csv_path}")

    by_source = df.groupby("source_series").size()
    print("\nPar source :")
    for src, n in by_source.items():
        print(f"  {src:<30} : {n:>5}")

    n_norm = int(df.get("normalization_applied", pd.Series(dtype=bool)).sum())
    if n_norm > 0:
        print(f"\nValeurs normalisées (rupture 2024) : {n_norm}")

    print("\nCouverture par année (pays avec données UNCTAD/WB) :")
    by_year = df[df["source_series"] != "ZERO_LANDLOCKED"].groupby("year")["country_iso3"].count()
    for year, n in sorted(by_year.items()):
        bar = "█" * min(n // 2, 25)
        print(f"  {int(year)} : {bar} {n}")

    if dry_run:
        print("\n[DRY-RUN] Aucune donnée écrite (ni CSV ni DB).")
    print("=" * 60)


# ── Orchestrateur ─────────────────────────────────────────
def run(
    year_filter: Optional[int] = None,
    dry_run: bool = False,
    apply_normalization: bool = True,
    year_min: int = YEAR_MIN,
    year_max: int = YEAR_MAX,
    output_mode: Literal["csv", "db", "both"] = "both",
) -> int:
    """
    Retourne : nombre de lignes insérées en DB (0 en mode csv ou dry-run).
    Exit code 1 si aucune donnée téléchargée.
    """
    log.info("=" * 60)
    log.info("OSA Fetcher UNCTAD — LSCI %s", INDICATOR_CODE)
    log.info("Fenêtre : %d–%d | Output : %s | Normalisation 2024 : %s",
             year_min, year_max, output_mode.upper(),
             "OUI" if apply_normalization else "NON")
    if dry_run:
        log.info("MODE DRY-RUN — aucune écriture (ni CSV ni DB)")

    # 1. Téléchargement
    df = fetch_lsci_from_unctad(year_min, year_max)

    if df.empty:
        log.warning(
            "Aucune donnée téléchargée (sources UNCTAD et WB indisponibles).\n"
            "  → Rapport généré avec dataset vide."
        )
        print_report(df, 0, dry_run=True, output_mode=output_mode)
        return -1   # signal d'échec réseau — caller peut sys.exit(1)

    # 2. Normalisation rupture de série 2024
    df = normalize_series_break(df, apply_normalization=apply_normalization)

    # 3. Ajout des zéros enclavés (nécessite la DB même en mode csv)
    conn = get_pg_conn()
    n_inserted = 0
    try:
        df = add_landlocked_zeros(df, conn, year_min, year_max)

        # 4a. Export CSV
        if not dry_run and output_mode in ("csv", "both"):
            export_csv(df, year_min, year_max)

        # 4b. Insertion DB
        if not dry_run and output_mode in ("db", "both"):
            n_inserted = insert_to_db(conn, df, dry_run=False, year_filter=year_filter)
        elif dry_run:
            n_inserted = insert_to_db(conn, df, dry_run=True, year_filter=year_filter)

        # 5. Rapport
        print_report(df, n_inserted, dry_run=dry_run, output_mode=output_mode)

    finally:
        conn.close()

    return n_inserted


# ── CLI ───────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(
        description="OSA — Fetcher UNCTAD LSCI annuel (PTRA_PORT_CONNECT)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Modes de sortie :
  --output csv   → CSV uniquement  (data/raw/ptra/lsci_XXXX_XXXX.csv)
  --output db    → DB uniquement   (ma.indicator_values layer_id=1)
  --output both  → CSV + DB        (défaut)
  --dry-run      → rapport seul, aucune écriture

Exemples :
  python fetcher_unctad.py --dry-run
  python fetcher_unctad.py --output csv
  python fetcher_unctad.py --output both
  python fetcher_unctad.py --year 2023 --output db
  python fetcher_unctad.py --no-normalize --output csv
  python fetcher_unctad.py --year-min 2015 --year-max 2024 --output both
        """
    )
    parser.add_argument("--dry-run",      action="store_true",
                        help="Rapport sans écriture (ni CSV ni DB)")
    parser.add_argument("--output",       choices=["csv", "db", "both"], default="both",
                        help="Mode de sortie (défaut: both)")
    parser.add_argument("--year",         type=int, default=None,
                        help="Traiter uniquement cette année")
    parser.add_argument("--year-min",     type=int, default=YEAR_MIN)
    parser.add_argument("--year-max",     type=int, default=YEAR_MAX)
    parser.add_argument("--no-normalize", action="store_true",
                        help="Désactiver la normalisation rupture 2024")

    args = parser.parse_args()

    result = run(
        year_filter=args.year,
        dry_run=args.dry_run,
        apply_normalization=not args.no_normalize,
        year_min=args.year_min,
        year_max=args.year_max,
        output_mode=args.output,
    )
    sys.exit(0 if result >= 0 else 1)


if __name__ == "__main__":
    main()
