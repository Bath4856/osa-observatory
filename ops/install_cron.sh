#!/usr/bin/env bash
# ============================================================
# OSA / ISA OBSERVATORY
# install_cron.sh — Installation idempotente du cron nightly
# ============================================================

set -euo pipefail

PROJECT_DIR=$(cd "$(dirname "$0")/.." && pwd)
PYTHON_BIN=${PYTHON_BIN:-/usr/local/bin/python}
CRON_SCHEDULE=${CRON_SCHEDULE:-"0 2 * * *"}
INCLUDE_PILOT=${INCLUDE_PILOT:-false}
REQUIRE_VALIDATION=${REQUIRE_VALIDATION:-true}
EXPORT_AUDIT_CSV=${EXPORT_AUDIT_CSV:-true}

CRON_TAG="# OSA_NIGHTLY"
CRON_LINE="$CRON_SCHEDULE cd $PROJECT_DIR && PYTHON_BIN=$PYTHON_BIN INCLUDE_PILOT=$INCLUDE_PILOT REQUIRE_VALIDATION=$REQUIRE_VALIDATION EXPORT_AUDIT_CSV=$EXPORT_AUDIT_CSV bash ops/run_osa_nightly.sh $CRON_TAG"

EXISTING=$(crontab -l 2>/dev/null || true)

if echo "$EXISTING" | grep -q "$CRON_TAG"; then
  NEW_CRON=$(echo "$EXISTING" | sed "s|^.*$CRON_TAG$|$CRON_LINE|")
  echo "$NEW_CRON" | crontab -
  echo "[OSA] Cron OSA mis a jour"
else
  {
    echo "$EXISTING"
    echo "$CRON_LINE"
  } | sed '/^$/N;/^\n$/D' | crontab -
  echo "[OSA] Cron OSA installe"
fi

crontab -l | grep "$CRON_TAG" || true
