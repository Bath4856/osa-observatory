f = open('G:/osa-observatory/collectors/fetcher_wb_ptra.py', 'r', encoding='utf-8')
c = f.read()
f.close()

# Remplacer le filtre agregats par un filtre sur rf.countries
old = '''    df = df[~df["country_iso3"].isin(WB_AGGREGATES)]
    return df'''

new = '''    df = df[~df["country_iso3"].isin(WB_AGGREGATES)]
    # Filtrer sur les ISO3 valides de rf.countries
    try:
        conn_filter = get_pg_conn()
        valid_iso3 = pd.read_sql("SELECT iso3 FROM rf.countries", conn_filter)["iso3"].tolist()
        conn_filter.close()
        df = df[df["country_iso3"].isin(valid_iso3)]
    except Exception:
        pass
    return df'''

c = c.replace(old, new)

f = open('G:/osa-observatory/collectors/fetcher_wb_ptra.py', 'w', encoding='utf-8')
f.write(c)
f.close()
print('OK')