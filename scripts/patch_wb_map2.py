content = open(r'G:\osa-observatory\collectors\wb_indicator_map.py', 'r', encoding='utf-8').read()

# ENV_WAS : changer EN.ATM.METH.PC -> EN.ATM.GHGT.ZG (emissions GES totales)
content = content.replace(
    '"ENV_WAS": {\n        "wb_code":    "EN.ATM.METH.PC"',
    '"ENV_WAS": {\n        "wb_code":    "EN.ATM.GHGT.ZG"'
)

# ENV_RSK : changer EN.CLC.MDAT.ZS -> SH.DYN.NCOM.ZS (proxy risque sante)
content = content.replace(
    '"ENV_RSK": {\n        "wb_code":    "EN.CLC.MDAT.ZS"',
    '"ENV_RSK": {\n        "wb_code":    "SH.DYN.NCOM.ZS"'
)

# ENV_ADA : changer EN.CLC.MDAT.ZS -> EN.ATM.CO2E.GF.ZS (proxy adaptation)
content = content.replace(
    '"ENV_ADA": {\n        "wb_code":    "EN.CLC.MDAT.ZS"',
    '"ENV_ADA": {\n        "wb_code":    "EN.ATM.CO2E.GF.ZS"'
)

open(r'G:\osa-observatory\collectors\wb_indicator_map.py', 'w', encoding='utf-8').write(content)
print('OK - codes WB corriges')