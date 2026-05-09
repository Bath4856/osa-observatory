import pandas as pd

osa_names = ['Algeria','Angola','Benin','Botswana','Burkina Faso','Burundi',
    'Cameroon','Cape Verde','Central African Republic','Chad','Comoros',
    'Congo','Djibouti','Egypt','Equatorial Guinea','Eritrea','Eswatini',
    'Ethiopia','Gabon','Gambia','Ghana','Guinea','Guinea-Bissau','Kenya',
    'Lesotho','Liberia','Libya','Madagascar','Malawi','Mali','Mauritania',
    'Mauritius','Morocco','Mozambique','Namibia','Niger','Nigeria','Rwanda',
    'Sao Tome and Principe','Senegal','Seychelles','Sierra Leone','Somalia',
    'South Africa','South Sudan','Sudan','Tanzania','Togo','Tunisia',
    'Uganda','Zambia','Zimbabwe','Dem. Rep. of the Congo','Côte d\'Ivoire']

hs_critical = ['Ores, slag and ash',
    'Natural, cultured pearls; precious, semi-precious stones; precious metals, metals clad with precious metal, and articles thereof; imitation jewellery; coin',
    'Mineral fuels, mineral oils and products of their distillation; bituminous substances; mineral waxes']

df1 = pd.read_csv(
    r'G:\osa-observatory\data\raw\pmin\comtrade\comtrade_minerals_2010_2021.csv',
    encoding='latin1', low_memory=False)

# reporterISO = country name, reporterDesc = flow (M/X)
df_osa = df1[df1['reporterISO'].isin(osa_names)]
print(f'Lignes pays OSA: {len(df_osa)}')
print(f'Pays OSA trouves: {sorted(df_osa["reporterISO"].unique())}')
print(f'Annees: {sorted(df_osa["refYear"].unique())}')
print()
df_exp = df_osa[df_osa['reporterDesc'] == 'X']
df_crit = df_exp[df_exp['cmdCode'].isin(hs_critical)]
print(f'Exports mineraux critiques: {len(df_crit)} lignes')
print()
print('Valeur exports par pays (top 10):')
top = df_crit.groupby('reporterISO')['primaryValue'].sum().sort_values(ascending=False).head(10)
print(top.to_string())
print()
print('Valeur exports par minerai:')
print(df_crit.groupby('cmdCode')['primaryValue'].sum().to_string())