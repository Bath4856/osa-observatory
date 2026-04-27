# ============================================================
# OSA Observatory — wb_indicator_map_pnum_patch.py
# Sprint 6 — Mai 2026
# ============================================================
# Ajouter ces entrées dans wb_indicator_map.py
# dans le dict WB_INDICATOR_MAP existant.
#
# PRIORITÉ 3 — Pilier PNUM (souveraineté numérique)
#
# Sources :
#   ITU Regulatory    — environnement réglementaire télécom
#   ITU GCI           — cybersécurité (dimensions Capacity + Cooperation)
#   UNESCO / EGDI     — e-gouvernement (UN E-Government Development Index)
#
# Stratégie :
#   WB propose des proxies numériques solides (IT.NET.*, IT.CEL.*)
#   qui complètent les indices non-WB.
#   ITU et EGDI → ingestion CSV native via fetchers dédiés.
#
# Régime d'imputation :
#   Indicateurs quantitatifs WB (accès, pénétration) → STANDARD
#   Scores composites (GCI, EGDI, Regulatory) → PHYSICAL
# ============================================================

# ── Indicateurs WB pour PNUM ──────────────────────────────

PNUM_WB_INDICATORS = {

    # ── Connectivité internet ─────────────────────────────
    "IT.NET.USER.ZS": {
        "osa_code":    "PNUM_INTERNET_USERS",
        "name_fr":     "Utilisateurs internet (% population)",
        "pillar":      "PNUM",
        "unit":        "PCT_POP",
        "direction":   "+",
        "multiplier":  1.0,
        "note":        "Source ITU via WB. ~54 pays africains. Annuel. "
                       "Indicateur central souveraineté numérique.",
    },

    "IT.NET.BBND.P2": {
        "osa_code":    "PNUM_BROADBAND_FIXED",
        "name_fr":     "Abonnements haut débit fixe (pour 100 habitants)",
        "pillar":      "PNUM",
        "unit":        "PER_100",
        "direction":   "+",
        "multiplier":  1.0,
        "note":        "Source ITU via WB. ~52 pays africains. Annuel. "
                       "Très faible en Afrique subsaharienne — fort différenciateur.",
    },

    "IT.CEL.SETS.P2": {
        "osa_code":    "PNUM_MOBILE_SUBSCRIPTIONS",
        "name_fr":     "Abonnements mobile (pour 100 habitants)",
        "pillar":      "PNUM",
        "unit":        "PER_100",
        "direction":   "+",
        "multiplier":  1.0,
        "note":        "Source ITU via WB. ~54 pays africains. Annuel. "
                       "Proxy connectivité mobile — fort en Afrique vs fixe.",
    },

    "IT.NET.SECR.P6": {
        "osa_code":    "PNUM_SECURE_SERVERS",
        "name_fr":     "Serveurs internet sécurisés (pour 1 million hab.)",
        "pillar":      "PNUM",
        "unit":        "PER_1M",
        "direction":   "+",
        "multiplier":  1.0,
        "note":        "Proxy infrastructure numérique souveraine. ~50 pays africains. "
                       "Corrèle avec capacité de cybersécurité.",
    },

    # ── Infrastructure numérique ──────────────────────────
    "IT.NET.BBND.P2": {
        "osa_code":    "PNUM_BROADBAND_MOBILE",
        "name_fr":     "Abonnements haut débit mobile (pour 100 habitants)",
        "pillar":      "PNUM",
        "unit":        "PER_100",
        "direction":   "+",
        "multiplier":  1.0,
        "note":        "Source ITU via WB. Distingue mobile de fixe. "
                       "~52 pays africains.",
    },

    # ── Gouvernance numérique (proxy WB) ──────────────────
    "GE.EST": {
        "osa_code":    "PNUM_GOV_EFFECTIVENESS",
        "name_fr":     "Efficacité gouvernementale (WGI)",
        "pillar":      "PNUM",
        "unit":        "SCORE_NORM",
        "direction":   "+",
        "multiplier":  1.0,     # WGI [-2.5, +2.5] → normaliser dans scorer
        "note":        "Proxy gouvernance numérique / e-gov. Source WB WGI. "
                       "~54 pays africains. Normalisation (val+2.5)/5×100. "
                       "Régime PHYSICAL (score composite).",
    },

    # ── Éducation / capital humain numérique ──────────────
    "SE.TER.ENRR": {
        "osa_code":    "PNUM_TERTIARY_ENROLL",
        "name_fr":     "Taux brut de scolarisation dans le supérieur (%)",
        "pillar":      "PNUM",
        "unit":        "PCT_POP",
        "direction":   "+",
        "multiplier":  1.0,
        "note":        "Proxy capital humain numérique. ~48 pays africains. "
                       "Fréquence irrégulière — interpolation STANDARD.",
    },
}

# ── Indicateurs PNUM natifs non-WB ────────────────────────

