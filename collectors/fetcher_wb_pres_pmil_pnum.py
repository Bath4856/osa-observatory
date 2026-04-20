"""
============================================================
OSA Observatory — collectors/fetcher_wb_pres_pmil_pnum.py
Sprint 6 — Mai 2026
============================================================
Fetcher WB — 21 indicateurs PRES / PMIL / PNUM
via API World Bank (WDI)

Priorités Sprint 6 :
  PRES (10) — IEA/IRENA/EIA proxies + FAO AQUASTAT
  PMIL  (5) — dépenses militaires + stabilité WGI
  PNUM  (6) — connectivité internet + gouvernance WGI

Modes de sortie (--output) :
  csv   → data/raw/{pilier}/{osa_code}_{year_min}_{year_max}.csv
  db    → insertion directe PostgreSQL (ma.indicator_values)
  both  → CSV + DB (défaut)

Gestion erreurs réseau :
  Toute erreur API WB → log warning + indicateur ignoré.
  Les autres indicateurs continuent. Rapport final distingue
  OK / KO / SKIP. Exit code 1 si tous les indicateurs échouent.

Particularités :
  - PRES_OIL_RENTS / PRES_GAS_RENTS : zéros réels pour
    pays non-producteurs (has_structural_zeros = True)
  - PMIL_STABILITY_WGI / PNUM_GOV_EFFECTIVENESS : WGI sur
    [-2.5, +2.5] — normalisation documentée dans le scorer
  - Régimes : PRES entier → PHYSICAL
               PMIL WB quantitatifs → STANDARD
               PNUM WB quantitatifs → STANDARD
               Scores composites WGI → PHYSICAL (is_composite_score)

Non couverts ici (fetchers dédiés) :
  PMIL_ARMS_IMPORT/EXPORT → fetcher_sipri.py   (Sprint 7)
  PMIL_GTI_TERROR         → fetcher_gti.py     (Sprint 7)
  PMIL_GCI_CYBER          → fetcher_itu.py     (Sprint 6)
  PNUM_ITU_REG_ENV        → fetcher_itu.py     (Sprint 6)
  PNUM_GCI_DIGITAL        → fetcher_itu.py     (Sprint 6)
  PNUM_EGDI_*             → fetcher_egdi.py    (Sprint 6)
  PRES_IEA/IRENA/EIA      → fetchers dédiés    (Sprint 7)

Usage :
  python collectors/fetcher_wb_pres_pmil_pnum.py --dry-run
  python collectors/fetcher_wb_pres_pmil_pnum.py --pillar PRES
  python collectors/fetcher_wb_pres_pmil_pnum.py --pillar PMIL --output csv
  python collectors/fetcher_wb_pres_pmil_pnum.py --output both
  python collectors/fetcher_wb_pres_pmil_pnum.py --indicator EG.ELC.PROD.KH
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
log = logging.getLogger("fetcher_wb_pres_pmil_pnum")

# ── Constantes ────────────────────────────────────────────
LAYER_RAW     = 1
YEAR_MIN      = 2010
YEAR_MAX      = 2024
BATCH_SIZE    = 500
MAX_RETRIES   = 3
RETRY_DELAY   = 5
WB_API_BASE   = "https://api.worldbank.org/v2"
REQUEST_DELAY = 0.25

CSV_OUTPUT_BASE = Path(os.getenv("OSA_DATA_DIR", "data/raw"))

# Pays non-producteurs de pétrole africains — PRES_OIL_RENTS = 0 réel
OIL_PRODUCERS_AFRICA = {
    "DZA", "AGO", "CMR", "CAF", "TCD", "COD", "COG", "GAB",
    "GNQ", "KEN", "LBY", "MDG", "MRT", "MOZ", "NGA", "SDN",
    "SSD", "TUN", "UGA", "ZAF",
}

# Pays non-producteurs de gaz africains significatifs
GAS_PRODUCERS_AFRICA = {
    "DZA", "AGO", "EGY", "LBY", "MOZ", "NGA", "TZA",
    "TUN", "COG", "GNQ", "CMR", "MRT",
}

# ── Mapping complet — 21 indicateurs WB ──────────────────
WB_MAP = {

    # ══════════════════════════════════════════════════════
    # PRES — Régime PHYSICAL (pilier entier)
    # ══════════════════════════════════════════════════════

    "EG.USE.PCAP.KG.OE": {
        "osa_code":             "PRES_ENRG_USE_CAP",
        "pillar":               "PRES",
        "name_fr":              "Consommation énergie par hab. (kg éq. pétrole)",
        "unit":                 "KG_OE_CAP",
        "direction":            "+",
        "multiplier":           1.0,
        "imputation_regime":    "PHYSICAL",
        "has_structural_zeros": False,
        "is_composite_score":   False,
        "min_valid":            0.0,
        "max_valid":            20000.0,
    },

    "EG.ELC.PROD.KH": {
        "osa_code":             "PRES_ENRG_PROD_IEA",
        "pillar":               "PRES",
        "name_fr":              "Production électricité (kWh total)",
        "unit":                 "KWH",
        "direction":            "+",
        "multiplier":           1.0,
        "imputation_regime":    "PHYSICAL",
        "has_structural_zeros": False,
        "is_composite_score":   False,
        "min_valid":            0.0,
        "max_valid":            1e14,
    },

    "EG.ELC.RNEW.ZS": {
        "osa_code":             "PRES_RENEW_CAP_IRENA",
        "pillar":               "PRES",
        "name_fr":              "Capacité électrique renouvelable (% total)",
        "unit":                 "PCT_ELEC",
        "direction":            "+",
        "multiplier":           1.0,
        "imputation_regime":    "PHYSICAL",
        "has_structural_zeros": False,
        "is_composite_score":   False,
        "min_valid":            0.0,
        "max_valid":            100.0,
    },

    "EG.FEC.RNEW.ZS": {
        "osa_code":             "PRES_RENEW_SHARE_FEC",
        "pillar":               "PRES",
        "name_fr":              "Renouvelables % consommation finale",
        "unit":                 "PCT_FEC",
        "direction":            "+",
        "multiplier":           1.0,
        "imputation_regime":    "PHYSICAL",
        "has_structural_zeros": False,
        "is_composite_score":   False,
        "min_valid":            0.0,
        "max_valid":            100.0,
    },

    "NY.GDP.TOTL.RT.ZS": {
        "osa_code":             "PRES_FOSSIL_RENTS_EIA",
        "pillar":               "PRES",
        "name_fr":              "Rentes ressources naturelles totales (% PIB)",
        "unit":                 "PCT_GDP",
        "direction":            "+",
        "multiplier":           1.0,
        "imputation_regime":    "PHYSICAL",
        "has_structural_zeros": False,
        "is_composite_score":   False,
        "min_valid":            0.0,
        "max_valid":            100.0,
    },

    "NY.GDP.PETR.RT.ZS": {
        "osa_code":             "PRES_OIL_RENTS",
        "pillar":               "PRES",
        "name_fr":              "Rentes pétrolières (% PIB)",
        "unit":                 "PCT_GDP",
        "direction":            "+",
        "multiplier":           1.0,
        "imputation_regime":    "PHYSICAL",
        "has_structural_zeros": True,
        "zero_producers":       OIL_PRODUCERS_AFRICA,
        "zero_confidence":      0.95,
        "is_composite_score":   False,
        "min_valid":            0.0,
        "max_valid":            80.0,
    },

    "NY.GDP.NGAS.RT.ZS": {
        "osa_code":             "PRES_GAS_RENTS",
        "pillar":               "PRES",
        "name_fr":              "Rentes gaz naturel (% PIB)",
        "unit":                 "PCT_GDP",
        "direction":            "+",
        "multiplier":           1.0,
        "imputation_regime":    "PHYSICAL",
        "has_structural_zeros": True,
        "zero_producers":       GAS_PRODUCERS_AFRICA,
        "zero_confidence":      0.95,
        "is_composite_score":   False,
        "min_valid":            0.0,
        "max_valid":            50.0,
    },

    "ER.H2O.INTR.PC": {
        "osa_code":             "PRES_WATER_FRESH",
        "pillar":               "PRES",
        "name_fr":              "Eau douce renouvelable par hab. (m³)",
        "unit":                 "M3_CAP",
        "direction":            "+",
        "multiplier":           1.0,
        "imputation_regime":    "PHYSICAL",
        "has_structural_zeros": False,
        "is_composite_score":   False,
        "min_valid":            0.0,
        "max_valid":            2e6,    # m³/hab — max Congo ~500k
    },

    "ER.H2O.FWTL.ZS": {
        "osa_code":             "PRES_WATER_WITHDRAWAL",
        "pillar":               "PRES",
        "name_fr":              "Prélèvements eau douce (% ressources)",
        "unit":                 "PCT_H2O",
        "direction":            "-",
        "multiplier":           1.0,
        "imputation_regime":    "PHYSICAL",
        "has_structural_zeros": False,
        "is_composite_score":   False,
        "min_valid":            0.0,
        "max_valid":            3000.0, # peut dépasser 100% (surexploitation)
    },

    "AG.LND.IRIG.AG.ZS": {
        "osa_code":             "PRES_WATER_AGRI",
        "pillar":               "PRES",
        "name_fr":              "Terres irriguées (% terres cultivées)",
        "unit":                 "PCT_AGRI",
        "direction":            "+",
        "multiplier":           1.0,
        "imputation_regime":    "PHYSICAL",
        "has_structural_zeros": False,
        "is_composite_score":   False,
        "min_valid":            0.0,
        "max_valid":            100.0,
    },

    # ══════════════════════════════════════════════════════
    # PMIL — Régime STANDARD (quantitatifs) ou PHYSICAL (WGI)
    # ══════════════════════════════════════════════════════

    "MS.MIL.XPND.GD.ZS": {
        "osa_code":             "PMIL_DEF_BUDGET_GDP",
        "pillar":               "PMIL",
        "name_fr":              "Dépenses militaires (% PIB)",
        "unit":                 "PCT_GDP",
        "direction":            "+",
        "multiplier":           1.0,
        "imputation_regime":    "STANDARD",
        "has_structural_zeros": False,
        "is_composite_score":   False,
        "min_valid":            0.0,
        "max_valid":            20.0,
    },

    "MS.MIL.XPND.ZS": {
        "osa_code":             "PMIL_DEF_BUDGET_GOV",
        "pillar":               "PMIL",
        "name_fr":              "Dépenses militaires (% dépenses gouvernementales)",
        "unit":                 "PCT_GOV",
        "direction":            "+",
        "multiplier":           1.0,
        "imputation_regime":    "STANDARD",
        "has_structural_zeros": False,
        "is_composite_score":   False,
        "min_valid":            0.0,
        "max_valid":            50.0,
    },

    "MS.MIL.TOTL.P1": {
        "osa_code":             "PMIL_ARMED_FORCES",
        "pillar":               "PMIL",
        "name_fr":              "Personnel des forces armées (total)",
        "unit":                 "COUNT_N",
        "direction":            "+",
        "multiplier":           1.0,
        "imputation_regime":    "STANDARD",
        "has_structural_zeros": False,
        "is_composite_score":   False,
        "min_valid":            0.0,
        "max_valid":            1e7,
    },

    "VC.IHR.PSRC.P5": {
        "osa_code":             "PMIL_HOMICIDE_RATE",
        "pillar":               "PMIL",
        "name_fr":              "Taux homicides intentionnels (pour 100 000 hab.)",
        "unit":                 "RATE_100K",
        "direction":            "-",
        "multiplier":           1.0,
        "imputation_regime":    "STANDARD",
        "has_structural_zeros": False,
        "is_composite_score":   False,
        "min_valid":            0.0,
        "max_valid":            150.0,
    },

    "PV.EST": {
        "osa_code":             "PMIL_STABILITY_WGI",
        "pillar":               "PMIL",
        "name_fr":              "Stabilité politique et absence de violence (WGI)",
        "unit":                 "SCORE_NORM",
        "direction":            "+",
        "multiplier":           1.0,
        # WGI natif [-2.5, +2.5] — normalisation (val+2.5)/5×100 dans le scorer ISA
        "imputation_regime":    "PHYSICAL",
        "has_structural_zeros": False,
        "is_composite_score":   True,
        "min_valid":            -3.0,
        "max_valid":            3.0,
    },

    # ══════════════════════════════════════════════════════
    # PNUM — Régime STANDARD (quantitatifs) ou PHYSICAL (WGI)
    # ══════════════════════════════════════════════════════

    "IT.NET.USER.ZS": {
        "osa_code":             "PNUM_INTERNET_USERS",
        "pillar":               "PNUM",
        "name_fr":              "Utilisateurs internet (% population)",
        "unit":                 "PCT_POP",
        "direction":            "+",
        "multiplier":           1.0,
        "imputation_regime":    "STANDARD",
        "has_structural_zeros": False,
        "is_composite_score":   False,
        "min_valid":            0.0,
        "max_valid":            100.0,
    },

    "IT.NET.BBND.P2": {
        "osa_code":             "PNUM_BROADBAND_FIXED",
        "pillar":               "PNUM",
        "name_fr":              "Abonnements haut débit fixe (pour 100 hab.)",
        "unit":                 "PER_100",
        "direction":            "+",
        "multiplier":           1.0,
        "imputation_regime":    "STANDARD",
        "has_structural_zeros": False,
        "is_composite_score":   False,
        "min_valid":            0.0,
        "max_valid":            100.0,
    },

    # CORRECTION BUG patch PNUM : BROADBAND_MOBILE ≠ BROADBAND_FIXED
    # Code WB correct : IT.MOB.BRND.P2 (haut débit mobile)
    "IT.MOB.BRND.P2": {
        "osa_code":             "PNUM_BROADBAND_MOBILE",
        "pillar":               "PNUM",
        "name_fr":              "Abonnements haut débit mobile (pour 100 hab.)",
        "unit":                 "PER_100",
        "direction":            "+",
        "multiplier":           1.0,
        "imputation_regime":    "STANDARD",
        "has_structural_zeros": False,
        "is_composite_score":   False,
        "min_valid":            0.0,
        "max_valid":            200.0,  # peut dépasser 100% (multi-SIM)
        "bug_fix_note":         "CORRECTION : wb_indicator_map_pnum_patch.py utilisait "
                                "IT.NET.BBND.P2 (haut débit fixe) par erreur pour ce code. "
                                "Code correct : IT.MOB.BRND.P2.",
    },

    "IT.CEL.SETS.P2": {
        "osa_code":             "PNUM_MOBILE_SUBSCRIPTIONS",
        "pillar":               "PNUM",
        "name_fr":              "Abonnements mobile (pour 100 hab.)",
        "unit":                 "PER_100",
        "direction":            "+",
        "multiplier":           1.0,
        "imputation_regime":    "STANDARD",
        "has_structural_zeros": False,
        "is_composite_score":   False,
        "min_valid":            0.0,
        "max_valid":            250.0,
    },

    "IT.NET.SECR.P6": {
        "osa_code":             "PNUM_SECURE_SERVERS",
        "pillar":               "PNUM",
        "name_fr":              "Serveurs internet sécurisés (pour 1M hab.)",
        "unit":                 "PER_1M",
        "direction":            "+",
        "multiplier":           1.0,
        "imputation_regime":    "STANDARD",
        "has_structural_zeros": False,
        "is_composite_score":   False,
        "min_valid":            0.0,
        "max_valid":            1e7,
    },

    "SE.TER.ENRR": {
        "osa_code":             "PNUM_TERTIARY_ENROLL",
        "pillar":               "PNUM",
        "name_fr":              "Scolarisation dans le supérieur (%)",
        "unit":                 "PCT_POP",
        "direction":            "+",
        "multiplier":           1.0,
        "imputation_regime":    "STANDARD",
        "has_structural_zeros": False,
        "is_composite_score":   False,
        "min_valid":            0.0,
        "max_valid":            150.0,  # taux brut peut dépasser 100
    },

    "GE.EST": {
        "osa_code":             "PNUM_GOV_EFFECTIVENESS",
        "pillar":               "PNUM",
        "name_fr":              "Efficacité gouvernementale (WGI)",
        "unit":                 "SCORE_NORM",
        "direction":            "+",
        "multiplier":           1.0,
        # WGI natif [-2.5, +2.5] — normalisation (val+2.5)/5×100 dans scorer
        "imputation_regime":    "PHYSICAL",
        "has_structural_zeros": False,
        "is_composite_score":   True,
        "min_valid":            -3.0,
        "max_valid":            3.0,
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
    Retourne None en cas d'échec définitif — jamais d'exception levée.
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
                    "Source indisponible après %d tentatives : %s\n"
                    "  Erreur : %s\n"
                    "  → Indicateur ignoré, poursuite sur les suivants.",
                    retries, url, e
                )
                return None
            log.warning("Tentative %d/%d — retry dans %ds (%s)",
                        attempt, retries, wait, e)
            time.sleep(wait)


# ── Téléchargement d'un indicateur WB ────────────────────
def fetch_wb_indicator(
    wb_code: str,
    year_min: int,
    year_max: int,
) -> pd.DataFrame:
    """Télécharge un indicateur WB pour tous pays sur la fenêtre."""
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
def validate_indicator(
    df: pd.DataFrame,
    wb_code: str,
    meta: dict,
) -> pd.DataFrame:
    if df.empty:
        return df

    min_v = meta.get("min_valid", float("-inf"))
    max_v = meta.get("max_valid", float("inf"))

    mask_invalid = (df["raw_value"] < min_v) | (df["raw_value"] > max_v)
    n_invalid = int(mask_invalid.sum())

    if n_invalid > 0:
        for _, row in df[mask_invalid].head(3).iterrows():
            log.warning("  [%s] Hors bornes [%.1f, %.1f] : %s %d → %.4f",
                        wb_code, min_v, max_v,
                        row["country_iso3"], row["year"], row["raw_value"])
        if n_invalid > 3:
            log.warning("  [%s] ... et %d autres hors bornes", wb_code, n_invalid - 3)
        df = df[~mask_invalid].copy()

    return df


# ── Zéros structurels (non-producteurs) ──────────────────
def add_structural_zeros(
    df: pd.DataFrame,
    wb_code: str,
    meta: dict,
    year_min: int,
    year_max: int,
) -> pd.DataFrame:
    """
    Pour PRES_OIL_RENTS et PRES_GAS_RENTS :
    les pays non-producteurs ont une valeur réelle = 0,
    pas une donnée manquante. Confiance 0.95.

    Stratégie inverse de PTRA (enclavés) :
    ici on liste les PRODUCTEURS — tous les autres = 0.
    """
    if not meta.get("has_structural_zeros", False):
        return df

    producers = meta.get("zero_producers", set())
    if not producers:
        return df

    osa_code   = meta["osa_code"]
    confidence = meta.get("zero_confidence", 0.95)

    existing_keys = set(zip(df["country_iso3"], df["year"]))
    rows = []

    # Ensemble de tous les pays africains ISO3 — on ne peut pas les lister
    # exhaustivement ici, mais on peut identifier les non-producteurs
    # parmi les pays déjà présents dans le DataFrame (même si sans valeur)
    # + les pays connus de nos tables.
    # Approche : on extrait les pays présents dans le DF et on applique 0
    # aux non-producteurs qui n'ont pas déjà une valeur.
    all_countries_in_df = set(df["country_iso3"].unique())
    non_producers = all_countries_in_df - producers

    for iso3 in non_producers:
        for year in range(year_min, year_max + 1):
            if (iso3, year) not in existing_keys:
                rows.append({
                    "country_iso3": iso3,
                    "year":         year,
                    "raw_value":    0.0,
                    "is_zero_structural": True,
                    "zero_confidence":    confidence,
                })

    if rows:
        df_zeros = pd.DataFrame(rows)
        log.info("  [%s] %d zéros réels ajoutés (pays non-producteurs)",
                 wb_code, len(df_zeros))
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
    pillar   = meta["pillar"].lower()
    osa_code = meta["osa_code"]
    out_dir  = CSV_OUTPUT_BASE / pillar
    out_dir.mkdir(parents=True, exist_ok=True)
    path = out_dir / f"{osa_code.lower()}_{year_min}_{year_max}.csv"

    df_export = df[["country_iso3", "year", "raw_value"]].copy()
    df_export.insert(0, "indicator_code", osa_code)
    df_export.insert(0, "wb_code", wb_code)

    if "is_zero_structural" in df.columns:
        df_export["is_zero_structural"] = df["is_zero_structural"].fillna(False)

    df_export.sort_values(["country_iso3", "year"]).to_csv(path, index=False)
    log.info("  [%s] CSV → %s (%d lignes)", wb_code, path, len(df_export))
    return path


# ── Insertion batch ───────────────────────────────────────
def insert_indicator(
    conn,
    df: pd.DataFrame,
    wb_code: str,
    meta: dict,
    dry_run: bool = False,
) -> int:
    if df.empty:
        return 0

    # Filtrer sur les pays africains valides de rf.countries
    try:
        _conn = get_pg_conn()
        _valid = pd.read_sql("SELECT iso3 FROM rf.countries", _conn)["iso3"].tolist()
        _conn.close()
        df = df[df["country_iso3"].isin(_valid)].copy()
    except Exception:
        pass

    if df.empty:
        return 0

    # Supprimer les lignes avec raw_value NaN
    df = df.dropna(subset=["raw_value"]).copy()

    if df.empty:
        return 0

    osa_code   = meta["osa_code"]
    multiplier = meta.get("multiplier", 1.0)

    if dry_run:
        valid = df[df["raw_value"].notna() & (df["raw_value"] != 0.0)]
        log.info(
            "  [DRY-RUN] [%s → %s] %d lignes prêtes "
            "(dont %d non-nulles, moy=%.4f)",
            wb_code, osa_code, len(df),
            len(valid),
            float(valid["raw_value"].mean()) if not valid.empty else 0.0,
        )
        return len(df)

    batch_data = []
    for _, row in df.iterrows():
        iso3   = str(row["country_iso3"]).strip()
        year   = int(row["year"])
        raw    = float(row["raw_value"])
        scaled = round(raw * multiplier, 6)

        if row.get("is_zero_structural", False):
            conf         = float(meta.get("zero_confidence", 0.95))
            value_status = "OBSERVED"
            quality_flag = "OK"
        else:
            conf         = 1.00
            value_status = "OBSERVED"
            quality_flag = "OK"

        batch_data.append((
            osa_code, iso3, year, LAYER_RAW,
            scaled, quality_flag, conf, value_status
        ))

    sql = """
        INSERT INTO ma.indicator_values
            (indicator_code, country_iso3, year, layer_id,
             raw_value, quality_flag, confidence_score, value_status)
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


