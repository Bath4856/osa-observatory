#!/usr/bin/env bash
# ============================================================
# OSA / ISA OBSERVATORY
# .devcontainer/reset_db.sh — Réinitialisation complète de la base
# Usage : bash .devcontainer/reset_db.sh
# ATTENTION : supprime toutes les données existantes
PROJET=$(cd "$(dirname "$0")/.." && pwd)
# ============================================================

set -euo pipefail

echo "ATTENTION : Ce script supprime et recrée tous les schémas OSA."
echo "Toutes les données collectées seront perdues."
echo ""
read -p "Confirmer (oui/non) : " CONFIRM

if [ "$CONFIRM" != "oui" ]; then
    echo "Annulé."
    exit 0
fi

PSQL="psql -h db -U osa_user -d osa_db -v ON_ERROR_STOP=1"

echo "Suppression des schémas..."
$PSQL -c "DROP SCHEMA IF EXISTS ma      CASCADE;"
$PSQL -c "DROP SCHEMA IF EXISTS collect CASCADE;"
$PSQL -c "DROP SCHEMA IF EXISTS mm      CASCADE;"
$PSQL -c "DROP SCHEMA IF EXISTS rf      CASCADE;"
echo "Schémas supprimés."

echo "Redéploiement..."
$PSQL -f ${PROJET}/db/01_rf_schema.sql
$PSQL -f ${PROJET}/db/02_mm_schema.sql
$PSQL -f ${PROJET}/db/03_collect_schema.sql
$PSQL -f ${PROJET}/db/04_ma_schema.sql
echo "Redéploiement terminé."

echo ""
echo "Vérification :"
$PSQL -c "SELECT 'rf.indicators' AS t, COUNT(*) FROM rf.indicators
          UNION ALL
          SELECT 'rf.countries',       COUNT(*) FROM rf.countries
          UNION ALL
          SELECT 'mm.categories',      COUNT(*) FROM mm.categories;"
