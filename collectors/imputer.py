"""
============================================================
OSA / ISA OBSERVATORY
collectors/imputer_v3.py -- Imputation avancée L2 v3
DuckDB + MICE par pilier + KNN géopolitique enrichi
+ Score de confiance cross_val_predict + execute_batch
+ Garde-fou sur-imputation + Traçabilité method_chain
============================================================

Corrections v2 -> v3 :
  [3.1] MICE par pilier -- pas de corrélations inter-piliers
  [3.2] Distance géo enrichie (PIB + commerce + stabilité)
  [3.3] Score confiance via cross_val_predict (pas OOB biaisé)
  [3.4] execute_batch -- x10-50 plus rapide
  [4.1] Garde-fou sur-imputation > 50%
  [4.2] Traçabilité method_chain (DUCKDB_LINEAR/MICE/KNN_GEO)

value_status mapping :
  DUCKDB_LINEAR / DUCKDB_FILL -> INTERPOLATED
  MICE / KNN_GEO              -> IMPUTED

Usage :
  python collectors/imputer_v3.py --dry-run
  python collectors/imputer_v3.py --pillar PECO --dry-run
  python collectors/imputer_v3.py --indicator ECO_LOG --dry-run
  python collectors/imputer_v3.py
============================================================
"""

from __future__ import annotations

import argparse
import logging
import os
import sys
import warnings
from typing import Optional

import duckdb
import numpy as np
import pandas as pd
import psycopg2
from psycopg2.extras import execute_batch
from dotenv import load_dotenv

warnings.filterwarnings("ignore", category=FutureWarning)
warnings.filterwarnings("ignore", category=UserWarning)

from sklearn.experimental import enable_iterative_imputer  # noqa: F401
from sklearn.impute import IterativeImputer
from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import cross_val_predict

load_dotenv()

logging.basicConfig(
    level=os.getenv("OSA_LOG_LEVEL", "INFO"),
    format="%(asctime)s | %(levelname)-8s | %(message)s",
)
log = logging.getLogger("imputer_v3")

# ── Constantes ────────────────────────────────────────────────
LAYER_RAW           = 1
LAYER_IMPUTED       = 2
MIN_COVERAGE        = 0.20
MAX_IMPUTATION_RATE = 0.50
KNN_NEIGHBORS       = 5
MICE_MAX_ITER       = 10
MICE_N_ESTIMATORS   = 50
MICE_RANDOM_STATE   = 42
BATCH_SIZE          = 500

# Scores de confiance statiques (fallback)
CONF_ORIGINAL       = 1.00
CONF_INTERP_LINEAR  = 0.85
CONF_INTERP_FILL    = 0.80
CONF_KNN_GEO        = 0.40

# Quality flags DB
FLAG_OK             = "OK"
FLAG_INTERPOLATED   = "INTERPOLATED"
FLAG_ESTIMATED      = "ESTIMATED"

# Value status DB (contrainte chk_value_status)
VS_OBSERVED         = "OBSERVED"
VS_INTERPOLATED     = "INTERPOLATED"
VS_IMPUTED          = "IMPUTED"

# Method chain labels (internes, pas en DB)
METHOD_DUCKDB_LINEAR = "DUCKDB_LINEAR"
METHOD_DUCKDB_FILL   = "DUCKDB_FILL"
METHOD_MICE          = "MICE"
METHOD_KNN_GEO       = "KNN_GEO"


def method_to_value_status(method: str) -> str:
    """Convertit method_chain en value_status accepté par la DB."""
    if method in (METHOD_DUCKDB_LINEAR, METHOD_DUCKDB_FILL):
        return VS_INTERPOLATED
    if method in (METHOD_MICE, METHOD_KNN_GEO):
        return VS_IMPUTED
    return VS_OBSERVED


# ── Connexion PostgreSQL ──────────────────────────────────────
def get_pg_conn():
    return psycopg2.connect(
        host=os.getenv("OSA_DB_HOST", "localhost"),
        port=int(os.getenv("OSA_DB_PORT", 5432)),
        dbname=os.getenv("OSA_DB_NAME", "osa_db"),
        user=os.getenv("OSA_DB_USER", "osa_user"),
        password=os.getenv("OSA_DB_PASS", ""),
    )


