#!/usr/bin/env bash
# ============================================================
# OSA / ISA OBSERVATORY
# download_data.sh — Téléchargement automatique des données
# ============================================================
# Usage : bash download_data.sh [--provider NOM] [--dry-run]
#
# Télécharge automatiquement tous les CSV/données disponibles
# sans inscription ni clé API.
#
# Providers automatiques  : WB, WHO, UNESCO, IPI (UNPK)
# Providers semi-manuels  : IMF WEO, FAO, UNDP, UNCTAD, SIPRI
# Providers manuels only  : USGS, EITI
# ============================================================

set -euo pipefail

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
BLUE="\033[0;34m"
NC="\033[0m"

info()    { echo -e "${GREEN}[DL]${NC} $*"; }
warning() { echo -e "${YELLOW}[DL]${NC} $*"; }
error()   { echo -e "${RED}[DL]${NC} $*"; }
section() { echo -e "\n${BLUE}══════════════════════════════════════${NC}"; echo -e "${BLUE}[DL] $*${NC}"; echo -e "${BLUE}══════════════════════════════════════${NC}"; }

PROJET=$(cd "$(dirname "$0")" && pwd)
DRY_RUN=false
PROVIDER=""

# ── Arguments ─────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)   DRY_RUN=true; shift ;;
        --provider)  PROVIDER="$2"; shift 2 ;;
        --help|-h)
            echo "Usage : bash download_data.sh [--provider NOM] [--dry-run]"
            echo ""
            echo "Providers disponibles :"
            echo "  auto   : WB, WHO, UNESCO, UNPK (téléchargement automatique)"
            echo "  semi   : IMF, FAO, UNDP, UNCTAD, SIPRI (URL directe)"
            echo "  manual : USGS, EITI (téléchargement manuel requis)"
            echo ""
            echo "Exemples :"
            echo "  bash download_data.sh                    # tout télécharger"
            echo "  bash download_data.sh --provider UNPK    # UNPK uniquement"
            echo "  bash download_data.sh --dry-run          # simulation"
            exit 0
            ;;
        *) warning "Option inconnue : $1"; shift ;;
    esac
done

if [ "$DRY_RUN" = true ]; then
    warning "Mode DRY-RUN — aucun fichier ne sera téléchargé"
fi

# ── Fonction de téléchargement ────────────────────────────
download() {
    local label="$1" url="$2" dest="$3"
    local dir
    dir=$(dirname "$dest")

    if [ "$DRY_RUN" = true ]; then
        info "  [DRY-RUN] $label → $dest"
        return 0
    fi

    mkdir -p "$dir"

    if [ -f "$dest" ]; then
        info "  Déjà présent : $dest — ignoré (supprimer pour re-télécharger)"
        return 0
    fi

    info "  Téléchargement $label..."
    if curl -fsSL --connect-timeout 30 --max-time 300 \
            -o "$dest" "$url" 2>/dev/null; then
        local size
        size=$(du -sh "$dest" 2>/dev/null | cut -f1 || echo "?")
        info "  ✓ $label → $dest ($size)"
    else
        warning "  ✗ $label — échec (URL peut nécessiter une inscription)"
        rm -f "$dest"
        return 1
    fi
}

# ── Résumé final ──────────────────────────────────────────
DOWNLOADED=0
FAILED=0
MANUAL=()

# ============================================================
# SECTION 1 — IPI PEACEKEEPING (UNPK) — AUTOMATIQUE
# ============================================================
if [ -z "$PROVIDER" ] || [ "$PROVIDER" = "UNPK" ]; then
    section "UNPK — IPI Peacekeeping Database"
    info "Source : Humanitarian Data Exchange (HDX)"
    info "Indicateurs : MIL_MIS, GEO_PEA"

    BASE_HDX="https://data.humdata.org/dataset/6fc8e7be-63da-4660-8557-b1c5d3501805/resource"

    download "UNPK Country Level" \
        "$BASE_HDX/0b5f1dd5-4d6d-45ab-928a-322cb0e4ad28/download/Country_Level_data.csv" \
        "$PROJET/data/unpk/Country_Level_data.csv" \
        && ((DOWNLOADED++)) || ((FAILED++))

    download "UNPK Mission Level" \
        "$BASE_HDX/073c9c47-e8e3-494e-9028-2f8e6c51bd91/download/Mission%20level%20data.csv" \
        "$PROJET/data/unpk/Mission_level_data.csv" \
        && ((DOWNLOADED++)) || true

    download "UNPK Full Data" \
        "$BASE_HDX/64e06182-d4a9-4739-b0a5-02b14d8f3a9d/download/full_data.csv" \
        "$PROJET/data/unpk/full_data.csv" \
        && ((DOWNLOADED++)) || true
