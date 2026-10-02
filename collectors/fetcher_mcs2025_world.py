"""
OSA Observatory — collectors/fetcher_mcs2025_world.py
Extraction ciblee depuis MCS2025_World_Data.csv (USGS Mineral Commodity
Summaries 2025) pour combler 2023-2024 sur les 7 indicateurs mineraux
deja crees par fetcher_usgs_xls.py (MIN_BAU, MIN_CHR, MIN_COB, MIN_COP,
MIN_GOL, MIN_IRO, MIN_MAN).

============================================================
CONTEXTE ET LIMITES -- A LIRE AVANT USAGE
============================================================
Ce fichier n'est PAS un Minerals Yearbook (format completement
different : une ligne par pays x minerai x type de production, pas un
tableau pays x colonnes-minerai). Couverture tres partielle : ce
fichier mondial ne liste que les tout premiers producteurs mondiaux
par minerai, pas l'ensemble des pays africains -- seulement 11 pays
OSA apparaissent au total (sur 54), avec seulement 1 a 4 pays par
minerai. Ne PAS attendre une vraie extension de couverture comparable
a la serie historique 2010-2021 (6 a 38 pays selon le minerai) : ce
script ajoute des points ponctuels pour les tout premiers producteurs
seulement, pas un comblement complet du trou 2022-2024.

Deux pieges corriges en construisant ce script (2026-10-02) :
  1. Le fer (Iron Ore) apparait DEUX FOIS par pays dans le fichier
     source, sous deux TYPE distincts : "Mine production, iron
     content" (metal contenu) et "Mine production, usable ore" (poids
     brut). Notre serie MIN_IRO (fetcher_usgs_xls.py, mots-cles ["iron
     ore","usable ore"]) suit le poids brut -- seul TYPE_IRON_ORE
     ci-dessous est retenu, jamais "iron content", pour ne pas
     mélanger deux bases differentes (meme piege que bauxite brute vs
     aluminium raffine deja rencontre).
  2. L'or est exprime en TONNES METRIQUES dans ce fichier, alors que
     MIN_GOL est en KILOGRAMMES dans toute la serie historique (verifie
     par comparaison directe : Burkina Faso 45 000 kg en 2019 vs
     57-60 tonnes/57 000-60 000 kg en 2023-2024, Ghana 141 982 kg en
     2019 vs 126-130 tonnes/126 000-130 000 kg -- ordres de grandeur
     coherents apres x1000). GOLD_MULTIPLIER=1000.0 ci-dessous.

PROD_2023 et PROD_EST_2024 sont tous deux retenus (deux annees de
donnees par ligne source), le second etant une estimation ("EST"),
marquee avec confidence_score plus bas que le premier.
============================================================

Usage :
  python collectors/fetcher_mcs2025_world.py --file data/raw/pmin/MCS2025_World_Data.csv --dry-run
  python collectors/fetcher_mcs2025_world.py --file data/raw/pmin/MCS2025_World_Data.csv
"""
from __future__ import annotations
import argparse, logging, os, sys
from pathlib import Path
import pandas as pd
import psycopg2
from psycopg2.extras import execute_batch
from dotenv import load_dotenv

sys.path.insert(0, str(Path(__file__).resolve().parent))
from country_resolver import CountryResolver  # noqa: E402

load_dotenv()

logging.basicConfig(level=os.getenv("OSA_LOG_LEVEL", "INFO"),
                     format="%(asctime)s | %(levelname)-8s | %(message)s")
log = logging.getLogger("fetcher_mcs2025_world")

LAYER_RAW = 1
GOLD_MULTIPLIER = 1000.0  # tonnes metriques -> kilogrammes, voir note ci-dessus

# Minerai (valeur de la colonne COMMODITY, espaces inclus tels quels
# dans le fichier source) -> (osa_code, multiplicateur, TYPE exact a
# retenir ; None = n'importe quel TYPE contenant "mine production")
MINERAL_MAP = {
    "Bauxite":    ("MIN_BAU", 1.0, None),
    "Chromium":   ("MIN_CHR", 1.0, None),
    "Cobalt":     ("MIN_COB", 1.0, None),
    "Copper ":    ("MIN_COP", 1.0, None),
    "Gold ":      ("MIN_GOL", GOLD_MULTIPLIER, None),
    "Iron Ore  ": ("MIN_IRO", 1.0, "usable ore"),  # jamais "iron content" -- voir note
    "Manganese":  ("MIN_MAN", 1.0, None),
}