# ── Chargement des données ────────────────────────────────────
def load_data(conn, indicator_filter=None, pillar_filter=None):
    """Charge L1 + métadonnées pays + couverture. Paramètres SQL sécurisés."""
    params = [LAYER_RAW]
    where  = ["iv.layer_id = %s"]

    if indicator_filter:
        where.append("iv.indicator_code = %s")
        params.append(indicator_filter)
    if pillar_filter:
        where.append("i.pillar_code = %s")
        params.append(pillar_filter)

    where_sql = " AND ".join(where)

    df_raw = pd.read_sql(f"""
        SELECT iv.indicator_code, iv.country_iso3, iv.year,
               iv.raw_value, i.pillar_code, i.direction
        FROM ma.indicator_values iv
        JOIN rf.indicators i ON i.code = iv.indicator_code
        WHERE {where_sql}
        ORDER BY iv.indicator_code, iv.country_iso3, iv.year
    """, conn, params=params)

    df_countries = pd.read_sql("""
        SELECT c.iso3, c.region_code,
               c.monetary_sovereignty_weight,
               COALESCE(gdp.raw_value,   0) AS gdp_per_capita,
               COALESCE(trade.raw_value, 0) AS trade_pct_gdp,
               COALESCE(stab.raw_value,  0) AS geo_stab
        FROM rf.countries c
        LEFT JOIN (
            SELECT country_iso3, AVG(raw_value) AS raw_value
            FROM ma.indicator_values
            WHERE indicator_code = 'ECO_GDP' AND layer_id = 1
              AND raw_value IS NOT NULL
            GROUP BY country_iso3
        ) gdp   ON gdp.country_iso3   = c.iso3
        LEFT JOIN (
            SELECT country_iso3, AVG(raw_value) AS raw_value
            FROM ma.indicator_values
            WHERE indicator_code = 'GEO_ALL' AND layer_id = 1
              AND raw_value IS NOT NULL
            GROUP BY country_iso3
        ) trade ON trade.country_iso3 = c.iso3
        LEFT JOIN (
            SELECT country_iso3, AVG(raw_value) AS raw_value
            FROM ma.indicator_values
            WHERE indicator_code = 'GEO_STAB' AND layer_id = 1
              AND raw_value IS NOT NULL
            GROUP BY country_iso3
        ) stab  ON stab.country_iso3  = c.iso3
        WHERE c.iso3 IS NOT NULL
    """, conn)

    df_coverage = pd.read_sql("""
        SELECT iv.indicator_code, i.pillar_code,
               COUNT(*)                    AS total,
               COUNT(iv.raw_value)         AS non_null,
               ROUND(COUNT(iv.raw_value)::numeric / COUNT(*) * 100, 1) AS coverage_pct
        FROM ma.indicator_values iv
        JOIN rf.indicators i ON i.code = iv.indicator_code
        WHERE iv.layer_id = 1
        GROUP BY iv.indicator_code, i.pillar_code
    """, conn)

    log.info("Données : %d lignes | %d indicateurs | %d pays",
             len(df_raw),
             df_raw["indicator_code"].nunique(),
             df_raw["country_iso3"].nunique())

    return df_raw, df_countries, df_coverage


