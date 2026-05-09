f = open('G:/osa-observatory/collectors/imputer_v3.py', 'r', encoding='utf-8')
c = f.read()
f.close()

# Enlever l'appel mal placé dans step1_duckdb
c = c.replace(
    '    log.info("Etape 0 -- Grille complète pays × années × indicateurs...")\n    df_raw = step0_full_grid(df_raw, df_countries)\n    log.info("Etape 1 -- DuckDB interpolation...")',
    '    log.info("Etape 1 -- DuckDB interpolation...")'
)

# Trouver le bon endroit dans run() - apres le chargement des données
c = c.replace(
    '    df_raw, df_countries, df_coverage = load_data(conn,',
    '    df_raw, df_countries, df_coverage = load_data(conn,'
)

# Injecter step0 dans run() apres load_data
old_run = '''    log.info("Données : %d lignes | %d indicateurs | %d pays",
             len(df_raw),
             df_raw["indicator_code"].nunique(),
             df_raw["country_iso3"].nunique())'''

new_run = '''    log.info("Données : %d lignes | %d indicateurs | %d pays",
             len(df_raw),
             df_raw["indicator_code"].nunique(),
             df_raw["country_iso3"].nunique())
    log.info("Etape 0 -- Grille complète pays × années × indicateurs...")
    df_raw = step0_full_grid(df_raw, df_countries)'''

c = c.replace(old_run, new_run)

f = open('G:/osa-observatory/collectors/imputer_v3.py', 'w', encoding='utf-8')
f.write(c)
f.close()
print('OK')