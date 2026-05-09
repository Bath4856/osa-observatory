f = open('G:/osa-observatory/collectors/fetcher_wb_ptra.py', 'r', encoding='utf-8')
c = f.read()
f.close()

old = '            iso3 = row.get("countryiso3code", "")\n            year = int(row.get("date", 0))\n            if not iso3 or not year:\n                continue'
new = '            iso3 = row.get("countryiso3code", "") or row.get("country", {}).get("id", "")\n            year = int(row.get("date", 0))\n            if not iso3 or not year:\n                continue'

c = c.replace(old, new)

f = open('G:/osa-observatory/collectors/fetcher_wb_ptra.py', 'w', encoding='utf-8')
f.write(c)
f.close()
print('OK' if old in open('G:/osa-observatory/collectors/fetcher_wb_ptra.py', 'r', encoding='utf-8').read() == False else 'REPLACED')
