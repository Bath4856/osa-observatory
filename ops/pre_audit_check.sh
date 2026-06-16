#!/usr/bin/env bash
# ==============================================================================
# OSA ISA – P8 OPS V2
# pre_audit_check.sh
#
# Script de vérification et de lancement de l'audit OPS.
# Exécute une checklist complète avant de lancer run_audit.py.
# Bloque le lancement si une condition critique n'est pas remplie.
#
# Usage :
#   bash ops/pre_audit_check.sh             # vérification + lancement interactif
#   bash ops/pre_audit_check.sh --force     # lancement sans confirmation
#   bash ops/pre_audit_check.sh --check     # vérification seule, sans lancer
#
# ==============================================================================

set -euo pipefail

# ── Couleurs ──────────────────────────────────────────────────────────────────
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
BLUE="\033[1;34m"
BOLD="\033[1m"
RESET="\033[0m"

# ── Chemins ───────────────────────────────────────────────────────────────────
REPO_ROOT="/mnt/data/osa-app/osa-observatory"
CONFIG="$REPO_ROOT/audit/config/audit_config.yaml"
RUNNER="$REPO_ROOT/ops/run_audit.py"
REPORTS_DIR="$REPO_ROOT/reports"

# ── Arguments ─────────────────────────────────────────────────────────────────
MODE="interactive"
for arg in "$@"; do
    case $arg in
        --force) MODE="force" ;;
        --check) MODE="check" ;;
    esac
done

# ── Compteurs ─────────────────────────────────────────────────────────────────
ERRORS=0
WARNINGS=0

# ── Fonctions utilitaires ─────────────────────────────────────────────────────

ok()   { echo -e "  ${GREEN}✓${RESET}  $1"; }
warn() { echo -e "  ${YELLOW}⚠${RESET}  $1"; WARNINGS=$((WARNINGS + 1)); }
fail() { echo -e "  ${RED}✗${RESET}  $1"; ERRORS=$((ERRORS + 1)); }
info() { echo -e "  ${BLUE}→${RESET}  $1"; }

section() {
    echo ""
    echo -e "${BOLD}$1${RESET}"
    echo "────────────────────────────────────────────"
}

ask_choice() {
    local prompt="$1"
    shift
    local options=("$@")
    echo ""
    echo -e "${YELLOW}$prompt${RESET}"
    for i in "${!options[@]}"; do
        echo "  $((i+1)). ${options[$i]}"
    done
    echo -n "Votre choix [1-${#options[@]}] : "
    read -r choice
    echo "$choice"
}

# ── En-tête ───────────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║   OSA ISA – Pre-Audit Check – P8 OPS V2     ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════╝${RESET}"
echo -e "  Date UTC : $(date -u '+%Y-%m-%d %H:%M:%S')"
echo -e "  Mode     : $MODE"

# ══════════════════════════════════════════════════════════════════════════════
# CHECK 1 — Fichiers essentiels
# ══════════════════════════════════════════════════════════════════════════════

section "1. Fichiers essentiels"

if [ -f "$CONFIG" ]; then
    ok "audit_config.yaml présent"
else
    fail "audit_config.yaml introuvable : $CONFIG"
fi

if [ -f "$RUNNER" ]; then
    ok "run_audit.py présent"
else
    fail "run_audit.py introuvable : $RUNNER"
fi

if [ -f "$REPO_ROOT/audit/core/audit_runner.py" ]; then
    ok "audit_runner.py (core) présent"
else
    fail "audit_runner.py (core) introuvable"
fi

if [ -d "$REPORTS_DIR" ]; then
    ok "Répertoire reports/ présent"
else
    warn "Répertoire reports/ absent — sera créé au run"
    mkdir -p "$REPORTS_DIR"
fi

# ══════════════════════════════════════════════════════════════════════════════
# CHECK 2 — Conteneurs Docker
# ══════════════════════════════════════════════════════════════════════════════

section "2. Conteneurs Docker"

REQUIRED_CONTAINERS=("osa-db" "osa-api" "osa-grafana" "osa-prometheus")

for container in "${REQUIRED_CONTAINERS[@]}"; do
    STATUS=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "absent")
    HEALTH=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}n/a{{end}}' "$container" 2>/dev/null || echo "absent")

    if [ "$STATUS" = "running" ]; then
        if [ "$HEALTH" = "healthy" ] || [ "$HEALTH" = "n/a" ]; then
            ok "$container — running ($HEALTH)"
        else
            warn "$container — running mais health=$HEALTH"
        fi
    elif [ "$STATUS" = "absent" ]; then
        fail "$container — conteneur introuvable"
    else
        fail "$container — status=$STATUS"
    fi
done

