with open('G:/osa-observatory/collectors/fetcher_wb_ptra.py', 'r', encoding='utf-8') as f:
    c = f.read()

old = '''    return pd.DataFrame(records) if records else pd.DataFrame(
        columns=["country_iso3", "year", "raw_value"]
    )'''

new = '''    df = pd.DataFrame(records) if records else pd.DataFrame(
        columns=["country_iso3", "year", "raw_value"]
    )
    # Exclure les agrégats régionaux WB (non ISO3 pays)
    # Les vrais ISO3 pays sont tous dans rf.countries
    # Filtre simple : exclure codes connus comme agrégats WB
    WB_AGGREGATES = {
        "AFE","AFW","ARB","CEB","CSS","EAP","EAR","EAS","ECA","ECS",
        "EMU","EUU","FCS","HIC","HPC","IBD","IBT","IDA","IDB","IDX",
        "LAC","LCN","LDC","LIC","LMC","LMY","LTE","MEA","MIC","MNA",
        "NAC","NOC","OEC","OSS","PRE","PSS","PST","SAR","SAS","SSA",
        "SSF","SST","TEA","TEC","TLA","TMN","TSA","TSS","UMC","WLD",
        "XZN","ZAF","ZAR",
    }
    df = df[~df["country_iso3"].isin(WB_AGGREGATES)]
    return df'''

c = c.replace(old, new)

with open('G:/osa-observatory/collectors/fetcher_wb_ptra.py', 'w', encoding='utf-8') as f:
    f.write(c)
print('OK')
