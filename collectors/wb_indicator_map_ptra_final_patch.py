# ============================================================
# OSA Observatory — wb_indicator_map_ptra_final_patch.py
# Sprint 6 — Avril 2026
# ============================================================
# Mapping FINAL — 10 indicateurs PTRA retenus
# Fenêtre cible : 2010–2024 · 54 pays africains
#
# Ce fichier remplace wb_indicator_map_ptra_patch.py (Sprint 5).
# Il inclut les 5 indicateurs Sprint 5 + 5 nouveaux.
#
# Résumé des 10 indicateurs :
#
#   BLOC ROUTIER (2)
#   ─────────────────────────────────────────────────────────
#   PTRA_RD_DENSITY    IS.ROD.DNST.K2   ~45 pays  ~55%  irrég.
#   PTRA_RD_PAVED      IS.ROD.PAVE.ZS   ~48 pays  ~58%  irrég.
#
#   BLOC AÉRIEN (3)
#   ─────────────────────────────────────────────────────────
#   PTRA_AIR_PASSENGERS IS.AIR.PSGR     ~52 pays  ~85%  annuel
#   PTRA_AIR_CARGO      IS.AIR.GOOD.MT.K1 ~48 pays ~78% annuel
#   PTRA_AIR_AIRPORTS   IS.AIR.DPRT     ~44 pays  ~65%  annuel (proxy)
#
#   BLOC MARITIME & PORTUAIRE (2)
#   ─────────────────────────────────────────────────────────
#   PTRA_PORT_CAP      IS.SHP.GOOD.TU   ~35 côtiers + 15 zéros enclavés
#   PTRA_PORT_CONNECT  IS.SHP.GCNW.XQ   ~40 pays  ~72%  annuel
#                      + UNCTAD LSCI CSV (voir URLs section ci-dessous)
#
#   BLOC LOGISTIQUE (3)
#   ─────────────────────────────────────────────────────────
#   PTRA_LOG_LPI       LP.LPI.OVRL.XQ   ~139 pays ~47%  biann.
#   PTRA_RD_QUALITY    IQ.CPA.TRAN.XQ   ~39 pays  ~62%  annuel (⚠ CPIA)
#   PTRA_LOG_CONNECT   IS.SHP.GCNW.XQ   → alias PTRA_PORT_CONNECT (non dupliqué)
#
# ──────────────────────────────────────────────────────────
# URLS DE TÉLÉCHARGEMENT — SOURCES PRIMAIRES
# ──────────────────────────────────────────────────────────
#
# WB API (tous indicateurs IS.*/LP.*/IQ.*) :
#   https://api.worldbank.org/v2/country/all/indicator/{CODE}
#   ?date=2010:2024&format=json&per_page=500
#   Documentation : https://datahelpdesk.worldbank.org/knowledgebase/articles/889392
#
# LSCI UNCTAD — données annuelles (recommandé ISA) :
#   https://unctadstat.unctad.org/datacentre/dataviewer/US.LSCI
#   → Sélectionner : All countries · 2010–2024 · Download CSV
#
# LSCI UNCTAD — données mensuelles (granularité maximale) :
#   https://unctadstat.unctad.org/datacentre/dataviewer/US.LSCI_M
#
# LSCI via WB API (alternative sans fetcher CSV dédié) :
#   Code WB : IS.SHP.GCNW.XQ
#   https://data.worldbank.org/indicator/IS.SHP.GCNW.XQ
#   Note : WB reprend le LSCI UNCTAD avec un léger décalage de publication.
#          Préférer le CSV UNCTAD natif pour contrôle de la rupture 2024.
#
# ⚠️  RUPTURE DE SÉRIE LSCI — MARS 2024
#   La CNUCED a révisé sa méthodologie en mars 2024 :
#   Avant 2024 : base 100 = valeur maximale mondiale Q1 2006
#   Depuis 2024 : base 100 = valeur MOYENNE mondiale Q1 2006
#   → Les valeurs post-2024 ne sont PAS comparables aux valeurs antérieures
#     sans renormalisation. Voir :
#     https://unctad.org/news/regional-analysis-liner-shipping-connectivity-what-does-revised-lsci-reveal
#   → fetcher_unctad.py doit normaliser les deux séries sur une base commune
#     avant ingestion dans ma.indicator_values.
#
# LPI World Bank — dataset complet 2007–2023 :
#   https://lpi.worldbank.org/international/global
#   (bouton Download → Excel/CSV)
#
# IRF World Road Statistics (référence — non intégré Sprint 6) :
#   https://worldroadstatistics.org/data/
#   Couverture : 2018–2023 uniquement. Série 2010–2017 absente.
#
# ============================================================