# ══════════════════════════════════════════════════════════════════════════════
# CHECK 3 — API
# ══════════════════════════════════════════════════════════════════════════════

section "3. API OSA"

API_URL=$(grep 'api_url:' "$CONFIG" | head -1 | awk '{print $2}' | tr -d '"')
API_URL=${API_URL:-"https://api.osa-observatory.africa"}

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$API_URL/health" 2>/dev/null || echo "000")

if [ "$HTTP_CODE" = "200" ]; then
    HEALTH_BODY=$(curl -s --max-time 10 "$API_URL/health" 2>/dev/null)
    ok "API répond HTTP 200 — $HEALTH_BODY"
elif [ "$HTTP_CODE" = "000" ]; then
    fail "API injoignable ($API_URL/health)"
else
    fail "API répond HTTP $HTTP_CODE (attendu 200)"
fi

# Test /api/v2/scores supprimé — consommerait le rate limit avant l'audit.
# /health suffit pour confirmer que l'API est opérationnelle.

# ══════════════════════════════════════════════════════════════════════════════
# CHECK 4 — Base de données
# ══════════════════════════════════════════════════════════════════════════════

section "4. Base de données PostgreSQL"

DB_HOST=$(grep 'db_host:' "$CONFIG" | head -1 | awk '{print $2}' | tr -d '"')
DB_PORT=$(grep 'db_port:' "$CONFIG" | head -1 | awk '{print $2}' | tr -d '"')
DB_NAME=$(grep 'db_name:' "$CONFIG" | head -1 | awk '{print $2}' | tr -d '"')
DB_USER=$(grep 'db_user:' "$CONFIG" | head -1 | awk '{print $2}' | tr -d '"')

info "Hôte DB configuré : $DB_HOST:$DB_PORT"

# Vérifier que l'IP Docker est toujours valide
DOCKER_IP=$(docker inspect osa-db 2>/dev/null | python3 -c "
import json,sys
d = json.load(sys.stdin)
nets = d[0]['NetworkSettings']['Networks']
print(list(nets.values())[0]['IPAddress'])
" 2>/dev/null || echo "")

if [ -n "$DOCKER_IP" ]; then
    if [ "$DB_HOST" = "$DOCKER_IP" ]; then
        ok "db_host=$DB_HOST correspond à l'IP Docker osa-db"
    else
        warn "db_host=$DB_HOST ≠ IP Docker osa-db ($DOCKER_IP)"
        echo ""
        CHOICE=$(ask_choice "L'IP Docker a changé. Que faire ?" \
            "Mettre à jour db_host automatiquement ($DOCKER_IP)" \
            "Continuer sans modifier" \
            "Annuler")
        case $CHOICE in
            1)
                sed -i "s/db_host: .*/db_host: $DOCKER_IP/" "$CONFIG"
                ok "db_host mis à jour → $DOCKER_IP"
                DB_HOST="$DOCKER_IP"
                ;;
            2) warn "db_host conservé ($DB_HOST) — risque de FAIL DATABASE" ;;
            *) echo -e "${RED}Annulé.${RESET}"; exit 1 ;;
        esac
    fi
fi

# Test connexion TCP
if python3 -c "
import socket, sys
try:
    s = socket.create_connection(('$DB_HOST', $DB_PORT), timeout=5)
    s.close()
    sys.exit(0)
except Exception as e:
    sys.exit(1)
" 2>/dev/null; then
    ok "Connexion TCP $DB_HOST:$DB_PORT — OK"
else
    fail "Impossible de joindre $DB_HOST:$DB_PORT"
fi

# ══════════════════════════════════════════════════════════════════════════════
# CHECK 5 — Rate limit (délai depuis le dernier run)
# ══════════════════════════════════════════════════════════════════════════════

section "5. Rate limit — délai depuis le dernier run"

MIN_DELAY_SECONDS=180  # 3 minutes minimum entre deux runs

LAST_REPORT=$(ls -t "$REPORTS_DIR"/audit_*.json 2>/dev/null | head -1 || echo "")

if [ -z "$LAST_REPORT" ]; then
    ok "Aucun run précédent — premier lancement"