def get_pg_conn():
    return psycopg2.connect(
        host=os.getenv("OSA_DB_HOST", "localhost"),
        port=int(os.getenv("OSA_DB_PORT", 5432)),
        dbname=os.getenv("OSA_DB_NAME", "osa_db"),
        user=os.getenv("OSA_DB_USER", "postgres"),
        password=os.getenv("OSA_DB_PASS", ""),
    )


def parse_file(filepath: str, resolver: CountryResolver) -> list[dict]:
    df = pd.read_csv(filepath)
    records = []

    for commodity, (osa_code, mult, type_filter) in MINERAL_MAP.items():
        sub = df[df["COMMODITY"] == commodity].copy()
        sub = sub[sub["TYPE"].str.contains("mine production", case=False, na=False)]
        if type_filter:
            sub = sub[sub["TYPE"].str.contains(type_filter, case=False, na=False)]

        for _, row in sub.iterrows():
            iso3, _mode = resolver.resolve(str(row["COUNTRY"]).strip())
            if not iso3:
                log.debug("  [%s] pays non resolu : %s", osa_code, row["COUNTRY"])
                continue

            for year_col, year, confidence in [
                ("PROD_2023", 2023, 0.90),
                ("PROD_EST_ 2024", 2024, 0.70),  # estimation, confiance plus basse
            ]:
                val = row.get(year_col)
                if pd.isna(val):
                    continue
                records.append({
                    "indicator_code": osa_code,
                    "country_iso3": iso3,
                    "year": year,
                    "raw_value": float(val) * mult,
                    "confidence_score": confidence,
                })

    log.info("Enregistrements extraits : %d (%d pays, %d indicateurs)",
              len(records),
              len({r["country_iso3"] for r in records}),
              len({r["indicator_code"] for r in records}))
    return records


def insert_to_db(conn, records: list[dict], dry_run: bool = False) -> int:
    if not records:
        return 0

    if dry_run:
        df = pd.DataFrame(records)
        for (ind, year), grp in df.groupby(["indicator_code", "year"]):
            log.info("  [DRY-RUN] %s %d : %d pays", ind, year, grp.country_iso3.nunique())
        return len(records)

    with conn.cursor() as cur:
        cur.execute("SELECT id FROM mm.source_origins WHERE code = %s", ("USGS",))
        row = cur.fetchone()
        if not row:
            raise RuntimeError("mm.source_origins : code USGS introuvable")
        usgs_source_id = row[0]

    sql = """
        INSERT INTO ma.indicator_values
            (indicator_code, country_iso3, year, layer_id,
             raw_value, quality_flag, confidence_score, value_status, source_id)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT (indicator_code, country_iso3, year, layer_id, method_version_id)
        DO UPDATE SET
            raw_value        = EXCLUDED.raw_value,
            quality_flag     = EXCLUDED.quality_flag,
            confidence_score = EXCLUDED.confidence_score,
            value_status     = EXCLUDED.value_status,
            source_id        = EXCLUDED.source_id
    """
    batch = [(r["indicator_code"], r["country_iso3"], r["year"], LAYER_RAW,
              r["raw_value"], "OK", r["confidence_score"], "OBSERVED", usgs_source_id)
             for r in records]

    with conn.cursor() as cur:
        execute_batch(cur, sql, batch)
    conn.commit()
    log.info("-> %d inseres (source USGS)", len(batch))
    return len(batch)


def main():
    parser = argparse.ArgumentParser(description="OSA Fetcher MCS2025 World (extraction ciblee 2023-2024)")
    parser.add_argument("--file", required=True, help="Chemin vers MCS2025_World_Data.csv")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    if not os.path.exists(args.file):
        log.error("Fichier introuvable : %s", args.file)
        sys.exit(1)

    log.info("=" * 60)
    log.info("OSA Fetcher MCS2025 World -- extraction 2023-2024")
    log.info("Dry-run : %s", args.dry_run)
    log.info("=" * 60)

    conn = get_pg_conn()
    try:
        resolver = CountryResolver.from_db(conn)
        records = parse_file(args.file, resolver)
        if not records:
            log.warning("Aucune donnee extraite.")
            return
        n = insert_to_db(conn, records, dry_run=args.dry_run)
    finally:
        conn.close()

    print("\n" + "=" * 60)
    print("RAPPORT MCS2025 WORLD")
    print(f"Prepares : {len(records)}")
    print(f"Inseres  : {n}")
    df = pd.DataFrame(records)
    for (ind, year), grp in df.groupby(["indicator_code", "year"]):
        print(f"  {ind:10s} {year} : {grp.country_iso3.nunique()} pays -- {sorted(grp.country_iso3.unique())}")
    print("=" * 60)


if __name__ == "__main__":
    main()
