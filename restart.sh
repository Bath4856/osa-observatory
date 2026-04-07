#!/usr/bin/env bash
# ============================================================
# OSA / ISA OBSERVATORY - 20260407
# restart.sh — Redémarrage complet après recréation Codespace
# ============================================================
# Usage : bash restart.sh
#
# Ce script est nécessaire UNIQUEMENT quand le Codespace a été
# recréé (données perdues). Si le Codespace était juste en
# veille, les données sont conservées — ne pas relancer.
#
# Durée estimée : 2 à 3 minutes
# ============================================================

set -euo pipefail

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
NC="\033[0m"

info()    { echo -e "${GREEN}[OSA]${NC} $*"; }
warning() { echo -e "${YELLOW}[OSA]${NC} $*"; }
error()   { echo -e "${RED}[OSA]${NC} $*"; exit 1; }

PROJET=$(cd "$(dirname "$0")" && pwd)

info "========================================================"
info "OSA Observatory — Redémarrage complet"
info "Répertoire : $PROJET"
info "========================================================"

# ── 1. Vérifier si la base est déjà déployée ─────────────
info "Vérification état de la base..."

# Installer psql si absent
if ! command -v psql &>/dev/null; then
    info "Installation postgresql-client..."
    sudo apt-get update -q
    sudo apt-get install -y postgresql-client -q
    info "postgresql-client installé"
fi

# Configurer .pgpass
if [ ! -f ~/.pgpass ]; then
    echo "db:5432:osa_db:osa_user:osa_pass" > ~/.pgpass
    chmod 600 ~/.pgpass
    info ".pgpass configuré"
fi

# Installer dépendances Python si nécessaire
if ! python3 -c "import psycopg2" 2>/dev/null; then
    info "Installation dépendances Python..."
    pip3 install --quiet psycopg2-binary python-dotenv requests \
        --break-system-packages 2>/dev/null || \
    pip3 install --quiet psycopg2-binary python-dotenv requests
    info "Dépendances Python installées"
fi

# Attendre PostgreSQL
info "Attente PostgreSQL..."
for i in $(seq 1 20); do
    if pg_isready -h localhost -U osa_user -d osa_db -q 2>/dev/null; then
        info "PostgreSQL prêt (tentative $i)"
        break
    fi
    if [ $i -eq 20 ]; then
        error "PostgreSQL non disponible — vérifiez le Codespace"
    fi
    sleep 3
done