else
    LAST_MODIFIED=$(stat -c %Y "$LAST_REPORT" 2>/dev/null || echo "0")
    NOW=$(date +%s)
    ELAPSED=$((NOW - LAST_MODIFIED))
    LAST_TIME=$(stat -c %y "$LAST_REPORT" | cut -d'.' -f1)

    if [ "$ELAPSED" -ge "$MIN_DELAY_SECONDS" ]; then
        ok "Dernier run : $LAST_TIME (il y a ${ELAPSED}s) — délai OK"
    else
        REMAINING=$((MIN_DELAY_SECONDS - ELAPSED))
        warn "Dernier run il y a ${ELAPSED}s — délai minimum : ${MIN_DELAY_SECONDS}s (encore ${REMAINING}s)"
        echo ""
        CHOICE=$(ask_choice "Délai insuffisant (risque de 429 rate limit). Que faire ?" \
            "Attendre ${REMAINING}s automatiquement puis lancer" \
            "Lancer maintenant quand même (risque 429)" \
            "Annuler")
        case $CHOICE in
            1)
                info "Attente de ${REMAINING}s…"
                sleep "$REMAINING"
                ok "Délai écoulé — prêt"
                ;;
            2) warn "Lancement forcé sans attendre" ;;
            *) echo -e "${RED}Annulé.${RESET}"; exit 1 ;;
        esac
    fi
fi

# ══════════════════════════════════════════════════════════════════════════════
# CHECK 6 — Audit déjà en cours
# ══════════════════════════════════════════════════════════════════════════════

section "6. Processus audit en cours"

RUNNING_PID=$(pgrep -f "run_audit.py" 2>/dev/null || echo "")

if [ -z "$RUNNING_PID" ]; then
    ok "Aucun audit en cours"
else
    fail "Un audit tourne déjà (PID $RUNNING_PID)"
    echo ""
    CHOICE=$(ask_choice "Un audit est déjà en cours. Que faire ?" \
        "Attendre sa fin" \
        "Le tuer et lancer un nouveau run" \
        "Annuler")
    case $CHOICE in
        1)
            info "Attente de la fin du processus $RUNNING_PID…"
            while kill -0 "$RUNNING_PID" 2>/dev/null; do sleep 5; done
            ok "Processus terminé — prêt"
            ERRORS=$((ERRORS - 1))
            ;;
        2)
            kill "$RUNNING_PID" 2>/dev/null
            ok "Processus $RUNNING_PID arrêté"
            ERRORS=$((ERRORS - 1))
            ;;
        *) echo -e "${RED}Annulé.${RESET}"; exit 1 ;;
    esac
fi

# ══════════════════════════════════════════════════════════════════════════════
# CHECK 7 — Python et dépendances
# ══════════════════════════════════════════════════════════════════════════════

section "7. Python et dépendances"

PYTHON_VERSION=$(python3 --version 2>&1)
ok "$PYTHON_VERSION"

for pkg in requests psycopg2 yaml reportlab; do
    if python3 -c "import $pkg" 2>/dev/null; then
        ok "import $pkg — OK"
    else
        fail "import $pkg — MANQUANT"
        info "Installer avec : pip3 install -r $REPO_ROOT/ops/requirements.txt --break-system-packages"
    fi
done

# ══════════════════════════════════════════════════════════════════════════════
# RÉSUMÉ
# ══════════════════════════════════════════════════════════════════════════════

echo ""
echo -e "${BOLD}══════════════════════════════════════════════${RESET}"
echo -e "${BOLD}  Résumé de la vérification${RESET}"
echo -e "${BOLD}══════════════════════════════════════════════${RESET}"
echo -e "  Erreurs   : ${RED}$ERRORS${RESET}"
echo -e "  Warnings  : ${YELLOW}$WARNINGS${RESET}"

if [ "$ERRORS" -gt 0 ]; then
    echo ""
    echo -e "  ${RED}✗ Lancement bloqué — corrigez les erreurs ci-dessus.${RESET}"
    exit 1
fi

if [ "$WARNINGS" -gt 0 ]; then
    echo ""
    echo -e "  ${YELLOW}⚠ Des warnings ont été détectés.${RESET}"
    if [ "$MODE" = "interactive" ]; then
        CHOICE=$(ask_choice "Lancer l'audit malgré les warnings ?" \
            "Oui, lancer l'audit" \
            "Non, annuler")
        case $CHOICE in
            1) ;;
            *) echo -e "${RED}Annulé.${RESET}"; exit 0 ;;
        esac
    fi
fi

# ══════════════════════════════════════════════════════════════════════════════
# LANCEMENT
# ══════════════════════════════════════════════════════════════════════════════

if [ "$MODE" = "check" ]; then
    echo ""
    echo -e "  ${GREEN}✓ Vérification terminée (mode --check, pas de lancement).${RESET}"
    exit 0
fi

echo ""
echo -e "  ${GREEN}✓ Toutes les vérifications passées — lancement de l'audit…${RESET}"
echo -e "${BOLD}══════════════════════════════════════════════${RESET}"

# Délai de sécurité : le pre-check a pu faire des appels API (health, etc.)
# qui consomment le rate limiter. On attend 15s pour le laisser se réinitialiser.
echo ""
info "Délai de sécurité anti-rate-limit (15s)…"
sleep 15
echo ""

cd "$REPO_ROOT"
python3 ops/run_audit.py