# ── Etape 1 : DuckDB interpolation ───────────────────────────
def step1_duckdb(df_raw: pd.DataFrame) -> pd.DataFrame:
    """Interpolation linéaire temporelle via DuckDB LAG/LEAD."""
    log.info("Etape 1 -- DuckDB interpolation...")

    con = duckdb.connect()
    con.register("raw_data", df_raw)

    result = con.execute("""
        SELECT
            indicator_code, country_iso3, year, raw_value,
            pillar_code, direction,
            LAST_VALUE(raw_value IGNORE NULLS) OVER (
                PARTITION BY indicator_code, country_iso3 ORDER BY year
                ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
            ) AS prev_value,
            LAST_VALUE(CASE WHEN raw_value IS NOT NULL THEN year END IGNORE NULLS) OVER (
                PARTITION BY indicator_code, country_iso3 ORDER BY year
                ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
            ) AS prev_year,
            FIRST_VALUE(raw_value IGNORE NULLS) OVER (
                PARTITION BY indicator_code, country_iso3 ORDER BY year
                ROWS BETWEEN 1 FOLLOWING AND UNBOUNDED FOLLOWING
            ) AS next_value,
            FIRST_VALUE(CASE WHEN raw_value IS NOT NULL THEN year END IGNORE NULLS) OVER (
                PARTITION BY indicator_code, country_iso3 ORDER BY year
                ROWS BETWEEN 1 FOLLOWING AND UNBOUNDED FOLLOWING
            ) AS next_year
        FROM raw_data
        ORDER BY indicator_code, country_iso3, year
    """).df()
    con.close()

    imputed_vals  = []
    quality_flags = []
    confidences   = []
    method_chains = []

    for _, row in result.iterrows():
        if pd.notnull(row["raw_value"]):
            imputed_vals.append(row["raw_value"])
            quality_flags.append(FLAG_OK)
            confidences.append(CONF_ORIGINAL)
            method_chains.append("ORIGINAL")
            continue

        pv   = row["prev_value"]
        nv   = row["next_value"]
        py   = row["prev_year"]
        ny   = row["next_year"]

        if pd.notnull(pv) and pd.notnull(nv):
            alpha = (row["year"] - py) / (ny - py)
            val   = float(pv) + alpha * (float(nv) - float(pv))
            imputed_vals.append(round(val, 6))
            quality_flags.append(FLAG_INTERPOLATED)
            confidences.append(CONF_INTERP_LINEAR)
            method_chains.append(METHOD_DUCKDB_LINEAR)
        elif pd.notnull(pv):
            imputed_vals.append(float(pv))
            quality_flags.append(FLAG_INTERPOLATED)
            confidences.append(CONF_INTERP_FILL)
            method_chains.append(METHOD_DUCKDB_FILL)
        elif pd.notnull(nv):
            imputed_vals.append(float(nv))
            quality_flags.append(FLAG_INTERPOLATED)
            confidences.append(CONF_INTERP_FILL)
            method_chains.append(METHOD_DUCKDB_FILL)
        else:
            imputed_vals.append(None)
            quality_flags.append(None)
            confidences.append(None)
            method_chains.append(None)

    result["imputed_value"] = imputed_vals
    result["quality_flag"]  = quality_flags
    result["confidence"]    = confidences
    result["method_chain"]  = method_chains

    n_linear = method_chains.count(METHOD_DUCKDB_LINEAR)
    n_fill   = method_chains.count(METHOD_DUCKDB_FILL)
    log.info("  -> %d interpolations linéaires + %d forward/backward fill",
             n_linear, n_fill)

    return result


