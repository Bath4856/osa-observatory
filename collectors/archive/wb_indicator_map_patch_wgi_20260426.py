# ============================================================
# OSA / ISA OBSERVATORY
# wb_indicator_map_patch_wgi.py
# Patch WGI — indicateurs supplémentaires PGEO + PMIL
# ============================================================
# Ce fichier COMPLÈTE wb_indicator_map.py existant.
#
# INTÉGRATION dans wb_indicator_map.py :
#   Copier le contenu de WGI_PATCH_MAP dans WB_INDICATOR_MAP
#   juste avant la ligne finale "}"
#
# Ou en Python, fusionner dynamiquement :
#   from wb_indicator_map import WB_INDICATOR_MAP
#   from wb_indicator_map_patch_wgi import WGI_PATCH_MAP
#   WB_INDICATOR_MAP.update(WGI_PATCH_MAP)
#
# Indicateurs WGI déjà présents dans wb_indicator_map.py :
#   GEO_STAB  PV.EST   Stabilité politique
#   GEO_RSK   RL.EST   État de droit (inversé)
#   NUM_GOV   GE.EST   Efficacité gouvernementale
#
# Indicateurs ajoutés ici :
#   PGEO : GEO_CON, GEO_RES, GEO_IND  → 3 indicateurs
#   PMIL : MIL_SEC, MIL_TER            → 2 via WGI
#   PMIN : MIN_GOV, MIN_CERT           → 2 via WB
#   PECO : ECO_SME, ECO_PRO            → 2 via WB
#
# Total patch : +9 indicateurs WB/WGI
# ============================================================

