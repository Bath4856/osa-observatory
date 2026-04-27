# ============================================================
# OSA Observatory — wb_indicator_map_pmil_patch.py
# Sprint 6 — Mai 2026
# ============================================================
# Ajouter ces entrées dans wb_indicator_map.py
# dans le dict WB_INDICATOR_MAP existant.
#
# PRIORITÉ 2 — Pilier PMIL (souveraineté militaire & sécuritaire)
#
# Sources :
#   SIPRI — importations/exportations d'armements
#   GTI   — Global Terrorism Index (IEP)
#   ITU GCI — Global Cybersecurity Index (cyberdéfense)
#
# Note critique : PMIL est en grande partie NON couvert par
# l'API WB. Les indicateurs ci-dessous sont des proxies WB
# ou des stubs pour ingestion CSV native.
#
# Proxies WB disponibles :
#   MS.MIL.XPND.GD.ZS  — dépenses militaires % PIB (WB/SIPRI)
#   MS.MIL.XPND.ZS     — dépenses militaires % dépenses publiques
#   VC.IHR.PSRC.P5      — homicides intentionnels (proxy instabilité)
#   IC.BUS.EASE.XQ      — environnement des affaires (proxy gouvernance)
#
# Sources CSV/natives à intégrer (fetchers dédiés) :
#   SIPRI → fetcher_sipri.py
#   GTI   → fetcher_gti.py
#   ITU GCI → fetcher_itu.py (partagé avec PNUM)
#
# Régime d'imputation : STANDARD pour indicateurs quantitatifs
#   MICE applicable (dépenses militaires corrèle avec GDP, etc.)
#   GTI et GCI → régime PHYSICAL (scores composites non MICE-ables)
# ============================================================

# ── Indicateurs WB disponibles pour PMIL ─────────────────

PMIL_WB_INDICATORS = {

    # ── Dépenses militaires (WB/SIPRI) ───────────────────
    "MS.MIL.XPND.GD.ZS": {
        "osa_code":    "PMIL_DEF_BUDGET_GDP",
        "name_fr":     "Dépenses militaires (% PIB)",
        "pillar":      "PMIL",
        "unit":        "PCT_GDP",
        "direction":   "+",
        "multiplier":  1.0,
        "note":        "Source WB/SIPRI. ~50 pays africains. Annuel. "
                       "Régime STANDARD — corrèle avec ECO_GDP.",
    },

    "MS.MIL.XPND.ZS": {
        "osa_code":    "PMIL_DEF_BUDGET_GOV",
        "name_fr":     "Dépenses militaires (% dépenses gouvernementales)",
        "pillar":      "PMIL",
        "unit":        "PCT_GOV",
        "direction":   "+",
        "multiplier":  1.0,
        "note":        "Source WB/SIPRI. ~48 pays africains. Annuel. "
                       "Complémentaire à PMIL_DEF_BUDGET_GDP.",
    },

    "MS.MIL.TOTL.P1": {
        "osa_code":    "PMIL_ARMED_FORCES",
        "name_fr":     "Personnel des forces armées (total)",
        "pillar":      "PMIL",
        "unit":        "COUNT_N",
        "direction":   "+",
        "multiplier":  1.0,
        "note":        "Source WB/IISS. ~48 pays africains. Couverture limitée. "
                       "Fréquence annuelle.",
    },

    # ── Sécurité interne (proxy instabilité) ──────────────
    "VC.IHR.PSRC.P5": {
        "osa_code":    "PMIL_HOMICIDE_RATE",
        "name_fr":     "Taux d'homicides intentionnels (pour 100 000 hab.)",
        "pillar":      "PMIL",
        "unit":        "RATE_100K",
        "direction":   "-",     # plus élevé = moins de sécurité interne
        "multiplier":  1.0,
        "note":        "Proxy instabilité interne. Direction négative. "
                       "~52 pays africains. Source UNODC via WB.",
    },

    "PV.EST": {
        "osa_code":    "PMIL_STABILITY_WGI",
        "name_fr":     "Stabilité politique et absence de violence (WGI)",
        "pillar":      "PMIL",
        "unit":        "SCORE_NORM",
        "direction":   "+",
        "multiplier":  1.0,     # WGI est sur [-2.5, +2.5] → normaliser en post-traitement
        "note":        "Source WB WGI (Worldwide Governance Indicators). "
                       "~54 pays africains. Annuel. "
                       "Normalisation [0,100] : (val + 2.5) / 5 × 100 dans le scorer.",
    },
}

# ── Indicateurs PMIL natifs non-WB ────────────────────────
#
# Ces indicateurs nécessitent des fetchers CSV dédiés.
# Aucun proxy WB satisfaisant n'existe.

