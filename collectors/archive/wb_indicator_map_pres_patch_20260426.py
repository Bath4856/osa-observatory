# ============================================================
# OSA Observatory — wb_indicator_map_pres_patch.py
# Sprint 6 — Mai 2026
# ============================================================
# Ajouter ces entrées dans wb_indicator_map.py
# dans le dict WB_INDICATOR_MAP existant.
#
# PRIORITÉ 1 — Pilier PRES (énergie + eau)
# Impact estimé sur ISA réel : +0.10 à +0.20
#
# Sources :
#   IEA   — production d'énergie (via WB proxy EG.*)
#   IRENA — capacité renouvelable (via WB EG.ELC.RNEW.ZS)
#   EIA   — réserves fossiles (via WB NY.GDP.TOTL.RT.ZS proxy)
#   FAO AQUASTAT — eau (via WB ER.H2O.*)
#
# Note sur les sources non-WB :
#   IEA et IRENA ne disposent pas d'API publique gratuite.
#   Les codes WB ci-dessous sont les meilleurs proxies disponibles.
#   Données IEA/IRENA natives → ingestion CSV séparée (voir
#   fetcher_iea.py, fetcher_irena.py — à créer Sprint 6).
#   FAO AQUASTAT → API WB ER.H2O.* couvre ~48 pays africains.
#
# Indicateurs PRES actifs post-sprint 6 :
#   Actuels (Sprint 5) : PRES_ELEC_ACCESS, PRES_ELEC_PROD,
#                        PRES_RENEW_SHARE, PRES_WATER_FRESH,
#                        PRES_WATER_STRESS
#   Nouveaux (Sprint 6): PRES_ENRG_PROD_IEA, PRES_RENEW_CAP_IRENA,
#                        PRES_FOSSIL_RENTS_EIA,
#                        PRES_WATER_WITHDRAWAL, PRES_WATER_AGRI
#
# Régime d'imputation : PHYSICAL (ffill → médiane régionale)
# conf max 0.70 / 0.55 — MICE exclu.
# ============================================================

# ── Bloc à insérer dans WB_INDICATOR_MAP ─────────────────

PRES_WB_INDICATORS_NEW = {

    # ── Bloc énergie — proxy IEA via WB ──────────────────
    "EG.USE.PCAP.KG.OE": {
        "osa_code":    "PRES_ENRG_USE_CAP",
        "name_fr":     "Consommation d'énergie par habitant (kg éq. pétrole)",
        "pillar":      "PRES",
        "unit":        "KG_OE_CAP",
        "direction":   "+",
        "multiplier":  1.0,
        "note":        "Proxy IEA production — couverture ~50 pays africains. "
                       "Fréquence annuelle. Source WB/IEA combinée.",
    },

    "EG.ELC.PROD.KH": {
        "osa_code":    "PRES_ENRG_PROD_IEA",
        "name_fr":     "Production d'électricité (kWh total)",
        "pillar":      "PRES",
        "unit":        "KWH",
        "direction":   "+",
        "multiplier":  1.0,
        "note":        "Source IEA via WB. ~52 pays africains. "
                       "Annuel — fréquence régulière depuis 2000.",
    },

    # ── Bloc renouvelable — proxy IRENA via WB ────────────
    "EG.ELC.RNEW.ZS": {
        "osa_code":    "PRES_RENEW_CAP_IRENA",
        "name_fr":     "Capacité électrique renouvelable (% total)",
        "pillar":      "PRES",
        "unit":        "PCT_ELEC",
        "direction":   "+",
        "multiplier":  1.0,
        "note":        "Proxy IRENA capacity share via WB. ~50 pays africains. "
                       "Pour capacité installée en GW → fetcher_irena.py (CSV IRENA natif).",
    },

    "EG.FEC.RNEW.ZS": {
        "osa_code":    "PRES_RENEW_SHARE_FEC",
        "name_fr":     "Part des renouvelables dans la consommation finale (% FEC)",
        "pillar":      "PRES",
        "unit":        "PCT_FEC",
        "direction":   "+",
        "multiplier":  1.0,
        "note":        "Source WB/IRENA. Complémentaire à PRES_RENEW_SHARE existant. "
                       "Couvre ~48 pays africains.",
    },

    # ── Bloc fossile — proxy EIA via WB ──────────────────
    "NY.GDP.TOTL.RT.ZS": {
        "osa_code":    "PRES_FOSSIL_RENTS_EIA",
        "name_fr":     "Rentes ressources naturelles totales (% PIB)",
        "pillar":      "PRES",
        "unit":        "PCT_GDP",
        "direction":   "+",
        "multiplier":  1.0,
        "note":        "Proxy EIA réserves fossiles — rentes totales = pétrole + gaz + charbon. "
                       "~54 pays africains. Annuel. "
                       "Pour réserves prouvées (barils/m³) → fetcher_eia.py (CSV EIA natif).",
    },

    "NY.GDP.PETR.RT.ZS": {
        "osa_code":    "PRES_OIL_RENTS",
        "name_fr":     "Rentes pétrolières (% PIB)",
        "pillar":      "PRES",
        "unit":        "PCT_GDP",
        "direction":   "+",
        "multiplier":  1.0,
        "note":        "Proxy EIA réserves pétrole. ~40 pays africains. "
                       "0 pour pays non-producteurs (valeur réelle, pas manquante).",
    },

    "NY.GDP.NGAS.RT.ZS": {
        "osa_code":    "PRES_GAS_RENTS",
        "name_fr":     "Rentes gaz naturel (% PIB)",
        "pillar":      "PRES",
        "unit":        "PCT_GDP",
        "direction":   "+",
        "multiplier":  1.0,
        "note":        "Proxy EIA réserves gaz. ~35 pays africains. "
                       "0 pour pays non-producteurs (valeur réelle, pas manquante).",
    },

    # ── Bloc eau — FAO AQUASTAT via WB ────────────────────
    "ER.H2O.INTR.PC": {
        "osa_code":    "PRES_WATER_FRESH",
        "name_fr":     "Ressources en eau douce renouvelables par habitant (m³)",
        "pillar":      "PRES",
        "unit":        "M3_CAP",
        "direction":   "+",
        "multiplier":  1.0,
        "note":        "Source FAO AQUASTAT via WB. ~54 pays africains. "
                       "Fréquence irrégulière — interpolation PHYSICAL conf 0.75.",
    },

    "ER.H2O.FWTL.ZS": {
        "osa_code":    "PRES_WATER_WITHDRAWAL",
        "name_fr":     "Prélèvements d'eau douce (% ressources disponibles)",
        "pillar":      "PRES",
        "unit":        "PCT_H2O",
        "direction":   "-",     # plus élevé = plus de pression sur la ressource
        "multiplier":  1.0,
        "note":        "Source FAO AQUASTAT via WB. Direction négative : "
                       "prélèvements élevés = stress hydrique. ~48 pays africains.",
    },

    "AG.LND.IRIG.AG.ZS": {
        "osa_code":    "PRES_WATER_AGRI",
        "name_fr":     "Terres agricoles irriguées (% terres cultivées)",
        "pillar":      "PRES",
        "unit":        "PCT_AGRI",
        "direction":   "+",
        "multiplier":  1.0,
        "note":        "Proxy FAO AQUASTAT usage agricole eau. ~50 pays africains. "
                       "Indicateur de capacité d'exploitation hydrique.",
    },
}