WGI_PATCH_MAP: dict = {

    # ══════════════════════════════════════════════════════════
    # PILIER GÉOPOLITIQUE (PGEO) — WGI complémentaires
    # Déjà mappés : GEO_STAB (PV.EST), GEO_RSK (RL.EST)
    # ══════════════════════════════════════════════════════════

    "GEO_CON": {
        "wb_code":    "PV.EST",
        "name_fr":    "Absence conflits et violence (WGI)",
        "unit_code":  "SCORE",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      """WGI Political Stability & Absence of Violence/Terrorism (PV.EST).
                        Score z [-2.5, +2.5]. Valeur haute = pays stable = peu de conflits.
                        Proxy GEO_CON — conflits frontaliers actifs (direction inversée dans pipeline).""",
    },
    "GEO_RES": {
        "wb_code":    "CC.EST",
        "name_fr":    "Contrôle de la corruption (WGI)",
        "unit_code":  "SCORE",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      """WGI Control of Corruption (CC.EST).
                        Score z [-2.5, +2.5]. Proxy résilience géopolitique institutionnelle.
                        Un État moins corrompu est plus résilient aux chocs externes.""",
    },
    "GEO_IND": {
        "wb_code":    "VA.EST",
        "name_fr":    "Expression et responsabilité (WGI)",
        "unit_code":  "SCORE",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      """WGI Voice and Accountability (VA.EST).
                        Score z [-2.5, +2.5]. Proxy indépendance stratégique et autonomie
                        décisionnelle — un État avec des institutions légitimes est plus autonome.""",
    },
    "GEO_STAB": {
        "wb_code":    "PV.EST",
        "name_fr":    "Stabilité politique (WGI)",
        "unit_code":  "SCORE",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "WGI Political Stability — score z [-2.5, +2.5]. Déjà dans wb_indicator_map.",
    },
    "GEO_RSK": {
        "wb_code":    "RL.EST",
        "name_fr":    "État de droit (WGI) — inversé",
        "unit_code":  "SCORE",
        "direction":  "-",
        "multiplier": -1.0,
        "notes":      "WGI Rule of Law inversé. Déjà dans wb_indicator_map.",
    },
    "GEO_POW": {
        "wb_code":    "RQ.EST",
        "name_fr":    "Qualité de la réglementation (WGI)",
        "unit_code":  "SCORE",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      """WGI Regulatory Quality (RQ.EST).
                        Score z [-2.5, +2.5]. Proxy influence régionale — un État avec
                        une bonne réglementation attire et influence ses voisins.""",
    },

    # ══════════════════════════════════════════════════════════
    # PILIER MILITAIRE (PMIL) — via WGI + WB
    # SIPRI couvre les indicateurs quantitatifs (fetcher_sipri_csv.py)
    # WGI couvre les indicateurs qualitatifs sécurité
    # ══════════════════════════════════════════════════════════

    "MIL_SEC": {
        "wb_code":    "PV.EST",
        "name_fr":    "Sécurité intérieure (WGI proxy)",
        "unit_code":  "SCORE",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      """WGI Political Stability (PV.EST) — meilleur proxy WB disponible
                        pour la sécurité intérieure. Complété par SIPRI pour les données
                        quantitatives (effectifs, dépenses).""",
    },
    "MIL_TER": {
        "wb_code":    "PV.EST",
        "name_fr":    "Risque terroriste (WGI proxy — inversé)",
        "unit_code":  "SCORE",
        "direction":  "-",
        "multiplier": -1.0,
        "notes":      """WGI PV.EST inversé — proxy risque terroriste.
                        Un pays instable a statistiquement un risque terroriste plus élevé.
                        Complété par ACLED (sprint suivant) pour données précises.""",
    },
    "MIL_STB": {
        "wb_code":    "CC.EST",
        "name_fr":    "Stabilité armée / contrôle corruption défense (WGI)",
        "unit_code":  "SCORE",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      """WGI Control of Corruption — proxy stabilité institutionnelle
                        des forces armées. La corruption dans le secteur défense est
                        un indicateur de fragilité militaire.""",
    },

    # ══════════════════════════════════════════════════════════
    # PILIER MINIER (PMIN) — compléments WB
    # ══════════════════════════════════════════════════════════

    "MIN_GOV": {
        "wb_code":    "CC.EST",
        "name_fr":    "Gouvernance minière (WGI proxy)",
        "unit_code":  "SCORE",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      """WGI Control of Corruption — proxy gouvernance minière.
                        En l'absence de données ITIE systématiques, la corruption
                        générale est le meilleur proxy disponible via WB.""",
    },
    "MIN_DEP": {
        "wb_code":    "TX.VAL.MMOR.ZS.UN",
        "name_fr":    "Exportations minerais métaux (% exports totaux)",
        "unit_code":  "PERCENT",
        "direction":  "-",
        "multiplier": 1.0,
        "notes":      """WB — ores and metals exports as % of merchandise exports.
                        Dépendance aux exportations minières — direction négative :
                        plus la part est élevée, moins l'économie est diversifiée.""",
    },
    "MIN_TAX": {
        "wb_code":    "NY.GDP.TOTL.RT.ZS",
        "name_fr":    "Rente totale ressources naturelles (% PIB)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      """WB — total natural resources rents % GDP.
                        Proxy recettes fiscales minières — inclut pétrole, gaz,
                        minerais, forêt, eau.""",
    },

    # ══════════════════════════════════════════════════════════
    # PILIER ÉCONOMIQUE (PECO) — compléments WB
    # ══════════════════════════════════════════════════════════

    "ECO_PRO": {
        "wb_code":    "SL.GDP.PCAP.EM.KD",
        "name_fr":    "PIB par travailleur (USD const. 2017)",
        "unit_code":  "USD_CONST",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "WB — GDP per person employed. Productivité du travail réelle.",
    },
    "ECO_IND": {
        "wb_code":    "NV.MNF.OTHR.ZS.UN",
        "name_fr":    "Valeur ajoutée industrie manufacturière (% PIB)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      """WB — manufacturing value added % GDP (UNSD).
                        Proxy industrialisation — exclut extractif, se concentre
                        sur la transformation locale.""",
    },
    "ECO_DIV": {
        "wb_code":    "NV.SRV.TOTL.ZS",
        "name_fr":    "Services (% PIB)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      """WB — services value added % GDP.
                        Proxy diversification économique — une économie avec
                        un secteur services développé est moins dépendante des matières premières.""",
    },

    # ══════════════════════════════════════════════════════════
    # PILIER HUMAIN (PHUM) — compléments WB
    # ══════════════════════════════════════════════════════════

    "HUM_MIG": {
        "wb_code":    "SM.POP.NETM",
        "name_fr":    "Migration nette (personnes)",
        "unit_code":  "PERSONS",
        "direction":  "-",
        "multiplier": -1.0,   # Émigration nette = valeur négative → inversé
        "notes":      """WB — net migration (number of people).
                        Valeur négative = émigration nette = fuite des cerveaux.
                        On inverse pour que la valeur haute = peu d'émigration = positif.""",
    },
    "HUM_GEN": {
        "wb_code":    "SG.GEN.PARL.ZS",
        "name_fr":    "Femmes au parlement (%)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "WB — proportion of seats held by women in national parliaments.",
    },
    "HUM_EDU": {
        "wb_code":    "SE.XPD.TOTL.GD.ZS",
        "name_fr":    "Dépenses éducation (% PIB)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "WB — government expenditure on education % GDP.",
    },

    # ══════════════════════════════════════════════════════════
    # PILIER NUMÉRIQUE (PNUM) — compléments WB
    # ══════════════════════════════════════════════════════════

    "NUM_DAT2": {
        "wb_code":    "IT.NET.SECR.P6",
        "name_fr":    "Serveurs Internet sécurisés (pour 1M hab.)",
        "unit_code":  "INDEX",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      """WB — secure internet servers per million people.
                        Proxy souveraineté des données — un pays avec plus de serveurs
                        sécurisés héberge mieux ses données localement.""",
    },
    "NUM_CLO": {
        "wb_code":    "IT.NET.BBND.P2",
        "name_fr":    "Abonnements haut débit fixe (pour 100 hab.)",
        "unit_code":  "INDEX",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "WB — fixed broadband subscriptions per 100 people. Proxy adoption cloud.",
    },
}

# ── Récapitulatif des indicateurs par pilier ───────────────

WGI_PATCH_SUMMARY = {
    "PGEO": ["GEO_CON", "GEO_RES", "GEO_IND", "GEO_POW"],
    "PMIL": ["MIL_SEC", "MIL_TER", "MIL_STB"],
    "PMIN": ["MIN_GOV", "MIN_DEP", "MIN_TAX"],
    "PECO": ["ECO_PRO", "ECO_IND", "ECO_DIV"],
    "PHUM": ["HUM_MIG", "HUM_GEN", "HUM_EDU"],
    "PNUM": ["NUM_DAT2", "NUM_CLO"],
}

if __name__ == "__main__":
    print(f"WGI Patch — {len(WGI_PATCH_MAP)} indicateurs ajoutés :")
    for pilier, codes in WGI_PATCH_SUMMARY.items():
        print(f"  {pilier} : {', '.join(codes)}")