# ── Rapport ───────────────────────────────────────────────
def print_report(
    results: dict,
    failed: list,
    dry_run: bool,
    output_mode: str,
) -> None:
    print("\n" + "=" * 70)
    print("RAPPORT FETCHER WB — PRES / PMIL / PNUM  — Sprint 6")
    print("=" * 70)

    by_pillar = {}
    for wb_code, n in results.items():
        pillar = WB_MAP.get(wb_code, {}).get("pillar", "?")
        by_pillar.setdefault(pillar, []).append((wb_code, n))

    print(f"\nMode sortie    : {output_mode.upper()}")
    total = sum(results.values())
    if output_mode in ("db", "both") and not dry_run:
        print(f"Total DB insérés : {total:>6}")
    if output_mode in ("csv", "both") and not dry_run:
        print(f"CSV dans       : data/raw/{{pres,pmil,pnum}}/")

    for pillar in ["PRES", "PMIL", "PNUM"]:
        items = by_pillar.get(pillar, [])
        if not items:
            continue
        print(f"\n  ── {pillar} ({len(items)} indicateurs) ──")
        print(f"  {'Code WB':<22} {'Code OSA':<28} {'Lignes':>7}  Statut")
        print(f"  {'-'*65}")
        for wb_code, n in items:
            osa    = WB_MAP[wb_code]["osa_code"]
            if wb_code in failed:
                status = "KO — source indisponible"
            elif dry_run:
                status = f"[DRY-RUN] {n} prêtes"
            elif n > 0:
                status = "OK"
            else:
                status = "SKIP (0 lignes)"
            print(f"  {wb_code:<22} {osa:<28} {n:>7}  {status}")

    if failed:
        print(f"\n⚠  En échec réseau : {', '.join(failed)}")
        print("   Relancer : --indicator <CODE> une fois la connexion rétablie.")

    if any("bug_fix_note" in WB_MAP.get(wb, {}) for wb in results):
        print("\n✔ Correction appliquée : IT.NET.BBND.P2 → IT.MOB.BRND.P2")
        print("  pour PNUM_BROADBAND_MOBILE (bug dans wb_indicator_map_pnum_patch.py)")

    print("\nVérification post-ingestion :")
    print("  SELECT indicator_code, COUNT(*), MIN(year), MAX(year),")
    print("         ROUND(COUNT(raw_value)::numeric/COUNT(*)*100,1) AS fill_pct")
    print("  FROM ma.indicator_values")
    print("  WHERE indicator_code ~ '^(PRES|PMIL|PNUM)_' AND layer_id = 1")
    print("  GROUP BY indicator_code ORDER BY indicator_code;")
    print("=" * 70)


