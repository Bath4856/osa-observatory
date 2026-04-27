# ============================================================
# OSA / ISA OBSERVATORY
# wb_indicator_map.py -- Mapping indicateurs OSA <-> codes WB (WDI)
# ============================================================
# Structure de chaque entree :
#   "OSA_CODE": {
#       "wb_code"    : code WDI officiel Banque mondiale,
#       "name_fr"    : libelle court pour les logs,
#       "unit_code"  : unite OSA (doit exister dans rf.units),
#       "direction"  : '+' favorable / '-' defavorable a la souverainete,
#       "multiplier" : facteur de conversion si necessaire (defaut 1.0),
#       "notes"      : remarques methodologiques,
#   }
# ============================================================

WB_INDICATOR_MAP: dict = {

    # ── PILIER ECONOMIQUE (PECO) ──────────────────────────
    "ECO_GDP": {
        "wb_code":    "NY.GDP.PCAP.KD",
        "name_fr":    "PIB par habitant (USD const. 2015)",
        "unit_code":  "USD_CONST",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "Dollars constants base 2015 -- serie longue fiable",
    },
    "ECO_GRW": {
        "wb_code":    "NY.GDP.MKTP.KD.ZG",
        "name_fr":    "Croissance PIB annuelle (%)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "Taux de variation reelle du PIB",
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
        "notes":      "Valeurs negatives possibles (desinvestissement)",
    },
    "ECO_LOG": {
        "wb_code":    "LP.LPI.OVRL.XQ",
        "name_fr":    "Indice performance logistique",
        "unit_code":  "SCORE_0_100",
        "direction":  "+",
        "multiplier": 20.0,
        "notes":      "LPI Banque mondiale, enquete tous les 2 ans -- interpolation necessaire",
    },
    "ECO_TAX": {
        "wb_code":    "GC.TAX.TOTL.GD.ZS",
        "name_fr":    "Recettes fiscales (% PIB)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "Indicateur de capacite extractive de l'Etat",
    },
    "ECO_IND": {
        "wb_code":    "NV.IND.TOTL.ZS",
        "name_fr":    "Valeur ajoutee industrie (% PIB)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "Inclut industries extractives et manufacturieres",
    },
    "ECO_EMP": {
        "wb_code":    "SL.EMP.TOTL.SP.ZS",
        "name_fr":    "Emploi (% population active)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "Taux d'emploi modelise OIT",
    },

    # ── PILIER MONETAIRE (PMON) ────────────────────────────
    "MON_INF": {
        "wb_code":    "FP.CPI.TOTL.ZG",
        "name_fr":    "Inflation (% annuel)",
        "unit_code":  "PERCENT",
        "direction":  "-",
        "multiplier": 1.0,
        "notes":      "Variation IPC -- valeurs extremes possibles (hyperinflation)",
    },
    "MON_RES": {
        "wb_code":    "FI.RES.TOTL.MO",
        "name_fr":    "Reserves de change (mois)",
        "unit_code":  "MONTHS",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "Reserves totales incluant or et DTS",
    },
    "MON_EXT": {
        "wb_code":    "GC.DOD.TOTL.GD.ZS",
        "name_fr":    "Dette exterieure totale (% PIB)",
        "unit_code":  "PERCENT",
        "direction":  "-",
        "multiplier": 1.0,
        "notes":      "Encours total dette exterieure rapporte au PIB",
    },
    "MON_FIN": {
        "wb_code":    "FS.AST.PRVT.GD.ZS",
        "name_fr":    "Credit secteur prive (% PIB)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "Proxy de profondeur financiere",
    },
    "MON_M2": {
        "wb_code":    "FM.LBL.BMNY.GD.ZS",
        "name_fr":    "Masse monetaire M2 (% PIB)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "Profondeur monetaire de l'economie",
    },
    "MON_INT": {
        "wb_code":    "FR.INR.RINR",
        "name_fr":    "Taux d'interet reel (%)",
        "unit_code":  "PERCENT",
        "direction":  "-",
        "multiplier": 1.0,
        "notes":      "Taux nominal deflate par l'IPC",
    },
    "MON_DET": {
        "wb_code":    "GC.XPN.INTP.RV.ZS",
        "name_fr":    "Service dette / recettes (%)",
        "unit_code":  "PERCENT",
        "direction":  "-",
        "multiplier": 1.0,
        "notes":      "Part du service de la dette dans les recettes publiques",
    },
    "MON_STB": {
        "wb_code":    "FB.BNK.CAPA.ZS",
        "name_fr":    "Ratio capital bancaire / actifs (%)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "WB FSI/IMF -- ratio capital et reserves / actifs totaux. "
                      "Standard international de solidite bancaire. "
                      "Remplace le proxy 'population totale' IMF LP (sans lien semantique).",
    },

    # ── PILIER HUMAIN (PHUM) ───────────────────────────────
    "HUM_LIT": {
        "wb_code":    "SE.ADT.LITR.ZS",
        "name_fr":    "Alphabetisation adultes (%)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "Frequence faible -- interpolation souvent necessaire",
    },
    "HUM_POV": {
        "wb_code":    "SI.POV.DDAY",
        "name_fr":    "Pauvrete < 2.15 USD/jour (%)",
        "unit_code":  "PERCENT",
        "direction":  "-",
        "multiplier": 1.0,
        "notes":      "Seuil international pauvrete extreme 2022",
    },
    "HUM_WAT": {
        "wb_code":    "SH.H2O.BASW.ZS",
        "name_fr":    "Acces eau potable (%)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "Services d'eau de base (JMP OMS/UNICEF)",
    },
    "HUM_SAN": {
        "wb_code":    "SH.STA.BASS.ZS",
        "name_fr":    "Acces assainissement (%)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "Services d'assainissement de base (JMP)",
    },
    "HUM_HEA": {
        "wb_code":    "SP.DYN.LE00.IN",
        "name_fr":    "Esperance de vie (annees)",
        "unit_code":  "YEARS",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "Esperance de vie a la naissance (total)",
    },
    "HUM_INF": {
        "wb_code":    "SH.DYN.MORT",
        "name_fr":    "Mortalite infantile < 5 ans (pour 1000)",
        "unit_code":  "PERCENT",
        "direction":  "-",
        "multiplier": 0.1,
        "notes":      "Taux de mortalite des moins de 5 ans pour 1000 naissances",
    },
    "HUM_MIG": {
        "wb_code":    "SM.POP.NETM",
        "name_fr":    "Solde migratoire net (personnes)",
        "unit_code":  "PERSONS",
        "direction":  "-",
        "multiplier": 1.0,
        "notes":      "WB -- solde migratoire net annuel (emigration - immigration). "
                      "Direction '-' : solde negatif (emigration nette) penalise la souverainete. "
                      "Remplace mortalite MNT WHO (NCDMORT3070) sans rapport avec la fuite des cerveaux. "
                      "A affiner en Sprint 5 avec SM.EMI.TERT.ZS (diplomes du tertiaire).",
    },
    "HUM_EDU": {
        "wb_code":    "SE.SEC.ENRR",
        "name_fr":    "Taux de scolarisation secondaire brut (%)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "WB -- proxy education : taux brut de scolarisation dans le secondaire. "
                      "Remplace densite de medecins WHO (HWF_0001) sans rapport avec l'education. "
                      "A remplacer en Sprint 4 par la composante education IDH (UNDP).",
    },

    # ── PILIER ENVIRONNEMENTAL (PENV) ─────────────────────
    "ENV_CO2": {
        "wb_code":    "EN.GHG.CO2.PC.CE.AR5",
        "name_fr":    "Emissions CO2 par habitant (tonnes)",
        "unit_code":  "TONNES",
        "direction":  "-",
        "multiplier": 1.0,
        "notes":      "Emissions CO2 tonnes metriques par habitant",
    },
    "ENV_FOR": {
        "wb_code":    "AG.LND.FRST.ZS",
        "name_fr":    "Couverture forestiere (% superficie)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "Part des forets dans la superficie totale",
    },
    "ENV_ENR": {
        "wb_code":    "EG.ELC.RNEW.ZS",
        "name_fr":    "Electricite renouvelable (% production)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "Part des renouvelables dans la production electrique",
    },
    "ENV_ENE": {
        "wb_code":    "EG.EGY.PRIM.PP.KD",
        "name_fr":    "Intensite energetique (MJ/USD 2017)",
        "unit_code":  "INDEX",
        "direction":  "-",
        "multiplier": 1.0,
        "notes":      "Consommation energie primaire par unite de PIB",
    },

    # ── PILIER NUMERIQUE (PNUM) ───────────────────────────
    "NUM_INT": {
        "wb_code":    "IT.NET.USER.ZS",
        "name_fr":    "Utilisateurs internet (% population)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "Individus ayant utilise internet dans les 3 derniers mois. "
                      "Alternative WB en cas d'indisponibilite ITU (i99H).",
    },
    "NUM_MOB": {
        "wb_code":    "IT.CEL.SETS",
        "name_fr":    "Abonnements mobiles (total)",
        "unit_code":  "PERSONS",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "Abonnements actifs -- peut depasser la population. "
                      "Alternative WB en cas d'indisponibilite ITU (i271).",
    },
    "NUM_FIB": {
        "wb_code":    "IT.NET.BBND.P2",
        "name_fr":    "Haut debit fixe /100 hab.",
        "unit_code":  "INDEX",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "Migration ITU i4213.",
    },
    "NUM_DAT": {
        "wb_code":    "IT.NET.BBND.P2",
        "name_fr":    "Internet fixe /100 hab.",
        "unit_code":  "INDEX",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "Migration ITU i271E.",
    },
    "NUM_CYB": {
        "wb_code":    "IT.NET.SECR.P6",
        "name_fr":    "Serveurs securises /1M (proxy GCI)",
        "unit_code":  "INDEX",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "Proxy GCI ITU inaccessible. Sprint 5.",
    },

    # ── PILIER NUMERIQUE (PNUM) -- indicateurs supplementaires ──
    "NUM_DIG": {
        "wb_code":    "BX.GSR.CCIS.ZS",
        "name_fr":    "Exports services ICT % exports totaux",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "WB -- part economie numerique dans exports. Proxy NUM_DIG.",
    },
    "NUM_AI": {
        "wb_code":    "IP.PAT.RESD",
        "name_fr":    "Brevets deposes residents (total)",
        "unit_code":  "NB",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "WB OMPI -- proxy capacite innovation et IA nationale.",
    },
    "NUM_RES": {
        "wb_code":    "GB.XPD.RSDV.GD.ZS",
        "name_fr":    "Depenses R&D % PIB",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "WB -- proxy resilience et capacite cyber. Refonte Sprint 5.",
    },
    "NUM_STU": {
        "wb_code":    "SP.POP.SCIE.RD.P6",
        "name_fr":    "Formation numerique -- chercheurs R&D /1M hab.",
        "unit_code":  "INDEX",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "WB SP.POP.SCIE.RD.P6 -- proxy NUM_STU (formation numerique). Refonte Sprint 5 avec UNESCO.",
    },

    # ── PILIER GEOPOLITIQUE (PGEO) -- indicateurs WGI ─────
    "GEO_STAB": {
        "wb_code":    "PV.EST",
        "name_fr":    "Stabilite politique (WGI)",
        "unit_code":  "SCORE",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "WGI Political Stability -- score z normalise [-2.5, +2.5]. ECHEC API -- CSV manuel requis.",
    },
    "GEO_RSK": {
        "wb_code":    "RL.EST",
        "name_fr":    "Etat de droit (WGI) -- inverse",
        "unit_code":  "SCORE",
        "direction":  "-",
        "multiplier": -1.0,
        "notes":      "WGI Rule of Law -- inverse pour representer le risque. ECHEC API -- CSV manuel requis.",
    },

    # ── PILIER GEOPOLITIQUE (PGEO) -- proxies WB ──────────
    "GEO_TRD": {
        "wb_code":    "TM.TAX.MRCH.SM.AR.ZS",
        "name_fr":    "Droits de douane moyens (%)",
        "unit_code":  "PERCENT",
        "direction":  "-",
        "multiplier": 1.0,
        "notes":      "WB -- proxy ouverture commerciale. Moins de droits = plus d'accords.",
    },
    "GEO_DIP": {
        "wb_code":    "BX.TRF.PWKR.CD.DT",
        "name_fr":    "Remittances recues (USD)",
        "unit_code":  "USD",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "WB -- proxy influence diaspora et reseaux diplomatiques.",
    },
    "GEO_ALL": {
        "wb_code":    "NE.TRD.GNFS.ZS",
        "name_fr":    "Commerce biens et services % PIB",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "WB -- proxy ouverture et partenariats strategiques.",
    },
    "GEO_POW": {
        "wb_code":    "NY.GDP.MKTP.CD",
        "name_fr":    "PIB total USD courants",
        "unit_code":  "USD",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "WB -- proxy puissance economique et influence regionale.",
    },

    "GEO_RES": {
        "wb_code":    "ER.PTD.TOTL.ZS",
        "name_fr":    "Aires protegees % territoire total",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "WB -- proxy resilience geopolitique via stabilite territoriale et environnementale.",
    },
    "GEO_SAN": {
        "wb_code":    "DT.ODA.ALLD.CD",
        "name_fr":    "Aide publique au developpement recue (USD)",
        "unit_code":  "USD",
        "direction":  "-",
        "multiplier": 1.0,
        "notes":      "WB -- proxy dependance externe. Direction negative : plus d'aide = moins de souverainete.",
    },
    "GEO_MIG": {
        "wb_code":    "SM.POP.NETM",
        "name_fr":    "Solde migratoire net (personnes)",
        "unit_code":  "INDEX",
        "direction":  "-",
        "multiplier": 1.0,
        "notes":      "WB -- solde migratoire net annuel. Proxy fuite des cerveaux.",
    },

    # ── PILIER GEOPOLITIQUE (PGEO) -- efficacite gouvernement ──
    "NUM_GOV": {
        "wb_code":    "GE.EST",
        "name_fr":    "Efficacite gouvernementale (WGI)",
        "unit_code":  "SCORE",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "WGI Government Effectiveness -- score z [-2.5, +2.5]. ECHEC API -- CSV manuel requis.",
    },

    # ── PILIER MINIER (PMIN) -- proxy disponible via WB ───
    "MIN_VAL": {
        "wb_code":    "NY.GDP.MINR.RT.ZS",
        "name_fr":    "Rente miniere (% PIB)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "Rente totale ressources naturelles hors petrole -- proxy MIN_VAL",
    },

    # ── PILIER MILITAIRE (PMIL) ────────────────────────────
    "MIL_PER": {
        "wb_code":    "MS.MIL.TOTL.P1",
        "name_fr":    "Effectif forces armees actives",
        "unit_code":  "PERSONS",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "WB -- effectif total forces armees actives (IISS)",
    },
    "MIL_SEC": {
        "wb_code":    "VC.IHR.PSRC.P5",
        "name_fr":    "Homicides intentionnels /100k hab.",
        "unit_code":  "SCORE_0_100",
        "direction":  "-",
        "multiplier": 1.0,
        "notes":      "WB -- proxy securite publique. Direction negative (moins = mieux).",
    },

    # ── INDICATEURS MIGRATION (HUM + FAO) ─────────────────
    "HUM_FOO": {
        "wb_code":    "SN.ITK.DEFC.ZS",
        "name_fr":    "Prevalence sous-nutrition %",
        "unit_code":  "PERCENT",
        "direction":  "-",
        "multiplier": 1.0,
        "notes":      "Migration FAO 2024.",
    },
    "ECO_AGR": {
        "wb_code":    "NV.AGR.TOTL.ZS",
        "name_fr":    "Agriculture valeur ajoutee % PIB",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "Migration FAO 2024.",
    },

    # ── PILIER MINIER (PMIN) -- indicateurs supplementaires ──
    "MIN_TAX": {
        "wb_code":    "GC.TAX.TOTL.GD.ZS",
        "name_fr":    "Recettes fiscales % PIB (proxy MIN_TAX)",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "WB -- meme code que ECO_TAX. Proxy recettes minieres dans recettes totales.",
    },
    "MIN_DEP": {
        "wb_code":    "TX.VAL.MMTL.ZS.UN",
        "name_fr":    "Minerais et metaux % exports totaux",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "WB UN Comtrade -- part minerais et metaux dans exportations totales.",
    },

    # ── PILIER MILITAIRE (PMIL) -- indicateurs supplementaires ──
    "MIL_STR": {
        "wb_code":    "MS.MIL.XPND.GD.ZS",
        "name_fr":    "Depenses militaires % PIB",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "WB SIPRI -- proxy capacite projection de force. Complement MIL_EXP SIPRI.",
    },
    "MIL_LOG": {
        "wb_code":    "MS.MIL.XPND.ZS",
        "name_fr":    "Depenses militaires % depenses gouvernementales",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "WB SIPRI -- part budget militaire dans budget total. Proxy capacite logistique.",
    },

    "MIL_STB": {
        "wb_code":    "VC.IHR.PSRC.FE.P5",
        "name_fr":    "Homicides feminins /100k hab. (proxy securite)",
        "unit_code":  "SCORE_0_100",
        "direction":  "-",
        "multiplier": 1.0,
        "notes":      "WB -- proxy stabilite securitaire. Direction negative (moins = mieux). Refonte Sprint 5.",
    },
    "MIL_RES": {
        "wb_code":    "MS.MIL.TOTL.TF.ZS",
        "name_fr":    "Forces armees % main d'oeuvre totale",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "WB IISS -- forces armees actives en % de la main d'oeuvre totale.",
    },

    "MIN_INV": {
        "wb_code":    "NY.GDP.TOTL.RT.ZS",
        "name_fr":    "Rente totale ressources naturelles % PIB",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "WB -- proxy investissement secteur minier. Inclut petrole, gaz, mineraux.",
    },
    "MIN_ENV": {
        "wb_code":    "NY.GDP.NGAS.RT.ZS",
        "name_fr":    "Rente gaz naturel % PIB",
        "unit_code":  "PERCENT",
        "direction":  "-",
        "multiplier": 1.0,
        "notes":      "WB -- proxy impact environnemental extraction. Direction negative.",
    },
    "MIN_EMP": {
        "wb_code":    "SL.IND.EMPL.ZS",
        "name_fr":    "Emploi industrie % emploi total",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "WB OIT -- proxy emploi minier. Inclut toute l'industrie.",
    },
    # ── PILIER RESSOURCES STRATEGIQUES (PRES) — WB indicators ─
    "PRES_EN_ELEC_PROD":   {"wb_code": "EG.USE.ELEC.KH.PC", "name_fr": "Consommation electricite/hab",   "unit_code": "KWH_PC",  "direction": "+", "multiplier": 1.0,          "notes": "WB WDI EG.ELC.PROD.KH archive — proxy consommation kWh/hab"},
    "PRES_EN_CAP_PC":      {"wb_code": "EG.USE.ELEC.KH.PC", "name_fr": "Consommation electricite/hab",   "unit_code": "KWH_PC",  "direction": "+", "multiplier": 1.0,          "notes": "WB WDI proxy capacite — EG.ELC.PROD.KH archive"},
    "PRES_EN_RENEW_SHARE": {"wb_code": "EG.ELC.RNEW.ZS",  "name_fr": "Part energies renouvelables",    "unit_code": "PERCENT", "direction": "+", "multiplier": 1.0,          "notes": "WB WDI electricite renouvelable pct production"},
    "PRES_WA_RES_TOTAL":   {"wb_code": "ER.H2O.INTR.K3",  "name_fr": "Ressources eau renouvelables",   "unit_code": "M3",      "direction": "+", "multiplier": 1000000000.0, "notes": "WB WDI milliards m3 convertis en m3"},
    "PRES_WA_RES_PC":      {"wb_code": "ER.H2O.INTR.PC",  "name_fr": "Eau par habitant",               "unit_code": "M3_PC",   "direction": "+", "multiplier": 1.0,          "notes": "WB WDI ressources eau renouvelables par habitant"},
    "PRES_EN_LOSS":        {"wb_code": "EG.ELC.LOSS.ZS",     "name_fr": "Pertes reseau electrique",       "unit_code": "PERCENT",  "direction": "-", "multiplier": 1.0, "notes": "WB WDI pertes transmission distribution — efficacite systeme"},
    "PRES_EN_USE_PC":      {"wb_code": "EG.USE.PCAP.KG.OE",  "name_fr": "Consommation energie par hab",   "unit_code": "KTOE",     "direction": "+", "multiplier": 0.001, "notes": "WB WDI kgoe/hab converti en ktoe — proxy capacite energetique"},
    "PRES_WA_WITHDRAW":   {"wb_code": "ER.H2O.FWTL.K3",  "name_fr": "Prelevements eau totaux",         "unit_code": "M3",      "direction": "+", "multiplier": 1000000000.0, "notes": "WB WDI milliards m3 convertis en m3 — remplace PRES_WA_VARIABILITY"},
    "PRES_WA_INTERNAL":    {"wb_code": "ER.H2O.INTR.K3",  "name_fr": "Ressources eau internes totales", "unit_code": "M3",      "direction": "+", "multiplier": 1000000000.0, "notes": "PROXY — ER.H2O.INTR.ZS invalide — FAO AQUASTAT requis Sprint 5"},
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

# Correspondance ISO-3 -> ISO-2 (pour API qui utilisent ISO-2)
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
