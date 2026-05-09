# ============================================================
# OSA — EXPORT MAPPING ANALYSIS (VERSION SQLALCHEMY)
# ============================================================

import os
import sys
from datetime import datetime

import pandas as pd
from sqlalchemy import create_engine


# ============================================================
# CONFIGURATION
# ============================================================

DB_URI = "postgresql+psycopg2://postgres:osa2026@localhost:5432/osa_db"
OUTPUT_DIR = "G:/osa-observatory/exports"


# ============================================================
# INIT
# ============================================================

def init():
    print("=========================================")
    print(" OSA — EXPORT MAPPING ANALYSIS (PRO)")
    print("=========================================")

    try:
        os.makedirs(OUTPUT_DIR, exist_ok=True)
    except Exception as e:
        print("❌ Erreur création dossier :", e)
        sys.exit(1)


def get_engine():
    try:
        engine = create_engine(DB_URI)
        print("✅ Connexion DB OK (SQLAlchemy)")
        return engine
    except Exception as e:
        print("❌ Erreur connexion DB :", e)
        sys.exit(1)


def get_file_path():
    timestamp = datetime.now().strftime("%Y%m%d_%H%M")
    return f"{OUTPUT_DIR}/mapping_analysis_{timestamp}.xlsx"


# ============================================================
# REQUÊTES
# ============================================================

QUERY_CRITIQUE = """
SELECT *
FROM ma.v_mapping_quality_score
WHERE quality_class = 'D — CRITIQUE'
ORDER BY mapping_quality_score
"""

QUERY_ORPHELINS = """
SELECT *
FROM ma.v_mapping_quality_score
WHERE orphan_flag = 'ORPHELIN'
"""

QUERY_EXCLUS = """
SELECT *
FROM ma.v_mapping_quality_score
WHERE isa_status = 'EXCLU ISA'
"""

QUERY_PILIERS = """
SELECT
    pillar_code,
    ROUND(AVG(mapping_quality_score), 3) AS avg_score
FROM ma.v_mapping_quality_score
GROUP BY pillar_code
ORDER BY avg_score
"""


# ============================================================
# EXECUTION
# ============================================================

def fetch_df(engine, query, label):
    try:
        print(f"📊 Chargement : {label}")
        return pd.read_sql(query, engine)
    except Exception as e:
        print(f"❌ Erreur {label} :", e)
        return pd.DataFrame()


def export_excel(engine, file_path):

    df_critique = fetch_df(engine, QUERY_CRITIQUE, "CRITIQUE")
    df_orphelins = fetch_df(engine, QUERY_ORPHELINS, "ORPHELINS")
    df_exclus = fetch_df(engine, QUERY_EXCLUS, "EXCLUS ISA")
    df_piliers = fetch_df(engine, QUERY_PILIERS, "SCORES PILIERS")

    try:
        print("📁 Écriture Excel...")

        with pd.ExcelWriter(file_path, engine="xlsxwriter") as writer:
            df_critique.to_excel(writer, sheet_name="CRITIQUE", index=False)
            df_orphelins.to_excel(writer, sheet_name="ORPHELINS", index=False)
            df_exclus.to_excel(writer, sheet_name="EXCLUS_ISA", index=False)
            df_piliers.to_excel(writer, sheet_name="SCORES_PILIERS", index=False)

        print(f"✅ Export terminé : {file_path}")

    except Exception as e:
        print("❌ Erreur export :", e)
        sys.exit(1)


# ============================================================
# MAIN
# ============================================================

def main():
    init()
    engine = get_engine()
    file_path = get_file_path()
    export_excel(engine, file_path)


if __name__ == "__main__":
    main()