PMIL_NATIVE_STUBS = {
    # SIPRI Arms Transfer Database
    # https://www.sipri.org/databases/armstransfers
    # Format CSV — licence libre pour usage non-commercial
    "SIPRI_ARMS_IMPORT": {
        "osa_code":    "PMIL_ARMS_IMPORT",
        "name_fr":     "Importations d'armements (TIV SIPRI, millions USD constants)",
        "pillar":      "PMIL",
        "unit":        "USD_M_CONST",
        "direction":   "+",
        "multiplier":  1.0,
        "note":        "Source SIPRI TIV (Trend Indicator Value). "
                       "Annuel 1950+. ~54 pays africains. "
                       "Fetcher : fetcher_sipri.py — ingestion CSV natif.",
    },

    "SIPRI_ARMS_EXPORT": {
        "osa_code":    "PMIL_ARMS_EXPORT",
        "name_fr":     "Exportations d'armements (TIV SIPRI, millions USD constants)",
        "pillar":      "PMIL",
        "unit":        "USD_M_CONST",
        "direction":   "+",
        "multiplier":  1.0,
        "note":        "Source SIPRI TIV. Très faible pour Afrique subsaharienne "
                       "(quelques exportateurs : ZAF, EGY). "
                       "0 = non-exportateur (valeur réelle). "
                       "Fetcher : fetcher_sipri.py.",
    },

    # GTI — Global Terrorism Index (IEP)
    # https://www.economicsandpeace.org/research/#gti
    # Publié annuellement — CSV téléchargeable
    "GTI_SCORE": {
        "osa_code":    "PMIL_GTI_TERROR",
        "name_fr":     "Indice mondial du terrorisme (GTI score)",
        "pillar":      "PMIL",
        "unit":        "SCORE_0_10",
        "direction":   "-",     # score élevé = plus de terrorisme
        "multiplier":  1.0,     # inverser dans scorer : (10 - val) / 10 × 100
        "note":        "Source IEP (Institute for Economics & Peace). "
                       "Annuel depuis 2008. ~54 pays africains. "
                       "Régime imputation : PHYSICAL (score composite). "
                       "Fetcher : fetcher_gti.py — ingestion CSV natif.",
    },

    # ITU GCI — Global Cybersecurity Index
    # https://www.itu.int/en/ITU-D/Cybersecurity/Pages/global-cybersecurity-index.aspx
    # Publié tous les 2-3 ans (2014, 2017, 2018, 2020, 2024)
    # PARTAGÉ avec PNUM — même fetcher fetcher_itu.py
    "ITU_GCI_SCORE": {
        "osa_code":    "PMIL_GCI_CYBER",
        "name_fr":     "Indice mondial cybersécurité — dimension défense (ITU GCI)",
        "pillar":      "PMIL",
        "unit":        "SCORE_0_100",
        "direction":   "+",
        "multiplier":  1.0,
        "note":        "Source ITU GCI. Publication ~biannuelle. "
                       "NB : même source que PNUM_GCI_DIGITAL — "
                       "dimension 'Legal' + 'Technical' extraite pour PMIL, "
                       "dimension 'Development' pour PNUM. "
                       "Régime imputation : PHYSICAL. "
                       "Fetcher : fetcher_itu.py (partagé PMIL/PNUM).",
    },
}

# ── Note sur la déduplication ITU GCI (PMIL vs PNUM) ─────
#
# ITU GCI publie 5 dimensions :
#   Legal        → PMIL (cadre légal cybersécurité)
#   Technical    → PMIL (capacités techniques défensives)
#   Organizational → PMIL
#   Capacity     → PNUM (développement numérique)
#   Cooperation  → PNUM (connectivité internationale)
#
# Implémentation recommandée :
#   PMIL_GCI_CYBER  = moyenne(Legal, Technical, Organizational)
#   PNUM_GCI_DIGITAL = moyenne(Capacity, Cooperation)
#   → Pas de redondance inter-piliers.
#
# fetcher_itu.py charge le fichier GCI complet une fois
# et génère les deux indicateurs séparément.
# ============================================================

# ── Instructions d'intégration ────────────────────────────
#
# Dans wb_indicator_map.py :
#   WB_INDICATOR_MAP.update(PMIL_WB_INDICATORS)
#
# Dans rf.indicators — pour chaque code PMIL :
#   Régime WB quantitatifs (DEF_BUDGET, ARMED_FORCES) → STANDARD
#   Régime scores composites (GTI, GCI, WGI) → PHYSICAL
#
#   UPDATE rf.indicators SET imputation_regime = 'PHYSICAL'
#   WHERE pillar_code = 'PMIL'
#     AND code IN ('PMIL_STABILITY_WGI', 'PMIL_GTI_TERROR', 'PMIL_GCI_CYBER');
#
# Fetchers à créer (Sprint 6) :
#   collectors/fetcher_sipri.py   — SIPRI Arms Transfer Database
#   collectors/fetcher_gti.py     — GTI (IEP CSV)
#   collectors/fetcher_itu.py     — ITU GCI (partagé PMIL + PNUM)
#
# Vérification :
#   SELECT indicator_code, COUNT(*), MIN(year), MAX(year)
#   FROM ma.indicator_values
#   WHERE indicator_code LIKE 'PMIL_%' AND layer_id = 1
#   GROUP BY indicator_code ORDER BY indicator_code;
