import requests
import pandas as pd

url = "https://comtradeapi.un.org/data/v1/get"

params = {
    "type": "C",
    "freq": "A",
    "px": "HS",
    "ps": "2010,2011,2012,2013,2014,2015,2016,2017,2018,2019,2020,2021,2022,2023",
    "r": "all",
    "p": "all",
    "cc": "TOTAL"
}

r = requests.get(url, params=params)
data = r.json()["data"]

df = pd.DataFrame(data)

df.to_csv("../raw/comtrade_raw.csv", index=False)

print("COMTRADE téléchargé")