# ── Mapping complet WB_INDICATOR_MAP — 10 indicateurs PTRA ─

PTRA_WB_INDICATORS_FINAL = {

    # ══════════════════════════════════════════════════════
    # BLOC ROUTIER
    # Sources : IRF World Road Statistics compilé par WB/WDI
    # Fréquence : irrégulière (recensements nationaux 3–7 ans)
    # Note qualité : sous-estimation IRF ~134% vs OSM (PLOS One 2017)
    #   — biais systématique acceptable pour comparaisons intra-africaines
    # ══════════════════════════════════════════════════════

    "IS.ROD.DNST.K2": {
        "osa_code":      "PTRA_RD_DENSITY",
        "name_fr":       "Densité du réseau routier (km / km² superficie)",
        "pillar":        "PTRA",
        "unit":          "KM_KM2",
        "direction":     "+",
        "multiplier":    1.0,
        "imputation_regime": "INFRASTRUCTURE",
        "has_structural_zeros": False,
        "wb_api_url":    "https://api.worldbank.org/v2/country/all/indicator/IS.ROD.DNST.K2?date=2010:2024&format=json&per_page=500",
        "note":          "Source IRF via WB. Couverture ~45 pays africains. "
                         "Fréquence irrégulière — interpolation INFRASTRUCTURE conf 0.75. "
                         "Sous-estimation IRF connue, cohérente entre pays (acceptable pour ISA).",
    },

    "IS.ROD.PAVE.ZS": {
        "osa_code":      "PTRA_RD_PAVED",
        "name_fr":       "Routes pavées (% du réseau total)",
        "pillar":        "PTRA",
        "unit":          "PCT_RD",
        "direction":     "+",
        "multiplier":    1.0,
        "imputation_regime": "INFRASTRUCTURE",
        "has_structural_zeros": False,
        "wb_api_url":    "https://api.worldbank.org/v2/country/all/indicator/IS.ROD.PAVE.ZS?date=2010:2024&format=json&per_page=500",
        "note":          "Source IRF via WB. Couverture ~48 pays africains. "
                         "Meilleure couverture que IS.ROD.DNST.K2. "
                         "Fréquence irrégulière — interpolation conf 0.75.",
    },

    # ══════════════════════════════════════════════════════
    # BLOC AÉRIEN
    # Source : ICAO (Organisation de l'Aviation Civile Internationale)
    #          compilé par WB/WDI — données déclarées par États membres
    # Fréquence : annuelle, série continue depuis 1970
    # ══════════════════════════════════════════════════════

    "IS.AIR.PSGR": {
        "osa_code":      "PTRA_AIR_PASSENGERS",
        "name_fr":       "Passagers aériens transportés (total)",
        "pillar":        "PTRA",
        "unit":          "PAX",
        "direction":     "+",
        "multiplier":    1.0,
        "imputation_regime": "INFRASTRUCTURE",
        "has_structural_zeros": False,
        "wb_api_url":    "https://api.worldbank.org/v2/country/all/indicator/IS.AIR.PSGR?date=2010:2024&format=json&per_page=500",
        "note":          "Source ICAO via WB. Couverture ~52 pays africains. Annuel 1970–2023. "
                         "Indicateur le plus continu du pilier PTRA. "
                         "NaN = compagnie nationale non déclarante (pas zéro).",
    },

    "IS.AIR.GOOD.MT.K1": {
        "osa_code":      "PTRA_AIR_CARGO",
        "name_fr":       "Fret aérien (millions de tonnes-kilomètres)",
        "pillar":        "PTRA",
        "unit":          "TONNES_MT_KM",
        "direction":     "+",
        "multiplier":    1.0,
        "imputation_regime": "INFRASTRUCTURE",
        "has_structural_zeros": False,
        "wb_api_url":    "https://api.worldbank.org/v2/country/all/indicator/IS.AIR.GOOD.MT.K1?date=2010:2024&format=json&per_page=500",
        "note":          "Source ICAO via WB. Couverture ~48 pays africains. Annuel 1970–2023. "
                         "Pays sans fret aérien enregistré → NaN, pas 0. "
                         "Séries discontinues pour pays à faible trafic (imputation conf 0.75).",
    },

    "IS.AIR.DPRT": {
        "osa_code":      "PTRA_AIR_AIRPORTS",
        "name_fr":       "Départs de vols enregistrés (proxy activité aéroportuaire)",
        "pillar":        "PTRA",
        "unit":          "COUNT_DEPARTURES",
        "direction":     "+",
        "multiplier":    1.0,
        "imputation_regime": "INFRASTRUCTURE",
        "has_structural_zeros": False,
        "is_proxy":      True,
        "proxy_note":    "Proxy pour nombre d'aéroports actifs. "
                         "Départs ≠ nombre physique d'aéroports, mais mesure l'activité "
                         "aéroportuaire effective — plus pertinent pour PTRA que le décompte brut. "
                         "Source ICAO directe non accessible via API publique gratuite.",
        "wb_api_url":    "https://api.worldbank.org/v2/country/all/indicator/IS.AIR.DPRT?date=2010:2024&format=json&per_page=500",
        "note":          "Source ICAO via WB. Couverture ~44 pays africains. Annuel. "
                         "Confiance d'imputation légèrement réduite (0.70/0.50) vs indicateurs directs "
                         "en raison du caractère proxy.",
    },

    # ══════════════════════════════════════════════════════
    # BLOC MARITIME & PORTUAIRE
    # Sources : WB WDI + UNCTAD LSCI
    # ══════════════════════════════════════════════════════

    "IS.SHP.GOOD.TU": {
        "osa_code":      "PTRA_PORT_CAP",
        "name_fr":       "Containers portuaires traités (TEU — Twenty-foot Equivalent Units)",
        "pillar":        "PTRA",
        "unit":          "COUNT_TEU",
        "direction":     "+",
        "multiplier":    1.0,
        "imputation_regime": "INFRASTRUCTURE",
        "has_structural_zeros": True,
        "structural_zero_condition": "Pays enclavés africains (15 pays) = 0 réel, conf 0.95. "
                                     "Exception : pays avec accord portuaire actif dans rf.port_agreements "
                                     "→ valeur proxy calculée (méthode PTRA_PROXY_ACCORD).",
        "wb_api_url":    "https://api.worldbank.org/v2/country/all/indicator/IS.SHP.GOOD.TU?date=2010:2024&format=json&per_page=500",
        "note":          "Source WB/UNCTAD. Couverture ~35 pays côtiers africains + 15 zéros enclavés. "
                         "Annuel 2000–2022. Couvre les ports à containers significatifs. "
                         "Pays côtiers sans infrastructure container → NaN (imputation conf 0.60).",
    },

    "IS.SHP.GCNW.XQ": {
        "osa_code":      "PTRA_PORT_CONNECT",
        "name_fr":       "Connectivité maritime — Liner Shipping Connectivity Index (LSCI UNCTAD)",
        "pillar":        "PTRA",
        "unit":          "SCORE_LSCI",
        "direction":     "+",
        "multiplier":    1.0,
        "imputation_regime": "INFRASTRUCTURE",
        "has_structural_zeros": True,
        "structural_zero_condition": "Pays enclavés africains = 0 réel (pas de façade maritime), conf 0.95.",
        "wb_api_url":    "https://api.worldbank.org/v2/country/all/indicator/IS.SHP.GCNW.XQ?date=2010:2024&format=json&per_page=500",
        "unctad_csv_annual":   "https://unctadstat.unctad.org/datacentre/dataviewer/US.LSCI",
        "unctad_csv_monthly":  "https://unctadstat.unctad.org/datacentre/dataviewer/US.LSCI_M",
        "unctad_methodology":  "https://unctad.org/news/regional-analysis-liner-shipping-connectivity-what-does-revised-lsci-reveal",
        "serie_break_2024":    True,
        "serie_break_note":    "Révision méthodologique UNCTAD mars 2024 : base 100 = max 2006 → moyenne 2006. "
                               "Série 2010–2023 et série 2024 non directement comparables. "
                               "fetcher_unctad.py doit normaliser avant ingestion. "
                               "Recommandation : multiplier série pré-2024 par facteur de conversion "
                               "calculé sur l'année de chevauchement (Q1 2024).",
        "note":          "Source UNCTAD via WB (IS.SHP.GCNW.XQ) ou CSV natif UNCTADStat. "
                         "Couverture ~40 pays africains côtiers. Annuel 2004–2024. "
                         "CSV UNCTAD préféré pour contrôle de la rupture de série 2024. "
                         "WB API acceptable si délai de publication acceptable.",
    },

    # ══════════════════════════════════════════════════════
    # BLOC LOGISTIQUE
    # ══════════════════════════════════════════════════════

    "LP.LPI.OVRL.XQ": {
        "osa_code":      "PTRA_LOG_LPI",
        "name_fr":       "Indice de Performance Logistique global (LPI — Banque Mondiale)",
        "pillar":        "PTRA",
        "unit":          "SCORE_0_100",
        "direction":     "+",
        "multiplier":    20.0,
        # LPI natif sur [1,5] → ×20 pour obtenir [20,100]
        "imputation_regime": "INFRASTRUCTURE",
        "is_composite_score": True,
        "has_structural_zeros": False,
        "publication_years":   [2007, 2010, 2012, 2014, 2016, 2018, 2023],
        "gap_note":    "Gap 2019–2022 dû à COVID-19 et refonte méthodologique WB. "
                       "Interpolation linéaire entre 2018 et 2023 valide (conf 0.75) : "
                       "performance logistique évolue lentement.",
        "migration_note": "Migré de PECO (ECO_LOG) vers PTRA au Sprint 5. "
                          "rf.indicators mis à jour : pillar_code PECO → PTRA.",
        "wb_api_url":    "https://api.worldbank.org/v2/country/all/indicator/LP.LPI.OVRL.XQ?date=2010:2024&format=json&per_page=500",
        "lpi_dataset_url": "https://lpi.worldbank.org/international/global",
        "note":          "Score composite — régime PHYSICAL (non MICE). "
                         "~139 pays couverts dans l'édition 2023. "
                         "fetcher_wb.py gère automatiquement via LP.LPI.OVRL.XQ.",
    },

    "IQ.CPA.TRAN.XQ": {
        "osa_code":      "PTRA_RD_QUALITY",
        "name_fr":       "Qualité des politiques de transport (CPIA 2.1 — Banque Mondiale)",
        "pillar":        "PTRA",
        "unit":          "SCORE_1_6",
        "direction":     "+",
        "multiplier":    (100.0 / 5.0),
        # CPIA sur [1,6] → ×20 pour obtenir [20,120] → corriger : (val-1)/5×100 dans scorer
        "imputation_regime": "INFRASTRUCTURE",
        "is_composite_score": True,
        "has_structural_zeros": False,
        "conceptual_caveat": True,
        "caveat_note":   "⚠ RÉSERVE DOCUMENTÉE : CPIA 2.1 mesure la qualité des POLITIQUES "
                         "de transport (gouvernance, réglementation, planification), "
                         "PAS la qualité physique des routes ou des infrastructures. "
                         "Inclus comme indicateur de capacité institutionnelle de transport. "
                         "À documenter explicitement dans le rapport méthodologique ISA. "
                         "Corrélation avec infrastructure physique réelle est positive "
                         "mais imparfaite.",
        "coverage_note": "Limité aux pays éligibles IDA (~39 pays africains). "
                         "Pays non-IDA (Afrique du Nord, ZAF, AGO, NGA récemment) → NaN.",
        "wb_api_url":    "https://api.worldbank.org/v2/country/all/indicator/IQ.CPA.TRAN.XQ?date=2010:2024&format=json&per_page=500",
        "note":          "Source WB CPIA. Couverture ~39 pays africains éligibles IDA. "
                         "Annuel 2005–2023. Score 1 (très faible) à 6 (très élevé). "
                         "Normalisation recommandée dans scorer : (val - 1) / 5 × 100.",
    },
}