# ── Orchestrateur ─────────────────────────────────────────
def run(
    indicator_filter: Optional[str] = None,
    pillar_filter:    Optional[str] = None,
    dry_run:          bool = False,
    year_min:         int  = YEAR_MIN,
    year_max:         int  = YEAR_MAX,
    output_mode:      Literal["csv", "db", "both"] = "both",
) -> int:
    log.info("=" * 70)
    log.info("OSA Fetcher WB PRES/PMIL/PNUM — %d indicateurs · %d–%d · %s",
             len(WB_MAP), year_min, year_max, output_mode.upper())
    if pillar_filter:
        log.info("Filtre pilier : %s", pillar_filter)
    if dry_run:
        log.info("MODE DRY-RUN — aucune écriture")

    conn = get_pg_conn()
    results: dict[str, int] = {}
    failed:  list[str]      = []

    try:
        for wb_code, meta in WB_MAP.items():
            if indicator_filter and wb_code != indicator_filter:
                continue
            if pillar_filter and meta["pillar"] != pillar_filter.upper():
                continue

            osa_code = meta["osa_code"]
            log.info("─" * 55)
            log.info("[%s] %s → %s", meta["pillar"], wb_code, osa_code)

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

            # 3. Zéros structurels (non-producteurs pétrole/gaz)
            df = add_structural_zeros(df, wb_code, meta, year_min, year_max)

            # 4a. Export CSV
            if not dry_run and output_mode in ("csv", "both"):
                export_csv(df, wb_code, meta, year_min, year_max)

            # 4b. Insertion DB
            if not dry_run and output_mode in ("db", "both"):
                n = insert_indicator(conn, df, wb_code, meta, dry_run=False)
            elif dry_run:
                n = insert_indicator(conn, df, wb_code, meta, dry_run=True)
            else:
                n = len(df)  # mode csv uniquement

            results[wb_code] = n
            time.sleep(REQUEST_DELAY)

    finally:
        conn.close()

    print_report(results, failed, dry_run=dry_run, output_mode=output_mode)

    n_attempted = len(results)
    all_failed  = (len(failed) == n_attempted and n_attempted > 0)
    return -1 if all_failed else sum(results.values())