# ── Indicateurs PRES natifs non-WB (ingestion CSV) ────────
# À créer dans fetcher_iea.py / fetcher_irena.py / fetcher_eia.py
#
# IEA (https://www.iea.org/data-and-statistics) — CSV manuel :
#   PRES_IEA_PROD_TOTAL   — production totale énergie primaire (Mtoe)
#   PRES_IEA_PROD_COAL    — production charbon (Mtoe)
#   PRES_IEA_PROD_OIL     — production pétrole (Mtoe)
#   PRES_IEA_PROD_GAS     — production gaz (Mtoe)
#
# IRENA (https://www.irena.org/Statistics) — API REST disponible :
#   PRES_IRENA_CAP_SOLAR  — capacité solaire installée (GW)
#   PRES_IRENA_CAP_WIND   — capacité éolienne installée (GW)
#   PRES_IRENA_CAP_HYDRO  — capacité hydraulique installée (GW)
#   PRES_IRENA_CAP_TOTAL  — capacité renouvelable totale (GW)
#
# EIA (https://www.eia.gov/opendata/) — API clé requise :
#   PRES_EIA_OIL_RESERVES — réserves pétrole prouvées (Gb)
#   PRES_EIA_GAS_RESERVES — réserves gaz prouvées (Tcf)
#   PRES_EIA_COAL_PROD    — production charbon (Mt)
#
# FAO AQUASTAT (http://www.fao.org/aquastat/en/) — CSV ou API :
#   PRES_AQUA_DAM_CAP     — capacité totale barrages (km³)
#   PRES_AQUA_DESAL       — capacité dessalement (m³/jour)
#
# Ces indicateurs seront en régime PHYSICAL dans rf.pillars.
# ============================================================

# ── Instructions d'intégration ────────────────────────────
#
# Dans wb_indicator_map.py :
#
#   WB_INDICATOR_MAP.update(PRES_WB_INDICATORS_NEW)
#
# Dans rf.indicators (SQL) — pour chaque nouveau code OSA :
#   INSERT INTO rf.indicators (code, pillar_code, direction,
#       unit, imputation_regime, is_port_indicator)
#   VALUES ('PRES_ENRG_PROD_IEA', 'PRES', '+',
#           'KWH', 'PHYSICAL', false);
#
# Dans rf.pillars — vérifier :
#   UPDATE rf.pillars SET imputation_regime = 'PHYSICAL'
#   WHERE code = 'PRES';
#
# Vérification après ingestion :
#   SELECT indicator_code, COUNT(*), MIN(year), MAX(year),
#          ROUND(AVG(confidence_score)::numeric, 3) AS conf
#   FROM ma.indicator_values
#   WHERE indicator_code LIKE 'PRES_%'
#     AND layer_id = 1
#   GROUP BY indicator_code ORDER BY indicator_code;
#
# Impact ISA estimé : +0.10 à +0.20 sur score ISA réel
# (gain principalement sur pays producteurs d'énergie
#  actuellement sous-évalués faute de données production).
