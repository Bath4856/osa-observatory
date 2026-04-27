import pandas as pd

# === LOAD FILES ===
df_org = pd.read_csv("../raw/organizedviolencecy_v25_1.csv")
df_bd  = pd.read_csv("../raw/BattleDeaths_v25_1_conf.csv")
df_prio = pd.read_csv("../raw/UcdpPrioConflict_v25_1.csv")
df_ns = pd.read_csv("../raw/NonState_v25_1.csv")

# === FILTER PERIOD ===
for df in [df_org, df_bd, df_prio, df_ns]:
    df = df[df["year"].between(2010, 2025)]

# === STANDARDIZE ISO3 ===
# selon structure UCDP (adapter si besoin)
def get_iso(df):
    if "iso3" in df.columns:
        return df
    if "gwno" in df.columns:
        return df  # mapping à prévoir si besoin
    return df

df_org = get_iso(df_org)
df_bd = get_iso(df_bd)
df_prio = get_iso(df_prio)
df_ns = get_iso(df_ns)

# === 1. FATALITIES ===
fatalities = df_org.groupby(["iso3","year"])["best"].sum().reset_index()
fatalities["indicator_code"] = "PGEO_FATALITIES"

# === 2. EVENTS ===
events = df_prio.groupby(["iso3","year"]).size().reset_index(name="value")
events["indicator_code"] = "PGEO_EVENTS"

# === 3. INTERNAL CONFLICT ===
internal = df_ns.groupby(["iso3","year"]).size().reset_index(name="value")
internal["indicator_code"] = "PGEO_INTERNAL"

# === MERGE BASE ===
df = fatalities.merge(events, on=["iso3","year"], how="left", suffixes=("_fatal","_event"))

# === 4. INTENSITY ===
df["PGEO_INTENSITY"] = df["best"] / df["value_event"].replace(0,1)

# === 5. TREND ===
df = df.sort_values(["iso3","year"])
df["PGEO_TREND"] = df.groupby("iso3")["best"].pct_change()

# === 6. PEAK ===
df["PGEO_PEAK"] = df.groupby("iso3")["best"].transform("max")

# === 7. SPREAD ===
spread = df_prio.groupby(["iso3","year"])["location"].nunique().reset_index()
spread.rename(columns={"location":"PGEO_SPREAD"}, inplace=True)

df = df.merge(spread, on=["iso3","year"], how="left")

# === 8. STRUCTURE ===
df["PGEO_STRUCTURE"] = df["value_event"] / (df["value_event"] + 1)

# === 9. PRESSURE SCORE ===
df["PGEO_PRESSURE"] = (
    df["best"].fillna(0) * 0.5 +
    df["value_event"].fillna(0) * 0.3 +
    df["PGEO_INTENSITY"].fillna(0) * 0.2
)

# === FORMAT FINAL ===
def melt_indicator(df, col):
    return df[["iso3","year",col]].rename(columns={
        "iso3":"country_iso3",
        col:"value"
    }).assign(
        indicator_code=col,
        source_id="UCDP",
        confidence=0.9
    )

indicators = [
    "PGEO_INTENSITY",
    "PGEO_TREND",
    "PGEO_PEAK",
    "PGEO_SPREAD",
    "PGEO_STRUCTURE",
    "PGEO_PRESSURE"
]

df_list = [fatalities.rename(columns={"iso3":"country_iso3","best":"value"})]
df_list[0]["indicator_code"] = "PGEO_FATALITIES"

df_list.append(events.rename(columns={"iso3":"country_iso3"}))
df_list[-1]["indicator_code"] = "PGEO_EVENTS"

df_list.append(internal.rename(columns={"iso3":"country_iso3"}))
df_list[-1]["indicator_code"] = "PGEO_INTERNAL"

for col in indicators:
    df_list.append(melt_indicator(df, col))

df_final = pd.concat(df_list)

# === SAVE ===
df_final.to_csv("../processed/pgeo_full_ucdp.csv", index=False)

print("PGEO COMPLET généré")