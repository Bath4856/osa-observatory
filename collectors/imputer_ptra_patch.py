# ============================================================
# OSA Observatory — imputer_ptra_patch.py
# Sprint 5 — Avril 2026
# ============================================================
# Patch à intégrer dans collectors/imputer.py
#
# PTRA = infrastructure physique dure — même logique que PRES,
# mais encore plus conservative (infrastructures quasi-stables).
#
# Différences clés vs PRES :
#   - Pays enclavés : PTRA_PORT_CAP/CONNECT = 0 réel, pas NaN
#   - KNN exclu complètement (trop risqué pour infra lourde)
#   - Scores de confiance plus bas (médiane régionale 0.45 vs 0.55)
#   - Pas de fallback médiane mondiale
#   - Seuil 50% données manquantes → ne pas imputer du tout
# ============================================================

# ── 1. Fonction de détection ──────────────────────────────

def is_ptra_indicator(indicator_code: str) -> bool:
    """
    Retourne True si l'indicateur appartient au pilier PTRA.
    Exclu du MICE global — infrastructure physique non devinable.
    """
    return str(indicator_code).startswith("PTRA_")


# ── 2. Constantes pays enclavés ───────────────────────────

PTRA_ZERO_FOR_LANDLOCKED = {
    "PTRA_PORT_CAP",
    "PTRA_PORT_CONNECT",
}

LANDLOCKED_AFRICA = {
    "BFA", "BDI", "CAF", "TCD", "ETH", "LSO", "MWI",
    "MLI", "NER", "RWA", "SSD", "SWZ", "UGA", "ZMB", "ZWE", "BWA",
}


# ── 3. Chaîne d'imputation PTRA ───────────────────────────

def step_ptra_imputation(
    df_ptra,
    country_col:    str = "country_iso3",
    indicator_col:  str = "indicator_code",
    year_col:       str = "year",
    value_col:      str = "processed_value",
    confidence_col: str = "confidence_score",
    method_col:     str = "value_status",
):
    """
    Imputation conservative pour les indicateurs PTRA.

    Chaîne :
      0. Zéro explicite pour pays enclavés (PTRA_PORT_*)  → conf 0.95
      1. Interpolation temporelle intra-pays               → conf 0.75
      2. Forward/backward fill intra-pays                  → conf 0.60
      3. Médiane régionale africaine (si < 50% manquants)  → conf 0.45

    MICE exclu. KNN exclu.
    """
    import pandas as pd

    df = df_ptra.copy()

    # ── Étape 0 — zéro pour pays enclavés ────────────────
    mask_landlocked = (
        df[indicator_col].isin(PTRA_ZERO_FOR_LANDLOCKED) &
        df[country_col].isin(LANDLOCKED_AFRICA) &
        df[value_col].isna()
    )
    df.loc[mask_landlocked, value_col]      = 0.0
    df.loc[mask_landlocked, confidence_col] = 0.95
    df.loc[mask_landlocked, method_col]     = "ZERO_LANDLOCKED"

    # ── Étape 1 — interpolation temporelle ───────────────
    def interpolate_country(group):
        was_na = group[value_col].isna().copy()
        group = group.sort_values(year_col)
        group[value_col] = group[value_col].interpolate(
            method="linear", limit_direction="both"
        )
        newly_filled = was_na & group[value_col].notna()
        group.loc[newly_filled, confidence_col] = 0.75
        group.loc[newly_filled, method_col]     = "INTERPOLATED"
        return group

    df = df.groupby([country_col, indicator_col], group_keys=False)\
           .apply(interpolate_country)

    # ── Étape 2 — forward/backward fill ──────────────────
    def ffill_country(group):
        was_na = group[value_col].isna().copy()
        group = group.sort_values(year_col)
        group[value_col] = group[value_col].ffill().bfill()
        newly_filled = was_na & group[value_col].notna()
        group.loc[newly_filled, confidence_col] = 0.60
        group.loc[newly_filled, method_col]     = "FORWARD_FILL"
        return group

    df = df.groupby([country_col, indicator_col], group_keys=False)\
           .apply(ffill_country)

    # ── Étape 3 — médiane régionale africaine ─────────────
    for indicator in df[indicator_col].unique():
        mask_ind     = df[indicator_col] == indicator
        missing_rate = df.loc[mask_ind, value_col].isna().mean()

        if missing_rate == 0:
            continue
        if missing_rate > 0.50:
            # Trop peu de données — ne pas inventer une médiane
            continue

        regional_median = (
            df.loc[mask_ind]
            .groupby(year_col)[value_col]
            .median()
        )

        for year, median_val in regional_median.items():
            if pd.isna(median_val):
                continue
            mask_fill = (
                mask_ind &
                (df[year_col] == year) &
                df[value_col].isna()
            )
            df.loc[mask_fill, value_col]      = median_val
            df.loc[mask_fill, confidence_col] = 0.45
            df.loc[mask_fill, method_col]     = "REGIONAL_MEDIAN"

    return df


# ── 4. Routing dans run() ─────────────────────────────────
# Remplacer le bloc de routing existant dans run() :
#
#   AVANT (2 régimes) :
#   ─────────────────────────────────────────────
#   df_pres     = df[df["indicator_code"].apply(is_pres_indicator)]
#   df_non_pres = df[~df["indicator_code"].apply(is_pres_indicator)]
#   df_pres_imp = step_pres_imputation(df_pres)
#   df_std_imp  = run_mice(df_non_pres)
#   df_result   = pd.concat([df_pres_imp, df_std_imp])
#
#   APRÈS (3 régimes) :
#   ─────────────────────────────────────────────
#   is_pres = df["indicator_code"].apply(is_pres_indicator)
#   is_ptra = df["indicator_code"].apply(is_ptra_indicator)
#
#   df_pres     = df[is_pres]
#   df_ptra     = df[is_ptra]
#   df_standard = df[~is_pres & ~is_ptra]
#
#   df_pres_imp = step_pres_imputation(df_pres)
#   df_ptra_imp = step_ptra_imputation(df_ptra)
#   df_std_imp  = run_mice(df_standard)
#
#   df_result = pd.concat([df_pres_imp, df_ptra_imp, df_std_imp])


# ── 5. Tableau récapitulatif des scores de confiance ─────
#
# Régime       │ OBSERVED │ INTERP │ FFILL │ REG_MED │ MICE │ KNN
# ─────────────┼──────────┼────────┼───────┼─────────┼──────┼─────
# STANDARD     │  1.00    │  —     │  —    │  —      │ 0.60 │ 0.55
# PRES         │  1.00    │  0.85  │ 0.70  │  0.55   │  ✗   │ léger
# PTRA         │  1.00    │  0.75  │ 0.60  │  0.45   │  ✗   │  ✗
# ZERO_LL      │  0.95    │  —     │  —    │  —      │  —   │  —
# ─────────────┴──────────┴────────┴───────┴─────────┴──────┴─────
# ZERO_LL = zéro réel pour pays enclavés (PTRA_PORT_*)
