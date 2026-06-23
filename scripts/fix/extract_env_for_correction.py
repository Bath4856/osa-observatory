"""
Sprint 23 -- Correction ENV_FOR
================================

Diagnostic (cf. db/patch_db/diag_sprint23_env_def_env_for.sql) :
  - ENV_FOR en base (item 6646 / element 5110, "Forest land", 1000 ha)
    est etiquete comme un pourcentage (AG.LND.FRST.ZS, unite declaree
    PERCENT/INDEX, bornes [0,100]) -- bug d'unite. Valeurs >> 100 pour
    495/692 lignes.
  - Le ratio correct existe dans le meme fichier RL.csv :
    item 6646 / element 7209 ("Forest land - Share in Land area", %).
  - Mais ce ratio est une INTERPOLATION LINEAIRE FAO entre points
    d'ancrage FRA quinquennaux (2010, 2015, 2020) -- confirme par test
    de linearite (std des pas ~ 0 sur 2010-2015 et 2015-2020 pour la
    quasi-totalite des 49 pays).

Decision doctrinale (P7E + "pas de donnees interpolees collectees") :
  - L1 (collect.raw_data) ne contient QUE les observations reelles
    2010 / 2015 / 2020 (points d'ancrage FRA), valeur = 6646/7209 (%).
  - Les annees intermediaires (2011-2014, 2016-2019, 2021-2024) sont
    laissees absentes de L1 -- elles seront produites par
    imputer_v3.step1_duckdb (interpolation/forward-fill, FLAG_INTERPOLATED,
    confidence reduite), PAS confondues avec des observations FAO.
  - step2_mice (MICE multivarie) sera skip pour ENV_FOR : taux
    d'imputation 12/15 = 80% > MAX_IMPUTATION_RATE (50%). Comportement
    attendu et coherent avec la doctrine TRAJECTOIRE (PMIN_SMUGGLING_
    SIGNAL_RANK, Sprint 21).

Ce script :
  1. Lit data/raw/fao/RL.csv
  2. Extrait item 6646 / element 7209, annees 2010/2015/2020
  3. Mappe Area (nom FAO) -> ISO3 via FAO_AREA_TO_ISO3
     (reutilise depuis collectors/fetcher_fao_csv.py)
  4. Filtre sur les 49 pays deja couverts par ENV_DEF (Sprint 22/23)
  5. Genere le SQL de correction :
       - DELETE des 692 lignes ENV_FOR existantes (endpoint_id=1)
       - INSERT des ~147 lignes (49 pays x 3 annees), value_raw = %,
         load_date = now()

Usage (depuis G:\\osa-observatory) :
    python scripts/fix/extract_env_for_correction.py
"""

import sys
from pathlib import Path

import pandas as pd

# Reutilise le mapping FAO Area -> ISO3 (source unique de verite)
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "collectors"))
from fetcher_fao_csv import FAO_AREA_TO_ISO3  # noqa: E402

RL_CSV_PATH = Path("data/raw/fao/RL.csv")
OUTPUT_SQL  = Path("db/patch_db/patch_sprint23_env_for_correction.sql")

ITEM_CODE_FOREST   = "6646"   # Forest land
ELEMENT_CODE_SHARE = "7209"   # Share in Land area (%)

ANCHOR_YEARS = [2010, 2015, 2020]

# Exceptions ANCHOR_YEARS -- SDN/SSD : scission politique 2011, le
# referentiel FAO ne couvre pas 2010 pour le Soudan post-scission (code
# 276) ni pour le Soudan du Sud (code 277, n'existe qu'a partir de 2012).
# "Sudan (former)" (code 206) ne couvre que 2010-2011 et n'a aucun point
# en commun avec 2015/2020. -> ancrage 2012/2015/2020 pour ces 2 pays.
ANCHOR_YEARS_OVERRIDE = {
    "SDN": [2012, 2015, 2020],
    "SSD": [2012, 2015, 2020],
}