# ── Etape 2 : MICE par pilier ─────────────────────────────────
def step2_mice_by_pillar(df_interp: pd.DataFrame, df_coverage: pd.DataFrame) -> pd.DataFrame:
    """
    MICE par pilier avec score de confiance via cross_val_predict.
    cross_val_predict donne une estimation réaliste hors échantillon
    contrairement à OOB qui est biaisé dans IterativeImputer.
    """
    log.info("Etape 2 -- MICE par pilier...")

    df_result = df_interp.copy()
    pillars   = df_interp["pillar_code"].dropna().unique()

    for pillar in sorted(pillars):
        log.info("  Pilier %s...", pillar)

        eligible = df_coverage[
            (df_coverage["pillar_code"]  == pillar) &
            (df_coverage["coverage_pct"] >= MIN_COVERAGE * 100)
        ]["indicator_code"].tolist()

        if not eligible:
            continue

        # Garde-fou sur-imputation par indicateur
        eligible_filtered = []
        for ind in eligible:
            row = df_coverage[df_coverage["indicator_code"] == ind]
            if row.empty:
                continue
            cov = float(row["coverage_pct"].values[0]) / 100
            if (1 - cov) > MAX_IMPUTATION_RATE:
                log.warning("    [GARDE-FOU] %s -- taux imputation %.0f%% > %.0f%% -- skip",
                            ind, (1 - cov) * 100, MAX_IMPUTATION_RATE * 100)
                continue
            eligible_filtered.append((ind, cov))

        if not eligible_filtered:
            continue

        eligible_codes = [ind for ind, _ in eligible_filtered]
        eligible_covs  = {ind: cov for ind, cov in eligible_filtered}

        df_pillar = df_interp[df_interp["indicator_code"].isin(eligible_codes)].copy()
        df_pillar["value_for_mice"] = df_pillar["imputed_value"].fillna(df_pillar["raw_value"])

        pivot = df_pillar.pivot_table(
            index=["country_iso3", "year"],
            columns="indicator_code",
            values="value_for_mice",
            aggfunc="first",
        )

        if pivot.empty or pivot.shape[1] < 2:
            log.info("    Matrice trop petite -- skip")
            continue

        n_missing = pivot.isna().sum().sum()
        if n_missing == 0:
            log.info("    Pas de valeurs manquantes -- skip")
            continue

        log.info("    Matrice %dx%d | %d manquantes", pivot.shape[0], pivot.shape[1], n_missing)

        # MICE
        rf = RandomForestRegressor(
            n_estimators=MICE_N_ESTIMATORS,
            random_state=MICE_RANDOM_STATE,
            n_jobs=-1,
        )
        imputer = IterativeImputer(
            estimator=rf,
            max_iter=MICE_MAX_ITER,
            random_state=MICE_RANDOM_STATE,
            verbose=0,
        )

        try:
            imputed_array = imputer.fit_transform(pivot.values)
        except Exception as e:
            log.error("    Erreur MICE %s : %s", pillar, e)
            continue

        pivot_imputed = pd.DataFrame(imputed_array, index=pivot.index, columns=pivot.columns)

        # Score de confiance dynamique via cross_val_predict (cv=3)
        rf_cv = RandomForestRegressor(
            n_estimators=MICE_N_ESTIMATORS,
            random_state=MICE_RANDOM_STATE,
            n_jobs=-1,
        )
        conf_by_indicator = {}

        for col_idx, col in enumerate(pivot.columns):
            y       = pivot.iloc[:, col_idx].values
            mask_kn = ~np.isnan(y)

            if mask_kn.sum() < 5:
                conf_by_indicator[col] = 0.55
                continue

            X       = np.delete(pivot.values, col_idx, axis=1)
            X_known = X[mask_kn].copy()
            y_known = y[mask_kn]

            # Remplacer NaN dans X par la moyenne de chaque colonne
            col_means = np.nanmean(X_known, axis=0)
            for ci in range(X_known.shape[1]):
                nan_mask = np.isnan(X_known[:, ci])
                X_known[nan_mask, ci] = col_means[ci]

            try:
                y_pred   = cross_val_predict(rf_cv, X_known, y_known, cv=3, n_jobs=-1)
                std_data = np.std(y_known)
                std_res  = np.std(y_known - y_pred)
                if std_data == 0:
                    conf = 0.70
                else:
                    conf = float(np.clip(1 - std_res / (std_data + 1e-8), 0.40, 0.95))
            except Exception:
                conf = 0.55

            conf_by_indicator[col] = round(conf, 3)

        # Réintégrer dans df_result
        n_mice_filled = 0
        for (iso3, year), row_vals in pivot_imputed.iterrows():
            for ind_code, val in row_vals.items():
                if pd.isna(val):
                    continue
                mask = (
                    (df_result["indicator_code"] == ind_code) &
                    (df_result["country_iso3"]   == iso3) &
                    (df_result["year"]           == year) &
                    (df_result["imputed_value"].isna())
                )
                if not mask.any():
                    continue
                conf = conf_by_indicator.get(ind_code, 0.55)
                df_result.loc[mask, "imputed_value"] = round(float(val), 6)
                df_result.loc[mask, "quality_flag"]  = FLAG_ESTIMATED
                df_result.loc[mask, "confidence"]    = conf
                df_result.loc[mask, "method_chain"]  = METHOD_MICE
                n_mice_filled += 1

        log.info("    -> %d valeurs imputées MICE (conf moy=%.2f)",
                 n_mice_filled, np.mean(list(conf_by_indicator.values())) if conf_by_indicator else 0)

    return df_result


