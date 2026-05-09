# Fix UNCTAD - filtre rf.countries avant insertion
path_unctad = 'G:/osa-observatory/collectors/fetcher_unctad.py'
with open(path_unctad, 'r', encoding='utf-8') as f:
    c = f.read()

old = '    log.info("Préparation insertion : %d lignes...", len(df_insert))'
new = '''    # Filtrer sur les pays africains valides
    try:
        conn_tmp = get_pg_conn()
        import pandas as pd
        valid_iso3 = pd.read_sql("SELECT iso3 FROM rf.countries", conn_tmp)["iso3"].tolist()
        conn_tmp.close()
        before = len(df_insert)
        df_insert = df_insert[df_insert["country_iso3"].isin(valid_iso3)]
        log.info("  Filtre rf.countries : %d → %d lignes", before, len(df_insert))
    except Exception as e:
        log.warning("  Filtre rf.countries échoué : %s", e)
    log.info("Préparation insertion : %d lignes...", len(df_insert))'''

c = c.replace(old, new)

with open(path_unctad, 'w', encoding='utf-8') as f:
    f.write(c)
# Fix fetcher_wb_pres_pmil_pnum - filtre rf.countries
path = 'G:/osa-observatory/collectors/fetcher_wb_pres_pmil_pnum.py'
with open(path, 'r', encoding='utf-8') as f:
    c = f.read()

# Ajouter filtre rf.countries dans fetch_wb_indicator
old = '''    df = pd.DataFrame(records) if records else pd.DataFrame(
        columns=["country_iso3", "year", "raw_value"]
    )'''

new = '''    df = pd.DataFrame(records) if records else pd.DataFrame(
        columns=["country_iso3", "year", "raw_value"]
    )
    # Filtrer sur les pays valides de rf.countries
    try:
        conn_filter = get_pg_conn()
        import pandas as _pd
        valid_iso3 = _pd.read_sql("SELECT iso3 FROM rf.countries", conn_filter)["iso3"].tolist()
        conn_filter.close()
        df = df[df["country_iso3"].isin(valid_iso3)]
    except Exception:
        pass
    return df'''

# Enlever le return df existant
old2 = '''    df = pd.DataFrame(records) if records else pd.DataFrame(
        columns=["country_iso3", "year", "raw_value"]
    )
    return df'''

c = c.replace(old2, new)

with open(path, 'w', encoding='utf-8') as f:
    f.write(c)
print('FIXED fetcher_wb_pres_pmil_pnum countries filter')
print('FIXED UNCTAD countries filter')
# Fix fetcher_wb_pres_pmil_pnum - filtre dans insert_indicator
path = 'G:/osa-observatory/collectors/fetcher_wb_pres_pmil_pnum.py'
with open(path, 'r', encoding='utf-8') as f:
    c = f.read()

old = '''    if df.empty:
        return 0

    osa_code   = meta["osa_code"]
    multiplier = meta.get("multiplier", 1.0)

    if dry_run:'''

new = '''    if df.empty:
        return 0

    # Filtrer sur les pays valides de rf.countries
    try:
        conn_filter = get_pg_conn()
        import pandas as _pd
        valid_iso3 = _pd.read_sql("SELECT iso3 FROM rf.countries", conn_filter)["iso3"].tolist()
        conn_filter.close()
        df = df[df["country_iso3"].isin(valid_iso3)].copy()
    except Exception:
        pass

    osa_code   = meta["osa_code"]
    multiplier = meta.get("multiplier", 1.0)

    if dry_run:'''

c = c.replace(old, new)

with open(path, 'w', encoding='utf-8') as f:
    f.write(c)
print('FIXED fetcher_wb_pres_pmil_pnum insert filter')