# ── CLI ───────────────────────────────────────────────────
def main():
    pillars   = ["PRES", "PMIL", "PNUM"]
    wb_codes  = list(WB_MAP.keys())

    parser = argparse.ArgumentParser(
        description="OSA — Fetcher WB PRES/PMIL/PNUM (21 indicateurs)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=f"""
Indicateurs par pilier :
  PRES (10) : {[v['osa_code'] for v in WB_MAP.values() if v['pillar']=='PRES']}
  PMIL  (5) : {[v['osa_code'] for v in WB_MAP.values() if v['pillar']=='PMIL']}
  PNUM  (6) : {[v['osa_code'] for v in WB_MAP.values() if v['pillar']=='PNUM']}

Modes de sortie :
  --output csv   → data/raw/{{pres,pmil,pnum}}/{{osa_code}}_*.csv
  --output db    → ma.indicator_values layer_id=1
  --output both  → CSV + DB (défaut)
  --dry-run      → rapport seul, aucune écriture

Exemples :
  python fetcher_wb_pres_pmil_pnum.py --dry-run
  python fetcher_wb_pres_pmil_pnum.py --pillar PRES --output both
  python fetcher_wb_pres_pmil_pnum.py --pillar PMIL --output csv
  python fetcher_wb_pres_pmil_pnum.py --indicator EG.ELC.PROD.KH --output db
  python fetcher_wb_pres_pmil_pnum.py --output both

Correction embarquée :
  IT.NET.BBND.P2 (fixe) et IT.MOB.BRND.P2 (mobile) sont correctement
  distincts ici — le bug du patch PNUM est corrigé dans ce fetcher.
        """
    )
    parser.add_argument("--dry-run",    action="store_true",
                        help="Rapport sans écriture")
    parser.add_argument("--output",     choices=["csv", "db", "both"], default="both")
    parser.add_argument("--pillar",     choices=pillars, default=None,
                        help="Traiter uniquement ce pilier")
    parser.add_argument("--indicator",  choices=wb_codes, default=None,
                        help="Traiter uniquement cet indicateur WB")
    parser.add_argument("--year-min",   type=int, default=YEAR_MIN)
    parser.add_argument("--year-max",   type=int, default=YEAR_MAX)

    args = parser.parse_args()
    result = run(
        indicator_filter=args.indicator,
        pillar_filter=args.pillar,
        dry_run=args.dry_run,
        year_min=args.year_min,
        year_max=args.year_max,
        output_mode=args.output,
    )
    sys.exit(0 if result >= 0 else 1)


if __name__ == "__main__":
    main()