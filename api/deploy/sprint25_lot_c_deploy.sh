#!/bin/bash
set -e

APP=/mnt/data/osa-app/osa-observatory

# 1. Copier le router
cp ~/amar_triggers.py $APP/api/routers/amar_triggers.py
echo "[1/3] amar_triggers.py copie"

# 2. Patcher main.py -- ajouter import apres early_warning_router
python3 - << 'PYEOF'
import re

path = "/mnt/data/osa-app/osa-observatory/api/main.py"
with open(path) as f:
    content = f.read()

# Verifier si deja patche
if "amar_triggers_router" in content:
    print("[2/3] main.py deja patche -- skip")
else:
    # Import : ajouter apres la ligne early_warning_router
    content = content.replace(
        "from api.routers.early_warning import router as early_warning_router",
        "from api.routers.early_warning import router as early_warning_router\n"
        "from api.routers.amar_triggers import router as amar_triggers_router  # SPRINT25"
    )
    # include_router : ajouter apres early_warning_router
    content = content.replace(
        "app.include_router(early_warning_router)",
        "app.include_router(early_warning_router)\n"
        "app.include_router(amar_triggers_router)  # SPRINT25"
    )
    with open(path, "w") as f:
        f.write(content)
    print("[2/3] main.py patche")
PYEOF

# 3. Redemarrer le container
docker restart osa-api
echo "[3/3] osa-api redемаrré"

# 4. Attendre et verifier
sleep 5
curl -s http://localhost:8000/health | python3 -c "import sys,json; d=json.load(sys.stdin); print('Health:', d['status'])"
echo ""
curl -s "http://localhost:8000/api/v2/amar/triggers?year=2024" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if isinstance(data, list):
    print(f'Triggers 2024 : {len(data)} resultats')
    for r in data[:3]:
        print(f'  {r[\"country_iso3\"]} {r[\"pillar_code\"]} => {r[\"trigger_class\"]}')
else:
    print('Erreur:', data)
"
