#!/usr/bin/env bash
# ============================================================
# OSA / ISA OBSERVATORY
# deploy_env.sh -- Deploiement automatise DEV / PREPROD / PROD
# ============================================================
# Tourne exclusivement sur le VPS. Windows ne sert qu'a committer
# et pousser le code (git push) avant d'executer ce script ici.
#
# Sequence par environnement : git pull -> execution SQL (optionnelle,
# 0 a N fichiers, sur la bonne base par environnement) -> docker rm -f
# -> docker build -> docker run -> verification (healthy) -> test
# (curl local + endpoint optionnel).
#
# Cree le 23 juillet 2026 apres plusieurs incidents de deploiement
# manuel dans la meme soiree (sed duplique dans main.py, docker run
# echoue silencieusement sans que le collage terminal ne le montre) --
# objectif : rendre la sequence deterministe et verifiable, plutot
# que retapee a la main a chaque lot.
#
# USAGE :
#   bash ops/deploy_env.sh dev
#   bash ops/deploy_env.sh preprod
#   bash ops/deploy_env.sh prod
#   bash ops/deploy_env.sh all              (dev puis preprod puis prod, arret au premier echec)
#   bash ops/deploy_env.sh dev --test /api/v2/oim/levers
#   bash ops/deploy_env.sh all --sql gaf/sql/add_interdependance_method.sql --test /api/v2/osoa/opportunities
#   bash ops/deploy_env.sh all --sql fichier1.sql --sql fichier2.sql   (plusieurs scripts SQL, dans l'ordre donne)
#
# Chaque script SQL est execute avec psql -v ON_ERROR_STOP=1, contre
# la base reelle de l'environnement (osa_dev / osa_preprod / osa_db) --
# le script s'arrete immediatement si le SQL echoue, avant meme de
# toucher au conteneur Docker.
#
# Ne fait JAMAIS docker restart -- toujours rm -f + run, conforme
# a la doctrine du projet (docker restart ne relit pas --env-file).
# ============================================================
set -euo pipefail

PROJECT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$PROJECT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${YELLOW}[deploy]${NC} $1"; }
ok()   { echo -e "${GREEN}[  OK  ]${NC} $1"; }
fail() { echo -e "${RED}[ECHEC]${NC} $1"; exit 1; }

# ── Configuration par environnement ────────────────────────────────────────────
# format : container|image|port_mapping|env_file|health_url|db_name
declare -A ENV_CONFIG
ENV_CONFIG[dev]="osa-api-dev|osa-api-dev|127.0.0.1:8002:8000|api/.env.dev|http://127.0.0.1:8002/health|osa_dev"
ENV_CONFIG[preprod]="osa-api-preprod|osa-api-preprod|8001:8000|api/.env.preprod|http://127.0.0.1:8001/health|osa_preprod"
ENV_CONFIG[prod]="osa-api|osa-api|127.0.0.1:8000:8000|api/.env|http://127.0.0.1:8000/health|osa_db"

