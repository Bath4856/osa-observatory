import pandas as pd

df = pd.read_csv(r'G:\osa-observatory\data\raw\pmin\usgs\MCS2025_World_Data.csv', encoding='latin1')

osa_countries = ['Algeria','Angola','Benin','Botswana','Burkina Faso','Burundi',
    'Cameroon','Cape Verde','Central African Republic','Chad','Comoros',
    'Congo','Djibouti','Egypt','Equatorial Guinea','Eritrea','Eswatini',
    'Ethiopia','Gabon','Gambia','Ghana','Guinea','Guinea-Bissau','Kenya',
    'Lesotho','Liberia','Libya','Madagascar','Malawi','Mali','Mauritania',
    'Mauritius','Morocco','Mozambique','Namibia','Niger','Nigeria','Rwanda',
    'Sao Tome and Principe','Senegal','Seychelles','Sierra Leone','Somalia',
    'South Africa','South Sudan','Sudan','Tanzania','Togo','Tunisia',
    'Uganda','Zambia','Zimbabwe','Democratic Republic of the Congo','Ivory Coast']

critical = ['Cobalt','Lithium','Manganese','Platinum','Uranium','Bauxite',
            'Phosphate Rock','Chromium','Graphite (Natural)','Rare Earths',
            'Nickel','Copper','Gold','Diamonds','Iron Ore','Zinc','Titanium']

df_osa = df[df['COUNTRY'].isin(osa_countries)]
df_crit = df_osa[df_osa['COMMODITY'].isin(critical)]

print('Pays OSA dans MCS2025:', df_osa['COUNTRY'].nunique())
print('Pays OSA avec minerais critiques:', df_crit['COUNTRY'].nunique())
print()
print('Tous les minerais disponibles:')
print(sorted(df_osa['COMMODITY'].unique()))
print()
print('Reserves par pays et minerai critique:')
res = df_crit[df_crit['RESERVES_2024'].notna()][['COUNTRY','COMMODITY','RESERVES_2024','UNIT_MEAS']]
print(res.to_string())