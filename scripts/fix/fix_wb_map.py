lines = open(r'G:\osa-observatory\collectors\wb_indicator_map.py', 'r', encoding='utf-8').readlines()

# Trouver la ligne 735 (}) et 738 (commentaire mal indente)
# Inserer un nouveau dict CANDIDATE_INDICATORS entre les deux
new_lines = []
i = 0
while i < len(lines):
    line = lines[i]
    # Detecter le commentaire mal indente apres la fermeture du dict ISO
    if i >= 736 and line.startswith('    # ') and '── Indicateurs' in line:
        # Inserer debut du nouveau dictionnaire
        new_lines.append('\nCANDIDATE_INDICATORS = {\n')
        new_lines.append(line)
    elif i >= 736 and line.startswith('    "PTRA') or (i >= 736 and line.startswith('    "') and 'candidate' in ''.join(lines[i:i+3])):
        new_lines.append(line)
    else:
        new_lines.append(line)
    i += 1

# Verifier si CANDIDATE_INDICATORS est ferme
content = ''.join(new_lines)
if 'CANDIDATE_INDICATORS = {' in content:
    # Trouver la derniere accolade et fermer le dict
    last_brace = content.rfind('\n}')
    if not content.strip().endswith('}'):
        content = content.rstrip() + '\n}\n'

open(r'G:\osa-observatory\collectors\wb_indicator_map.py', 'w', encoding='utf-8').write(content)

# Verifier syntaxe
import subprocess
result = subprocess.run(['python', '-c',
    'import sys; sys.path.insert(0, r"G:\osa-observatory\collectors"); from wb_indicator_map import WB_INDICATOR_MAP; print("OK -", len(WB_INDICATOR_MAP), "indicateurs")'],
    capture_output=True, text=True)
print(result.stdout or result.stderr)