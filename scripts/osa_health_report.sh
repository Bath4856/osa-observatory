#!/bin/bash
# OSA Observatory — Rapport de santé quotidien
# Execution : 06:00 UTC via cron
# Log : /mnt/data/logs/health/health_YYYYMMDD.log

set -euo pipefail

DATE=$(date +%Y%m%d)
DATETIME=$(date '+%Y-%m-%d %H:%M:%S UTC')
LOG_DIR="/mnt/data/logs/health"
LOG_FILE="${LOG_DIR}/health_${DATE}.log"
API="http://127.0.0.1:8000"
DB_HOST="172.18.0.3"
ALERT_EMAIL="contact@osa-observatory.africa"

mkdir -p "$LOG_DIR"

# Retention : garder 30 jours de logs
find "$LOG_DIR" -name "health_*.log" -mtime +30 -delete 2>/dev/null || true

STATUS="OK"
ERRORS=""

log() { echo "$1" | tee -a "$LOG_FILE"; }
err() { echo "[ERROR] $1" | tee -a "$LOG_FILE"; STATUS="DEGRADED"; ERRORS="${ERRORS}\n- $1"; }

log "=================================================================="
log "OSA Observatory — Rapport de santé — ${DATETIME}"
log "=================================================================="
log ""

# 1. Containers Docker
log "=== 1. CONTAINERS DOCKER ==="
for container in osa-api osa-db osa-prometheus osa-grafana; do
    state=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "absent")
    health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "N/A")
    if [ "$state" != "running" ]; then
        err "Container $container : $state"
    else
        log "  ✓ $container : $state (health: $health)"
    fi
done
log ""

# 2. API Health
log "=== 2. API HEALTH ==="
api_resp=$(curl -s -w "\n%{http_code}" --max-time 10 "${API}/health" 2>/dev/null || echo -e "\n000")
api_code=$(echo "$api_resp" | tail -1)
api_body=$(echo "$api_resp" | head -1)
if [ "$api_code" = "200" ]; then
    log "  ✓ API HTTP $api_code — $api_body"
else
    err "API inaccessible — HTTP $api_code"
fi
log ""

# 3. Base de données
log "=== 3. BASE DE DONNEES ==="
db_count=$(docker exec osa-db psql -U postgres -d osa_db -t -c \
    "SELECT COUNT(*) FROM ma.indicator_values WHERE layer_id=3;" 2>/dev/null | tr -d ' \n' || echo "ERR")
if [ "$db_count" = "ERR" ]; then
    err "Base de données inaccessible"
else
    log "  ✓ ma.indicator_values L3 : ${db_count} lignes"
fi

# Vérifier les 4 indicateurs TRAJECTOIRE
traj_count=$(docker exec osa-db psql -U postgres -d osa_db -t -c \
    "SELECT COUNT(DISTINCT indicator_code) FROM ma.indicator_values
     WHERE indicator_code IN ('PMIN_VALUE_CAPTURE','PMIN_VALUE_LEAKAGE',
     'PMIN_SMUGGLING_SIGNAL_RANK','PHUM_VALUE_CAPTURE');" 2>/dev/null | tr -d ' \n' || echo "0")
log "  ✓ Indicateurs TRAJECTOIRE en base : ${traj_count}/4"
if [ "$traj_count" != "4" ]; then
    err "Indicateurs TRAJECTOIRE incomplets : ${traj_count}/4"
fi

# Vérifier publication_policy
pp_count=$(docker exec osa-db psql -U postgres -d osa_db -t -c \
    "SELECT COUNT(*) FROM rf.publication_policy;" 2>/dev/null | tr -d ' \n' || echo "0")
log "  ✓ rf.publication_policy : ${pp_count} annees"
log ""

# 4. Endpoints critiques
log "=== 4. ENDPOINTS CRITIQUES ==="
declare -A ENDPOINTS=(
    ["/health"]="Health"
    ["/api/v2/scores?year=2024"]="Scores ISA 2024"
    ["/opendata/countries/latest"]="OpenData latest"
    ["/opendata/trajectories?year=2024"]="Trajectoires 2024"
    ["/opendata/publication-policy"]="Politique publication"
    ["/opendata/alerts/amar"]="Alertes AMAR"
)
for path in "${!ENDPOINTS[@]}"; do
    label="${ENDPOINTS[$path]}"
    code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 "${API}${path}" 2>/dev/null || echo "000")
    time_ms=$(curl -s -o /dev/null -w "%{time_total}" --max-time 15 "${API}${path}" 2>/dev/null || echo "0")
    time_ms=$(echo "$time_ms * 1000" | bc | cut -d. -f1)
    if [ "$code" = "200" ]; then
        log "  ✓ ${label} : HTTP $code — ${time_ms}ms"
    else
        err "${label} : HTTP $code"
    fi
done
log ""

# 5. Espace disque
log "=== 5. INFRASTRUCTURE ==="
disk_pct=$(df /mnt/data | awk 'NR==2{print $5}' | tr -d '%')
mem_free=$(free -m | awk 'NR==2{print $7}')
log "  ✓ Disque /mnt/data : ${disk_pct}% utilise"
log "  ✓ Memoire disponible : ${mem_free}MB"
if [ "$disk_pct" -gt 80 ]; then
    err "Espace disque critique : ${disk_pct}%"
fi
log ""

# 6. Résumé
log "=================================================================="
log "STATUT GLOBAL : ${STATUS}"
log "Rapport complet : ${LOG_FILE}"
log "=================================================================="

# Envoyer alerte email si dégradé
if [ "$STATUS" = "DEGRADED" ]; then
    echo -e "OSA Observatory — Alerte santé ${DATETIME}\n\nProblèmes détectés :\n${ERRORS}\n\nRapport complet : ${LOG_FILE}" | \
    python3 -c "
import sys, smtplib
from email.mime.text import MIMEText
body = sys.stdin.read()
msg = MIMEText(body)
msg['Subject'] = 'OSA Observatory — ALERTE SANTÉ ${DATE}'
msg['From'] = 'noreply@osa-observatory.africa'
msg['To'] = '${ALERT_EMAIL}'
with smtplib.SMTP('mail.gandi.net', 587) as s:
    s.starttls()
    s.login('noreply@osa-observatory.africa', 'Bada48561192')
    s.send_message(msg)
" 2>/dev/null && log "Alerte email envoyee a ${ALERT_EMAIL}" || log "Echec envoi email alerte"
fi

exit 0
