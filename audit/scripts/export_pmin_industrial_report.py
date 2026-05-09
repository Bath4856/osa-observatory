import os
from datetime import datetime
import pandas as pd
from sqlalchemy import create_engine

DB_URI = 'postgresql+psycopg2://postgres:osa2026@localhost:5432/osa_db'
OUTPUT_DIR = 'G:/osa-observatory/exports'
os.makedirs(OUTPUT_DIR, exist_ok=True)
engine = create_engine(DB_URI)
file_path = f"{OUTPUT_DIR}/pmin_industrial_report_{datetime.now():%Y%m%d_%H%M}.xlsx"

queries = {
    'SUMMARY_NATURE': '''
        SELECT nature_code, COUNT(*) AS nb,
               ROUND(AVG(mapping_quality_score), 3) AS avg_mapping_quality,
               ROUND(AVG(mapping_maturity_score), 3) AS avg_maturity
        FROM ma.v_pmin_industrial_quality
        GROUP BY nature_code
        ORDER BY avg_maturity DESC
    ''',
    'ORPHELINS_PMIN': '''
        SELECT * FROM ma.v_pmin_industrial_quality
        WHERE orphan_flag = 'ORPHELIN'
        ORDER BY mapping_quality_score
    ''',
    'RISQUES_PMIN': '''
        SELECT * FROM ma.v_pmin_industrial_quality
        WHERE pmin_quality_flag IN ('PHYSICAL_RISK', 'ORPHAN', 'NATURE_MISSING')
        ORDER BY pmin_quality_flag, mapping_quality_score
    ''',
    'PMIN_OK': '''
        SELECT * FROM ma.v_pmin_industrial_quality
        WHERE pmin_quality_flag = 'OK'
        ORDER BY mapping_maturity_score DESC
    ''',
    'FULL': '''
        SELECT * FROM ma.v_pmin_industrial_quality
        ORDER BY mapping_maturity_score DESC
    ''',
}

print('📊 Export PMIN industrial report...')
with pd.ExcelWriter(file_path, engine='xlsxwriter') as writer:
    for sheet, query in queries.items():
        pd.read_sql(query, engine).to_excel(writer, sheet_name=sheet[:31], index=False)
print(f'✅ Export terminé : {file_path}')
