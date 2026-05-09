# ============================================================
# OSA — EXPORT MAPPING MATURITY
# ============================================================

import os
from datetime import datetime
import pandas as pd
from sqlalchemy import create_engine

DB_URI = os.getenv("OSA_DB_URI", "postgresql+psycopg2://postgres:osa2026@localhost:5432/osa_db")
OUTPUT_DIR = "G:/osa-observatory/exports"
os.makedirs(OUTPUT_DIR, exist_ok=True)
engine = create_engine(DB_URI)

timestamp = datetime.now().strftime("%Y%m%d_%H%M")
file_path = f"{OUTPUT_DIR}/mapping_maturity_{timestamp}.xlsx"
print("📊 Export mapping maturity...")

df_all = pd.read_sql("""
    SELECT * FROM ma.v_mapping_maturity
    ORDER BY mapping_maturity_score, pillar_code, indicator_code
""", engine)

df_pillars = pd.read_sql("""
    SELECT pillar_code, COUNT(*) AS nb_indicators,
           ROUND(AVG(mapping_maturity_score), 3) AS avg_maturity,
           MIN(mapping_maturity_score) AS min_maturity,
           MAX(mapping_maturity_score) AS max_maturity
    FROM ma.v_mapping_maturity
    GROUP BY pillar_code
    ORDER BY avg_maturity
""", engine)

df_actions = pd.read_sql("""
    SELECT recommended_action, COUNT(*) AS nb_indicators
    FROM ma.v_mapping_maturity
    GROUP BY recommended_action
    ORDER BY nb_indicators DESC
""", engine)

df_physical = pd.read_sql("""
    SELECT * FROM ma.v_mapping_maturity
    WHERE nature_code = 'PHYSICAL'
    ORDER BY mapping_maturity_score, pillar_code, indicator_code
""", engine)

df_critical = pd.read_sql("""
    SELECT * FROM ma.v_mapping_maturity
    WHERE maturity_class IN ('D — FRAGILE', 'E — CRITIQUE')
    ORDER BY mapping_maturity_score, pillar_code, indicator_code
""", engine)

df_summary = pd.DataFrame({
    "Metric": ["Nb indicateurs", "Nb physiques", "Nb critiques maturité", "Score moyen global"],
    "Value": [
        len(df_all),
        len(df_physical),
        len(df_critical),
        round(df_all["mapping_maturity_score"].mean(), 3) if not df_all.empty else 0,
    ],
})

with pd.ExcelWriter(file_path, engine="xlsxwriter") as writer:
    df_summary.to_excel(writer, sheet_name="SUMMARY", index=False)
    df_pillars.to_excel(writer, sheet_name="PILIERS", index=False)
    df_actions.to_excel(writer, sheet_name="ACTIONS", index=False)
    df_physical.to_excel(writer, sheet_name="PHYSICAL_RISK", index=False)
    df_critical.to_excel(writer, sheet_name="CRITICAL", index=False)
    df_all.to_excel(writer, sheet_name="ALL", index=False)

print(f"✅ Export terminé : {file_path}")