# ══════════════════════════════════════════════════════════
# INDICATEURS EXCLUS — DOCUMENTATION
# (pour traçabilité et Sprint suivant)
# ══════════════════════════════════════════════════════════

PTRA_EXCLUDED_INDICATORS = {

    "PTRA_RD_TOTAL": {
        "candidate_source":  "IRF World Road Statistics CSV",
        "candidate_url":     "https://worldroadstatistics.org/data/",
        "exclusion_reason":  "Série disponible 2018–2023 uniquement (édition libre 2025). "
                             "Manque 2010–2017 (47% de la fenêtre ISA). "
                             "Incohérences inter-annuelles documentées pour Afrique "
                             "(PLOS One 2017, IRF ~134% sous-estimation vs OSM). "
                             "À réintégrer si série historique complète disponible.",
        "sprint_target":     "Sprint 8+ (conditionnel accès données)",
    },

    "PTRA_RAIL_LINES": {
        "candidate_source":  "WB WDI IS.RRS.TOTL.KM",
        "candidate_url":     "https://api.worldbank.org/v2/country/all/indicator/IS.RRS.TOTL.KM",
        "exclusion_reason":  "Couverture ~25/54 pays africains. "
                             "Garde-fou imputer (>50% NaN) déclenché. "
                             "Mise à jour arrêtée ~2020 pour la majorité des pays. "
                             "Réseaux hérités ère coloniale — peu représentatifs "
                             "capacité transport contemporaine.",
        "sprint_target":     "Sprint 8+ si source AfDB/AFRAA disponible",
    },

    "PTRA_AIR_CONNECT": {
        "candidate_source":  "IATA / OAG (payant)",
        "exclusion_reason":  "Licence commerciale requise (coût non compatible budget OSA). "
                             "Couverture et qualité excellentes — exclusion temporaire. "
                             "Alternative libre partielle : OAG via partenariats académiques.",
        "sprint_target":     "Sprint 7+ si partenariat IATA ou OAG académique",
    },
}


