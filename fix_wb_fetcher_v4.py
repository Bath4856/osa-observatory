"""
OSA Observatory — fix_wb_fetcher_v4.py
Correction par lecture ligne par ligne — robuste aux indentations
"""
from pathlib import Path

FETCHER = Path("collectors/fetcher_wb_pres_pmil_pnum.py")
lines = FETCHER.read_text(encoding="utf-8").splitlines()

new_lines = []
i = 0
fix1_done = False
fix2_done = False

while i < len(lines):
    line = lines[i]

    # Fix 1 : batch_data.append multi-lignes
    # Détecter le début du tuple et ajouter WB_SOURCE_ID
    if not fix1_done and 'batch_data.append((' in line:
        # Trouver la ligne de fermeture ))
        new_lines.append(line)  # batch_data.append((
        i += 1
        while i < len(lines):
            inner = lines[i]
            new_lines.append(inner)
            if inner.strip() == '))':
                # Insérer WB_SOURCE_ID avant la fermeture
                # Remplacer la dernière ligne ajoutée
                new_lines.pop()  # enlever le ))
                # Trouver l'indentation
                indent = len(inner) - len(inner.lstrip())
                new_lines.append(' ' * (indent + 4) + 'WB_SOURCE_ID')
                new_lines.append(inner)  # remettre le ))
                fix1_done = True
                break
            i += 1
        i += 1
        continue

    # Fix 2 : INSERT INTO + colonnes + ON CONFLICT DO NOTHING
    if not fix2_done and 'INSERT INTO ma.indicator_values' in line:
        indent = len(line) - len(line.lstrip())
        sp = ' ' * indent
        sp4 = ' ' * (indent + 4)
        sp8 = ' ' * (indent + 8)

        # Remplacer le bloc INSERT jusqu'à ON CONFLICT DO NOTHING inclus
        new_lines.append(sp + 'INSERT INTO ma.indicator_values')
        i += 1
        # Sauter les lignes de colonnes existantes jusqu'à VALUES
        while i < len(lines) and 'VALUES' not in lines[i]:
            i += 1

        # Insérer nouvelles colonnes
        new_lines.append(sp8 + '(indicator_code, country_iso3, year, layer_id,')
        new_lines.append(sp8 + ' raw_value, quality_flag, confidence_score, value_status,')
        new_lines.append(sp8 + ' source_id)')
        new_lines.append(sp4 + 'VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)')
        new_lines.append(sp4 + 'ON CONFLICT (indicator_code, country_iso3, year, layer_id, method_version_id)')
        new_lines.append(sp4 + 'DO UPDATE SET')
        new_lines.append(sp8 + 'raw_value        = EXCLUDED.raw_value,')
        new_lines.append(sp8 + 'quality_flag     = EXCLUDED.quality_flag,')
        new_lines.append(sp8 + 'confidence_score = EXCLUDED.confidence_score,')
        new_lines.append(sp8 + 'value_status     = EXCLUDED.value_status,')
        new_lines.append(sp8 + 'source_id        = EXCLUDED.source_id')

        # Sauter jusqu'après ON CONFLICT DO NOTHING
        while i < len(lines) and 'ON CONFLICT DO NOTHING' not in lines[i]:
            i += 1
        i += 1  # sauter la ligne ON CONFLICT DO NOTHING elle-même
        fix2_done = True
        continue

    new_lines.append(line)
    i += 1

# Ajouter WB_SOURCE_ID = 11 avant la fonction insert_indicator
content = '\n'.join(new_lines)

# Ajouter la constante WB_SOURCE_ID dans la fonction insert_indicator
OLD_BATCH_START = 'batch_data = []'
NEW_BATCH_START = 'WB_SOURCE_ID = 11  # collect.source_registry WB (id=11)\n    batch_data = []'
if OLD_BATCH_START in content and 'WB_SOURCE_ID = 11' not in content:
    content = content.replace(OLD_BATCH_START, NEW_BATCH_START, 1)

FETCHER.write_text(content, encoding="utf-8")

# Vérification
c = FETCHER.read_text(encoding="utf-8")
print("Verification finale :")
print(f"  WB_SOURCE_ID = 11   : {'WB_SOURCE_ID = 11' in c}")
print(f"  source_id colonne   : {'source_id)' in c}")
print(f"  DO UPDATE SET       : {'DO UPDATE SET' in c}")
print(f"  ON CONFLICT DO NOTHING restant : {'ON CONFLICT DO NOTHING' in c}")
print(f"  Fix 1 (batch tuple) : {fix1_done}")
print(f"  Fix 2 (INSERT)      : {fix2_done}")
