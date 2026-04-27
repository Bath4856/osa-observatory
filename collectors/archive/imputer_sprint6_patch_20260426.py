# ============================================================
# OSA Observatory — imputer_sprint6_patch.py
# Sprint 6 — Mai 2026
# ============================================================
# Patch à intégrer dans collectors/imputer_v3.py
#
# Priorités 1, 2, 3 :
#   PRES — IEA / IRENA / EIA / FAO AQUASTAT
#   PMIL — SIPRI / GTI / ITU GCI
#   PNUM — ITU Regulatory / ITU GCI / UNESCO EGDI
#
# Ce patch ne modifie PAS la logique d'imputation existante.
# Il précise uniquement :
#   1. Les règles de routing par régime pour les nouveaux piliers
#   2. Les indicateurs à score composite → régime PHYSICAL
#   3. Les cas particuliers de valeurs réelles = 0
#      (pays non-producteurs pétrole/gaz, non-exportateurs armes)
#   4. Les publications biannuelles → interpolation conf 0.75
#
# La logique de routing est 100% dynamique depuis
# collect.v_imputer_config (patch_imputer_metadata.sql).
# Ce fichier documente les règles pour le SQL de migration.
# ============================================================

# ── 1. Règles de régime par pilier ────────────────────────

SPRINT6_REGIME_RULES = {
    # Pilier → régime → justification
    "PRES": {
        "regime":      "PHYSICAL",
        "justification": (
            "Infrastructure énergie/eau quasi-stable, comme PTRA. "
            "Production, capacité et réserves ne varient pas brusquement. "
            "MICE exclu — pas de corrélation utile entre énergie et eau. "
            "KNN exclu — géographie trop différenciée."
        ),
        "conf_scores": {
            "INTERPOLATED": 0.80,   # interpolation intra-pays
            "FFILL":        0.70,   # forward/backward fill
            "REG_MEDIAN":   0.55,   # médiane régionale africaine
        },
    },

    "PMIL": {
        "regime":      "MIXED",     # voir détail ci-dessous
        "justification": (
            "Indicateurs quantitatifs (dépenses militaires, forces armées) "
            "→ régime STANDARD (MICE par pilier, KNN géopolitique). "
            "Scores composites (GTI, GCI, WGI) → régime PHYSICAL. "
            "Le routing dynamique distingue les deux via is_composite_score "
            "dans rf.indicators."
        ),
        "conf_scores": {
            "STANDARD": {"MICE": "dynamic", "KNN": 0.40},
            "PHYSICAL": {"INTERPOLATED": 0.75, "FFILL": 0.60, "REG_MEDIAN": 0.45},
        },
    },

    "PNUM": {
        "regime":      "MIXED",
        "justification": (
            "Indicateurs de pénétration (internet, mobile, broadband) "
            "→ régime STANDARD (évoluent rapidement, MICE utile). "
            "Scores composites (GCI, EGDI, Regulatory) → régime PHYSICAL. "
            "Publication biannuelle → interpolation linéaire conf 0.75."
        ),
        "conf_scores": {
            "STANDARD": {"MICE": "dynamic", "KNN": 0.40},
            "PHYSICAL": {"INTERPOLATED": 0.75, "FFILL": 0.60, "REG_MEDIAN": 0.45},
        },
    },
}


# ── 2. Indicateurs composites → régime PHYSICAL ───────────
#
# À insérer dans patch_imputer_metadata.sql :
#   UPDATE rf.indicators
#   SET imputation_regime = 'PHYSICAL'
#   WHERE code IN (
#     -- PRES scores composites
#     -- (aucun — PRES entier en PHYSICAL)
#
#     -- PMIL scores composites
#     'PMIL_STABILITY_WGI',
#     'PMIL_GTI_TERROR',
#     'PMIL_GCI_CYBER',
#
#     -- PNUM scores composites
#     'PNUM_GOV_EFFECTIVENESS',
#     'PNUM_ITU_REG_ENV',
#     'PNUM_GCI_DIGITAL',
#     'PNUM_EGDI_EGOV',
#     'PNUM_EGDI_ONLINE_SVC',
#     'PNUM_EGDI_HUMAN_CAP'
#   );
#
# Indicateurs PMIL/PNUM en STANDARD (MICE applicable) :
#   'PMIL_DEF_BUDGET_GDP', 'PMIL_DEF_BUDGET_GOV',
#   'PMIL_ARMED_FORCES', 'PMIL_HOMICIDE_RATE',
#   'PNUM_INTERNET_USERS', 'PNUM_BROADBAND_FIXED',
#   'PNUM_BROADBAND_MOBILE', 'PNUM_MOBILE_SUBSCRIPTIONS',
#   'PNUM_SECURE_SERVERS', 'PNUM_TERTIARY_ENROLL'

