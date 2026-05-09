import os
from datetime import datetime
import pandas as pd
from sqlalchemy import create_engine

DB_URI = os.getenv("OSA_DB_URI", "postgresql+psycopg2://postgres:osa2026@localhost:5432/osa_db")
OUTPUT_DIR = "G:/osa-observatory/exports"
os.makedirs(OUTPUT_DIR, exist_ok=True)

file_path = f"{OUTPUT_DIR}/p6_trust_vulnerability_{datetime.now().strftime('%Y%m%d_%H%M')}.xlsx"
engine = create_engine(DB_URI)

queries = {
    "AI_ML_VECTOR": "SELECT * FROM ma.v_ai_ml_sovereignty_vector ORDER BY country_iso3, year, pillar_code",
    "TRUST_SIGNALS": "SELECT * FROM ma.v_signal_trust_engine ORDER BY country_iso3, year, pillar_code, indicator_code",
    "STRUCTURAL_GAPS": "SELECT * FROM ma.v_structural_gap_engine ORDER BY structural_gap_score DESC",
    "PILLAR_SUMMARY": '''
        SELECT pillar_code, COUNT(*) nb_signals,
               ROUND(AVG(signal_trust_score),3) avg_trust,
               ROUND(AVG(signal_vulnerability_score),3) avg_vulnerability,
               ROUND(AVG(mapping_maturity_score),3) avg_maturity
        FROM ma.v_signal_trust_engine
        GROUP BY pillar_code
        ORDER BY avg_trust
    ''',
    "WEAK_SIGNALS": '''
        SELECT * FROM ma.v_signal_trust_engine
        WHERE signal_status IN ('STRUCTURAL_GAP','NATURE_GAP','LOW_TRUST_SIGNAL')
        ORDER BY signal_vulnerability_score DESC
    '''
}

print("Export P6 Trust & Vulnerability Engine...")

with pd.ExcelWriter(file_path, engine="xlsxwriter") as writer:
    workbook = writer.book
    header_fmt = workbook.add_format({"bold": True})
    for sheet, query in queries.items():
        print(f"  -> {sheet}")
        df = pd.read_sql(query, engine)
        df.to_excel(writer, sheet_name=sheet[:31], index=False)
        ws = writer.sheets[sheet[:31]]
        ws.set_row(0, None, header_fmt)
        ws.set_column(0, max(0, len(df.columns)-1), 16)

print(f"Export terminé : {file_path}")
