import pandas as pd

osa_map = {
    'Algeria':'DZA','Angola':'AGO','Benin':'BEN','Botswana':'BWA',
    'Burkina Faso':'BFA','Burundi':'BDI','Cameroon':'CMR','Cape Verde':'CPV',
    'Central African Republic':'CAF','Chad':'TCD','Comoros':'COM',
    'Congo':'COG','Djibouti':'DJI','Egypt':'EGY','Equatorial Guinea':'GNQ',
    'Eritrea':'ERI','Eswatini':'SWZ','Ethiopia':'ETH','Gabon':'GAB',
    'Gambia':'GMB','Ghana':'GHA','Guinea':'GIN','Guinea-Bissau':'GNB',
    'Kenya':'KEN','Lesotho':'LSO','Liberia':'LBR','Libya':'LBY',
    'Madagascar':'MDG','Malawi':'MWI','Mali':'MLI','Mauritania':'MRT',
    'Mauritius':'MUS','Morocco':'MAR','Mozambique':'MOZ','Namibia':'NAM',
    'Niger':'NER','Nigeria':'NGA','Rwanda':'RWA','Sao Tome and Principe':'STP',
    'Senegal':'SEN','Seychelles':'SYC','Sierra Leone':'SLE','Somalia':'SOM',
    'South Africa':'ZAF','South Sudan':'SSD','Sudan':'SDN','Tanzania':'TZA',
    'Togo':'TGO','Tunisia':'TUN','Uganda':'UGA','Zambia':'ZMB','Zimbabwe':'ZWE',
    'Dem. Rep. of the Congo':'COD',"Cote d'Ivoire":'CIV',"Côte d'Ivoire":'CIV',
}

hs_map = {
    'Ores, slag and ash': 'MIN_EXP_ORE',
    'Natural, cultured pearls; precious, semi-precious stones; precious metals, metals clad with precious metal, and articles thereof; imitation jewellery; coin': 'MIN_EXP_PRC',
    'Mineral fuels, mineral oils and products of their distillation; bituminous substances; mineral waxes': 'MIN_EXP_FUL',
}

results = []
for fname, years in [
    (r'G:\osa-observatory\data\raw\pmin\comtrade\comtrade_minerals_2010_2021.csv', range(2010,2022)),
    (r'G:\osa-observatory\data\raw\pmin\comtrade\comtrade_minerals_2022_2024.csv', range(2022,2025)),
]:
    try:
        df = pd.read_csv(fname, encoding='latin1', low_memory=False)
        df_osa = df[df['reporterISO'].isin(osa_map.keys())]
        df_exp = df_osa[df_osa['reporterDesc'] == 'X']
        df_crit = df_exp[df_exp['cmdCode'].isin(hs_map.keys())]
        for _, row in df_crit.iterrows():
            iso3 = osa_map.get(row['reporterISO'])
            year = row['refPeriodId']
            ind = hs_map.get(row['cmdCode'])
            val = row['fobvalue']
            if iso3 and year and ind and pd.notna(val) and float(val) > 0:
                results.append((ind, iso3, int(year), float(val)))
        print(f'{fname[-30:]}: {len(df_crit)} lignes')
    except Exception as e:
        print(f'Erreur: {e}')

# Creer indicateurs si necessaire
inds = set(r[0] for r in results)
print(f'\nIndicateurs: {inds}')
print(f'Total resultats: {len(results)}')
print(f'Pays: {len(set(r[1] for r in results))}')
print(f'Annees: {sorted(set(r[2] for r in results))}')

# Generer SQL
q = chr(39)
ep = '(SELECT id FROM collect.provider_endpoints WHERE endpoint_code = ' + q + 'COMTRADE_MINERALS' + q + ')'
with open(r'G:\osa-observatory\db\ingest_comtrade_minerals.sql', 'w', encoding='utf-8') as f:
    f.write('-- PMIN : Ingestion COMTRADE exportations mineraux\n\n')
    # Provider endpoint
    f.write('INSERT INTO collect.provider_endpoints (provider_id, endpoint_code, name, endpoint_url, output_format, description, is_active)\n')
    f.write('SELECT id, ' + q + 'COMTRADE_MINERALS' + q + ', ' + q + 'COMTRADE Minerals exports' + q + ', ')
    f.write(q + 'https://comtradeplus.un.org' + q + ', ' + q + 'csv' + q + ', ')
    f.write(q + 'Exportations mineraux critiques HS26 HS71 HS27 2010-2024' + q + ', true\n')
    f.write('FROM collect.data_providers WHERE code = ' + q + 'WB' + q + '\n')
    f.write('ON CONFLICT (endpoint_code) DO NOTHING;\n\n')
    # Indicateurs
    for ind in inds:
        f.write('INSERT INTO rf.indicators (code, name_fr, name_en, pillar_code, direction, unit_code, imputation_regime)\n')
        f.write('VALUES (' + q + ind + q + ', ' + q + 'Exportations mineraux ' + ind[-3:] + q + ', ')
        f.write(q + 'Mineral exports ' + ind[-3:] + q + ', ' + q + 'PMIN' + q + ', ' + q + '+' + q + ', ')
        f.write(q + 'USD' + q + ', ' + q + 'STANDARD' + q + ')\n')
        f.write('ON CONFLICT (code) DO NOTHING;\n\n')
    # Data
    for ind, iso3, year, val in results:
        f.write('INSERT INTO collect.raw_data (endpoint_id, indicator_code, country_iso3, year, value_raw) ')
        f.write('VALUES (' + ep + ', ' + q + ind + q + ', ' + q + iso3 + q + ', ' + str(year) + ', ' + str(val) + ');\n')

print('Script genere: ingest_comtrade_minerals.sql')