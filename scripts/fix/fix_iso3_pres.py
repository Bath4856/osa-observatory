f = open('G:/osa-observatory/collectors/fetcher_wb_pres_pmil_pnum.py', 'r', encoding='utf-8')
c = f.read()
f.close()
c = c.replace(
    'iso3 = row.get("countryiso3code", "")\n            year',
    'iso3 = row.get("countryiso3code", "") or row.get("country", {}).get("id", "")\n            year'
)
f = open('G:/osa-observatory/collectors/fetcher_wb_pres_pmil_pnum.py', 'w', encoding='utf-8')
f.write(c)
f.close()
print('OK')