COMPOSITE_SCORE_INDICATORS = {
    # Pilier PRES — tout en PHYSICAL
    "PRES_ENRG_USE_CAP", "PRES_ENRG_PROD_IEA",
    "PRES_RENEW_CAP_IRENA", "PRES_RENEW_SHARE_FEC",
    "PRES_FOSSIL_RENTS_EIA", "PRES_OIL_RENTS", "PRES_GAS_RENTS",
    "PRES_WATER_FRESH", "PRES_WATER_WITHDRAWAL", "PRES_WATER_AGRI",

    # Pilier PMIL — scores composites seulement
    "PMIL_STABILITY_WGI", "PMIL_GTI_TERROR", "PMIL_GCI_CYBER",

    # Pilier PNUM — scores composites seulement
    "PNUM_GOV_EFFECTIVENESS",
    "PNUM_ITU_REG_ENV", "PNUM_GCI_DIGITAL",
    "PNUM_EGDI_EGOV", "PNUM_EGDI_ONLINE_SVC", "PNUM_EGDI_HUMAN_CAP",
}


# ── 3. Indicateurs avec valeur réelle = 0 ─────────────────

# Analogie avec PTRA_PORT_CAP (pays enclavés) :
# Ces indicateurs ont une valeur réelle = 0 (non-producteur),
# pas une donnée manquante.

ZERO_REAL_VALUES = {
    # Pays non-producteurs de pétrole
    # value_status = OBSERVED, confidence = 0.95
    "PRES_OIL_RENTS": {
        "zero_condition": "production nulle vérifiée (EIA/BP Statistical Review)",
        "non_zero_countries": {
            "DZA", "AGO", "CMR", "CAF", "TCD", "COD", "COG", "GAB",
            "GNQ", "KEN", "LBY", "MDG", "MRT", "MOZ", "NGA", "SDN",
            "SSD", "TUN", "UGA", "ZAF",
        },
        "note": "Pays hors liste → PRES_OIL_RENTS = 0.0 (réel), conf 0.95",
    },

    # Pays non-exportateurs d'armes
    # value_status = OBSERVED, confidence = 0.90
    "PMIL_ARMS_EXPORT": {
        "zero_condition": "SIPRI TIV = 0 sur toute la période",
        "non_zero_countries": {
            "ZAF", "EGY", "MAR",   # exportateurs africains significatifs
        },
        "note": "Pays hors liste → PMIL_ARMS_EXPORT = 0.0 (réel), conf 0.90. "
                "Différent de PMIL_ARMS_IMPORT (tous les pays importent).",
    },
}


# ── 4. Publications biannuelles — conf interpolation ──────

BIANNUAL_INDICATORS = {
    # ITU GCI (~tous les 2-3 ans)
    "PMIL_GCI_CYBER":    0.75,   # conf interpolation linéaire
    "PNUM_GCI_DIGITAL":  0.75,

    # ITU Regulatory (annuel depuis 2017, irrégulier avant)
    "PNUM_ITU_REG_ENV":  0.75,

    # UN EGDI (biannuel — années paires)
    "PNUM_EGDI_EGOV":       0.75,
    "PNUM_EGDI_ONLINE_SVC": 0.75,
    "PNUM_EGDI_HUMAN_CAP":  0.75,

    # GTI (annuel depuis 2008)
    "PMIL_GTI_TERROR":   0.80,   # plus fréquent → conf légèrement supérieure

    # WGI (annuel mais couverture partielle)
    "PMIL_STABILITY_WGI": 0.80,
    "PNUM_GOV_EFFECTIVENESS": 0.80,

    # PRES — fréquence irrégulière FAO/IEA
    "PRES_WATER_FRESH":       0.75,
    "PRES_WATER_WITHDRAWAL":  0.75,
    "PRES_RENEW_CAP_IRENA":   0.78,
}


# ── 5. Normalisation des scores composites ────────────────