# ── Etape 3 : KNN géopolitique enrichi ───────────────────────
def step3_knn_geo(df_mice: pd.DataFrame, df_countries: pd.DataFrame) -> pd.DataFrame:
    """
    KNN géopolitique avec distance composite :
      d = 0.5 * |gdp_i - gdp_j| / max_gdp
        + 0.3 * |trade_i - trade_j| / max_trade
        + 0.2 * |stab_i - stab_j| / max_stab
        x 0.5 si même région UA
        x 0.8 si même zone monétaire UEMOA/CEMAC
    """
    log.info("Etape 3 -- KNN géopolitique enrichi...")

    countries = df_countries["iso3"].tolist()

    max_gdp   = max(float(df_countries["gdp_per_capita"].max()), 1.0)
    max_trade = max(float(df_countries["trade_pct_gdp"].max()),  1.0)
    max_stab  = max(float(df_countries["geo_stab"].abs().max()), 1e-6)

    # Matrice de distance géopolitique
    dist_matrix = {}
    for iso3 in countries:
        r1 = df_countries[df_countries["iso3"] == iso3]
        if r1.empty:
            dist_matrix[iso3] = {c: 1.0 for c in countries}
            continue
        r1 = r1.iloc[0]
        dist_matrix[iso3] = {}

        for iso3_j in countries:
            if iso3 == iso3_j:
                dist_matrix[iso3][iso3_j] = 1e-6
                continue
            r2 = df_countries[df_countries["iso3"] == iso3_j]
            if r2.empty:
                dist_matrix[iso3][iso3_j] = 1.0
                continue
            r2 = r2.iloc[0]

            d_gdp   = abs(float(r1["gdp_per_capita"]) - float(r2["gdp_per_capita"])) / max_gdp
            d_trade = abs(float(r1["trade_pct_gdp"])  - float(r2["trade_pct_gdp"]))  / max_trade
            d_stab  = abs(float(r1["geo_stab"])        - float(r2["geo_stab"]))        / max_stab

            d = 0.5 * d_gdp + 0.3 * d_trade + 0.2 * d_stab

            if r1["region_code"] == r2["region_code"]:
                d *= 0.5
            if (float(r1["monetary_sovereignty_weight"]) < 1.0 and
                    float(r2["monetary_sovereignty_weight"]) < 1.0):
                d *= 0.8

            dist_matrix[iso3][iso3_j] = max(d, 1e-6)

    df_result    = df_mice.copy()
    n_knn_filled = 0

    still_missing = df_result[
        df_result["imputed_value"].isna() & df_result["raw_value"].isna()
    ]

    for _, miss_row in still_missing.iterrows():
        iso3 = miss_row["country_iso3"]
        year = miss_row["year"]
        ind  = miss_row["indicator_code"]

        if iso3 not in dist_matrix:
            continue

        neighbors = sorted(dist_matrix[iso3].items(), key=lambda x: x[1])[1:KNN_NEIGHBORS + 1]

        vals, weights = [], []
        for nb_iso3, dist in neighbors:
            nmask = (
                (df_result["indicator_code"] == ind) &
                (df_result["country_iso3"]   == nb_iso3) &
                (df_result["year"]           == year)
            )
            nrows = df_result[nmask]
            if nrows.empty:
                continue
            v = nrows["imputed_value"].values[0]
            if pd.isna(v):
                v = nrows["raw_value"].values[0]
            if pd.isna(v):
                continue
            vals.append(float(v))
            weights.append(1.0 / dist)

        if vals and sum(weights) > 0:
            wval = sum(v * w for v, w in zip(vals, weights)) / sum(weights)
            mask = (
                (df_result["indicator_code"] == ind) &
                (df_result["country_iso3"]   == iso3) &
                (df_result["year"]           == year)
            )
            df_result.loc[mask, "imputed_value"] = round(wval, 6)
            df_result.loc[mask, "quality_flag"]  = FLAG_ESTIMATED
            df_result.loc[mask, "confidence"]    = CONF_KNN_GEO
            df_result.loc[mask, "method_chain"]  = METHOD_KNN_GEO
            n_knn_filled += 1

    log.info("  -> %d valeurs imputées par KNN géopolitique", n_knn_filled)
    return df_result


# ── Etape 4 : Résumé confiance ────────────────────────────────
def step4_summary(df_final: pd.DataFrame) -> pd.DataFrame:
    imputed = df_final[df_final["raw_value"].isna() & df_final["imputed_value"].notna()]
    if imputed.empty:
        return df_final

    by_method = imputed.groupby("method_chain").agg(
        n=("imputed_value", "count"),
        conf_moy=("confidence", "mean"),
    )
    log.info("Scores de confiance par méthode :")
    for method, row in by_method.iterrows():
        log.info("  %-22s : %5d valeurs  conf_moy=%.3f",
                 method, int(row["n"]), row["conf_moy"])
    return df_final


