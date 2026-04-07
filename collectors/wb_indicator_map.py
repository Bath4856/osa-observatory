# ============================================================
# OSA / ISA OBSERVATORY
# wb_indicator_map.py — Mapping indicateurs OSA ↔ codes WB (WDI)
# ============================================================
# Structure de chaque entrée :
#   "OSA_CODE": {
#       "wb_code"    : code WDI officiel Banque mondiale,
#       "name_fr"    : libellé court pour les logs,
#       "unit_code"  : unité OSA (doit exister dans rf.units),
#       "direction"  : '+' favorable / '-' défavorable à la souveraineté,
#       "multiplier" : facteur de conversion si nécessaire (défaut 1.0),
#       "notes"      : remarques méthodologiques,
#   }
# ============================================================

WB_INDICATOR_MAP: dict = {

    # ── PILIER ÉCONOMIQUE (PECO) ──────────────────────────
    "ECO_GDP": {
        "wb_code":    "NY.GDP.PCAP.KD",
        "name_fr":    "PIB par habitant (USD const. 2015)",
        "unit_code":  "USD_CONST",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "Dollars constants base 2015 — série longue fiable",
    },
    "ECO_GRW": {
        "wb_code":    "NY.GDP.MKTP.KD.ZG",
        "name_fr":    "Croissance PIB annuelle (%)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "Taux de variation réelle du PIB",
    },
    "ECO_INV": {
        "wb_code":    "NE.GDI.TOTL.ZS",
        "name_fr":    "Formation brute capital fixe (% PIB)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "Proxy investissement domestique",
    },
    "ECO_FDI": {
        "wb_code":    "BX.KLT.DINV.CD.WD",
        "name_fr":    "IDE entrants nets (USD)",
        "unit_code":  "MONTHS",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "Valeurs négatives possibles (désinvestissement)",
    },
    "ECO_LOG": {
        "wb_code":    "LP.LPI.OVRL.XQ",
        "name_fr":    "Indice performance logistique",
        "unit_code":  "SCORE_0_100",
        "direction":  "+",
        "multiplier": 20.0,   # LPI natif sur 5 → ramené à 100
        "notes":      "LPI Banque mondiale, enquête tous les 2 ans — interpolation nécessaire",
    },
    "ECO_TAX": {
        "wb_code":    "GC.TAX.TOTL.GD.ZS",
        "name_fr":    "Recettes fiscales (% PIB)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "Indicateur de capacité extractive de l'État",
    },
    "ECO_IND": {
        "wb_code":    "NV.IND.TOTL.ZS",
        "name_fr":    "Valeur ajoutée industrie (% PIB)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "Inclut industries extractives et manufacturières",
    },
    "ECO_EMP": {
        "wb_code":    "SL.EMP.TOTL.SP.ZS",
        "name_fr":    "Emploi (% population active)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "Taux d'emploi modélisé OIT",
    },

    # ── PILIER MONÉTAIRE (PMON) ────────────────────────────
    "MON_INF": {
        "wb_code":    "FP.CPI.TOTL.ZG",
        "name_fr":    "Inflation (% annuel)",
        "unit_code":  "PERCENT",
        "direction":  "-",
        "multiplier": 1.0,
        "notes":      "Variation IPC — valeurs extrêmes possibles (hyperinflation)",
    },
    "MON_RES": {
        "wb_code":    "FI.RES.TOTL.MO",
        "name_fr":    "Réserves de change (USD)",
        "unit_code":  "MONTHS",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "Réserves totales incluant or et DTS",
    },
    "MON_EXT": {
        "wb_code":    "GC.DOD.TOTL.GD.ZS",
        "name_fr":    "Dette extérieure totale (% PIB)",
        "unit_code":  "PERCENT",
        "direction":  "-",
        "multiplier": 1.0,
        "notes":      "Encours total dette extérieure rapporté au PIB",
    },
    "MON_FIN": {
        "wb_code":    "FS.AST.PRVT.GD.ZS",
        "name_fr":    "Crédit secteur privé (% PIB)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "Proxy de profondeur financière",
    },
    "MON_M2": {
        "wb_code":    "FM.LBL.BMNY.GD.ZS",
        "name_fr":    "Masse monétaire M2 (% PIB)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "Profondeur monétaire de l'économie",
    },
    "MON_INT": {
        "wb_code":    "FR.INR.RINR",
        "name_fr":    "Taux d'intérêt réel (%)",
        "unit_code":  "PERCENT",
        "direction":  "-",
        "multiplier": 1.0,
        "notes":      "Taux nominal déflaté par l'IPC",
    },
    "MON_DET": {
        "wb_code":    "GC.XPN.INTP.RV.ZS",
        "name_fr":    "Service dette / recettes (%)",
        "unit_code":  "PERCENT",
        "direction":  "-",
        "multiplier": 1.0,
        "notes":      "Part du service de la dette dans les recettes publiques",
    },

    # ── PILIER HUMAIN (PHUM) ───────────────────────────────
    "HUM_LIT": {
        "wb_code":    "SE.ADT.LITR.ZS",
        "name_fr":    "Alphabétisation adultes (%)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "Fréquence faible — interpolation souvent nécessaire",
    },
    "HUM_POV": {
        "wb_code":    "SI.POV.DDAY",
        "name_fr":    "Pauvreté < 2.15 USD/jour (%)",
        "unit_code":  "PERCENT",
        "direction":  "-",
        "multiplier": 1.0,
        "notes":      "Seuil international pauvreté extrême 2022",
    },
    "HUM_WAT": {
        "wb_code":    "SH.H2O.BASW.ZS",
        "name_fr":    "Accès eau potable (%)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "Services d'eau de base (JMP OMS/UNICEF)",
    },
    "HUM_SAN": {
        "wb_code":    "SH.STA.BASS.ZS",
        "name_fr":    "Accès assainissement (%)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "Services d'assainissement de base (JMP)",
    },
    "HUM_HEA": {
        "wb_code":    "SP.DYN.LE00.IN",
        "name_fr":    "Espérance de vie (années)",
        "unit_code":  "YEARS",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "Espérance de vie à la naissance (total)",
    },
    "HUM_INF": {
        "wb_code":    "SH.DYN.MORT",
        "name_fr":    "Mortalité infantile < 5 ans (‰)",
        "unit_code":  "PERCENT",
        "direction":  "-",
        "multiplier": 0.1,    # Pour 1000 naissances → converti en %
        "notes":      "Taux de mortalité des moins de 5 ans pour 1000 naissances",
    },

    # ── PILIER ENVIRONNEMENTAL (PENV) ─────────────────────
    "ENV_CO2": {
        "wb_code":    "EN.GHG.CO2.PC.CE.AR5",
        "name_fr":    "Émissions CO2 par habitant (tonnes)",
        "unit_code":  "TONNES",
        "direction":  "-",
        "multiplier": 1.0,
        "notes":      "Émissions CO2 tonnes métriques par habitant",
    },
    "ENV_FOR": {
        "wb_code":    "AG.LND.FRST.ZS",
        "name_fr":    "Couverture forestière (% superficie)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "Part des forêts dans la superficie totale",
    },
    "ENV_ENR": {
        "wb_code":    "EG.ELC.RNEW.ZS",
        "name_fr":    "Électricité renouvelable (% production)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "Part des renouvelables dans la production électrique",
    },
    "ENV_ENE": {
        "wb_code":    "EG.EGY.PRIM.PP.KD",
        "name_fr":    "Intensité énergétique (MJ/USD 2017)",
        "unit_code":  "INDEX",
        "direction":  "-",
        "multiplier": 1.0,
        "notes":      "Consommation énergie primaire par unité de PIB",
    },

    # ── PILIER NUMÉRIQUE (PNUM) ───────────────────────────
    "NUM_INT": {
        "wb_code":    "IT.NET.USER.ZS",
        "name_fr":    "Utilisateurs internet (% population)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "Individus ayant utilisé internet dans les 3 derniers mois. "
                      "Alternative WB en cas d'indisponibilité ITU (i99H).",
    },
    "NUM_MOB": {
        "wb_code":    "IT.CEL.SETS",
        "name_fr":    "Abonnements mobiles (total)",
        "unit_code":  "PERSONS",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "Abonnements actifs — peut dépasser la population. "
                      "Alternative WB en cas d'indisponibilité ITU (i271).",
    },

    # ── PILIER GÉOPOLITIQUE (PGEO) — indicateurs WGI ──────
    "GEO_STAB": {
        "wb_code":    "PV.EST",
        "name_fr":    "Stabilité politique (WGI)",
        "unit_code":  "SCORE",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "WGI Political Stability — score z normalisé [-2.5, +2.5]",
    },
    "GEO_RSK": {
        "wb_code":    "RL.EST",
        "name_fr":    "État de droit (WGI) — inversé",
        "unit_code":  "SCORE",
        "direction":  "-",
        "multiplier": -1.0,   # Inversé : faible état de droit = risque élevé
        "notes":      "WGI Rule of Law — inversé pour représenter le risque",
    },
    "NUM_GOV": {
        "wb_code":    "GE.EST",
        "name_fr":    "Efficacité gouvernementale (WGI)",
        "unit_code":  "SCORE",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "WGI Government Effectiveness — score z [-2.5, +2.5]",
    },

    # ── PILIER MINIER (PMIN) — proxy disponible via WB ────
    "MIN_VAL": {
        "wb_code":    "NY.GDP.MINR.RT.ZS",
        "name_fr":    "Rente minière (% PIB)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "Rente totale ressources naturelles hors pétrole — proxy MIN_VAL",
    },
    # ── PILIER MONÉTAIRE — ajout Sprint 3 (remplacement proxy IMF LP) ──
    "MON_STB": {
        "wb_code":    "FB.BNK.CAPA.ZS",
        "name_fr":    "Ratio capital bancaire / actifs (%)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "WB FSI/IMF — ratio capital et réserves / actifs totaux. "
                      "Standard international de solidité bancaire. "
                      "Remplace le proxy 'population totale' IMF LP (sans lien sémantique).",
    },

    # ── PILIER HUMAIN — ajout Sprint 3 (remplacement proxies WHO non pertinents) ──
    "HUM_MIG": {
        "wb_code":    "SM.POP.NETM",
        "name_fr":    "Solde migratoire net (personnes)",
        "unit_code":  "PERSONS",
        "direction":  "-",
        "multiplier": 1.0,
        "notes":      "WB — solde migratoire net annuel (émigration – immigration). "
                      "Direction '-' : solde négatif (émigration nette) pénalise la souveraineté. "
                      "Remplace mortalité MNT WHO (NCDMORT3070) sans rapport avec la fuite des cerveaux. "
                      "À affiner en Sprint 5 avec SM.EMI.TERT.ZS (diplômés du tertiaire).",
    },
    "HUM_EDU": {
        "wb_code":    "SE.SEC.ENRR",
        "name_fr":    "Taux de scolarisation secondaire brut (%)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "WB — proxy éducation : taux brut de scolarisation dans le secondaire. "
                      "Remplace densité de médecins WHO (HWF_0001) sans rapport avec l'éducation. "
                      "À remplacer en Sprint 4 par la composante éducation IDH (UNDP).",
    },

    "NUM_FIB": {"wb_code": "IT.NET.BBND.P2", "name_fr": "Haut debit fixe /100 hab.", "unit_code": "INDEX", "direction": "+", "multiplier": 1.0, "notes": "Migration ITU i4213."},
    "NUM_DAT": {"wb_code": "IT.NET.BBND.P2", "name_fr": "Internet fixe /100 hab.", "unit_code": "INDEX", "direction": "+", "multiplier": 1.0, "notes": "Migration ITU i271E."},
    "NUM_CYB": {"wb_code": "IT.NET.SECR.P6", "name_fr": "Serveurs securises /1M (proxy GCI)", "unit_code": "INDEX", "direction": "+", "multiplier": 1.0, "notes": "Proxy GCI ITU inaccessible. Sprint 5."},
    "NUM_STU": {"wb_code": "SP.POP.SCIE.RD.P6", "name_fr": "Formation numerique — chercheurs R&D /1M hab.", "unit_code": "INDEX", "direction": "+", "multiplier": 1.0, "notes": "WB SP.POP.SCIE.RD.P6 — proxy NUM_STU (formation numerique). Refonte Sprint 5 avec UNESCO."},
    "HUM_FOO": {"wb_code": "SN.ITK.DEFC.ZS", "name_fr": "Prevalence sous-nutrition %", "unit_code": "PERCENT", "direction": "-", "multiplier": 1.0, "notes": "Migration FAO 2024."},
    "ECO_AGR": {"wb_code": "NV.AGR.TOTL.ZS", "name_fr": "Agriculture valeur ajoutee % PIB", "unit_code": "PERCENT", "direction": "+", "multiplier": 1.0, "notes": "Migration FAO 2024."},
}

