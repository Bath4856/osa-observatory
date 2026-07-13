#!/bin/bash
# ============================================================
# create_founder.sh -- Pre-creation d'un affilie fondateur (cooptation)
# Usage :
#   ADMIN_PASSWORD='...' ./create_founder.sh \
#     "Prenom" "Nom" "email@example.com" \
#     COMMITTEE COMITE_TECH
#   ou
#   ADMIN_PASSWORD='...' ./create_founder.sh \
#     "Prenom" "Nom" "email@example.com" \
#     WORKING_GROUP PGEO
#
# Variables d'environnement :
#   API_BASE       (defaut: http://127.0.0.1:8001 -- preprod)
#   BASE_URL       (defaut: https://preprod.osa-observatory.africa)
#   ADMIN_EMAIL    (defaut: theophile.bakang@gmail.com)
#   ADMIN_PASSWORD (obligatoire, pas de valeur par defaut -- ne jamais
#                   l'ecrire en dur dans ce fichier)
#   TOKEN_DAYS     (defaut: 30)
#   SEND_EMAIL     (defaut: true -- envoi automatique via noreply@)
# ============================================================

set -e

FIRST_NAME="$1"
LAST_NAME="$2"
EMAIL="$3"
TARGET_TYPE="$4"   # COMMITTEE ou WORKING_GROUP
TARGET_VALUE="$5"  # ex. COMITE_TECH ou PGEO

if [ -z "$FIRST_NAME" ] || [ -z "$LAST_NAME" ] || [ -z "$EMAIL" ] || [ -z "$TARGET_TYPE" ] || [ -z "$TARGET_VALUE" ]; then
    echo "Usage: $0 \"Prenom\" \"Nom\" \"email\" COMMITTEE|WORKING_GROUP CODE"
    exit 1
fi

if [ -z "$ADMIN_PASSWORD" ]; then
    echo "Erreur : variable ADMIN_PASSWORD non definie."
    echo "Exemple : ADMIN_PASSWORD='...' $0 ..."
    exit 1
fi

API_BASE="${API_BASE:-http://127.0.0.1:8001}"
BASE_URL="${BASE_URL:-https://preprod.osa-observatory.africa}"
ADMIN_EMAIL="${ADMIN_EMAIL:-theophile.bakang@gmail.com}"
TOKEN_DAYS="${TOKEN_DAYS:-30}"
SEND_EMAIL="${SEND_EMAIL:-true}"

# Construire le JSON de la cible
if [ "$TARGET_TYPE" = "COMMITTEE" ]; then
    TARGET_JSON="{\"type\":\"COMMITTEE\",\"committee_code\":\"$TARGET_VALUE\"}"
elif [ "$TARGET_TYPE" = "WORKING_GROUP" ]; then
    TARGET_JSON="{\"type\":\"WORKING_GROUP\",\"pillar_code\":\"$TARGET_VALUE\"}"
else
    echo "Erreur : TARGET_TYPE doit etre COMMITTEE ou WORKING_GROUP."
    exit 1
fi

echo "→ Connexion admin..."
TOKEN=$(curl -s -X POST "$API_BASE/api/v2/affiliates/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('token',''))")

if [ -z "$TOKEN" ]; then
    echo "Erreur : connexion admin echouee."
    exit 1
fi

echo "→ Creation de l'affilie $FIRST_NAME $LAST_NAME ($EMAIL)..."
RESPONSE=$(curl -s -X POST "$API_BASE/api/v2/affiliates/admin/preaffiliate" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"first_name\": \"$FIRST_NAME\",
        \"last_name\": \"$LAST_NAME\",
        \"email\": \"$EMAIL\",
        \"target\": $TARGET_JSON,
        \"token_expiry_days\": $TOKEN_DAYS,
        \"base_url\": \"$BASE_URL\",
        \"send_email\": $SEND_EMAIL
    }")

echo "$RESPONSE" | python3 -m json.tool

echo ""
echo "→ Copie le bloc JSON ci-dessus et transmets-le pour generer le flyer personnalise."