# ── Insertion batch ───────────────────────────────────────────
def insert_l2_batch(conn, df_final: pd.DataFrame, dry_run: bool = False) -> int:
    """
    Insertion par batch avec execute_batch.
    Compte les insertions réelles via COUNT avant/après (ON CONFLICT safe).
    value_status mappé depuis method_chain vers les valeurs DB autorisées.
    """
    to_insert = df_final[
        df_final["raw_value"].isna() &
        df_final["imputed_value"].notna() &
        df_final["quality_flag"].notna()
    ].copy()

    if to_insert.empty:
        log.info("Aucune valeur à insérer")
        return 0

    log.info("Préparation batch insertion : %d valeurs...", len(to_insert))

    if dry_run:
        log.info("[DRY-RUN] %d valeurs non insérées", len(to_insert))
        return len(to_insert)

    # Vérifier colonnes disponibles
    with conn.cursor() as cur:
        cur.execute("""
            SELECT column_name FROM information_schema.columns
            WHERE table_schema = 'ma' AND table_name = 'indicator_values'
        """)
        cols = {r[0] for r in cur.fetchall()}

    has_confidence = "confidence_score" in cols
    has_status     = "value_status"     in cols

    # Cache method_version_id depuis L1
    meta_cache = {}
    with conn.cursor() as cur:
        cur.execute("""
            SELECT DISTINCT ON (indicator_code, country_iso3)
                indicator_code, country_iso3, method_version_id
            FROM ma.indicator_values WHERE layer_id = 1
            ORDER BY indicator_code, country_iso3
        """)
        for ind, iso3, mvid in cur.fetchall():
            meta_cache[(ind, iso3)] = mvid

    # Construire les tuples batch
    batch_data = []
    for _, row in to_insert.iterrows():
        ind    = row["indicator_code"]
        iso3   = row["country_iso3"]
        year   = int(row["year"])
        val    = float(row["imputed_value"])
        flag   = row["quality_flag"]
        conf   = float(row["confidence"])   if pd.notnull(row["confidence"])   else 0.5
        method = str(row["method_chain"])   if pd.notnull(row["method_chain"]) else "ORIGINAL"
        vs     = method_to_value_status(method)
        mvid   = meta_cache.get((ind, iso3), 1)

        if has_confidence and has_status:
            batch_data.append((ind, iso3, year, LAYER_IMPUTED, val, None, mvid, flag, conf, vs))
        elif has_confidence:
            batch_data.append((ind, iso3, year, LAYER_IMPUTED, val, None, mvid, flag, conf))
        else:
            batch_data.append((ind, iso3, year, LAYER_IMPUTED, val, None, mvid, flag))

    # SQL selon colonnes disponibles
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
        # Compter avant pour mesurer l'impact réel (ON CONFLICT DO NOTHING)
        with conn.cursor() as cur:
            cur.execute(
                "SELECT COUNT(*) FROM ma.indicator_values WHERE layer_id = %s",
                (LAYER_IMPUTED,)
            )
            count_before = cur.fetchone()[0]

        with conn.cursor() as cur:
            execute_batch(cur, sql, batch_data, page_size=BATCH_SIZE)

        conn.commit()

        with conn.cursor() as cur:
            cur.execute(
                "SELECT COUNT(*) FROM ma.indicator_values WHERE layer_id = %s",
                (LAYER_IMPUTED,)
            )
            count_after = cur.fetchone()[0]

        inserted = count_after - count_before
        log.info("  -> %d insérés en batch (préparé=%d, page_size=%d)",
                 inserted, len(batch_data), BATCH_SIZE)
        return inserted

    except Exception as e:
        log.error("  Erreur batch : %s", e)
        conn.rollback()
        return 0


