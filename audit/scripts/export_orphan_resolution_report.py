# ============================================================
# OSA / ISA — EXPORT ORPHAN RESOLUTION REPORT
# ============================================================

import os
from datetime import datetime

import pandas as pd
from sqlalchemy import create_engine

DB_URI = "postgresql+psycopg2://postgres:osa2026@localhost:5432/osa_db"
OUTPUT_DIR = "G:/osa-observatory/exports"

os.makedirs(OUTPUT_DIR, exist_ok=True)
engine = create_engine(DB_URI)
timestamp = datetime.now().strftime("%Y%m%d_%H%M")
file_path = f"{OUTPUT_DIR}/orphan_resolution_{timestamp}.xlsx"

queries = {
    "ORPHELINS_RESTANTS": """
        SELECT *
        FROM ma.v_orphan_resolution_status
        WHERE orphan_flag = 'ORPHELIN'
        ORDER BY pillar_code, indicator_code
    """,
    "RESOLUTION_PAR_PILIER": """
        SELECT pillar_code, resolution_status, COUNT(*) AS nb
        FROM ma.v_orphan_resolution_status
        GROUP BY pillar_code, resolution_status
        ORDER BY pillar_code, resolution_status
    """,
    "FAIBLES_HORS_ORPHELINS": """
        SELECT *
        FROM ma.v_orphan_resolution_status
        WHERE orphan_flag IS NULL AND mapping_quality_score < 0.50
        ORDER BY mapping_quality_score, pillar_code, indicator_code
    """,
}

print("📊 Export orphan resolution report...")
with pd.ExcelWriter(file_path, engine="xlsxwriter") as writer:
    summary_rows = []
    for sheet, query in queries.items():
        df = pd.read_sql(query, engine)
        df.to_excel(writer, sheet_name=sheet[:31], index=False)
        summary_rows.append({"sheet": sheet, "rows": len(df)})
    pd.DataFrame(summary_rows).to_excel(writer, sheet_name="SUMMARY", index=False)

print(f"✅ Export terminé : {file_path}")
