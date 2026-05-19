"""
OSA Observatory — fix_wb_fetcher_v3.py
Correction fetcher_wb_pres_pmil_pnum.py — patterns multi-lignes
"""
from pathlib import Path

FETCHER = Path("collectors/fetcher_wb_pres_pmil_pnum.py")
content = FETCHER.read_text(encoding="utf-8")

# Fix 1 : tuple batch_data multi-lignes
OLD_BATCH = """        batch_data.append((
              osa_code, iso3, year, LAYER_RAW,
              scaled, quality_flag, conf, value_status
          ))"""

NEW_BATCH = """        WB_SOURCE_ID = 11  # collect.source_registry WB (id=11)
        batch_data.append((
              osa_code, iso3, year, LAYER_RAW,
              scaled, quality_flag, conf, value_status,
              WB_SOURCE_ID
          ))"""

# Fix 2 : INSERT colonnes
OLD_INSERT_COLS = """        INSERT INTO ma.indicator_values
              (indicator_code, country_iso3, year, layer_id,
               raw_value, quality_flag, confidence_score, value_status)
          VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
          ON CONFLICT DO NOTHING"""

NEW_INSERT_COLS = """        INSERT INTO ma.indicator_values
              (indicator_code, country_iso3, year, layer_id,
               raw_value, quality_flag, confidence_score, value_status,
               source_id)
          VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
          ON CONFLICT (indicator_code, country_iso3, year, layer_id, method_version_id)
          DO UPDATE SET
              raw_value        = EXCLUDED.raw_value,
              quality_flag     = EXCLUDED.quality_flag,
              confidence_score = EXCLUDED.confidence_score,
              value_status     = EXCLUDED.value_status,
              source_id        = EXCLUDED.source_id"""

ok1 = OLD_BATCH in content
ok2 = OLD_INSERT_COLS in content

if ok1:
    content = content.replace(OLD_BATCH, NEW_BATCH, 1)
    print("OK Fix 1 -- batch_data.append corrige (+WB_SOURCE_ID)")
else:
    print("WARN Fix 1 -- pattern batch_data non trouve")

if ok2:
    content = content.replace(OLD_INSERT_COLS, NEW_INSERT_COLS, 1)
    print("OK Fix 2 -- INSERT colonnes + ON CONFLICT corrige")
else:
    print("WARN Fix 2 -- pattern INSERT non trouve")

if ok1 or ok2:
    FETCHER.write_text(content, encoding="utf-8")
    print(f"OK -- {FETCHER} sauvegarde")

# Vérification
content2 = FETCHER.read_text(encoding="utf-8")
print()
print("Verification :")
print(f"  WB_SOURCE_ID present   : {'WB_SOURCE_ID' in content2}")
print(f"  source_id dans INSERT  : {'source_id' in content2}")
print(f"  DO UPDATE SET present  : {'DO UPDATE SET' in content2}")
print(f"  ON CONFLICT DO NOTHING : {'ON CONFLICT DO NOTHING' in content2}")
