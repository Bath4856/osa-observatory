import pandas as pd
import numpy as np

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

# Criticite CE CRM 2023 + USGS 2024
# Score criticite: 3=tres critique, 2=critique, 1=important, 0=standard
criticality = {
    'Cobalt': 3, 'Lithium': 3, 'Rare earths': 3, 'Graphite': 3,
    'Platinum-Group metals': 3, 'Niobium': 3, 'Tantalum': 3,
    'Chromium': 2, 'Uranium': 2, 'Titanium Mineral Concentrates': 2,
    'Manganese': 2, 'Phosphate rock ': 1, 'Bauxite': 1,
    'Copper ': 1,
}

df_osa = df[df['COUNTRY'].isin(osa_map.keys())]

# Convertir les colonnes numeriques
df_osa = df_osa.copy()
df_osa['RESERVES_2024'] = pd.to_numeric(df_osa['RESERVES_2024'], errors='coerce')
df_osa['PROD_2023'] = pd.to_numeric(df_osa['PROD_2023'], errors='coerce')
df_osa['PROD_EST_ 2024'] = pd.to_numeric(df_osa['PROD_EST_ 2024'], errors='coerce')

# Calcul des 4 indicateurs par pays
results = {}
for country, iso3 in osa_map.items():
    df_c = df_osa[df_osa['COUNTRY'] == country]
    if df_c.empty:
        continue

    # MIN_GEO : reserves normalisees (log scale)
    res = df_c['RESERVES_2024'].dropna()
    min_geo = np.log1p(res.sum()) if len(res) > 0 else 0

    # MIN_CRI : score criticite pondere par reserves
    cri_score = 0
    for _, row in df_c.iterrows():
        crit = criticality.get(row['COMMODITY'], 0)
        res_val = row['RESERVES_2024'] if pd.notna(row['RESERVES_2024']) else 0
        prod_val = row['PROD_2023'] if pd.notna(row['PROD_2023']) else 0
        cri_score += crit * (res_val + prod_val * 10)

    # MIN_POT : rapport reserves/production (potentiel non exploite)
    total_res = df_c['RESERVES_2024'].dropna().sum()
    total_prod = df_c['PROD_2023'].dropna().sum()
    min_pot = total_res / (total_prod * 100 + 1) if total_prod > 0 else (
        np.log1p(total_res) if total_res > 0 else 0)

    # MIN_RAR : concentration terres rares et mineraux strategiques
    rar_minerals = ['Cobalt','Rare earths','Platinum-Group metals',
                    'Niobium','Tantalum','Lithium']
    df_rar = df_c[df_c['COMMODITY'].isin(rar_minerals)]
    rar_res = df_rar['RESERVES_2024'].dropna().sum()
    rar_prod = df_rar['PROD_2023'].dropna().sum()
    min_rar = np.log1p(rar_res + rar_prod * 100)

    results[iso3] = {
        'MIN_GEO': min_geo,
        'MIN_CRI': cri_score,
        'MIN_POT': min_pot,
        'MIN_RAR': min_rar,
    }

print(f'Pays avec donnees: {len(results)}')

# Normalisation 0-1 par indicateur
for ind in ['MIN_GEO','MIN_CRI','MIN_POT','MIN_RAR']:
    vals = [v[ind] for v in results.values() if v[ind] > 0]
    if not vals:
        continue
    max_v = max(vals)
    min_v = min(vals)
    for iso3 in results:
        raw = results[iso3][ind]
        if max_v > min_v and raw > 0:
            results[iso3][ind] = round((raw - min_v) / (max_v - min_v), 6)
        else:
            results[iso3][ind] = 0.0

# Afficher le top 10 par indicateur
for ind in ['MIN_GEO','MIN_CRI','MIN_POT','MIN_RAR']:
    top = sorted(results.items(), key=lambda x: x[1][ind], reverse=True)[:5]
    print(f'\nTop 5 {ind}: {[(iso3, round(v[ind],3)) for iso3, v in top]}')

# Generer SQL -- propagation 2010-2024 (donnees MCS stable)
q = chr(39)
ep = '(SELECT id FROM collect.provider_endpoints WHERE endpoint_code = ' + q + 'USGS_MYB_AFRICA' + q + ')'

with open(r'G:\osa-observatory\db\ingest_pmin_physical.sql', 'w', encoding='utf-8') as f:
    f.write('-- PMIN : Indicateurs physiques MIN_GEO MIN_CRI MIN_POT MIN_RAR\n')
    f.write('-- Source : USGS MCS2025_World_Data.csv\n')
    f.write('-- Normalisation 0-1 sur perimetre OSA\n')
    f.write('-- Propagation 2010-2024 (donnees geologiques stables)\n\n')
    for iso3, inds in results.items():
        for ind, val in inds.items():
            if val > 0:
                for year in range(2010, 2025):
                    f.write(
                        f'INSERT INTO ma.indicator_values '
                        f'(indicator_code, country_iso3, year, raw_value, processed_value, '
                        f'value_status, confidence_score, layer_id) '
                        f'VALUES ({q}{ind}{q}, {q}{iso3}{q}, {year}, {val}, {val}, '
                        f'{q}OBSERVED{q}, 0.85, 1) '
                        f'ON CONFLICT DO NOTHING;\n'
                    )

print(f'\nScript genere: ingest_pmin_physical.sql')
total = sum(1 for iso3, inds in results.items()
            for ind, val in inds.items() if val > 0) * 15
print(f'Lignes estimees: {total}')