# ── Rapport ───────────────────────────────────────────────────
def print_report(df_final: pd.DataFrame, n_inserted: int) -> None:
    print("\n" + "=" * 65)
    print("RAPPORT IMPUTATION L2 v3 -- DuckDB + MICE/pilier + KNN Géo")
    print("=" * 65)

    orig       = df_final["raw_value"].notna().sum()
    imputed    = df_final[df_final["raw_value"].isna() & df_final["imputed_value"].notna()]
    still_null = df_final[df_final["raw_value"].isna() & df_final["imputed_value"].isna()]

    print(f"\nValeurs L1 originales : {orig:>8}")
    print(f"Valeurs imputées      : {len(imputed):>8}")
    print(f"Encore manquantes     : {len(still_null):>8}")
    print(f"Insertions L2         : {n_inserted:>8}")

    if not imputed.empty:
        print("\nPar méthode (method_chain) :")
        by_m = imputed.groupby("method_chain").agg(
            n=("imputed_value", "count"),
            conf=("confidence", "mean"),
        ).sort_values("n", ascending=False)
        for m, r in by_m.iterrows():
            print(f"  {m:<22} : {int(r['n']):>6}  conf={r['conf']:.3f}")

        print("\nPar pilier :")
        by_p = imputed.groupby("pillar_code")["imputed_value"].count().sort_values(ascending=False)
        for p, n in by_p.items():
            print(f"  {p} : {n:>6}")

        print("\nTop 10 indicateurs imputés :")
        by_i = imputed.groupby("indicator_code").agg(
            n=("imputed_value", "count"),
            conf=("confidence", "mean"),
        ).sort_values("n", ascending=False).head(10)
        for i, r in by_i.iterrows():
            print(f"  {i:<15} : {int(r['n']):>5}  conf={r['conf']:.3f}")

    if not still_null.empty:
        print("\nIndicateurs encore incomplets :")
        by_null = still_null.groupby("indicator_code").size().sort_values(ascending=False)
        for i, n in by_null.head(10).items():
            print(f"  {i:<15} : {n} valeurs manquantes")

    print("=" * 65)


# ── Orchestrateur ─────────────────────────────────────────────
def run(
    indicator_filter: Optional[str] = None,
    pillar_filter:    Optional[str] = None,
    min_coverage:     float = MIN_COVERAGE,
    dry_run:          bool  = False,
) -> None:
    log.info("=" * 65)
    log.info("OSA Imputer v3 -- DuckDB + MICE/pilier + KNN Géo enrichi")
    log.info("=" * 65)
    if dry_run:
        log.info("MODE DRY-RUN -- aucune écriture en base")

    conn = get_pg_conn()
    try:
        df_raw, df_countries, df_coverage = load_data(
            conn, indicator_filter, pillar_filter
        )
        if df_raw.empty:
            log.warning("Aucune donnée -- vérifier les filtres")
            return

        df_interp = step1_duckdb(df_raw)
        df_mice   = step2_mice_by_pillar(df_interp, df_coverage)
        df_knn    = step3_knn_geo(df_mice, df_countries)
        df_final  = step4_summary(df_knn)
        n         = insert_l2_batch(conn, df_final, dry_run)
        print_report(df_final, n)

    finally:
        conn.close()


# ── CLI ───────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(
        description="OSA -- Imputation L2 v3 (DuckDB + MICE/pilier + KNN géo enrichi)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Corrections v2 -> v3 :
  [3.1] MICE par pilier
  [3.2] Distance géo enrichie (PIB + commerce + stabilité)
  [3.3] Score confiance cross_val_predict (pas OOB biaisé)
  [3.4] execute_batch + count avant/après (ON CONFLICT safe)
  [4.1] Garde-fou sur-imputation > 50%
  [4.2] Traçabilité method_chain -> value_status DB

Exemples :
  python imputer_v3.py --dry-run
  python imputer_v3.py --pillar PGEO --dry-run
  python imputer_v3.py --indicator ECO_LOG --dry-run
  python imputer_v3.py
        """,
    )
    parser.add_argument("--indicator",    type=str,   default=None)
    parser.add_argument("--pillar",       type=str,   default=None)
    parser.add_argument("--min-coverage", type=float, default=MIN_COVERAGE)
    parser.add_argument("--dry-run",      action="store_true")
    args = parser.parse_args()

    run(
        indicator_filter=args.indicator,
        pillar_filter=args.pillar,
        min_coverage=args.min_coverage,
        dry_run=args.dry_run,
    )
    sys.exit(0)


if __name__ == "__main__":
    main()