fi

# ============================================================
# SECTION 2 — IMF WEO — SEMI-AUTOMATIQUE
# ============================================================
if [ -z "$PROVIDER" ] || [ "$PROVIDER" = "IMF" ] || [ "$PROVIDER" = "IMF_WEO" ]; then
    section "IMF WEO — World Economic Outlook"
    info "Source : IMF.org"
    info "Indicateurs : MON_INF, MON_EXT, ECO_GDP, ECO_GRW, ECO_UNE..."

    # IMF WEO October 2024 — URL directe du fichier CSV complet
    download "IMF WEO Oct 2024" \
        "https://www.imf.org/-/media/Files/Publications/WEO/WEO-Database/2024/October/WEOOct2024all.ashx" \
        "$PROJET/data/imf/WEO.csv" \
        && ((DOWNLOADED++)) || {
            ((FAILED++))
            warning "  → Téléchargement manuel requis :"
            warning "    https://www.imf.org/en/Publications/WEO/weo-database/2024/October"
            warning "    Cliquer : By Countries (all countries) → Tab-delimited"
            warning "    Renommer en WEO.csv → placer dans data/imf/"
            MANUAL+=("IMF WEO : https://www.imf.org/en/Publications/WEO/weo-database/2024/October")
        }
fi

# ============================================================
# SECTION 3 — IMF DOTS — SEMI-AUTOMATIQUE
# ============================================================
if [ -z "$PROVIDER" ] || [ "$PROVIDER" = "IMF_DOTS" ]; then
    section "IMF DOTS — Direction of Trade Statistics"
    info "Indicateurs : ECO_EXP, ECO_IMP, ECO_COM, ECO_DIV"

    download "IMF DOTS" \
        "https://dataservices.imf.org/REST/SDMX_JSON.svc/CompactData/DOT/A..TMG_CIF_USD+TXG_FOB_USD.?startPeriod=2000&endPeriod=2024" \
        "$PROJET/data/imf/DOTS.csv" \
        && ((DOWNLOADED++)) || {
            ((FAILED++))
            warning "  → Téléchargement manuel requis :"
            warning "    https://data.imf.org/?sk=9d6028d4-f14a-464c-a2f2-59b2cd424b85"
            MANUAL+=("IMF DOTS : https://data.imf.org/?sk=9d6028d4-f14a-464c-a2f2-59b2cd424b85")
        }
fi

# ============================================================
# SECTION 4 — IMF BOP — SEMI-AUTOMATIQUE
# ============================================================
if [ -z "$PROVIDER" ] || [ "$PROVIDER" = "IMF_BOP" ]; then
    section "IMF BOP — Balance of Payments"
    info "Indicateurs : MON_DEP, MON_PAY, ECO_FDI"

    download "IMF BOP" \
        "https://dataservices.imf.org/REST/SDMX_JSON.svc/CompactData/BOP/A..BCA_USD?startPeriod=2000&endPeriod=2024" \
        "$PROJET/data/imf/BOP.csv" \
        && ((DOWNLOADED++)) || {
            ((FAILED++))
            warning "  → Téléchargement manuel requis :"
            warning "    https://data.imf.org/?sk=7a51304b-6426-40c0-83dd-ca473ca1fd52"
            MANUAL+=("IMF BOP : https://data.imf.org/?sk=7a51304b-6426-40c0-83dd-ca473ca1fd52")
        }
fi