SCORE_NORMALIZERS = {
    # WGI scores [-2.5, +2.5] → [0, 100]
    "PMIL_STABILITY_WGI":     {"type": "linear", "in_min": -2.5, "in_max": 2.5},
    "PNUM_GOV_EFFECTIVENESS": {"type": "linear", "in_min": -2.5, "in_max": 2.5},

    # GTI [0, 10] → [0, 100] inversé (10 = pire → score 0)
    "PMIL_GTI_TERROR":        {"type": "linear_inverted", "in_min": 0, "in_max": 10},

    # ITU Regulatory [0, 5] générations → [0, 100]
    "PNUM_ITU_REG_ENV":       {"type": "linear", "in_min": 0, "in_max": 5},

    # EGDI [0, 1] → [0, 100]
    "PNUM_EGDI_EGOV":         {"type": "linear", "in_min": 0, "in_max": 1},
    "PNUM_EGDI_ONLINE_SVC":   {"type": "linear", "in_min": 0, "in_max": 1},
    "PNUM_EGDI_HUMAN_CAP":    {"type": "linear", "in_min": 0, "in_max": 1},

    # GCI déjà en [0, 100] — pas de normalisation
    # LPI (PTRA) déjà géré via multiplier 20.0
}


def normalize_score(value: float, osa_code: str) -> float:
    """
    Normalise un score composite vers [0, 100].
    Appliqué dans le scorer ISA, pas dans l'imputer.
    Documenté ici pour cohérence entre les modules.
    """
    if osa_code not in SCORE_NORMALIZERS:
        return value

    cfg = SCORE_NORMALIZERS[osa_code]
    in_min, in_max = cfg["in_min"], cfg["in_max"]

    if in_max == in_min:
        return 50.0  # fallback si plage nulle

    normalized = (value - in_min) / (in_max - in_min) * 100.0

    if cfg["type"] == "linear_inverted":
        normalized = 100.0 - normalized

    return round(max(0.0, min(100.0, normalized)), 3)


# ── 6. Résumé des actions SQL Sprint 6 ────────────────────
#
# patch_imputer_metadata_sprint6.sql (à créer) :
#
# A. Ajouter colonne is_composite_score si absente :
#    ALTER TABLE rf.indicators
#    ADD COLUMN IF NOT EXISTS is_composite_score BOOLEAN DEFAULT false;
#
# B. Mettre à jour régimes :
#    UPDATE rf.pillars SET imputation_regime = 'PHYSICAL'
#    WHERE code = 'PRES';
#
#    UPDATE rf.indicators SET imputation_regime = 'PHYSICAL'
#    WHERE code IN (...COMPOSITE_SCORE_INDICATORS...);
#
#    UPDATE rf.indicators SET is_composite_score = true
#    WHERE code IN (...COMPOSITE_SCORE_INDICATORS...);
#
# C. Valeurs zéro réelles — ajouter colonne :
#    ALTER TABLE rf.indicators
#    ADD COLUMN IF NOT EXISTS has_structural_zeros BOOLEAN DEFAULT false;
#
#    UPDATE rf.indicators SET has_structural_zeros = true
#    WHERE code IN ('PRES_OIL_RENTS', 'PRES_GAS_RENTS',
#                   'PMIL_ARMS_EXPORT');
#
# D. Mettre à jour collect.v_imputer_config pour inclure
#    les nouvelles colonnes dans la vue.

# ── 7. Tableau récapitulatif des scores de confiance ─────
#
# Régime       │ OBSERVED │ INTERP │ FFILL │ REG_MED │ MICE  │ KNN
# ─────────────┼──────────┼────────┼───────┼─────────┼───────┼──────
# STANDARD     │  1.00    │  0.85  │  0.80 │   —     │ ~dyn  │ 0.40
# PHYSICAL     │  1.00    │  0.80  │  0.70 │  0.55   │  ✗    │  ✗
# INFRA(PTRA)  │  1.00    │  0.75  │  0.60 │  0.45   │  ✗    │  ✗
# ZERO_REAL    │  0.95    │   —    │   —   │   —     │  —    │  —
# BIANNUAL_INT │   —      │  0.75  │   —   │   —     │  —    │  —
# ─────────────┴──────────┴────────┴───────┴─────────┴───────┴──────
#
# PRES → PHYSICAL (conf max 0.80/0.55)
# PMIL → MIXED  : quantitatifs STANDARD, scores PHYSICAL
# PNUM → MIXED  : connectivité STANDARD, scores PHYSICAL