# 49 pays actuellement couverts par ENV_DEF (Sprint 23 diagnostic) --
# DJI, ERI, MRT, NER, STP en sont absents (a traiter separement si
# besoin -- hors perimetre de cette correction ENV_FOR).
ENV_DEF_COUNTRIES = {
    "AGO", "BDI", "BEN", "BFA", "BWA", "CAF", "CIV", "CMR", "COD", "COG",
    "COM", "CPV", "DZA", "EGY", "ETH", "GAB", "GHA", "GIN", "GMB", "GNB",
    "GNQ", "KEN", "LBR", "LBY", "LSO", "MAR", "MDG", "MLI", "MOZ", "MUS",
    "MWI", "NAM", "NGA", "RWA", "SDN", "SEN", "SLE", "SOM", "SSD", "SWZ",
    "SYC", "TCD", "TGO", "TUN", "TZA", "UGA", "ZAF", "ZMB", "ZWE",
}


def main() -> None:
    if not RL_CSV_PATH.exists():
        raise FileNotFoundError(
            f"Fichier introuvable : {RL_CSV_PATH.resolve()}\n"
            "Lancer ce script depuis la racine du repo (G:\\osa-observatory)."
        )

    df = pd.read_csv(RL_CSV_PATH, encoding="utf-8-sig")

    sub = df[
        (df["Item Code"].astype(str) == ITEM_CODE_FOREST)
        & (df["Element Code"].astype(str) == ELEMENT_CODE_SHARE)
    ].copy()

    # FAO_AREA_TO_ISO3 est indexe par Area Code (string)
    sub["iso3"] = sub["Area Code"].astype(str).map(FAO_AREA_TO_ISO3)

    rows = []
    seen = set()  # (iso3, year) deja rempli -- evite doublons si plusieurs
                   # Area Code FAO mappent vers le meme ISO3 (ex SDN: 206 et 276)
    missing_countries = set(ENV_DEF_COUNTRIES)
    missing_values = []

    for _, row in sub.iterrows():
        iso3 = row["iso3"]
        if iso3 not in ENV_DEF_COUNTRIES:
            continue

        years_for_country = ANCHOR_YEARS_OVERRIDE.get(iso3, ANCHOR_YEARS)

        for year in years_for_country:
            if (iso3, year) in seen:
                continue
            col = f"Y{year}"
            val = row.get(col)
            if pd.isna(val):
                continue
            rows.append((iso3, year, round(float(val), 6)))
            seen.add((iso3, year))
            missing_countries.discard(iso3)

    # Recenser les (iso3, year) jamais trouves, tous Area Code confondus
    for iso3 in ENV_DEF_COUNTRIES:
        years_for_country = ANCHOR_YEARS_OVERRIDE.get(iso3, ANCHOR_YEARS)
        for year in years_for_country:
            if (iso3, year) not in seen:
                missing_values.append((iso3, year))

    print(f"Lignes extraites (pays x annees ancrage) : {len(rows)}")
    print(f"Attendu (49 pays x 3 annees)             : {len(ENV_DEF_COUNTRIES) * len(ANCHOR_YEARS)}")

    if missing_countries:
        print("\n[ATTENTION] Pays ENV_DEF sans aucune valeur 6646/7209 :")
        for c in sorted(missing_countries):
            print(f"  - {c}")

    if missing_values:
        print("\n[INFO] Valeurs manquantes ponctuelles (pays/annee) :")
        for iso3, year in missing_values:
            print(f"  - {iso3} / {year}")

    # ── Generation du SQL ─────────────────────────────────────
    sql_lines = []
    sql_lines.append("-- ============================================================")
    sql_lines.append("-- Sprint 23 -- Correction ENV_FOR")
    sql_lines.append("-- ")
    sql_lines.append("-- Remplace les 692 lignes ENV_FOR existantes (item 6646/element")
    sql_lines.append("-- 5110, '1000 ha' mal etiquete PERCENT, bug d'unite -- valeurs")
    sql_lines.append("-- jusqu'a 283340 alors que bornes declarees = [0,100]) par les")
    sql_lines.append("-- observations reelles 6646/7209 (% couvert forestier, FAO RL),")
    sql_lines.append("-- limitees aux annees d'ancrage FRA 2010/2015/2020 -- les annees")
    sql_lines.append("-- intermediaires sont volontairement absentes de L1 (cf.")
    sql_lines.append("-- doctrine P7E : pas de donnees interpolees collectees comme")
    sql_lines.append("-- observations -- imputer_v3.step1_duckdb les produira en L2")
    sql_lines.append("-- avec FLAG_INTERPOLATED / confidence reduite).")
    sql_lines.append("-- ============================================================")
    sql_lines.append("")
    sql_lines.append("BEGIN;")
    sql_lines.append("")
    sql_lines.append("-- 1. Suppression des 692 lignes ENV_FOR existantes (bug d'unite)")
    sql_lines.append("DELETE FROM collect.raw_data WHERE indicator_code = 'ENV_FOR';")
    sql_lines.append("")
    sql_lines.append(f"-- 2. Insertion des {len(rows)} observations reelles (item 6646 / element 7209, %)")
    sql_lines.append("--    endpoint_id = 1 (WB_COUNTRY_INDICATOR, partage WB/FAO -- cf. 03_collect_schema.sql)")
    sql_lines.append("INSERT INTO collect.raw_data (endpoint_id, indicator_code, country_iso3, year, value_raw, load_date)")
    sql_lines.append("VALUES")

    value_lines = []
    for iso3, year, val in sorted(rows, key=lambda r: (r[0], r[1])):
        value_lines.append(f"    (1, 'ENV_FOR', '{iso3}', {year}, {val}, now())")

    sql_lines.append(",\n".join(value_lines) + ";")
    sql_lines.append("")
    sql_lines.append("-- 3. Verification post-insertion : bornes [0,100] respectees")
    sql_lines.append("--    et 0 valeur hors plage")
    sql_lines.append("DO $$")
    sql_lines.append("DECLARE")
    sql_lines.append("    n_out_of_range INT;")
    sql_lines.append("    n_total        INT;")
    sql_lines.append("BEGIN")
    sql_lines.append("    SELECT COUNT(*) INTO n_total")
    sql_lines.append("    FROM collect.raw_data WHERE indicator_code = 'ENV_FOR';")
    sql_lines.append("")
    sql_lines.append("    SELECT COUNT(*) INTO n_out_of_range")
    sql_lines.append("    FROM collect.raw_data")
    sql_lines.append("    WHERE indicator_code = 'ENV_FOR'")
    sql_lines.append("      AND (value_raw < 0 OR value_raw > 100);")
    sql_lines.append("")
    sql_lines.append("    RAISE NOTICE 'ENV_FOR -- total lignes : %, hors plage [0,100] : %', n_total, n_out_of_range;")
    sql_lines.append("")
    sql_lines.append("    IF n_out_of_range > 0 THEN")
    sql_lines.append("        RAISE EXCEPTION 'Correction ENV_FOR invalide : % valeur(s) hors plage [0,100]', n_out_of_range;")
    sql_lines.append("    END IF;")
    sql_lines.append("END $$;")
    sql_lines.append("")
    sql_lines.append("COMMIT;")
    sql_lines.append("")
    sql_lines.append("-- ============================================================")
    sql_lines.append("-- ETAPES SUIVANTES (hors de ce script) :")
    sql_lines.append("--   1. Relancer imputer_v3 pour ENV_FOR (step1_duckdb produira")
    sql_lines.append("--      2011-2014, 2016-2019 par interpolation lineaire et")
    sql_lines.append("--      2021-2024 par forward-fill depuis 2020, FLAG_INTERPOLATED).")
    sql_lines.append("--      step2_mice (MICE) sera skip : 80% > MAX_IMPUTATION_RATE 50%.")
    sql_lines.append("--   2. Recalculer L3 (normalisation) pour ENV_FOR 2010-2024.")
    sql_lines.append("--   3. Recalculer SOV_PENV (compute_pillar_score / compute_isa)")
    sql_lines.append("--      pour 2010-2024 -- impact attendu sur les scores OFFICIAL")
    sql_lines.append("--      2011-2014, 2016-2019, 2021-2023 (poids ENV_FOR desormais")
    sql_lines.append("--      base sur valeurs imputees DuckDB, confidence reduite,")
    sql_lines.append("--      au lieu de l'interpolation FAO brute mal etiquetee.)")
    sql_lines.append("-- ============================================================")

    OUTPUT_SQL.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_SQL.write_text("\n".join(sql_lines), encoding="utf-8")

    print(f"\nSQL genere : {OUTPUT_SQL.resolve()}")
    print(f"  - DELETE : 692 lignes ENV_FOR existantes")
    print(f"  - INSERT : {len(rows)} lignes (observations 2010/2015/2020, item 6646/element 7209, %)")


if __name__ == "__main__":
    main()
