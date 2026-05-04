content = open(r'G:\osa-observatory\collectors\wb_indicator_map.py', 'r', encoding='utf-8').read()

new_entries = """
    # -- PENV complement D9
    "ENV_PRO": {
        "wb_code":    "ER.LND.PTLD.ZS",
        "name_fr":    "Aires protegees pct superficie",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "Part territoire en aires protegees",
    },
    "ENV_WAT": {
        "wb_code":    "ER.H2O.INTR.PC",
        "name_fr":    "Ressources eau douce par hab",
        "unit_code":  "M3_PC",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "m3 par habitant par an",
    },
    "ENV_LAN": {
        "wb_code":    "AG.LND.AGRI.ZS",
        "name_fr":    "Terres agricoles pct superficie",
        "unit_code":  "PERCENT",
        "direction":  "-",
        "multiplier": 1.0,
        "notes":      "Proxy degradation terres",
    },
    "ENV_FIS": {
        "wb_code":    "ER.FSH.PROD.MT",
        "name_fr":    "Production halieutique totale",
        "unit_code":  "TONNES",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "Production peche et aquaculture",
    },
    "ENV_SOL": {
        "wb_code":    "AG.LND.ARBL.ZS",
        "name_fr":    "Terres arables pct superficie",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "Proxy fertilite sols",
    },
    "ENV_WAS": {
        "wb_code":    "EN.ATM.METH.PC",
        "name_fr":    "Emissions methane par habitant",
        "unit_code":  "TONNES",
        "direction":  "-",
        "multiplier": 1.0,
        "notes":      "Proxy gestion dechets",
    },
    "ENV_RSK": {
        "wb_code":    "EN.CLC.MDAT.ZS",
        "name_fr":    "Mortalite catastrophes climatiques",
        "unit_code":  "PERCENT",
        "direction":  "-",
        "multiplier": 1.0,
        "notes":      "Proxy risque climatique",
    },
    "ENV_ADA": {
        "wb_code":    "EN.CLC.MDAT.ZS",
        "name_fr":    "Adaptation climatique proxy",
        "unit_code":  "PERCENT",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "Inverse mortalite catastrophes",
    },
    "ENV_ECO": {
        "wb_code":    "AG.LND.FRST.K2",
        "name_fr":    "Superficie forestiere km2",
        "unit_code":  "KM_TOTAL",
        "direction":  "+",
        "multiplier": 1.0,
        "notes":      "Proxy resilience ecologique",
    },
"""

marker = '    # ── PILIER NUMERIQUE (PNUM)'
if marker in content:
    content = content.replace(marker, new_entries + marker)
    open(r'G:\osa-observatory\collectors\wb_indicator_map.py', 'w', encoding='utf-8').write(content)
    print('OK - 9 indicateurs ENV ajoutes')
else:
    print('Marqueur non trouve - cherche alternatives')
    for line in content.split('\n'):
        if 'PNUM' in line or 'NUM_INT' in line:
            print(repr(line))