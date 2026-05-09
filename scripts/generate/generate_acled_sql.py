import pandas as pd
import json
import psycopg2
import os
from math import radians, sin, cos, sqrt, atan2
from dotenv import load_dotenv
load_dotenv()

def haversine(lat1, lon1, lat2, lon2):
    R = 6371
    lat1, lon1, lat2, lon2 = map(radians, [lat1, lon1, lat2, lon2])
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    a = sin(dlat/2)**2 + cos(lat1)*cos(lat2)*sin(dlon/2)**2
    return R * 2 * atan2(sqrt(a), sqrt(1-a))

osa_map = {
    'Algeria':'DZA','Angola':'AGO','Benin':'BEN','Botswana':'BWA',
    'Burkina Faso':'BFA','Burundi':'BDI','Cameroon':'CMR','Cape Verde':'CPV',
    'Central African Republic':'CAF','Chad':'TCD','Comoros':'COM',
    'Congo':'COG','Djibouti':'DJI','Egypt':'EGY','Equatorial Guinea':'GNQ',
    'Eritrea':'ERI','Eswatini':'SWZ','Ethiopia':'ETH','Gabon':'GAB',
    'Gambia':'GMB','Ghana':'GHA','Guinea':'GIN','Guinea-Bissau':'GNB',
    'Ivory Coast':'CIV','Kenya':'KEN','Lesotho':'LSO','Liberia':'LBR',
    'Libya':'LBY','Madagascar':'MDG','Malawi':'MWI','Mali':'MLI',
    'Mauritania':'MRT','Mauritius':'MUS','Morocco':'MAR','Mozambique':'MOZ',
    'Namibia':'NAM','Niger':'NER','Nigeria':'NGA','Rwanda':'RWA',
    'Sao Tome and Principe':'STP','Senegal':'SEN','Seychelles':'SYC',
    'Sierra Leone':'SLE','Somalia':'SOM','South Africa':'ZAF',
    'South Sudan':'SSD','Sudan':'SDN','Tanzania':'TZA','Togo':'TGO',
    'Tunisia':'TUN','Uganda':'UGA','Zambia':'ZMB','Zimbabwe':'ZWE',
    'Democratic Republic of Congo':'COD','DR Congo':'COD',
    'Democratic Republic of the Congo':'COD',
}

print("Chargement ACLED...")
df = pd.read_excel(r'G:\osa-observatory\data\raw\pgeo\acled_africa.xlsx')
df['year'] = pd.to_datetime(df['WEEK']).dt.year
df_osa = df[df['COUNTRY'].isin(osa_map.keys()) & df['year'].between(2010,2024)].copy()
df_osa['iso3'] = df_osa['COUNTRY'].map(osa_map)
print(f"Evenements OSA 2010-2024: {len(df_osa)}")

conn = psycopg2.connect(
    host=os.getenv("OSA_DB_HOST","localhost"),
    port=int(os.getenv("OSA_DB_PORT","5432")),
    dbname=os.getenv("OSA_DB_NAME","osa_db"),
    user=os.getenv("OSA_DB_USER","postgres"),
    password=os.getenv("OSA_DB_PASS",""),
)
cur = conn.cursor()

cur.execute("""
    SELECT id, country_iso3, latitude, longitude
    FROM osa.pgeo_site
    WHERE latitude IS NOT NULL AND longitude IS NOT NULL
""")
sites = cur.fetchall()
print(f"Sites avec coords: {len(sites)}")

BUFFER_KM = 50
inserted = 0
matched = 0

for site_id, iso3, site_lat, site_lon in sites:
    df_site = df_osa[df_osa['iso3'] == iso3]
    if df_site.empty:
        continue
    for _, ev in df_site.iterrows():
        ev_lat = ev.get('CENTROID_LATITUDE')
        ev_lon = ev.get('CENTROID_LONGITUDE')
        if pd.isna(ev_lat) or pd.isna(ev_lon):
            continue
        dist = haversine(site_lat, site_lon, float(ev_lat), float(ev_lon))
        if dist <= BUFFER_KM:
            matched += 1
            raw_payload = json.dumps({
                'sub_type': str(ev.get('SUB_EVENT_TYPE','')),
                'disorder': str(ev.get('DISORDER_TYPE','')),
                'events': int(ev.get('EVENTS',1)) if pd.notna(ev.get('EVENTS')) else 1,
                'distance_km': round(dist, 1)
            })
            event_date = pd.to_datetime(ev['WEEK']).date()
            event_type = str(ev.get('EVENT_TYPE',''))[:100]
            fatalities = int(ev['FATALITIES']) if pd.notna(ev['FATALITIES']) else 0
            try:
                cur.execute("""
                    INSERT INTO osa.pmin_security_event
                        (site_id, source, event_date, event_type,
                         fatalities, raw_payload)
                    VALUES (%s, %s, %s, %s, %s, %s)
                    ON CONFLICT DO NOTHING
                """, (site_id, 'ACLED', event_date, event_type,
                      fatalities, raw_payload))
                inserted += 1
            except Exception as e:
                conn.rollback()
                print(f"Erreur: {e}")

conn.commit()
print(f"Evenements dans buffer 50km: {matched}")
print(f"Inseres dans pmin_security_event: {inserted}")

cur.execute("SELECT COUNT(*), SUM(fatalities) FROM osa.pmin_security_event WHERE source='ACLED'")
row = cur.fetchone()
print(f"Total pmin_security_event: {row[0]} evenements, {row[1]} fatalites")
cur.close()
conn.close()