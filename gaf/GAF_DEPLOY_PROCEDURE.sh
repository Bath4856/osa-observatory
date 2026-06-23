# OSA ISA – Sprint 24 GAF
# Procédure de déploiement sur VPS
# Rédigée le 2026-06-17
# ============================================================
#
# Prérequis :
#   - Fichier gaf_sprint24_v2.zip téléchargé localement
#   - Clé SSH : G:\ssh-keys\osa-observatory-key.pem
#   - VPS    : ubuntu@179.237.69.94
#   - Repo   : /mnt/data/osa-app/osa-observatory/
#
# Durée estimée : 10-15 minutes
# ============================================================


# ════════════════════════════════════════════════════════════
# ÉTAPE 1 — TRANSFERT DU ZIP (PowerShell Windows)
# ════════════════════════════════════════════════════════════

# Depuis G:\osa-observatory en PowerShell :

scp -i G:\ssh-keys\osa-observatory-key.pem `
    G:\osa-observatory\gaf_sprint24_v2.zip `
    ubuntu@179.237.69.94:/home/ubuntu/

# Attendu : "gaf_sprint24_v2.zip  100%  28KB ..."


# ════════════════════════════════════════════════════════════
# ÉTAPE 2 — CONNEXION AU VPS
# ════════════════════════════════════════════════════════════

ssh -i G:\ssh-keys\osa-observatory-key.pem ubuntu@179.237.69.94


# ════════════════════════════════════════════════════════════
# ÉTAPE 3 — EXTRACTION DU ZIP (sur le VPS)
# ════════════════════════════════════════════════════════════

# 3.1 Aller dans le repo OSA
cd /mnt/data/osa-app/osa-observatory

# 3.2 Extraire le dossier gaf/ à la racine du repo
#     Le zip contient gaf_v2/ → on extrait puis renomme
unzip -o ~/gaf_sprint24_v2.zip -d /home/ubuntu/gaf_tmp

