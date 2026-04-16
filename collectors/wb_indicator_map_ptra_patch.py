# ============================================================
# OSA Observatory — wb_indicator_map_ptra_patch.py
# Sprint 5 — Avril 2026
# ============================================================
# Ajouter ces entrées dans wb_indicator_map.py
# dans le dict WB_INDICATOR_MAP existant.
#
# 5 indicateurs PTRA alimentés par l'API World Bank :
#   PTRA_RD_DENSITY    — densité routière      IS.ROD.DNST.K2
#   PTRA_RD_PAVED      — routes pavées %        IS.ROD.PAVE.ZS
#   PTRA_AIR_PASSENGERS— passagers aériens      IS.AIR.PSGR
#   PTRA_AIR_CARGO     — fret aérien            IS.AIR.GOOD.MT.K1
#   PTRA_LOG_LPI       — LPI (migré de ECO_LOG) LP.LPI.OVRL.XQ
#
# Note sur LP.LPI.OVRL.XQ :
#   Anciennement ECO_LOG dans PECO.
#   Supprimé de PECO et migré vers PTRA en Sprint 5.
#   Le fetcher_wb.py n'a pas besoin d'être modifié —
#   seul le mapping change ici.
#
# Note sur LPI (publication biannuelle) :
#   LP.LPI.OVRL.XQ est publié tous les 2 ans (2007, 2010,
#   2012, 2014, 2016, 2018, 2023...).
#   L'imputer PTRA (chaîne physique) gère les années vides
#   via interpolation linéaire, confiance 0.75.
#
# Indicateurs PTRA sans API WB (sources CSV — Sprint 5) :
#   PTRA_RD_TOTAL      — longueur totale réseau  IRF ou FAO
#   PTRA_RD_QUALITY    — qualité routes           CPIA WB (à confirmer)
#   PTRA_AIR_AIRPORTS  — nombre aéroports         WB IS.AIR.DPRT (proxy)
#   PTRA_AIR_CONNECT   — connectivité aérienne    WB IS.AIR.DPRT ou IATA
#   PTRA_PORT_CAP      — containers ports         WB IS.SHP.GOOD.TU
#   PTRA_PORT_CONNECT  — LSCI maritime            UNCTAD CSV
# ============================================================

# ── Bloc à insérer dans WB_INDICATOR_MAP ─────────────────

PTRA_WB_INDICATORS = {

    # ── Bloc routier ─────────────────────────────────────
    "IS.ROD.DNST.K2": {
        "osa_code":    "PTRA_RD_DENSITY",
        "name_fr":     "Densité du réseau routier (km/km²)",
        "pillar":      "PTRA",
        "unit":        "KM_KM2",
        "direction":   "+",
        "multiplier":  1.0,
        "note":        "Couverture ~45 pays africains — fréquence irrégulière",
    },

    "IS.ROD.PAVE.ZS": {
        "osa_code":    "PTRA_RD_PAVED",
        "name_fr":     "Routes pavées (% réseau total)",
        "pillar":      "PTRA",
        "unit":        "PCT_RD",
        "direction":   "+",
        "multiplier":  1.0,
        "note":        "Couverture ~48 pays africains — fréquence irrégulière",
    },

    # ── Bloc aérien ───────────────────────────────────────
    "IS.AIR.PSGR": {
        "osa_code":    "PTRA_AIR_PASSENGERS",
        "name_fr":     "Trafic aérien passagers (total)",
        "pillar":      "PTRA",
        "unit":        "PAX",
        "direction":   "+",
        "multiplier":  1.0,
        "note":        "Couverture ~52 pays africains — annuel",
    },

    "IS.AIR.GOOD.MT.K1": {
        "osa_code":    "PTRA_AIR_CARGO",
        "name_fr":     "Trafic aérien fret (millions de tonnes-km)",
        "pillar":      "PTRA",
        "unit":        "TONNES_MT",
        "direction":   "+",
        "multiplier":  1.0,
        "note":        "Couverture ~48 pays africains — annuel",
    },

    # ── Bloc logistique ───────────────────────────────────
    "LP.LPI.OVRL.XQ": {
        "osa_code":    "PTRA_LOG_LPI",
        "name_fr":     "Indice de performance logistique (LPI)",
        "pillar":      "PTRA",
        "unit":        "SCORE_0_100",
        "direction":   "+",
        "multiplier":  20.0,   # LPI est sur [1,5] → ×20 pour [20,100]
        "note":        "Migré de ECO_LOG (PECO) en Sprint 5. "
                       "Publication biannuelle WB — interpolation L2 pour années vides.",
    },
}

# ── Indicateurs WB supplémentaires PTRA (proxies) ────────
# À ajouter dans WB_INDICATOR_MAP si confirmation WB :

PTRA_WB_PROXIES = {

    # Proxy aéroports — départs comme proxy du nombre d'aéroports actifs
    "IS.AIR.DPRT": {
        "osa_code":    "PTRA_AIR_AIRPORTS",
        "name_fr":     "Départs vols enregistrés (proxy aéroports)",
        "pillar":      "PTRA",
        "unit":        "COUNT_N",
        "direction":   "+",
        "multiplier":  1.0,
        "note":        "Proxy départs → nombre aéroports actifs. "
                       "Source directe ICAO non accessible via API.",
    },

    # Containers portuaires — proxy capacité portuaire
    "IS.SHP.GOOD.TU": {
        "osa_code":    "PTRA_PORT_CAP",
        "name_fr":     "Containers portuaires traités (TEU)",
        "pillar":      "PTRA",
        "unit":        "COUNT_N",
        "direction":   "+",
        "multiplier":  1.0,
        "note":        "Couverture ~35 pays africains (ports significatifs). "
                       "Pays enclavés = 0 (valeur réelle, pas donnée manquante).",
    },
}

# ── Instructions d'intégration ────────────────────────────
#
# Dans wb_indicator_map.py, ajouter au WB_INDICATOR_MAP :
#
#   WB_INDICATOR_MAP.update(PTRA_WB_INDICATORS)
#   WB_INDICATOR_MAP.update(PTRA_WB_PROXIES)   # si proxies validés
#
# Aucune modification du fetcher_wb.py nécessaire —
# il itère sur WB_INDICATOR_MAP automatiquement.
#
# Vérification après ingestion :
#   SELECT indicator_code, COUNT(*), MIN(year), MAX(year)
#   FROM ma.indicator_values
#   WHERE indicator_code LIKE 'PTRA_%' AND layer = 1
#   GROUP BY indicator_code ORDER BY indicator_code;
