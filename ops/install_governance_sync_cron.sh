#!/usr/bin/env bash
# ============================================================
# OSA / ISA OBSERVATORY
# install_governance_sync_cron.sh -- Installation idempotente du cron
# de synchronisation du bus de gouvernance evenementielle (ADR-003/004)
# ============================================================
# Sur le meme patron que install_cron.sh (tag de commentaire en fin de
# ligne pour idempotence -- reexecuter ce script met a jour l'entree
# existante au lieu d'en creer une seconde).
#
# Le secret IDENTITY_SYNC_SECRET n'est jamais ecrit en clair dans la
# ligne crontab elle-meme (crontab -l le rendrait lisible en clair a
# quiconque a acces au compte) -- il est relu depuis api/.env a chaque
# execution, source de verite unique deja utilisee par les conteneurs
# Docker.
# ============================================================
set -euo pipefail
PROJECT_DIR=$(cd "$(dirname "$0")/.." && pwd)
PYTHON_BIN=${PYTHON_BIN:-$HOME/flyer-venv/bin/python3}
CRON_SCHEDULE=${CRON_SCHEDULE:-"*/5 * * * *"}
PROD_API_BASE=${PROD_API_BASE:-"https://open.osa-observatory.africa/api"}

CRON_TAG="# OSA_GOVERNANCE_SYNC"

if [ ! -f "$PROJECT_DIR/api/.env" ] || ! grep -q '^IDENTITY_SYNC_SECRET=' "$PROJECT_DIR/api/.env"; then
  echo "[OSA] Erreur : IDENTITY_SYNC_SECRET introuvable dans api/.env -- verifier avant d'installer le cron." >&2
  exit 1
fi

if [ ! -x "$PYTHON_BIN" ]; then
  echo "[OSA] Erreur : interpreteur Python introuvable a $PYTHON_BIN -- ajuster PYTHON_BIN." >&2
  exit 1
fi

mkdir -p "$PROJECT_DIR/ops/logs"

# Le secret est relu depuis api/.env AU MOMENT DE L'EXECUTION cron,
# jamais fige dans la ligne crontab elle-meme.
CRON_CMD="cd $PROJECT_DIR && IDENTITY_SYNC_SECRET=\$(grep '^IDENTITY_SYNC_SECRET=' api/.env | head -1 | cut -d= -f2-) PROD_API_BASE='$PROD_API_BASE' $PYTHON_BIN ops/governance_synchronizer.py >> $PROJECT_DIR/ops/logs/governance_sync.log 2>&1"
CRON_LINE="$CRON_SCHEDULE $CRON_CMD $CRON_TAG"

EXISTING=$(crontab -l 2>/dev/null || true)
if echo "$EXISTING" | grep -q "$CRON_TAG"; then
  NEW_CRON=$(echo "$EXISTING" | sed "s|^.*$CRON_TAG\$|$CRON_LINE|")
  echo "$NEW_CRON" | crontab -
  echo "[OSA] Cron de synchronisation du bus de gouvernance mis a jour (frequence: $CRON_SCHEDULE)"
else
  {
    echo "$EXISTING"
    echo "$CRON_LINE"
  } | sed '/^$/N;/^\n$/D' | crontab -
  echo "[OSA] Cron de synchronisation du bus de gouvernance installe (frequence: $CRON_SCHEDULE)"
fi
crontab -l | grep "$CRON_TAG" || true