PNUM_NATIVE_STUBS = {

    # ITU Regulatory Environment
    # Source : ITU ICT Regulatory Tracker
    # https://www.itu.int/en/ITU-D/Regulatory-Market/Pages/ICTRegTracker.aspx
    # Publié annuellement — score [0,5] par génération réglementaire
    "ITU_REG_GEN": {
        "osa_code":    "PNUM_ITU_REG_ENV",
        "name_fr":     "Environnement réglementaire TIC — génération (ITU Regulatory)",
        "pillar":      "PNUM",
        "unit":        "SCORE_0_5",
        "direction":   "+",
        "multiplier":  20.0,    # [0,5] → ×20 pour [0,100]
        "note":        "Source ITU ICT Regulatory Tracker. ~54 pays africains. "
                       "Annuel. Générations 1 (monopole) à 5 (numérique avancé). "
                       "Régime imputation : PHYSICAL. "
                       "Fetcher : fetcher_itu.py (partagé avec PMIL_GCI).",
    },

    # ITU GCI — dimensions numériques (Capacity + Cooperation)
    # Partagé avec PMIL (voir wb_indicator_map_pmil_patch.py)
    "ITU_GCI_CAPACITY": {
        "osa_code":    "PNUM_GCI_DIGITAL",
        "name_fr":     "Cybersécurité — dimension développement numérique (ITU GCI)",
        "pillar":      "PNUM",
        "unit":        "SCORE_0_100",
        "direction":   "+",
        "multiplier":  1.0,
        "note":        "Source ITU GCI — dimensions Capacity + Cooperation. "
                       "Publication ~biannuelle (2014, 2017, 2018, 2020, 2024). "
                       "DISTINCT de PMIL_GCI_CYBER (dimensions Legal+Technical+Org). "
                       "Régime : PHYSICAL. "
                       "Fetcher : fetcher_itu.py (partagé PMIL/PNUM). "
                       "Interpolation linéaire conf 0.75 pour années vides.",
    },

    # UNESCO / UN EGDI — E-Government Development Index
    # Source : UN DESA (https://publicadministration.un.org/egovkb/)
    # Publié tous les 2 ans depuis 2003
    # 3 composantes : Online Service Index (OSI),
    #                 Telecommunication Infrastructure Index (TII),
    #                 Human Capital Index (HCI)
    "UN_EGDI_SCORE": {
        "osa_code":    "PNUM_EGDI_EGOV",
        "name_fr":     "Indice de développement e-gouvernement (EGDI — ONU)",
        "pillar":      "PNUM",
        "unit":        "SCORE_0_1",
        "direction":   "+",
        "multiplier":  100.0,   # [0,1] → ×100 pour [0,100]
        "note":        "Source UN DESA / EGDI. ~54 pays africains. "
                       "Publication biannuelle (années paires). "
                       "Régime : PHYSICAL — interpolation linéaire conf 0.75. "
                       "Fetcher : fetcher_egdi.py.",
    },

    "UN_EGDI_OSI": {
        "osa_code":    "PNUM_EGDI_ONLINE_SVC",
        "name_fr":     "Indice services en ligne (OSI — composante EGDI)",
        "pillar":      "PNUM",
        "unit":        "SCORE_0_1",
        "direction":   "+",
        "multiplier":  100.0,
        "note":        "Composante EGDI — services gouvernementaux numériques. "
                       "Mesure directe de la maturité e-gov. Biannuel. "
                       "Fetcher : fetcher_egdi.py.",
    },

    "UN_EGDI_HCI": {
        "osa_code":    "PNUM_EGDI_HUMAN_CAP",
        "name_fr":     "Indice capital humain numérique (HCI — composante EGDI)",
        "pillar":      "PNUM",
        "unit":        "SCORE_0_1",
        "direction":   "+",
        "multiplier":  100.0,
        "note":        "Composante EGDI — alphabétisation, scolarisation. "
                       "Complémente SE.TER.ENRR (WB). Biannuel. "
                       "Fetcher : fetcher_egdi.py.",
    },
}

# ── Matrice déduplication PMIL / PNUM (ITU GCI) ───────────
#
# Dimension GCI       │ Pilier │ Code OSA
# ────────────────────┼────────┼──────────────────────
# Legal               │ PMIL   │ PMIL_GCI_CYBER
# Technical           │ PMIL   │ PMIL_GCI_CYBER
# Organizational      │ PMIL   │ PMIL_GCI_CYBER
# Capacity            │ PNUM   │ PNUM_GCI_DIGITAL
# Cooperation         │ PNUM   │ PNUM_GCI_DIGITAL
# ────────────────────┴────────┴──────────────────────
# Un seul fichier GCI chargé → 2 indicateurs distincts.
# Aucune donnée partagée entre piliers.

# ── Fetchers à créer (Sprint 6) ───────────────────────────
#
# fetcher_itu.py  :
#   - ITU ICT Regulatory Tracker → PNUM_ITU_REG_ENV
#   - ITU GCI → PMIL_GCI_CYBER + PNUM_GCI_DIGITAL (split auto)
#
# fetcher_egdi.py :
#   - UN EGDI → PNUM_EGDI_EGOV, PNUM_EGDI_ONLINE_SVC, PNUM_EGDI_HUMAN_CAP
#   Source : https://publicadministration.un.org/egovkb/Data-Center
#   Format : Excel / CSV biannuel
#
# ── Instructions d'intégration ────────────────────────────
#
# Dans wb_indicator_map.py :
#   WB_INDICATOR_MAP.update(PNUM_WB_INDICATORS)
#
# Dans rf.indicators :
#   Quantitatifs WB (IT.NET.*, IT.CEL.*) → STANDARD
#   Scores composites (GCI, EGDI, Regulatory, WGI) → PHYSICAL
#
#   UPDATE rf.indicators SET imputation_regime = 'PHYSICAL'
#   WHERE pillar_code = 'PNUM'
#     AND code IN (
#       'PNUM_ITU_REG_ENV', 'PNUM_GCI_DIGITAL',
#       'PNUM_EGDI_EGOV', 'PNUM_EGDI_ONLINE_SVC', 'PNUM_EGDI_HUMAN_CAP',
#       'PNUM_GOV_EFFECTIVENESS'
#     );
#
# Vérification :
#   SELECT indicator_code, COUNT(*), MIN(year), MAX(year)
#   FROM ma.indicator_values
#   WHERE indicator_code LIKE 'PNUM_%' AND layer_id = 1
#   GROUP BY indicator_code ORDER BY indicator_code;
