content = open(r'G:\osa-observatory\collectors\wb_indicator_map.py', 'r', encoding='utf-8').read()

# ENV_WAS : urbanisation comme proxy gestion dechets
content = content.replace(
    '"ENV_WAS": {\n        "wb_code":    "EN.ATM.GHGT.ZG"',
    '"ENV_WAS": {\n        "wb_code":    "EN.POP.SLUM.UR.ZS"'
)
content = content.replace(
    '"ENV_WAS": {\n        "name_fr":    "Emissions methane par habitant"',
    '"ENV_WAS": {\n        "name_fr":    "Population bidonvilles pct urbain"'
)

# ENV_ADA : mortalite infantile comme proxy adaptation climatique
content = content.replace(
    '"ENV_ADA": {\n        "wb_code":    "EN.ATM.CO2E.GF.ZS"',
    '"ENV_ADA": {\n        "wb_code":    "SH.DYN.MORT"'
)
content = content.replace(
    '"ENV_ADA": {\n        "name_fr":    "Adaptation climatique proxy"',
    '"ENV_ADA": {\n        "name_fr":    "Mortalite infantile proxy adaptation"'
)

open(r'G:\osa-observatory\collectors\wb_indicator_map.py', 'w', encoding='utf-8').write(content)
print('OK')