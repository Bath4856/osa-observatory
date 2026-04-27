import requests
import pandas as pd

API_KEY = "Bada48561192"
EMAIL = "contact@kon-won.com"

url = "https://api.acleddata.com/acled/read"

params = {
    "key": API_KEY,
    "email": EMAIL,
    "region": "Africa",
    "year": "2010,2011,2012,2013,2014,2015,2016,2017,2018,2019,2020,2021,2022,2023"
}

r = requests.get(url, params=params)
data = r.json()["data"]

df = pd.DataFrame(data)

df.to_csv("../raw/acled_raw.csv", index=False)

print("ACLED téléchargé")