# Vérifier si schéma déjà présent
ALREADY=$(psql -h localhost -U osa_user -d osa_db -tAq \
    -c "SELECT COUNT(*) FROM information_schema.schemata
        WHERE schema_name = 'rf'" 2>/dev/null || echo "0")

if [ "$ALREADY" = "1" ]; then
    IND_COUNT=$(psql -h localhost -U osa_user -d osa_db -tAq \
        -c "SELECT COUNT(*) FROM rf.indicators" 2>/dev/null || echo "0")
    BLOCS_COUNT=$(psql -h localhost -U osa_user -d osa_db -tAq \
        -c "SELECT COUNT(*) FROM rf.country_blocs" 2>/dev/null || echo "0")
    PROV_COUNT=$(psql -h localhost -U osa_user -d osa_db -tAq \
        -c "SELECT COUNT(*) FROM collect.data_providers WHERE code IN ('UNESCO','UNDP')" 2>/dev/null || echo "0")
    # 17 providers attendus (16 précédents + UNPK)
    REGISTRY_COUNT=$(psql -h localhost -U osa_user -d osa_db -tAq \
        -c "SELECT COUNT(*) FROM collect.source_registry
            WHERE source_id IN (
                'WB','IMF','IMF_WEO','IMF_DOTS','IMF_BOP',
                'WHO','ITU','FAO','UNDP','UNESCO',
                'EITI','SIPRI','USGS','ACLED',
                'COMTRADE','UNCTAD','UNPK',
                'OECD'
            )" 2>/dev/null || echo "0")
    MATRIX_OK=$(psql -h localhost -U osa_user -d osa_db -tAq \
        -c "SELECT COUNT(*) FROM pg_proc p
            JOIN pg_namespace n ON n.oid = p.pronamespace
            WHERE n.nspname = 'collect'
              AND p.proname = 'run_ingestion_from_matrix'
              AND p.pronargs = 5" 2>/dev/null || echo "0")
    QUALITY_OK=$(psql -h localhost -U osa_user -d osa_db -tAq \
        -c "SELECT COUNT(*) FROM pg_proc p
            JOIN pg_namespace n ON n.oid = p.pronamespace
            WHERE n.nspname = 'collect'
              AND p.proname = 'compute_quality_score'" 2>/dev/null || echo "0")
    OECD_NOGO=$(psql -h localhost -U osa_user -d osa_db -tAq \
        -c "SELECT COUNT(*) FROM collect.source_registry
            WHERE source_id = 'OECD' AND status = 'NO_GO'" 2>/dev/null || echo "0")
    UNCTAD_GO=$(psql -h localhost -U osa_user -d osa_db -tAq \
        -c "SELECT COUNT(*) FROM collect.source_registry
            WHERE source_id = 'UNCTAD' AND status = 'GO'" 2>/dev/null || echo "0")
    MIL_CYB_OK=$(psql -h localhost -U osa_user -d osa_db -tAq \
        -c "SELECT COUNT(*) FROM collect.source_registry_indicators
            WHERE source_id = 'ITU' AND osa_code = 'MIL_CYB'" 2>/dev/null || echo "0")

    if [ "$IND_COUNT" = "121" ] && [ "$BLOCS_COUNT" = "167" ] \
       && [ "$PROV_COUNT" = "2" ] && [ "$REGISTRY_COUNT" = "18" ] \
       && [ "$MATRIX_OK" = "1" ] && [ "$QUALITY_OK" = "1" ] \
       && [ "$OECD_NOGO" = "1" ] && [ "$UNCTAD_GO" = "1" ] \
       && [ "$MIL_CYB_OK" = "1" ]; then
        info "========================================================"
        info "Base déjà déployée et à jour !"
        info "  Indicateurs       : $IND_COUNT (attendu 121)"
        info "  Blocs pays        : $BLOCS_COUNT (attendu 167)"
        info "  Source registry   : $REGISTRY_COUNT (attendu 18)"
        info "  Fonction matrice  : OK (5 paramètres)"
        info "  Qualité score     : OK"
        info "  OECD              : NO_GO"
        info "  UNCTAD            : GO"
        info "  MIL_CYB (ITU)     : OK"
        info "Rien à faire — vous pouvez travailler directement."
        info "========================================================"
        exit 0
    else
        warning "Base présente mais incomplète — application des patches..."
        warning "  source_registry   : $REGISTRY_COUNT / 17"
        warning "  fonction matrice  : $MATRIX_OK (attendu 1)"
        warning "  qualité score     : $QUALITY_OK (attendu 1)"
        warning "  OECD NO_GO        : $OECD_NOGO (attendu 1)"
        warning "  UNCTAD GO         : $UNCTAD_GO (attendu 1)"
        warning "  MIL_CYB ITU       : $MIL_CYB_OK (attendu 1)"
    fi
fi

# ── 2. Déploiement des schémas ────────────────────────────
info "Déploiement des 4 schémas SQL..."

psql -h localhost -U osa_user -d osa_db \
    -f "$PROJET/db/01_rf_schema.sql" -q && info "  01_rf OK"
psql -h localhost -U osa_user -d osa_db \
    -f "$PROJET/db/02_mm_schema.sql" -q && info "  02_mm OK"
psql -h localhost -U osa_user -d osa_db \
    -f "$PROJET/db/03_collect_schema.sql" -q && info "  03_collect OK"
psql -h localhost -U osa_user -d osa_db \
    -f "$PROJET/db/04_ma_schema.sql" -q && info "  04_ma OK"

# ── 3. Application des patches ────────────────────────────
info "Application des patches..."

psql -h localhost -U osa_user -d osa_db \
    -f "$PROJET/db/patch_eco_une.sql" -q && info "  patch_eco_une OK"
psql -h localhost -U osa_user -d osa_db \
    -f "$PROJET/db/patch_proxies_sprint3.sql" -q && info "  patch_proxies OK"
psql -h localhost -U osa_user -d osa_db \
    -f "$PROJET/db/patch_country_blocs.sql" -q && info "  patch_country_blocs OK"
psql -h localhost -U osa_user -d osa_db \
    -f "$PROJET/db/patch_blocs_sahel.sql" -q && info "  patch_blocs_sahel OK"
psql -h localhost -U osa_user -d osa_db \
    -f "$PROJET/db/patch_indicator_bounds.sql" -q && info "  patch_indicator_bounds OK"
psql -h localhost -U osa_user -d osa_db \
    -f "$PROJET/db/patch_central_banks.sql" -q && info "  patch_central_banks OK"
psql -h localhost -U osa_user -d osa_db \
    -f "$PROJET/db/patch_monetary_zone_history.sql" -q && info "  patch_monetary_zone_history OK"
psql -h localhost -U osa_user -d osa_db \
    -f "$PROJET/db/patch_providers_sprint4.sql" -q && info "  patch_providers_sprint4 OK"
psql -h localhost -U osa_user -d osa_db \
    -f "$PROJET/db/patch_quality_checks.sql" -q && info "  patch_quality_checks OK"
psql -h localhost -U osa_user -d osa_db \
    -f "$PROJET/db/patch_source_matrix_registry.sql" -q && info "  patch_source_matrix_registry OK"
psql -h localhost -U osa_user -d osa_db \
    -f "$PROJET/db/patch_source_matrix_supported_ids.sql" -q && info "  patch_source_matrix_supported_ids OK"
psql -h localhost -U osa_user -d osa_db \
    -f "$PROJET/db/patch_source_registry_missing_providers.sql" -q && info "  patch_source_registry_missing_providers OK"
psql -h localhost -U osa_user -d osa_db \
    -f "$PROJET/db/patch_oecd_nogo.sql" -q && info "  patch_oecd_nogo OK"
psql -h localhost -U osa_user -d osa_db \
    -f "$PROJET/db/patch_missing_core_providers.sql" -q && info "  patch_missing_core_providers OK"
psql -h localhost -U osa_user -d osa_db \
    -f "$PROJET/db/patch_comtrade_unctad_providers.sql" -q && info "  patch_comtrade_unctad_providers OK"
psql -h localhost -U osa_user -d osa_db \
    -f "$PROJET/db/patch_unpk_milcyb_providers.sql" -q && info "  patch_unpk_milcyb_providers OK"

# ── 4. Vérifications finales ──────────────────────────────
info "Vérifications..."

check() {
    local label="$1" query="$2" expected="$3"
    local result
    result=$(psql -h localhost -U osa_user -d osa_db -tAq -c "$query" 2>/dev/null || echo "ERR")
    if [ "$result" = "$expected" ]; then
        info "  ✓ $label : $result"
    else
        warning "  ✗ $label : attendu=$expected, obtenu=$result"
    fi
}

check "rf.indicators"     "SELECT COUNT(*) FROM rf.indicators"       "121"
check "rf.countries"      "SELECT COUNT(*) FROM rf.countries"        "54"
check "rf.pillars"        "SELECT COUNT(*) FROM rf.pillars"          "8"
check "rf.regional_blocs" "SELECT COUNT(*) FROM rf.regional_blocs"   "11"
check "rf.country_blocs"  "SELECT COUNT(*) FROM rf.country_blocs"    "167"
check "MON_AUT désactivé" \
    "SELECT is_active::text FROM rf.indicator_meta_link
     WHERE indicator_code='MON_AUT' LIMIT 1" "false"
check "Poids PECO" \
    "SELECT SUM(weight)::text FROM rf.indicator_meta_link
     WHERE meta_code='SOV_PECO'" "1.00000000"
check "source_registry 17 providers" \
    "SELECT COUNT(*) FROM collect.source_registry
     WHERE source_id IN (
         'WB','IMF','IMF_WEO','IMF_DOTS','IMF_BOP',
         'WHO','ITU','FAO','UNDP','UNESCO',
         'EITI','SIPRI','USGS','ACLED',
         'COMTRADE','UNCTAD','UNPK'
     )" "17"
check "source_registry GO (13)" \
    "SELECT COUNT(*) FROM collect.source_registry
     WHERE status = 'GO' AND source_id IN (
         'WB','IMF','IMF_WEO','IMF_DOTS','IMF_BOP',
         'WHO','ITU','FAO','UNDP','UNESCO',
         'EITI','SIPRI','UNCTAD'
     )" "13"
check "compute_quality_score" \
    "SELECT COUNT(*) FROM pg_proc p
     JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'collect' AND p.proname = 'compute_quality_score'" "1"
check "run_ingestion_from_matrix (5 params)" \
    "SELECT COUNT(*) FROM pg_proc p
     JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'collect'
       AND p.proname = 'run_ingestion_from_matrix'
       AND p.pronargs = 5" "1"
check "v_unsupported_providers vide" \
    "SELECT COUNT(*) FROM collect.v_unsupported_providers
     WHERE in_registry = false" "0"
check "OECD NO_GO" \
    "SELECT status FROM collect.source_registry
     WHERE source_id = 'OECD'" "NO_GO"
check "UNCTAD GO" \
    "SELECT status FROM collect.source_registry
     WHERE source_id = 'UNCTAD'" "GO"
check "COMTRADE PILOT" \
    "SELECT status FROM collect.source_registry
     WHERE source_id = 'COMTRADE'" "PILOT"
check "UNPK PILOT" \
    "SELECT status FROM collect.source_registry
     WHERE source_id = 'UNPK'" "PILOT"
check "MIL_CYB dans ITU" \
    "SELECT COUNT(*) FROM collect.source_registry_indicators
     WHERE source_id = 'ITU' AND osa_code = 'MIL_CYB'" "1"
check "MIL_MIS + GEO_PEA dans UNPK" \
    "SELECT COUNT(*) FROM collect.source_registry_indicators
     WHERE source_id = 'UNPK'
       AND osa_code IN ('MIL_MIS','GEO_PEA')" "2"

# ── 5. Alias utiles ───────────────────────────────────────
if ! grep -q "# OSA aliases" ~/.bashrc 2>/dev/null; then
    cat >> ~/.bashrc << EOF

# OSA aliases
alias psql-osa='psql -h localhost -U osa_user -d osa_db'
alias osa-check='psql -h localhost -U osa_user -d osa_db -c "SELECT pillar_code, COUNT(*) FROM rf.indicators GROUP BY pillar_code ORDER BY pillar_code;"'
alias osa-coverage='cd $PROJET/collectors && python3 run_collect_all.py --coverage-only'
alias osa-registry='psql -h localhost -U osa_user -d osa_db -c "SELECT source_id, status, priority FROM collect.source_registry ORDER BY priority, source_id;"'
alias osa-plan='cd $PROJET/collectors && python3 run_ingestion_from_matrix.py --print-plan'
EOF
    source ~/.bashrc 2>/dev/null || true
    info "Alias OSA ajoutés"
fi

# ── Résumé ────────────────────────────────────────────────
info "========================================================"
info "Redémarrage terminé. Commandes disponibles :"
info ""
info "  psql-osa       — connexion PostgreSQL"
info "  osa-check      — indicateurs par pilier"
info "  osa-coverage   — couverture des données"
info "  osa-registry   — état des providers (GO/PILOT/NO_GO)"
info "  osa-plan       — plan d'exécution matrice"
info ""
info "Collecte échantillon (10 pays) :"
info "  cd collectors"
info "  python3 run_collect_all.py --from 2010 --to 2023 --sample --dry-run"
info ""
info "Ingestion par matrice :"
info "  cd collectors"
info "  python3 run_ingestion_from_matrix.py --print-plan"
info "  python3 run_ingestion_from_matrix.py --from 2010 --to 2024"
info ""
info "UNCTAD (CSV requis dans data/unctad/FDI_flows.csv) :"
info "  python3 collectors/fetcher_unctad_csv.py --file data/unctad/FDI_flows.csv --dry-run"
info ""
info "COMTRADE (API publique — utiliser --sample pour tester) :"
info "  python3 collectors/fetcher_comtrade_api.py --from 2020 --to 2022 --sample --dry-run"
info ""
info "UNPK (CSV requis dans data/unpk/Country_Level_data.csv) :"
info "  python3 collectors/fetcher_unpk_csv.py --file data/unpk/Country_Level_data.csv --dry-run"
info "========================================================"