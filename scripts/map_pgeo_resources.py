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

# Charger le mapping wiki_keywords -> resource_id
cur.execute("SELECT resource_id, wiki_keywords FROM osa.mineral_mapping WHERE wiki_keywords IS NOT NULL")
mappings = [(rid, [kw.strip().lower() for kw in kws.split(',')]) for rid, kws in cur.fetchall()]

# Charger les sites sans resource_id
cur.execute("SELECT id, name FROM osa.pgeo_site WHERE resource_id IS NULL")
sites = cur.fetchall()
print(f"Sites sans resource_id : {len(sites)}")

updated = 0
for site_id, name in sites:
    name_lower = name.lower()
    matched_rid = None
    for resource_id, keywords in mappings:
        if any(kw in name_lower for kw in keywords):
            matched_rid = resource_id
            break
    if matched_rid:
        cur.execute("UPDATE osa.pgeo_site SET resource_id = %s WHERE id = %s",
                   (matched_rid, site_id))
        updated += 1

conn.commit()
print(f"Sites mis a jour : {updated}")

# Verification
cur.execute("""
    SELECT mr.category, mr.label, COUNT(*) AS nb_sites
    FROM osa.pgeo_site ps
    JOIN osa.mineral_resource mr ON mr.id = ps.resource_id
    GROUP BY mr.category, mr.label
    ORDER BY nb_sites DESC
    LIMIT 20
""")
print("\nDistribution par ressource:")
for row in cur.fetchall():
    print(f"  {row[0]} / {row[1]}: {row[2]} sites")

cur.close()
conn.close()