run_sql_files() {
    local db_name="$1"
    shift
    local sql_files=("$@")

    if [[ ${#sql_files[@]} -eq 0 ]]; then
        log "Aucun script SQL fourni -- étape ignorée"
        return 0
    fi

    for sql_file in "${sql_files[@]}"; do
        if [[ ! -f "$sql_file" ]]; then
            fail "Script SQL introuvable : $sql_file"
        fi
        log "Exécution de $sql_file sur $db_name"
        # -v ON_ERROR_STOP=1 : psql s'arrete et sort en erreur des le premier
        # probleme SQL, au lieu de continuer silencieusement (comportement par
        # defaut de psql) -- evite un COMMIT partiel non detecte.
        if ! docker exec -i osa-db psql -v ON_ERROR_STOP=1 -U postgres -d "$db_name" < "$sql_file" > /tmp/deploy_sql_$(basename "$sql_file")_${db_name}.log 2>&1; then
            tail -30 /tmp/deploy_sql_$(basename "$sql_file")_${db_name}.log
            fail "Échec de l'exécution SQL de $sql_file sur $db_name -- voir le log ci-dessus"
        fi
        ok "$sql_file appliqué avec succès sur $db_name"
    done
}

deploy_one() {
    local env_name="$1"
    local extra_test_path="$2"
    shift 2
    local sql_files=("$@")

    if [[ -z "${ENV_CONFIG[$env_name]+x}" ]]; then
        fail "Environnement inconnu : '$env_name' (attendu : dev, preprod, prod)"
    fi

    IFS='|' read -r container image port_mapping env_file health_url db_name <<< "${ENV_CONFIG[$env_name]}"

    echo ""
    log "=== Déploiement $env_name (conteneur: $container, base: $db_name) ==="

    if [[ ! -f "$env_file" ]]; then
        fail "Fichier d'environnement introuvable : $env_file"
    fi

    log "1/6 git pull"
    git pull || fail "git pull a échoué"
    ok "Dépôt à jour"

    log "2/6 Exécution des scripts SQL (si fournis)"
    run_sql_files "$db_name" "${sql_files[@]}"

    log "3/6 Arrêt du conteneur existant (si présent)"
    docker rm -f "$container" > /dev/null 2>&1 || true
    ok "Conteneur '$container' supprimé (ou absent)"

    log "4/6 Build de l'image ($image:latest)"
    if ! docker build -t "${image}:latest" -f api/Dockerfile . > /tmp/deploy_build_${env_name}.log 2>&1; then
        tail -30 /tmp/deploy_build_${env_name}.log
        fail "Build échoué -- voir /tmp/deploy_build_${env_name}.log"
    fi
    ok "Image construite"

    log "5/6 Lancement du conteneur"
    docker run -d --name "$container" --network osa-network -p "$port_mapping" --env-file "$env_file" "${image}:latest" > /dev/null \
        || fail "docker run a échoué"

    log "Vérification (jusqu'à 6 tentatives, 5s d'intervalle)"
    local healthy=0
    for i in $(seq 1 6); do
        sleep 5
        status=$(docker ps --filter "name=^${container}\$" --format "{{.Status}}" 2>/dev/null || true)
        if [[ "$status" == *"healthy"* ]]; then
            healthy=1
            break
        fi
        log "  tentative $i/6 -- statut actuel : ${status:-<conteneur absent>}"
    done
    if [[ "$healthy" -ne 1 ]]; then
        echo "--- Derniers logs du conteneur ---"
        docker logs "$container" --tail 40 2>&1 || true
        fail "Le conteneur '$container' n'est jamais devenu healthy"
    fi
    ok "Conteneur '$container' healthy"

    log "6/6 Test"
    if ! curl -sf "$health_url" > /tmp/deploy_test_${env_name}.json; then
        fail "Échec de l'appel à $health_url"
    fi
    ok "Réponse /health : $(cat /tmp/deploy_test_${env_name}.json)"

    if [[ -n "$extra_test_path" ]]; then
        local base_url="${health_url%/health}"
        local extra_url="${base_url}${extra_test_path}"
        if ! curl -sf "$extra_url" > /tmp/deploy_test_extra_${env_name}.json; then
            fail "Échec de l'appel à $extra_url"
        fi
        ok "Réponse $extra_test_path : $(cat /tmp/deploy_test_extra_${env_name}.json | head -c 200)"
    fi

    echo ""
    ok "=== $env_name déployé et vérifié avec succès ==="
}

# ── Point d'entrée ────────────────────────────────────────────────────────────
TARGET="${1:-}"
shift || true

EXTRA_TEST=""
SQL_FILES=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --test)
            EXTRA_TEST="$2"
            shift 2
            ;;
        --sql)
            SQL_FILES+=("$2")
            shift 2
            ;;
        *)
            echo "Argument inconnu : $1"
            exit 1
            ;;
    esac
done

case "$TARGET" in
    dev|preprod|prod)
        deploy_one "$TARGET" "$EXTRA_TEST" "${SQL_FILES[@]}"
        ;;
    all)
        deploy_one dev "$EXTRA_TEST" "${SQL_FILES[@]}"
        deploy_one preprod "$EXTRA_TEST" "${SQL_FILES[@]}"
        deploy_one prod "$EXTRA_TEST" "${SQL_FILES[@]}"
        echo ""
        ok "=== Les 3 environnements sont déployés et synchronisés ==="
        ;;
    *)
        echo "Usage : bash ops/deploy_env.sh <dev|preprod|prod|all> [--sql fichier1.sql --sql fichier2.sql ...] [--test /chemin/endpoint]"
        exit 1
        ;;
esac