# ── 54 pays africains (codes ISO-3) ───────────────────────
AFRICAN_COUNTRIES_ISO3: list[str] = [
    # Afrique du Nord
    "DZA", "EGY", "LBY", "MAR", "MRT", "SDN", "TUN",
    # Afrique de l'Ouest
    "BEN", "BFA", "CIV", "CPV", "GMB", "GHA", "GIN",
    "GNB", "LBR", "MLI", "NER", "NGA", "SLE", "SEN", "TGO",
    # Afrique de l'Est
    "BDI", "COM", "DJI", "ERI", "ETH", "KEN", "MDG",
    "MWI", "MUS", "MOZ", "RWA", "SYC", "SOM", "SSD",
    "TZA", "UGA", "ZMB", "ZWE",
    # Afrique Centrale
    "AGO", "CMR", "CAF", "TCD", "COG", "COD", "GNQ", "GAB", "STP",
    # Afrique Australe
    "BWA", "SWZ", "LSO", "NAM", "ZAF",
]


# Correspondance ISO-3 → ISO-2 (pour API qui utilisent ISO-2)
ISO3_TO_ISO2: dict[str, str] = {
    "DZA": "DZ", "EGY": "EG", "LBY": "LY", "MAR": "MA", "MRT": "MR",
    "SDN": "SD", "TUN": "TN", "BEN": "BJ", "BFA": "BF", "CIV": "CI",
    "CPV": "CV", "GMB": "GM", "GHA": "GH", "GIN": "GN", "GNB": "GW",
    "LBR": "LR", "MLI": "ML", "NER": "NE", "NGA": "NG", "SLE": "SL",
    "SEN": "SN", "TGO": "TG", "BDI": "BI", "COM": "KM", "DJI": "DJ",
    "ERI": "ER", "ETH": "ET", "KEN": "KE", "MDG": "MG", "MWI": "MW",
    "MUS": "MU", "MOZ": "MZ", "RWA": "RW", "SYC": "SC", "SOM": "SO",
    "SSD": "SS", "TZA": "TZ", "UGA": "UG", "ZMB": "ZM", "ZWE": "ZW",
    "AGO": "AO", "CMR": "CM", "CAF": "CF", "TCD": "TD", "COG": "CG",
    "COD": "CD", "GNQ": "GQ", "GAB": "GA", "STP": "ST", "BWA": "BW",
    "SWZ": "SZ", "LSO": "LS", "NAM": "NA", "ZAF": "ZA",
}