# ══════════════════════════════════════════════════════════
# INSTRUCTIONS D'INTÉGRATION
# ══════════════════════════════════════════════════════════
#
# 1. Dans wb_indicator_map.py :
#
#    from wb_indicator_map_ptra_final_patch import PTRA_WB_INDICATORS_FINAL
#    WB_INDICATOR_MAP.update(PTRA_WB_INDICATORS_FINAL)
#
#    ⚠ Supprimer l'ancien update PTRA_WB_INDICATORS (Sprint 5)
#      pour éviter les doublons sur IS.ROD.*, IS.AIR.PSGR, etc.
#
# 2. Dans rf.indicators — nouveaux indicateurs Sprint 6 :
#
#    INSERT INTO rf.indicators
#        (code, pillar_code, name_fr, unit, direction,
#         imputation_regime, is_composite_score, has_structural_zeros, is_proxy)
#    VALUES
#        ('PTRA_AIR_AIRPORTS',  'PTRA', 'Départs vols (proxy aéroports)', 'COUNT_DEPARTURES', '+', 'INFRASTRUCTURE', false, false, true),
#        ('PTRA_PORT_CONNECT',  'PTRA', 'LSCI — connectivité maritime',   'SCORE_LSCI',       '+', 'INFRASTRUCTURE', false, true,  false),
#        ('PTRA_RD_QUALITY',    'PTRA', 'Qualité politiques transport',   'SCORE_1_6',        '+', 'INFRASTRUCTURE', true,  false, false)
#    ON CONFLICT (code) DO UPDATE
#        SET imputation_regime = EXCLUDED.imputation_regime,
#            is_composite_score = EXCLUDED.is_composite_score;
#
# 3. Fetcher UNCTAD à créer : collectors/fetcher_unctad.py
#
#    Source CSV : https://unctadstat.unctad.org/datacentre/dataviewer/US.LSCI
#    Gestion rupture 2024 :
#      - Télécharger les deux séries séparément
#      - Calculer le facteur de conversion sur Q1 2024 (chevauchement)
#      - Normaliser la série pré-2024 avant INSERT dans ma.indicator_values
#      - value_status = 'OBSERVED' pour les données natives
#      - Insérer en layer_id = 1
#
# 4. Vérification post-ingestion :
#
#    SELECT
#        indicator_code,
#        COUNT(*)                                    AS total_rows,
#        COUNT(raw_value)                            AS non_null,
#        ROUND(COUNT(raw_value)::numeric / COUNT(*) * 100, 1) AS fill_pct,
#        MIN(year)                                   AS yr_min,
#        MAX(year)                                   AS yr_max
#    FROM ma.indicator_values
#    WHERE indicator_code LIKE 'PTRA_%'
#      AND layer_id = 1
#      AND year BETWEEN 2010 AND 2024
#    GROUP BY indicator_code
#    ORDER BY fill_pct DESC;
#
#    Cibles minimales :
#      PTRA_AIR_PASSENGERS  ≥ 80%
#      PTRA_AIR_CARGO       ≥ 70%
#      PTRA_RD_PAVED        ≥ 55%
#      PTRA_RD_DENSITY      ≥ 50%
#      PTRA_PORT_CONNECT    ≥ 65%
#      PTRA_PORT_CAP        ≥ 50% (+ zéros enclavés)
#      PTRA_AIR_AIRPORTS    ≥ 60%
#      PTRA_RD_QUALITY      ≥ 55%
#      PTRA_LOG_LPI         ≥ 40% (biannuel — acceptable)
#      PTRA_RD_DENSITY      ≥ 50%
