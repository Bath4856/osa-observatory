import pandas as pd

df = pd.read_csv(r'G:\osa-observatory\data\raw\pmin\usgs\MCS2025_World_Data.csv', encoding='latin1')

osa_map = {
    'Algeria':'DZA','Angola':'AGO','Benin':'BEN','Botswana':'BWA',
    'Burkina Faso':'BFA','Burundi':'BDI','Cameroon':'CMR','Cape Verde':'CPV',
    'Central African Republic':'CAF','Chad':'TCD','Comoros':'COM',
    'Congo':'COG','Djibouti':'DJI','Egypt':'EGY','Equatorial Guinea':'GNQ',
    'Eritrea':'ERI','Eswatini':'SWZ','Ethiopia':'ETH','Gabon':'GAB',
    'Gambia':'GMB','Ghana':'GHA','Guinea':'GIN','Guinea-Bissau':'GNB',
    'Ivory Coast':'CIV','Kenya':'KEN','Lesotho':'LSO','Liberia':'LBR',
    'Libya':'LBY','Madagascar':'MDG','Malawi':'MWI','Mali':'MLI',
    'Mauritania':'MRT','Mauritius':'MUS','Morocco':'MAR','Mozambique':'MOZ',
    'Namibia':'NAM','Niger':'NER','Nigeria':'NGA','Rwanda':'RWA',
    'Sao Tome and Principe':'STP','Senegal':'SEN','Seychelles':'SYC',
    'Sierra Leone':'SLE','Somalia':'SOM','South Africa':'ZAF',
    'South Sudan':'SSD','Sudan':'SDN','Tanzania':'TZA','Togo':'TGO',
    'Tunisia':'TUN','Uganda':'UGA','Zambia':'ZMB','Zimbabwe':'ZWE',
    'Democratic Republic of the Congo':'COD',
}

# Mineraux critiques CE + USGS
critical_minerals = [
    'Cobalt','Lithium','Manganese','Platinum-Group metals',
    'Rare earths','Graphite','Chromium','Uranium',
    'Niobium','Tantalum','Titanium Mineral Concentrates',
    'Bauxite','Phosphate rock ','Copper '
]

df_osa = df[df['COUNTRY'].isin(osa_map.keys())]
df_crit = df_osa[df_osa['COMMODITY'].isin(critical_minerals)]

print(f'Pays OSA: {df_osa["COUNTRY"].nunique()}')
print(f'Pays avec mineraux critiques: {df_crit["COUNTRY"].nunique()}')
print()

# Reserves par pays
print('=== RESERVES 2024 par pays et minerai ===')
res = df_crit[df_crit['RESERVES_2024'].notna()][
    ['COUNTRY','COMMODITY','RESERVES_2024','UNIT_MEAS']
].sort_values(['COUNTRY','COMMODITY'])
print(res.to_string())
print()

# Production 2023
print('=== PRODUCTION 2023 par minerai critique ===')
prod = df_crit[df_crit['PROD_2023'].notna()][
    ['COUNTRY','COMMODITY','PROD_2023','UNIT_MEAS']
].sort_values('PROD_2023', ascending=False)
print(prod.to_string())