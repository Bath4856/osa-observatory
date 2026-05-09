import pandas as pd
import psycopg2
from datetime import datetime

# 🔐 Connexion DB (à adapter si besoin)
conn = psycopg2.connect(
    dbname="osa_db",
    user="postgres",
    password="osa2026",
    host="localhost",
    port="5432"
)

# 📁 Nom fichier avec timestamp
timestamp = datetime.now().strftime("%Y%m%d_%H%M")
file_path = f"G:/osa-observatory/exports/mapping_analysis_{timestamp}.xlsx"

print("📊 Export mapping analysis en cours...")

with pd.ExcelWriter(file_path, engine="xlsxwriter") as writer:

    # 🔴 CRITIQUE
    df_critique = pd.read_sql("""
        SELECT *
        FROM ma.v_mapping_quality_score
        WHERE quality_class = 'D — CRITIQUE'
        ORDER BY mapping_quality_score
    """, conn)
    df_critique.to_excel(writer, sheet_name="CRITIQUE", index=False)

    # 🔴 ORPHELINS
    df_orphelins = pd.read_sql("""
        SELECT *
        FROM ma.v_mapping_quality_score
        WHERE orphan_flag = 'ORPHELIN'
    """, conn)
    df_orphelins.to_excel(writer, sheet_name="ORPHELINS", index=False)

    # 🟡 EXCLUS ISA
    df_exclus = pd.read_sql("""
        SELECT *
        FROM ma.v_mapping_quality_score
        WHERE isa_status = 'EXCLU ISA'
    """, conn)
    df_exclus.to_excel(writer, sheet_name="EXCLUS_ISA", index=False)

    # 🟣 SCORES PILIERS
    df_piliers = pd.read_sql("""
        SELECT
            pillar_code,
            ROUND(AVG(mapping_quality_score), 3) AS avg_score
        FROM ma.v_mapping_quality_score
        GROUP BY pillar_code
        ORDER BY avg_score
    """, conn)
    df_piliers.to_excel(writer, sheet_name="SCORES_PAR_PILIER", index=False)

print(f"✅ Export terminé : {file_path}")