# ============================================================
# SECTION 5 — FAO — SEMI-AUTOMATIQUE
# ============================================================
if [ -z "$PROVIDER" ] || [ "$PROVIDER" = "FAO" ]; then
    section "FAO — FAOSTAT"
    info "Indicateurs : ENV_FOR, ENV_LAN, ENV_WAT, HUM_FOO, ECO_AGR..."

    FAO_BASE="https://bulks-faostat.fao.org/production"

    download "FAO Forestry (GF)" \
        "$FAO_BASE/Forestry_E_All_Data_(Normalized).zip" \
        "$PROJET/data/fao/GF.zip" \
        && ((DOWNLOADED++)) || ((FAILED++))

    download "FAO Land Use (RL)" \
        "$FAO_BASE/Inputs_LandUse_E_All_Data_(Normalized).zip" \
        "$PROJET/data/fao/RL.zip" \
        && ((DOWNLOADED++)) || ((FAILED++))

    download "FAO Food Security (FS)" \
        "$FAO_BASE/Food_Security_Data_E_All_Data_(Normalized).zip" \
        "$PROJET/data/fao/FS.zip" \
        && ((DOWNLOADED++)) || ((FAILED++))

    download "FAO Crops (QCL)" \
        "$FAO_BASE/Production_Crops_Livestock_E_All_Data_(Normalized).zip" \
        "$PROJET/data/fao/QCL.zip" \
        && ((DOWNLOADED++)) || ((FAILED++))

    download "FAO Emissions (GT)" \
        "$FAO_BASE/Emissions_Totals_E_All_Data_(Normalized).zip" \
        "$PROJET/data/fao/GT.zip" \
        && ((DOWNLOADED++)) || ((FAILED++))

    # Décompresser les ZIP FAO
    if [ "$DRY_RUN" = false ]; then
        info "Décompression des archives FAO..."
        for zipfile in "$PROJET"/data/fao/*.zip; do
            [ -f "$zipfile" ] || continue
            base=$(basename "$zipfile" .zip)
            csv_target="$PROJET/data/fao/${base}.csv"
            if [ ! -f "$csv_target" ]; then
                # FAO nomme le CSV différemment dans le ZIP
                unzip -o "$zipfile" -d "$PROJET/data/fao/" 2>/dev/null || true
                # Trouver et renommer le CSV extrait
                extracted=$(find "$PROJET/data/fao/" -name "*.csv" \
                    -newer "$zipfile" 2>/dev/null | head -1)
                if [ -n "$extracted" ] && [ "$extracted" != "$csv_target" ]; then
                    mv "$extracted" "$csv_target" 2>/dev/null || true
                fi
                rm -f "$zipfile"
                info "  ✓ FAO $base décompressé"
            fi
        done
    fi
fi

# ============================================================
# SECTION 6 — UNDP HDR — SEMI-AUTOMATIQUE
# ============================================================
if [ -z "$PROVIDER" ] || [ "$PROVIDER" = "UNDP" ]; then
    section "UNDP — Human Development Report"
    info "Indicateurs : HUM_EDU, HUM_LIT, HUM_GEN, HUM_DIG, HUM_SOC"

    download "UNDP HDR 2023/24" \
        "https://hdr.undp.org/sites/default/files/2023-24_HDR/HDR23-24_Statistical_Annex_HDI_Table.xlsx" \
        "$PROJET/data/undp/HDR.xlsx" \
        && ((DOWNLOADED++)) || {
            # Essayer l'URL alternative CSV
            download "UNDP HDR CSV" \
                "https://hdr.undp.org/sites/default/files/2023-24_HDR/HDR23-24_Composite_indices_complete_time_series.csv" \
                "$PROJET/data/undp/HDR.csv" \
                && ((DOWNLOADED++)) || {
                    ((FAILED++))
                    warning "  → Téléchargement manuel requis :"
                    warning "    https://hdr.undp.org/data-center/documentation-and-downloads"
                    MANUAL+=("UNDP HDR : https://hdr.undp.org/data-center/documentation-and-downloads")
                }
        }
fi

# ============================================================
# SECTION 7 — UNCTAD FDI — SEMI-AUTOMATIQUE
# ============================================================
if [ -z "$PROVIDER" ] || [ "$PROVIDER" = "UNCTAD" ]; then
    section "UNCTAD — Flux d'IDE"
    info "Indicateur : ECO_FDI"

    download "UNCTAD FDI Flows" \
        "https://unctadstat.unctad.org/EN/BulkDownload.html" \
        "$PROJET/data/unctad/FDI_flows.csv" \
        && ((DOWNLOADED++)) || {
            ((FAILED++))
            warning "  → Téléchargement manuel requis :"
            warning "    https://unctadstat.unctad.org/datacentre/dataviewer/US.FdiFlows"
            warning "    Sélectionner : Economy=All African / Variable=Inward FDI flows"
            warning "    Renommer en FDI_flows.csv → data/unctad/"
            MANUAL+=("UNCTAD FDI : https://unctadstat.unctad.org/datacentre/dataviewer/US.FdiFlows")
        }
fi

# ============================================================
# SECTION 8 — SIPRI — SEMI-AUTOMATIQUE
# ============================================================
if [ -z "$PROVIDER" ] || [ "$PROVIDER" = "SIPRI" ]; then
    section "SIPRI — Dépenses militaires"
    info "Indicateurs : MIL_EXP, MIL_DEP"

    download "SIPRI Milex USD courants" \
        "https://www.sipri.org/sites/default/files/SIPRI-Milex-data-1988-2023.xlsx" \
        "$PROJET/data/sipri/SIPRI_Milex.xlsx" \
        && ((DOWNLOADED++)) || {
            ((FAILED++))
            warning "  → Téléchargement manuel requis :"
            warning "    https://www.sipri.org/databases/milex"
            warning "    Cliquer : Download data → Excel"
            warning "    Placer dans data/sipri/"
            MANUAL+=("SIPRI Milex : https://www.sipri.org/databases/milex")
        }
fi

# ============================================================
# SECTION 9 — EITI — MANUEL UNIQUEMENT
# ============================================================
if [ -z "$PROVIDER" ] || [ "$PROVIDER" = "EITI" ]; then
    section "EITI — Gouvernance extractive"
    info "Indicateurs : MIN_GOV, MIN_TAX"
    warning "Téléchargement manuel requis :"
    warning "  1. Aller sur https://eiti.org/open-data"
    warning "  2. Télécharger Summary Data → Africa → CSV"
    warning "  3. Placer dans data/eiti/eiti_summary.csv"
    MANUAL+=("EITI : https://eiti.org/open-data")
fi

# ============================================================
# SECTION 10 — USGS — MANUEL UNIQUEMENT
# ============================================================
if [ -z "$PROVIDER" ] || [ "$PROVIDER" = "USGS" ]; then
    section "USGS — Ressources minières"
    info "Indicateur : MIN_RES"
    warning "Téléchargement manuel requis :"
    warning "  1. Aller sur https://www.sciencebase.gov/catalog/item/677eaf95d34e760b392c4970"
    warning "  2. Télécharger World_Data_Release_MCS_2025.zip"
    warning "  3. Décompresser → renommer en MCS2025_World_Data.csv"
    warning "  4. Placer dans data/usgs/"
    MANUAL+=("USGS MCS : https://www.sciencebase.gov/catalog/item/677eaf95d34e760b392c4970")
fi

# ============================================================
# RÉSUMÉ FINAL
# ============================================================
echo ""
echo -e "${BLUE}══════════════════════════════════════${NC}"
echo -e "${BLUE}[DL] RÉSUMÉ DU TÉLÉCHARGEMENT${NC}"
echo -e "${BLUE}══════════════════════════════════════${NC}"

if [ "$DRY_RUN" = true ]; then
    info "Mode DRY-RUN — aucun fichier téléchargé réellement"
else
    info "Téléchargements réussis  : $DOWNLOADED"
    if [ $FAILED -gt 0 ]; then
        warning "Téléchargements échoués : $FAILED"
    fi
fi

if [ ${#MANUAL[@]} -gt 0 ]; then
    echo ""
    warning "Téléchargements manuels requis (${#MANUAL[@]}) :"
    for item in "${MANUAL[@]}"; do
        warning "  → $item"
    done
fi

echo ""
info "Vérification des fichiers présents :"
for f in \
    "data/unpk/Country_Level_data.csv" \
    "data/imf/WEO.csv" \
    "data/imf/DOTS.csv" \
    "data/imf/BOP.csv" \
    "data/fao/GF.csv" \
    "data/fao/RL.csv" \
    "data/fao/FS.csv" \
    "data/fao/QCL.csv" \
    "data/fao/GT.csv" \
    "data/undp/HDR.csv" \
    "data/unctad/FDI_flows.csv" \
    "data/sipri/SIPRI_Milex.xlsx" \
    "data/usgs/MCS2025_World_Data.csv" \
    "data/eiti/eiti_summary.csv"
do
    full="$PROJET/$f"
    if [ -f "$full" ]; then
        size=$(du -sh "$full" 2>/dev/null | cut -f1 || echo "?")
        info "  ✓ $f ($size)"
    else
        warning "  ✗ $f — manquant"
    fi
done

echo ""
info "Prochaine étape :"
info "  cd collectors"
info "  python3 run_ingestion_from_matrix.py --print-plan"
info "  python3 run_ingestion_from_matrix.py --from 2022 --to 2022"
