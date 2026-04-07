#!/usr/bin/env bash
set -euo pipefail

PROJET=$(cd "$(dirname "$0")/.." && pwd)

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
NC="\033[0m"

info()    { echo -e "${GREEN}[OSA]${NC} $*"; }
warning() { echo -e "${YELLOW}[OSA]${NC} $*"; }
error()   { echo -e "${RED}[OSA]${NC} $*"; exit 1; }

info "OSA Observatory — Configuration Codespaces"
info "Repertoire projet : $PROJET"

info "Installation postgresql-client..."
sudo apt-get install -y postgresql-client -q 2>/dev/null || true
info "postgresql-client installe"

info "Installation des dependances Python..."
pip install --quiet --upgrade pip
pip install --quiet -r "$PROJET/requirements.txt"
info "Python OK"

info "Attente PostgreSQL..."
for i in $(seq 1 30); do
    if pg_isready -h db -U osa_user -d osa_db -q 2>/dev/null; then
        info "PostgreSQL pret"
        break
    fi
    if [ $i -eq 30 ]; then error "PostgreSQL non disponible"; fi
    sleep 2
done

PSQL="psql -h db -U osa_user -d osa_db -v ON_ERROR_STOP=1"

ALREADY=$(psql -h db -U osa_user -d osa_db -tAq     -c "SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name = 'rf'"     2>/dev/null || echo "0")

if [ "$ALREADY" = "1" ]; then
    warning "Schema RF deja present"
else
    info "Deploiement des schemas SQL..."
    $PSQL -f "$PROJET/db/01_rf_schema.sql"      && info "01_rf OK"
    $PSQL -f "$PROJET/db/02_mm_schema.sql"      && info "02_mm OK"
    $PSQL -f "$PROJET/db/03_collect_schema.sql"  && info "03_collect OK"
    $PSQL -f "$PROJET/db/04_ma_schema.sql"      && info "04_ma OK"
    info "Schema OSA deploye."
fi

psql -h db -U osa_user -d osa_db -tAq     -c "SELECT pillar_code, COUNT(*) FROM rf.indicators GROUP BY pillar_code ORDER BY pillar_code;"

if [ ! -f "$PROJET/.env" ]; then
    printf "OSA_DB_HOST=db
OSA_DB_PORT=5432
OSA_DB_NAME=osa_db
OSA_DB_USER=osa_user
OSA_DB_PASS=osa_pass
OSA_LOG_LEVEL=INFO
" > "$PROJET/.env"
    info ".env cree"
fi

info "Configuration terminee."
