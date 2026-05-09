# ============================================================
# OSA — EXPORT MAPPING ANALYSIS (SIMPLE & PROPRE)
# ============================================================

import os
from datetime import datetime

import pandas as pd
from sqlalchemy import create_engine


# ============================================================
# CONFIGURATION
# ============================================================

DB_URI = "postgresql+psycopg2://postgres:osa2026@localhost:5432/osa_db"
OUTPUT_DIR = "G:/osa-observatory/exports"


# ============================================================
# INITIALISATION
# ============================================================

os.makedirs(OUTPUT_DIR, exist_ok=True)

engine = create_engine(DB_URI)

timestamp = datetime.now().strftime("%Y%m%d_%H%M")
file_path = f"{OUTPUT_DIR}/mapping_analysis_{timestamp}.xlsx"

print("📊 Export mapping analysis...")


# ============================================================
# REQUÊTES
# ============================================================

df_critique = pd.read_sql("""
    SELECT *
    FROM ma.v_mapping_quality_score
    WHERE quality_class = 'D — CRITIQUE'
    ORDER BY mapping_quality_score
""", engine)

df_orphelins = pd.read_sql("""
    SELECT *
    FROM ma.v_mapping_quality_score
    WHERE orphan_flag = 'ORPHELIN'
""", engine)

df_exclus = pd.read_sql("""
    SELECT *
    FROM ma.v_mapping_quality_score
    WHERE isa_status = 'EXCLU ISA'
""", engine)

df_piliers = pd.read_sql("""
    SELECT
        pillar_code,
        ROUND(AVG(mapping_quality_score), 3) AS avg_score
    FROM ma.v_mapping_quality_score
    GROUP BY pillar_code
    ORDER BY avg_score
""", engine)


# ============================================================
# RÉSUMÉ SIMPLE
# ============================================================

df_summary = pd.DataFrame({
    "Indicateur": [
        "Nb CRITIQUES",
        "Nb ORPHELINS",
        "Nb EXCLUS ISA",
        "Score moyen global"
    ],
    "Valeur": [
        len(df_critique),
        len(df_orphelins),
        len(df_exclus),
        round(df_piliers["avg_score"].mean(), 3)
    ]
})


# ============================================================
# EXPORT EXCEL
# ============================================================

with pd.ExcelWriter(file_path, engine="xlsxwriter") as writer:

    df_summary.to_excel(writer, sheet_name="SUMMARY", index=False)
    df_critique.to_excel(writer, sheet_name="CRITIQUE", index=False)
    df_orphelins.to_excel(writer, sheet_name="ORPHELINS", index=False)
    df_exclus.to_excel(writer, sheet_name="EXCLUS_ISA", index=False)
    df_piliers.to_excel(writer, sheet_name="PILIERS", index=False)

print(f"✅ Export terminé : {file_path}")