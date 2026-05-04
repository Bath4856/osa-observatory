import psycopg2
import os
from dotenv import load_dotenv
load_dotenv()

conn = psycopg2.connect(
    host=os.getenv("OSA_DB_HOST","localhost"),
    port=int(os.getenv("OSA_DB_PORT","5432")),
    dbname=os.getenv("OSA_DB_NAME","osa_db"),
    user=os.getenv("OSA_DB_USER","postgres"),
    password=os.getenv("OSA_DB_PASS",""),
)
cur = conn.cursor()

# Supprimer les references bibliographiques (footnotes Wikipedia)
cur.execute("""
    DELETE FROM osa.pgeo_site
    WHERE name LIKE '^"%'
       OR name LIKE '^ %'
       OR name LIKE '%Retrieved%'
       OR name LIKE '%[update]%'
       OR LENGTH(name) > 150
""")
deleted_refs = cur.rowcount
print(f"References bibliographiques supprimees: {deleted_refs}")

# Mapper les sites avec ressource identifiable
extra_mappings = {
    'gold':       38, 'or ':        38, 'auriferous':  38,
    'diamond':    35, 'kimberlite': 35,
    'bauxite':    19, 'alumin':     19,
    'coal':       30, 'charbon':    30,
    'copper':     16, 'cuivre':     16,
    'iron':       14, 'fer':        14,
    'uranium':    25,
    'nickel':     17,
    'cobalt':     18,
    'manganese':  15,
    'chromium':   23, 'chrome':     23,
    'zinc':       21,
    'lead':       20, 'plomb':      20,
    'tin':        22, 'etain':      22,
    'titanium':   27, 'ilmenite':   27,
    'graphite':   2,
    'phosphate':  5,
    'potash':     5,
    'platinum':   39,
    'silver':     37,
    'niobium':    28, 'tantalum':   28, 'coltan':     28,
    'tungsten':   24,
}

cur.execute("SELECT id, name FROM osa.pgeo_site WHERE resource_id IS NULL")
sites = cur.fetchall()
print(f"Sites restants sans resource_id: {len(sites)}")

updated = 0
for site_id, name in sites:
    name_lower = name.lower()
    matched_rid = None
    for kw, rid in extra_mappings.items():
        if kw in name_lower:
            matched_rid = rid
            break
    if matched_rid:
        cur.execute("UPDATE osa.pgeo_site SET resource_id = %s WHERE id = %s",
                   (matched_rid, site_id))
        updated += 1

conn.commit()
print(f"Sites supplementaires mappes: {updated}")

# Bilan final
cur.execute("""
    SELECT
        COUNT(*) AS total,
        COUNT(resource_id) AS avec_resource,
        COUNT(*) - COUNT(resource_id) AS sans_resource,
        COUNT(latitude) AS avec_coords,
        COUNT(DISTINCT country_iso3) AS nb_pays
    FROM osa.pgeo_site
""")
row = cur.fetchone()
print(f"\nBilan final pgeo_site:")
print(f"  Total sites    : {row[0]}")
print(f"  Avec resource  : {row[1]}")
print(f"  Sans resource  : {row[2]}")
print(f"  Avec coords    : {row[3]}")
print(f"  Pays couverts  : {row[4]}")

cur.close()
conn.close()