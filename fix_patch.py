import re
with open('G:/osa-observatory/db/patch_imputer_metadata_sprint6.sql', 'r', encoding='utf-8') as f:
    content = f.read()

def add_name_en(m):
    return m.group(1) + m.group(2) + ', ' + m.group(2) + ', ' + m.group(3)

pattern = r"('([A-Z][A-Z_]+)',\s*('[A-Z]+'),\s*('[^']+'))(,\s*'[A-Z_]+')"
def fix(m):
    full = m.group(0)
    name_fr = m.group(4)
    return full[:full.rindex(',')] + ', ' + name_fr + ',' + full[full.rindex(','):]

content = re.sub(
    r"(\('[A-Z_]+',\s*'[A-Z]+',\s*)('[^']+')(,\s*'[A-Z_0-9]+',\s*['+\-])",
    lambda m: m.group(1) + m.group(2) + ', ' + m.group(2) + m.group(3),
    content
)

with open('G:/osa-observatory/db/patch_imputer_metadata_sprint6.sql', 'w', encoding='utf-8') as f:
    f.write(content)
print('OK')
