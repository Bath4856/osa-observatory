"""
OSA Observatory — fix_fetcher_base_countries.py v2
Migre AFRICAN_ISO3 (list) vers rf.countries WHERE is_active=TRUE
"""
import re
from pathlib import Path

FETCHER = Path("collectors/fetcher_base.py")
content = FETCHER.read_text(encoding="utf-8")

# Pattern : AFRICAN_ISO3: list[str] = [ ... ]
pattern = r'(AFRICAN_ISO3\s*:\s*list\[str\]\s*=\s*\[[^\]]+\])'
match = re.search(pattern, content, re.DOTALL)

if not match:
    # Essayer sans annotation de type
    pattern2 = r'(AFRICAN_ISO3\s*=\s*\[[^\]]+\])'
    match = re.search(pattern2, content, re.DOTALL)

if match:
    old_def = match.group(0)
    print(f"Pattern trouvé ({len(old_def)} chars)")
    print(f"Début : {repr(old_def[:80])}")

    new_def = '''AFRICAN_ISO3_FALLBACK: list[str] = [
    "DZA","EGY","LBY","MAR","MRT","SDN","TUN",
    "BEN","BFA","CIV","CPV","GMB","GHA","GIN","GNB","LBR",
    "MLI","NER","NGA","SEN","SLE","TGO",
    "BDI","COM","DJI","ERI","ETH","KEN","MDG","MWI","MUS",
    "MOZ","RWA","SYC","SOM","SSD","TZA","UGA","ZMB","ZWE",
    "AGO","CMR","CAF","TCD","COG","COD","GNQ","GAB","STP",
    "BWA","LSO","NAM","ZAF","SWZ",
]

def _load_african_iso3() -> list:
    """Charge la liste des pays OSA actifs depuis rf.countries.
    Fallback sur liste locale si DB inaccessible.
    Doctrine OSA : rf.countries est la source de verite unique.
    Ajouter un pays = 1 INSERT dans rf.countries WHERE is_active=TRUE.
    """
    try:
        import psycopg2, os
        from dotenv import load_dotenv
        load_dotenv()
        conn = psycopg2.connect(
            host=os.getenv("OSA_DB_HOST", "127.0.0.1"),
            port=int(os.getenv("OSA_DB_PORT", 5432)),
            dbname=os.getenv("OSA_DB_NAME", "osa_db"),
            user=os.getenv("OSA_DB_USER", "postgres"),
            password=os.getenv("OSA_DB_PASS", ""),
        )
        with conn.cursor() as cur:
            cur.execute(
                "SELECT iso3 FROM rf.countries WHERE is_active = TRUE ORDER BY iso3"
            )
            iso3_list = [row[0] for row in cur.fetchall()]
        conn.close()
        if len(iso3_list) >= 50:
            return iso3_list
        return AFRICAN_ISO3_FALLBACK
    except Exception as e:
        import logging
        logging.getLogger(__name__).warning(
            "rf.countries inaccessible (%s) -- fallback liste locale", e
        )
        return AFRICAN_ISO3_FALLBACK

AFRICAN_ISO3: list[str] = _load_african_iso3()'''

    content = content.replace(old_def, new_def, 1)
    FETCHER.write_text(content, encoding="utf-8")
    print("OK -- fetcher_base.py migre vers rf.countries")
    print("   AFRICAN_ISO3 charge depuis rf.countries WHERE is_active=TRUE")
    print("   Fallback local si DB inaccessible")
else:
    print("WARN -- Pattern non trouve")
    idx = content.find("AFRICAN_ISO3")
    print(f"  Position : {idx}")
    print(f"  Contexte : {repr(content[idx:idx+200])}")
