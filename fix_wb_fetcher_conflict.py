"""
OSA Observatory — fix_wb_fetcher_conflict.py
Sprint 8 — Mai 2026

Correction complète du fetcher_wb_pres_pmil_pnum.py :
1. Ajouter source_id=11 (WB) dans l'INSERT
2. Corriger ON CONFLICT DO NOTHING → DO UPDATE SET
3. Générer patch SQL nettoyage 106 884 doublons L1

Usage :
  python fix_wb_fetcher_conflict.py
"""
from pathlib import Path

FETCHER = Path("collectors/fetcher_wb_pres_pmil_pnum.py")

OLD_INSERT = '''      sql = """
          INSERT INTO ma.indicator_values
              (indicator_code, country_iso3, year, layer_id,
               raw_value, quality_flag, confidence_score, value_status)
          VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
          ON CONFLICT DO NOTHING
      """'''

NEW_INSERT = '''      WB_SOURCE_ID = 11  # collect.source_registry WB (id=11)
      sql = """
          INSERT INTO ma.indicator_values
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
              source_id        = EXCLUDED.source_id
      """'''

content = FETCHER.read_text(encoding="utf-8")

# Fix 1 : INSERT + ON CONFLICT
if OLD_INSERT in content:
    content = content.replace(OLD_INSERT, NEW_INSERT, 1)
    print("OK Fix 1 -- INSERT + ON CONFLICT corrige")
else:
    print("WARN -- Pattern INSERT non trouve")

# Fix 2 : tuple batch_data -- chercher la ligne exacte
lines = content.split('\n')
fixed = False
for i, line in enumerate(lines):
    if 'batch_data.append' in line and 'LAYER_RAW' in line:
        print(f"Ligne {i+1} trouvee : {line.strip()}")
        # Ajouter WB_SOURCE_ID a la fin du tuple
        new_line = line.rstrip()
        if new_line.endswith('))'):
            new_line = new_line[:-2] + ', WB_SOURCE_ID))'
        elif new_line.endswith(')'):
            new_line = new_line[:-1] + ', WB_SOURCE_ID)'
        lines[i] = new_line
        fixed = True
        print(f"  -> Corrige : {new_line.strip()}")
        break

if not fixed:
    print("WARN -- Ligne batch_data non trouvee")

content = '\n'.join(lines)
FETCHER.write_text(content, encoding="utf-8")
print(f"OK -- {FETCHER} sauvegarde")

# ── Génération patch SQL ──────────────────────────────────────────────────────

SQL = """-- ============================================================
-- OSA Observatory — patch_deduplicate_l1_only.sql
-- Sprint 8 — Mai 2026
-- Nettoyage 106 884 doublons L1 + ECO_GDP L2
-- ============================================================

BEGIN;

-- 1. Supprimer doublons L1
DELETE FROM ma.indicator_values
WHERE layer_id = 1
  AND id NOT IN (
      SELECT MIN(id)
      FROM ma.indicator_values
      WHERE layer_id = 1
      GROUP BY indicator_code, country_iso3, year, layer_id
  );

DO $$
DECLARE
    v_restants INTEGER;
    v_total    INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_restants
    FROM ma.indicator_values
    WHERE layer_id = 1
      AND id NOT IN (
          SELECT MIN(id) FROM ma.indicator_values
          WHERE layer_id = 1
          GROUP BY indicator_code, country_iso3, year, layer_id
      );
    SELECT COUNT(*) INTO v_total FROM ma.indicator_values WHERE layer_id = 1;
    RAISE NOTICE 'Doublons residuels : % | Total L1 propre : %', v_restants, v_total;
    IF v_restants > 0 THEN RAISE EXCEPTION 'Doublons residuels -- rollback'; END IF;
END;
$$;

-- 2. ECO_GDP L2 copie directe depuis L1
DELETE FROM ma.indicator_values WHERE indicator_code = 'ECO_GDP' AND layer_id = 2;

INSERT INTO ma.indicator_values
    (indicator_code, country_iso3, year, layer_id,
     raw_value, processed_value, source_id,
     confidence_score, is_estimated, quality_flag, value_status)
SELECT
    indicator_code, country_iso3, year, 2,
    raw_value, raw_value, source_id,
    0.95, FALSE, 'OK', 'OBSERVED'
FROM ma.indicator_values
WHERE indicator_code = 'ECO_GDP'
  AND layer_id = 1
  AND year BETWEEN 2010 AND 2024
ON CONFLICT DO NOTHING;

DO $$
DECLARE v_nb INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_nb FROM ma.indicator_values
    WHERE indicator_code = 'ECO_GDP' AND layer_id = 2;
    RAISE NOTICE 'ECO_GDP L2 : % lignes', v_nb;
END;
$$;

COMMIT;
"""

sql_path = Path("db/patch_db/patch_deduplicate_l1_only.sql")
sql_path.write_text(SQL, encoding="utf-8")
print(f"OK -- Patch SQL : {sql_path}")
print()
print("Etapes suivantes :")
print("  1. psql ... -f db/patch_db/patch_deduplicate_l1_only.sql")
print("  2. Relancer L2 PECO -> L3 -> alert refresh")