# 3.3 Copier le contenu de gaf_v2/ → gaf/
mkdir -p gaf
cp -r /home/ubuntu/gaf_tmp/gaf_v2/* gaf/

# 3.4 Copier ops_run_audit.py → ops/run_audit.py
#     (sauvegarde de l'ancien d'abord)
cp ops/run_audit.py ops/run_audit.py.bak
cp /home/ubuntu/gaf_tmp/gaf_v2/ops_run_audit.py ops/run_audit.py

# 3.5 Nettoyer
rm -rf /home/ubuntu/gaf_tmp

# 3.6 Vérifier la structure
ls gaf/
ls gaf/core/
ls gaf/sql/
ls gaf/tests/


# ════════════════════════════════════════════════════════════
# ÉTAPE 4 — MIGRATION BASE DE DONNÉES
# ════════════════════════════════════════════════════════════

# Variables de connexion
DB_HOST=172.18.0.3
DB_PORT=5432
DB_NAME=osa_db
DB_USER=postgres

# 4.1 Script 001 : créer les 4 tables + vues + triggers
PGPASSWORD=Il1tRBwubTkPd8jd psql \
    -h $DB_HOST -p $DB_PORT \
    -U $DB_USER -d $DB_NAME \
    -f gaf/sql/001_create_gaf_tables.sql

# Attendu en fin de sortie :
#   tablename               | size
#   audit_corrections       | 8192 bytes
#   audit_decisions         | 8192 bytes
#   audit_findings          | 8192 bytes
#   audit_recommendations   | 8192 bytes

# 4.2 Script 002 : seed des 12 règles d'orientation
PGPASSWORD=Il1tRBwubTkPd8jd psql \
    -h $DB_HOST -p $DB_PORT \
    -U $DB_USER -d $DB_NAME \
    -f gaf/sql/002_seed_rules.sql

# Attendu en fin de sortie : 12 lignes avec rule_code, severity, owner

# 4.3 Vérification rapide
PGPASSWORD=Il1tRBwubTkPd8jd psql \
    -h $DB_HOST -p $DB_PORT \
    -U $DB_USER -d $DB_NAME \
    -c "SELECT COUNT(*) AS regles FROM ops.gaf_orientation_rules;"

# Attendu : regles = 12


# ════════════════════════════════════════════════════════════
# ÉTAPE 5 — TESTS UNITAIRES
# ════════════════════════════════════════════════════════════

cd /mnt/data/osa-app/osa-observatory

python3 gaf/tests/test_orientation.py

# Attendu :
#   ══════════════════════════════════════════════════
#     OSA GAF – Tests unitaires orientation_engine
#   ══════════════════════════════════════════════════
#   ✓ R01_METHOD_VERSION_NULL
#   ✓ R02_DUPLICATE_VALUES
#   ✓ R03_WEIGHT_CONSISTENCY
#   ✓ R04_INDICATOR_NOT_LINKED
#   ✓ R05_ENDPOINT_MISSING
#   ✓ R06_ENDPOINT_TIMEOUT
#   ✓ R07_ENDPOINT_SLOW
#   ✓ R08_NULL_VALUES
#   ✓ R09_TRAJECTORY_INACTIVE
#   ✓ R10_SECURITY_SENSITIVE
#   ✓ R11_MISSING_COUNTRY
#   ✓ R12_NO_AUTH_TOKEN
#   ✓ UNCLASSIFIED (fallback)
#   ✓ orient_run_full — 5 findings orientés
#   ══════════════════════════════════════════════════
#     14/14 tests passés
#   ══════════════════════════════════════════════════

# Si un test échoue → STOP, ne pas continuer


# ════════════════════════════════════════════════════════════
# ÉTAPE 6 — TEST GAF À SEC (dry-run)
# ════════════════════════════════════════════════════════════

# Utilise le dernier rapport d'audit sans écrire en DB
python3 gaf/run_gaf.py --dry-run

# Attendu :
#   ════════════════════════════════════════════════════
#     OSA GAF – Résumé d'orientation
#   ════════════════════════════════════════════════════
#   Findings orientés : N
#   Par sévérité : {'CRITICAL': N, 'HIGH': N, ...}
#   ...
#   Mode --dry-run : persistance ignorée.

# Si le rapport est introuvable ou vide → vérifier :
#   ls -lt reports/audit_*.json | head -3


# ════════════════════════════════════════════════════════════
# ÉTAPE 7 — ACTIVATION LEDGER ET GAF DANS LA CONFIG
# ════════════════════════════════════════════════════════════

# Activer le ledger dans audit_config.yaml
sed -i 's/  enabled: false/  enabled: true/' \
    audit/config/audit_config.yaml

# Vérifier
grep -A3 'ledger:' audit/config/audit_config.yaml

# Ajouter la section gaf si absente
python3 << 'PYEOF'
path = "audit/config/audit_config.yaml"
with open(path) as f:
    src = f.read()

if "gaf:" not in src:
    src += """
# ====================================================
# GAF — Governance of Audit Findings
# ====================================================
gaf:
  enabled: false   # passer à true après validation du dry-run
"""
    with open(path, "w") as f:
        f.write(src)
    print("Section gaf ajoutée")
else:
    print("Section gaf déjà présente")
PYEOF


# ════════════════════════════════════════════════════════════
# ÉTAPE 8 — RUN GAF COMPLET SUR LE DERNIER RAPPORT
# ════════════════════════════════════════════════════════════

# Lancer le GAF sur le dernier rapport d'audit (avec persistance DB)
# Note : audit_id sera null si le ledger n'a pas encore été activé.
# Dans ce cas les findings sont orientés mais non persistés.
python3 gaf/run_gaf.py

# Attendu :
#   [INFO] Rapport chargé — audit_id=None | modules=21 | IPRS=89.24
#   [INFO] Orientation terminée — N findings | CRITICAL=2 | HIGH=2
#   [WARNING] audit_id absent — findings non persistés
#   (résumé d'orientation affiché)
#   → Normal à cette étape : audit_id sera disponible
#     après le premier run via ops/run_audit.py


# ════════════════════════════════════════════════════════════
# ÉTAPE 9 — PREMIER RUN COMPLET AVEC AUDIT_ID
# ════════════════════════════════════════════════════════════

# Le nouveau ops/run_audit.py intègre ledger + GAF
# Lancer via pre_audit_check pour respecter les gardes
bash ops/pre_audit_check.sh

# Attendu en fin d'exécution :
#   [INFO] Ledger persisté — audit_id=N
#   [INFO] GAF désactivé — lancer manuellement : python3 gaf/run_gaf.py
#   [INFO] Audit terminé | statut=READY_FOR_PUBLICATION | IPRS=89.xx

# Puis lancer le GAF sur ce rapport (qui contient maintenant audit_id)
python3 gaf/run_gaf.py

# Attendu :
#   [INFO] Rapport chargé — audit_id=N | modules=21
#   [INFO] GAF persisté — findings=N | recommandations=N
#   KPIs GAF cumulés :
#     Total findings      : N
#     CRITICAL ouverts    : 2
#     HIGH ouverts        : 2
#     Résolution rate     : 0.0%


# ════════════════════════════════════════════════════════════
# ÉTAPE 10 — VÉRIFICATION DB FINALE
# ════════════════════════════════════════════════════════════

PGPASSWORD=Il1tRBwubTkPd8jd psql \
    -h $DB_HOST -p $DB_PORT \
    -U $DB_USER -d $DB_NAME << 'SQL'

-- Findings persistés
SELECT module, finding_code, severity, status
FROM ops.audit_findings
ORDER BY
    CASE severity
        WHEN 'CRITICAL' THEN 1
        WHEN 'HIGH'     THEN 2
        WHEN 'MEDIUM'   THEN 3
        WHEN 'LOW'      THEN 4
        WHEN 'INFO'     THEN 5
    END;

-- Recommandations
SELECT f.finding_code, r.priority, r.owner, r.sprint_target
FROM ops.audit_findings f
JOIN ops.audit_recommendations r ON r.finding_id = f.finding_id
ORDER BY r.priority;

-- Findings ouverts (vue de travail)
SELECT finding_code, severity, owner, sprint_target
FROM ops.v_findings_open
LIMIT 10;

SQL


# ════════════════════════════════════════════════════════════
# ÉTAPE 11 — COMMIT GIT
# ════════════════════════════════════════════════════════════

cd /mnt/data/osa-app/osa-observatory

git add gaf/ ops/run_audit.py
git commit -m "Sprint 24 GAF : Governance of Audit Findings — déploiement initial"
git push origin main


# ════════════════════════════════════════════════════════════
# ROLLBACK (si nécessaire)
# ════════════════════════════════════════════════════════════

# Si la migration DB échoue ou produit des erreurs :
PGPASSWORD=Il1tRBwubTkPd8jd psql \
    -h $DB_HOST -p $DB_PORT \
    -U $DB_USER -d $DB_NAME \
    -f gaf/sql/003_rollback.sql

# Restaurer l'ancien run_audit.py :
cp ops/run_audit.py.bak ops/run_audit.py

# Supprimer le dossier gaf/ :
rm -rf gaf/


# ════════════════════════════════════════════════════════════
# RÉSUMÉ DES COMMANDES DANS L'ORDRE
# ════════════════════════════════════════════════════════════

# PowerShell :
# 1. scp gaf_sprint24_v2.zip → VPS

# VPS :
# 2.  cd /mnt/data/osa-app/osa-observatory
# 3.  unzip + cp gaf_v2/* → gaf/ + cp ops_run_audit.py → ops/run_audit.py
# 4.  psql -f gaf/sql/001_create_gaf_tables.sql
# 5.  psql -f gaf/sql/002_seed_rules.sql
# 6.  python3 gaf/tests/test_orientation.py          → 14/14 tests
# 7.  python3 gaf/run_gaf.py --dry-run               → orientation seule
# 8.  (activer ledger dans audit_config.yaml)
# 9.  bash ops/pre_audit_check.sh                    → audit + audit_id
# 10. python3 gaf/run_gaf.py                         → GAF complet
# 11. psql vérification findings en DB
# 12. git add gaf/ ops/run_audit.py && git commit && git push
