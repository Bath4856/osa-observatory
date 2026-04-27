import pandas as pd
from africa import AFRICA_ISO3

df = pd.read_csv("../raw/acled_raw.csv")

df["year"] = pd.to_datetime(df["event_date"]).dt.year
df = df[df["year"].between(2010, 2025)]

df = df[df["iso3"].isin(AFRICA_ISO3)]

df_grouped = df.groupby(["iso3","year"])["fatalities"].sum().reset_index()

df_grouped["indicator_code"] = "PGEO_FATALITIES"
df_grouped["source_id"] = "ACLED"
df_grouped["unit"] = "count"
df_grouped["confidence"] = 0.85

df_grouped.rename(columns={
    "iso3":"country_iso3",
    "fatalities":"value"
}, inplace=True)

df_grouped.to_csv("../processed/acled_pgeo.csv", index=False)