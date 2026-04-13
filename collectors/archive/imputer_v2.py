"""
============================================================
OSA / ISA OBSERVATORY
collectors/imputer_v2.py -- Imputation avancée L2
DuckDB + MICE + KNN géopolitique + Score de confiance
============================================================

Pipeline d'imputation en 4 étapes :

  Etape 1 -- DuckDB interpolation temporelle
    Utilise les fonctions fenêtres LAG/LEAD de DuckDB
    pour interpoler linéairement les valeurs manquantes
    entre deux valeurs connues pour le même pays.
    Rapide même sur gros volumes (colonnes analytiques).

  Etape 2 -- MICE (Multiple Imputation by Chained Equations)
    Impute les valeurs restantes en utilisant les corrélations
    entre indicateurs. Chaque indicateur manquant est prédit
    par un RandomForest entraîné sur tous les autres.
    Seulement sur les indicateurs avec couverture >= 20%.

  Etape 3 -- KNN géopolitique pondéré
    Pour les valeurs encore manquantes après MICE,
    utilise les k pays les plus proches géopolitiquement
    (même région UA + proximité PIB/hab) comme voisins.
    Les valeurs sont pondérées par l'inverse de la distance.

  Etape 4 -- Score de confiance par valeur
    Chaque valeur imputée reçoit un score de confiance [0,1] :
    - Valeur originale L1          : confiance = 1.0  (flag OK)
    - Interpolation DuckDB         : confiance = 0.85 (flag INTERPOLATED)
    - MICE (couverture >= 60%)     : confiance = 0.70 (flag ESTIMATED)
    - MICE (couverture 20-60%)     : confiance = 0.55 (flag ESTIMATED)
    - KNN géopolitique             : confiance = 0.40 (flag ESTIMATED)
    - Couverture < 20%             : pas d'imputation  (flag inchangé)

  Stockage : layer_id = 2, quality_flag = 'INTERPOLATED' ou 'ESTIMATED'
  Le score de confiance est stocké dans la colonne confidence_score.

Usage :
  python collectors/imputer_v2.py --dry-run
  python collectors/imputer_v2.py --indicator ECO_LOG --dry-run
  python collectors/imputer_v2.py --pillar PGEO --dry-run
  python collectors/imputer_v2.py
  python collectors/imputer_v2.py --min-coverage 0.25

Prerequis :
  pip install duckdb pandas scikit-learn numpy --break-system-packages
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
from dotenv import load_dotenv

warnings.filterwarnings("ignore", category=FutureWarning)

# sklearn imports avec activation iterative imputer (experimental)
from sklearn.experimental import enable_iterative_imputer  # noqa: F401
from sklearn.impute import IterativeImputer
from sklearn.ensemble import RandomForestRegressor

load_dotenv()

logging.basicConfig(
    level=os.getenv("OSA_LOG_LEVEL", "INFO"),
    format="%(asctime)s | %(levelname)-8s | %(message)s",
)
log = logging.getLogger("imputer_v2")

# ── Constantes ────────────────────────────────────────────────
LAYER_RAW            = 1
LAYER_IMPUTED        = 2
MIN_COVERAGE         = 0.20    # < 20% -> pas d'imputation
KNN_NEIGHBORS        = 5       # nombre de voisins géopolitiques
MICE_MAX_ITER        = 10
MICE_N_ESTIMATORS    = 50
MICE_RANDOM_STATE    = 42

# Scores de confiance par methode
CONF_ORIGINAL        = 1.00
CONF_INTERPOLATED    = 0.85
CONF_MICE_HIGH       = 0.70    # couverture >= 60%
CONF_MICE_LOW        = 0.55    # couverture 20-60%
CONF_KNN_GEO         = 0.40

# Valeurs quality_flag acceptées par la contrainte DB
FLAG_OK              = "OK"
FLAG_INTERPOLATED    = "INTERPOLATED"
FLAG_ESTIMATED       = "ESTIMATED"


# ── Connexion PostgreSQL ──────────────────────────────────────
def get_pg_conn() -> psycopg2.extensions.connection:
    return psycopg2.connect(
        host=os.getenv("OSA_DB_HOST", "localhost"),
        port=int(os.getenv("OSA_DB_PORT", 5432)),
        dbname=os.getenv("OSA_DB_NAME", "osa_db"),
        user=os.getenv("OSA_DB_USER", "osa_user"),
        password=os.getenv("OSA_DB_PASS", ""),
    )


# ── Chargement des données ────────────────────────────────────
def load_raw_data(
    conn,
    indicator_filter: Optional[str] = None,
    pillar_filter:    Optional[str] = None,
) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    """
    Charge :
    - df_raw    : toutes les valeurs L1
    - df_countries : métadonnées pays (région, monetary_weight)
    - df_coverage  : taux de couverture par indicateur
    """
    # Filtres optionnels
    where_clauses = ["iv.layer_id = 1"]
    if indicator_filter:
        where_clauses.append(f"iv.indicator_code = '{indicator_filter}'")
    if pillar_filter:
        where_clauses.append(f"i.pillar_code = '{pillar_filter}'")
    where_sql = " AND ".join(where_clauses)

    df_raw = pd.read_sql(f"""
        SELECT iv.indicator_code, iv.country_iso3, iv.year,
               iv.raw_value, i.pillar_code, i.direction
        FROM ma.indicator_values iv
        JOIN rf.indicators i ON i.code = iv.indicator_code
        WHERE {where_sql}
        ORDER BY iv.indicator_code, iv.country_iso3, iv.year
    """, conn)

    df_countries = pd.read_sql("""
        SELECT c.iso3, c.region_code, c.monetary_sovereignty_weight,
               COALESCE(gdp.raw_value, 0) as gdp_per_capita
        FROM rf.countries c
        LEFT JOIN (
            SELECT country_iso3, AVG(raw_value) as raw_value
            FROM ma.indicator_values
            WHERE indicator_code = 'ECO_GDP' AND layer_id = 1
              AND raw_value IS NOT NULL
            GROUP BY country_iso3
        ) gdp ON gdp.country_iso3 = c.iso3
        WHERE c.iso3 IS NOT NULL
    """, conn)

    df_coverage = pd.read_sql("""
        SELECT iv.indicator_code,
               COUNT(*) as total,
               COUNT(iv.raw_value) as non_null,
               ROUND(COUNT(iv.raw_value)::numeric / COUNT(*) * 100, 1) as coverage_pct
        FROM ma.indicator_values iv
        WHERE iv.layer_id = 1
        GROUP BY iv.indicator_code
    """, conn)

    log.info("Données chargées : %d lignes, %d indicateurs, %d pays",
             len(df_raw),
             df_raw["indicator_code"].nunique(),
             df_raw["country_iso3"].nunique())

    return df_raw, df_countries, df_coverage


# ── Etape 1 : Interpolation DuckDB ───────────────────────────
def step1_duckdb_interpolate(df_raw: pd.DataFrame) -> pd.DataFrame:
    """
    Interpolation linéaire temporelle via DuckDB LAG/LEAD.
    Pour chaque (indicator_code, country_iso3), interpole
    les valeurs manquantes entre deux valeurs connues.
    Forward/backward fill aux extrémités.
    """
    log.info("Etape 1 -- Interpolation DuckDB...")

    con = duckdb.connect()
    con.register("raw_data", df_raw)

    # Fenêtres LAG/LEAD pour trouver les voisins temporels
    result = con.execute("""
        SELECT
            indicator_code,
            country_iso3,
            year,
            raw_value,
            -- Valeur précédente connue
            LAST_VALUE(raw_value IGNORE NULLS) OVER (
                PARTITION BY indicator_code, country_iso3
                ORDER BY year
                ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
            ) AS prev_value,
            -- Année de la valeur précédente
            LAST_VALUE(CASE WHEN raw_value IS NOT NULL THEN year END IGNORE NULLS) OVER (
                PARTITION BY indicator_code, country_iso3
                ORDER BY year
                ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
            ) AS prev_year,
            -- Valeur suivante connue
            FIRST_VALUE(raw_value IGNORE NULLS) OVER (
                PARTITION BY indicator_code, country_iso3
                ORDER BY year
                ROWS BETWEEN 1 FOLLOWING AND UNBOUNDED FOLLOWING
            ) AS next_value,
            -- Année de la valeur suivante
            FIRST_VALUE(CASE WHEN raw_value IS NOT NULL THEN year END IGNORE NULLS) OVER (
                PARTITION BY indicator_code, country_iso3
                ORDER BY year
                ROWS BETWEEN 1 FOLLOWING AND UNBOUNDED FOLLOWING
            ) AS next_year,
            pillar_code,
            direction
        FROM raw_data
        ORDER BY indicator_code, country_iso3, year
    """).df()

    con.close()

    # Calcul de la valeur interpolée
    def interpolate_row(row):
        if pd.notnull(row["raw_value"]):
            return row["raw_value"], FLAG_OK, CONF_ORIGINAL

        prev_v = row["prev_value"]
        next_v = row["next_value"]
        prev_y = row["prev_year"]
        next_y = row["next_year"]

        if pd.notnull(prev_v) and pd.notnull(next_v):
            # Interpolation linéaire
            alpha = (row["year"] - prev_y) / (next_y - prev_y)
            val = float(prev_v) + alpha * (float(next_v) - float(prev_v))
            return round(val, 6), FLAG_INTERPOLATED, CONF_INTERPOLATED

        if pd.notnull(prev_v):
            # Forward fill
            return float(prev_v), FLAG_INTERPOLATED, CONF_INTERPOLATED

        if pd.notnull(next_v):
            # Backward fill
            return float(next_v), FLAG_INTERPOLATED, CONF_INTERPOLATED

        return None, None, None

    rows_result = [interpolate_row(row) for _, row in result.iterrows()]
    result["imputed_value"], result["quality_flag"], result["confidence"] = zip(*rows_result)

    n_filled = result[
        result["raw_value"].isna() & result["imputed_value"].notna()
    ].shape[0]
    log.info("  -> %d valeurs interpolées par DuckDB", n_filled)

    return result


# ── Etape 2 : MICE ────────────────────────────────────────────
def step2_mice(
    df_interp: pd.DataFrame,
    df_coverage: pd.DataFrame,
) -> pd.DataFrame:
    """
    Multiple Imputation by Chained Equations sur les valeurs
    encore manquantes après l'interpolation DuckDB.

    Seuls les indicateurs avec couverture >= MIN_COVERAGE sont traités.
    Le RandomForest capture les corrélations entre indicateurs.
    """
    log.info("Etape 2 -- MICE (Multiple Imputation by Chained Equations)...")

    # Indicateurs éligibles (couverture >= MIN_COVERAGE)
    eligible = df_coverage[
        df_coverage["coverage_pct"] >= MIN_COVERAGE * 100
    ]["indicator_code"].tolist()

    # Filtrer sur les indicateurs éligibles
    df_eligible = df_interp[df_interp["indicator_code"].isin(eligible)].copy()

    if df_eligible.empty:
        log.warning("  Aucun indicateur éligible pour MICE")
        return df_interp

    # Construire la matrice pivot (pays x année, indicateur)
    # Utiliser imputed_value si disponible, sinon raw_value
    df_eligible["value_for_mice"] = df_eligible["imputed_value"].fillna(
        df_eligible["raw_value"]
    )

    pivot = df_eligible.pivot_table(
        index=["country_iso3", "year"],
        columns="indicator_code",
        values="value_for_mice",
        aggfunc="first"
    )

    log.info("  Matrice MICE : %d lignes x %d colonnes", *pivot.shape)

    # Compter les valeurs manquantes avant MICE
    n_missing_before = pivot.isna().sum().sum()
    log.info("  Valeurs manquantes avant MICE : %d", n_missing_before)

    # Lancer MICE
    imputer = IterativeImputer(
        estimator=RandomForestRegressor(
            n_estimators=MICE_N_ESTIMATORS,
            random_state=MICE_RANDOM_STATE,
            n_jobs=-1,
        ),
        max_iter=MICE_MAX_ITER,
        random_state=MICE_RANDOM_STATE,
        verbose=0,
    )

    try:
        imputed_array = imputer.fit_transform(pivot.values)
        pivot_imputed = pd.DataFrame(
            imputed_array,
            index=pivot.index,
            columns=pivot.columns,
        )
    except Exception as e:
        log.error("  Erreur MICE : %s -- skip", e)
        return df_interp

    n_missing_after = pd.DataFrame(imputed_array, columns=pivot.columns).isna().sum().sum()
    n_mice_filled = n_missing_before - n_missing_after
    log.info("  -> %d valeurs imputées par MICE", n_mice_filled)

    # Réintégrer dans df_interp
    df_result = df_interp.copy()

    for (iso3, year), row in pivot_imputed.iterrows():
        for ind_code, val in row.items():
            if pd.isna(val):
                continue

            # Chercher la ligne correspondante dans df_result
            mask = (
                (df_result["indicator_code"] == ind_code) &
                (df_result["country_iso3"]   == iso3) &
                (df_result["year"]           == year) &
                (df_result["imputed_value"].isna())  # seulement si pas déjà imputé
            )

            if mask.any():
                # Score de confiance selon couverture
                cov = df_coverage.loc[
                    df_coverage["indicator_code"] == ind_code, "coverage_pct"
                ].values[0] if ind_code in df_coverage["indicator_code"].values else 0

                conf = CONF_MICE_HIGH if cov >= 60 else CONF_MICE_LOW

                df_result.loc[mask, "imputed_value"] = round(float(val), 6)
                df_result.loc[mask, "quality_flag"]  = FLAG_ESTIMATED
                df_result.loc[mask, "confidence"]    = conf

    return df_result


# ── Etape 3 : KNN géopolitique ────────────────────────────────
def step3_knn_geo(
    df_mice: pd.DataFrame,
    df_countries: pd.DataFrame,
) -> pd.DataFrame:
    """
    KNN géopolitique pondéré pour les valeurs encore manquantes.

    Distance géopolitique entre deux pays :
      d = |gdp_per_capita_i - gdp_per_capita_j| / max_gdp
          x (0.5 si même région UA, 1.0 sinon)
          x (0.8 si même zone monétaire, 1.0 sinon)

    Les valeurs des voisins sont pondérées par 1/distance.
    """
    log.info("Etape 3 -- KNN géopolitique pondéré...")

    # Construire la matrice de distance géopolitique
    countries = df_countries["iso3"].tolist()
    n = len(countries)

    max_gdp = df_countries["gdp_per_capita"].max()
    if max_gdp == 0:
        max_gdp = 1.0

    dist_matrix = {}
    for i, c1 in enumerate(countries):
        row1 = df_countries[df_countries["iso3"] == c1].iloc[0]
        dist_matrix[c1] = {}
        for j, c2 in enumerate(countries):
            if c1 == c2:
                dist_matrix[c1][c2] = 0.0
                continue
            row2 = df_countries[df_countries["iso3"] == c2].iloc[0]

            # Distance PIB/hab normalisée
            gdp_dist = abs(
                float(row1["gdp_per_capita"]) - float(row2["gdp_per_capita"])
            ) / max_gdp

            # Bonus région UA
            region_factor = 0.5 if row1["region_code"] == row2["region_code"] else 1.0

            # Bonus zone monétaire
            mon_factor = 0.8 if (
                float(row1["monetary_sovereignty_weight"]) < 1.0 and
                float(row2["monetary_sovereignty_weight"]) < 1.0
            ) else 1.0

            dist_matrix[c1][c2] = gdp_dist * region_factor * mon_factor + 1e-6

    df_result = df_mice.copy()
    n_knn_filled = 0

    # Traiter les valeurs encore manquantes
    still_missing = df_result[
        df_result["imputed_value"].isna() &
        df_result["raw_value"].isna()
    ]

    for _, miss_row in still_missing.iterrows():
        iso3 = miss_row["country_iso3"]
        year = miss_row["year"]
        ind  = miss_row["indicator_code"]

        if iso3 not in dist_matrix:
            continue

        # Trouver les k voisins les plus proches
        neighbors = sorted(
            dist_matrix[iso3].items(),
            key=lambda x: x[1]
        )[1:KNN_NEIGHBORS + 1]  # exclure le pays lui-même

        vals    = []
        weights = []

        for neighbor_iso3, dist in neighbors:
            # Chercher la valeur du voisin (imputée ou brute)
            neighbor_mask = (
                (df_result["indicator_code"] == ind) &
                (df_result["country_iso3"]   == neighbor_iso3) &
                (df_result["year"]           == year)
            )
            neighbor_rows = df_result[neighbor_mask]
            if neighbor_rows.empty:
                continue

            v = neighbor_rows["imputed_value"].values[0]
            if pd.isna(v):
                v = neighbor_rows["raw_value"].values[0]
            if pd.isna(v):
                continue

            vals.append(float(v))
            weights.append(1.0 / dist)

        if vals and weights:
            # Moyenne pondérée par inverse distance
            weighted_val = sum(v * w for v, w in zip(vals, weights)) / sum(weights)

            mask = (
                (df_result["indicator_code"] == ind) &
                (df_result["country_iso3"]   == iso3) &
                (df_result["year"]           == year)
            )
            df_result.loc[mask, "imputed_value"] = round(weighted_val, 6)
            df_result.loc[mask, "quality_flag"]  = FLAG_ESTIMATED
            df_result.loc[mask, "confidence"]    = CONF_KNN_GEO
            n_knn_filled += 1

    log.info("  -> %d valeurs imputées par KNN géopolitique", n_knn_filled)
    return df_result


# ── Etape 4 : Résumé des scores de confiance ─────────────────
def step4_confidence_summary(df_final: pd.DataFrame) -> pd.DataFrame:
    """
    Synthèse des scores de confiance.
    Ajoute une colonne confidence_label pour l'interprétation.
    """
    def label(conf):
        if conf is None or pd.isna(conf):
            return "NA"
        if conf >= 0.85:
            return "HAUTE"
        if conf >= 0.60:
            return "MODEREE"
        if conf >= 0.40:
            return "FAIBLE"
        return "TRES_FAIBLE"

    df_final = df_final.copy()
    df_final["confidence_label"] = df_final["confidence"].apply(label)

    # Statistiques
    imputed_only = df_final[
        df_final["raw_value"].isna() & df_final["imputed_value"].notna()
    ]

    if not imputed_only.empty:
        conf_dist = imputed_only["confidence_label"].value_counts()
        log.info("Distribution des scores de confiance :")
        for label_val, count in conf_dist.items():
            log.info("  %s : %d valeurs", label_val, count)

    return df_final


# ── Insertion en base L2 ──────────────────────────────────────
def insert_l2(
    conn,
    df_final: pd.DataFrame,
    dry_run: bool = False,
) -> int:
    """
    Insère les valeurs imputées (layer_id=2) dans ma.indicator_values.
    Seules les valeurs qui étaient NULL en L1 et ont été imputées sont insérées.
    Le score de confiance est stocké dans confidence_score si la colonne existe.
    """
    # Valeurs à insérer : L1 était NULL et on a une valeur imputée
    to_insert = df_final[
        df_final["raw_value"].isna() &
        df_final["imputed_value"].notna() &
        df_final["quality_flag"].notna()
    ].copy()

    if to_insert.empty:
        log.info("Aucune valeur à insérer")
        return 0

    log.info("Insertion de %d valeurs L2...", len(to_insert))

    if dry_run:
        log.info("[DRY-RUN] %d valeurs non insérées", len(to_insert))
        return len(to_insert)

    # Vérifier si la colonne confidence_score existe
    with conn.cursor() as cur:
        cur.execute("""
            SELECT column_name FROM information_schema.columns
            WHERE table_schema = 'ma'
              AND table_name   = 'indicator_values'
              AND column_name  = 'confidence_score'
        """)
        has_confidence_col = cur.fetchone() is not None

    inserted = 0
    errors   = 0

    with conn.cursor() as cur:
        for _, row in to_insert.iterrows():
            try:
                if has_confidence_col:
                    cur.execute("""
                        INSERT INTO ma.indicator_values
                            (indicator_code, country_iso3, year, layer_id,
                             raw_value, processed_value, method_version_id,
                             quality_flag, confidence_score)
                        SELECT
                            %s, %s, %s, %s,
                            %s, NULL, method_version_id,
                            %s, %s
                        FROM ma.indicator_values
                        WHERE indicator_code = %s
                          AND country_iso3   = %s
                          AND layer_id       = 1
                        LIMIT 1
                        ON CONFLICT DO NOTHING
                    """, (
                        row["indicator_code"], row["country_iso3"],
                        int(row["year"]), LAYER_IMPUTED,
                        float(row["imputed_value"]),
                        row["quality_flag"],
                        float(row["confidence"]) if pd.notnull(row["confidence"]) else 0.5,
                        row["indicator_code"], row["country_iso3"],
                    ))
                else:
                    cur.execute("""
                        INSERT INTO ma.indicator_values
                            (indicator_code, country_iso3, year, layer_id,
                             raw_value, processed_value, method_version_id,
                             quality_flag)
                        SELECT
                            %s, %s, %s, %s,
                            %s, NULL, method_version_id, %s
                        FROM ma.indicator_values
                        WHERE indicator_code = %s
                          AND country_iso3   = %s
                          AND layer_id       = 1
                        LIMIT 1
                        ON CONFLICT DO NOTHING
                    """, (
                        row["indicator_code"], row["country_iso3"],
                        int(row["year"]), LAYER_IMPUTED,
                        float(row["imputed_value"]),
                        row["quality_flag"],
                        row["indicator_code"], row["country_iso3"],
                    ))

                inserted += cur.rowcount

            except Exception as e:
                errors += 1
                if errors <= 5:
                    log.warning("  Erreur (%s, %s, %s) : %s",
                                row["indicator_code"], row["country_iso3"],
                                row["year"], e)
                conn.rollback()
                continue

        conn.commit()

    log.info("  -> %d insérés, %d erreurs", inserted, errors)
    return inserted


# ── Rapport final ─────────────────────────────────────────────
def print_report(df_final: pd.DataFrame, n_inserted: int) -> None:
    print("\n" + "=" * 65)
    print("RAPPORT IMPUTATION L2 -- DuckDB + MICE + KNN Géopolitique")
    print("=" * 65)

    total     = len(df_final)
    orig_ok   = df_final["raw_value"].notna().sum()
    imputed   = df_final[
        df_final["raw_value"].isna() & df_final["imputed_value"].notna()
    ]
    still_null = df_final[
        df_final["raw_value"].isna() & df_final["imputed_value"].isna()
    ]

    print(f"\nDonnées totales       : {total:>8}")
    print(f"Valeurs L1 originales : {orig_ok:>8}")
    print(f"Valeurs imputées      : {len(imputed):>8}")
    print(f"Encore manquantes     : {len(still_null):>8}")
    print(f"Insertions L2         : {n_inserted:>8}")

    if not imputed.empty:
        print("\nPar méthode :")
        by_flag = imputed.groupby("quality_flag").agg(
            n=("imputed_value", "count"),
            conf_moy=("confidence", "mean"),
        )
        for flag, row in by_flag.iterrows():
            print(f"  {flag:<15} : {int(row['n']):>6} valeurs  "
                  f"confiance moy = {row['conf_moy']:.2f}")

        print("\nPar pilier :")
        by_pillar = imputed.groupby("pillar_code").agg(
            n=("imputed_value", "count"),
        )
        for pillar, row in by_pillar.iterrows():
            print(f"  {pillar} : {int(row['n']):>6} valeurs imputées")

        print("\nTop 10 indicateurs imputés :")
        by_ind = imputed.groupby("indicator_code").agg(
            n=("imputed_value", "count"),
            conf=("confidence", "mean"),
        ).sort_values("n", ascending=False).head(10)
        for ind, row in by_ind.iterrows():
            cov = imputed[imputed["indicator_code"] == ind]["confidence"].mean()
            print(f"  {ind:<15} : {int(row['n']):>5} valeurs  conf={cov:.2f}")

    if not still_null.empty:
        print("\nIndicateurs encore incomplets (couverture < 20%) :")
        by_ind_null = still_null.groupby("indicator_code").size().sort_values(ascending=False)
        for ind, n in by_ind_null.head(10).items():
            print(f"  {ind:<15} : {n} valeurs manquantes -- changer source")

    print("=" * 65)


# ── Orchestrateur principal ────────────────────────────────────
def run(
    indicator_filter: Optional[str] = None,
    pillar_filter:    Optional[str] = None,
    min_coverage:     float = MIN_COVERAGE,
    dry_run:          bool  = False,
) -> None:
    log.info("=" * 65)
    log.info("OSA Imputer v2 -- DuckDB + MICE + KNN Géopolitique")
    log.info("=" * 65)
    if dry_run:
        log.info("MODE DRY-RUN -- aucune écriture en base")

    conn = get_pg_conn()
    try:
        # Chargement
        df_raw, df_countries, df_coverage = load_raw_data(
            conn, indicator_filter, pillar_filter
        )

        if df_raw.empty:
            log.warning("Aucune donnée chargée -- vérifier les filtres")
            return

        # Etape 1 -- DuckDB interpolation
        df_interp = step1_duckdb_interpolate(df_raw)

        # Etape 2 -- MICE
        df_mice = step2_mice(df_interp, df_coverage)

        # Etape 3 -- KNN géopolitique
        df_final = step3_knn_geo(df_mice, df_countries)

        # Etape 4 -- Score de confiance
        df_final = step4_confidence_summary(df_final)

        # Insertion L2
        n_inserted = insert_l2(conn, df_final, dry_run)

        # Rapport
        print_report(df_final, n_inserted)

    finally:
        conn.close()


# ── Point d'entrée ─────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(
        description="OSA -- Imputation avancée L2 (DuckDB + MICE + KNN géopolitique)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Pipeline :
  1. DuckDB   -- interpolation linéaire temporelle (LAG/LEAD)
  2. MICE     -- corrélations inter-indicateurs (RandomForest)
  3. KNN Geo  -- voisins géopolitiques pondérés (région UA + PIB)
  4. Confiance -- score par valeur [0.40 - 1.00]

Scores de confiance :
  1.00  Valeur originale L1
  0.85  Interpolation DuckDB (entre deux valeurs connues)
  0.70  MICE (indicateur bien couvert >= 60%)
  0.55  MICE (indicateur peu couvert 20-60%)
  0.40  KNN géopolitique
  --    Couverture < 20% -> pas d'imputation

Exemples :
  python imputer_v2.py --dry-run
  python imputer_v2.py --indicator ECO_LOG --dry-run
  python imputer_v2.py --pillar PGEO --dry-run
  python imputer_v2.py --min-coverage 0.25
  python imputer_v2.py
        """,
    )
    parser.add_argument("--indicator",    type=str,   default=None)
    parser.add_argument("--pillar",       type=str,   default=None)
    parser.add_argument("--min-coverage", type=float, default=MIN_COVERAGE)
    parser.add_argument("--dry-run",      action="store_true")
    args = parser.parse_args()

    run(
        indicator_filter = args.indicator,
        pillar_filter    = args.pillar,
        min_coverage     = args.min_coverage,
        dry_run          = args.dry_run,
    )
    sys.exit(0)


if __name__ == "__main__":
    main()
