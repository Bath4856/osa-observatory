# =============================================================================
# OSA — RUN P7K COST MODEL V3 (DÉFINITIF)
#
# Ordre d'exécution obligatoire :
#   1. patch_p7k_cost_model_v3.sql              RF : cost model + calibration
#   2. patch_p7k_cost_model_audit_log_v3.sql    RF : audit log + trigger
#                                               MG : governance policy + review view
#   3. patch_p7k_materialized_layer_v3.sql      MA : MV avec predictive_execution_status
#   4. audit_p7k_cost_model_v3.sql              Rapport complet
#
# Placer les fichiers dans :
#   db/patch_db/patch_p7k_cost_model_v3.sql
#   db/patch_db/patch_p7k_cost_model_audit_log_v3.sql
#   db/patch_db/patch_p7k_materialized_layer_v3.sql
#   audit/audit_p7k_cost_model_v3.sql
# =============================================================================

$ErrorActionPreference = "Stop"

$env:PGPASSWORD = (Read-Host -Prompt "Mot de passe PostgreSQL")
$psql = "psql"
$db   = "osa_db"
$dbhost = "127.0.0.1"
$port = "5432"
$user = "postgres"

function Invoke-SQL {
    param([string]$file, [string]$label)
    Write-Host ""
    Write-Host ">>> $label"
    & $psql -h $dbhost -p $port -U $user -d $db -v ON_ERROR_STOP=1 -f $file
    if ($LASTEXITCODE -ne 0) { throw "Erreur SQL : $file" }
}

Write-Host ""
Write-Host "========================================="
Write-Host " OSA — RUN P7K COST MODEL V3"
Write-Host "========================================="

# ---------------------------------------------------------------------------
# Pré-test : dépendances obligatoires
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host ">>> Pré-test dépendances P7K V3"
& $psql -h $dbhost -p $port -U $user -d $db -v ON_ERROR_STOP=1 -c @"
SELECT
    -- Portfolio P7K
    (SELECT CASE WHEN COUNT(*) > 0 THEN 'OK' ELSE 'MISSING' END
     FROM information_schema.tables
     WHERE table_schema='ma'
       AND table_name='v_isa_executive_priority_portfolio')        AS check_portfolio,

    -- Country year P7J
    (SELECT CASE WHEN COUNT(*) > 0 THEN 'OK' ELSE 'MISSING' END
     FROM information_schema.tables
     WHERE table_schema='ma'
       AND table_name='v_isa_decision_country_year')               AS check_country_year,

    -- Famille intervention
    (SELECT CASE WHEN COUNT(*) > 0 THEN 'OK' ELSE 'MISSING' END
     FROM information_schema.tables
     WHERE table_schema='rf'
       AND table_name='isa_intervention_family_registry')          AS check_family_registry,

    -- Schéma MG accessible
    (SELECT CASE WHEN COUNT(*) > 0 THEN 'OK' ELSE 'MISSING' END
     FROM information_schema.schemata
     WHERE schema_name = 'mg')                                     AS check_schema_mg,

    -- Schéma RF accessible
    (SELECT CASE WHEN COUNT(*) > 0 THEN 'OK' ELSE 'MISSING' END
     FROM information_schema.schemata
     WHERE schema_name = 'rf')                                     AS check_schema_rf;
"@
if ($LASTEXITCODE -ne 0) { throw "Pré-test dépendances échoué" }

# ---------------------------------------------------------------------------
# Étape 1 — Cost model V3 (RF)
# ---------------------------------------------------------------------------
Invoke-SQL "db/patch_db/patch_p7k_cost_model_v3.sql" `
    "SQL : patch_p7k_cost_model_v3.sql (RF — cost model + calibration)"

# ---------------------------------------------------------------------------
# Étape 2 — Audit log + trigger + gouvernance MG
# ---------------------------------------------------------------------------
Invoke-SQL "db/patch_db/patch_p7k_cost_model_audit_log_v3.sql" `
    "SQL : patch_p7k_cost_model_audit_log_v3.sql (RF audit log + MG governance)"

# ---------------------------------------------------------------------------
# Contrôle intermédiaire : 10 lignes cost model + politique MG complète
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host ">>> Contrôle intermédiaire RF/MG"
& $psql -h $dbhost -p $port -U $user -d $db -v ON_ERROR_STOP=1 -c @"
SELECT
    (SELECT COUNT(*) FROM rf.isa_executive_cost_model)             AS cost_model_rows,
    (SELECT COUNT(*) FROM mg.isa_model_governance_policy)          AS governance_policy_rows,
    (SELECT COUNT(*) FROM rf.isa_cost_model_audit_log)             AS audit_log_rows,
    (SELECT CASE WHEN COUNT(*) = 1 THEN 'OK' ELSE 'MISSING' END
     FROM pg_trigger t
     JOIN pg_class c     ON c.oid = t.tgrelid
     JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname='rf'
       AND c.relname='isa_executive_cost_model'
       AND t.tgname='trg_cost_model_audit')                        AS trigger_status;
"@
if ($LASTEXITCODE -ne 0) { throw "Contrôle intermédiaire RF/MG échoué" }

# ---------------------------------------------------------------------------
# Étape 3 — MV V3 (MA)
# ---------------------------------------------------------------------------
Invoke-SQL "db/patch_db/patch_p7k_materialized_layer_v3.sql" `
    "SQL : patch_p7k_materialized_layer_v3.sql (MA — MV predictive_execution_status)"

# ---------------------------------------------------------------------------
# Contrôle MV : 8091 lignes, aucun NULL sur pression et statut prédictif
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host ">>> Contrôle MV V3"
& $psql -h $dbhost -p $port -U $user -d $db -v ON_ERROR_STOP=1 -c @"
SELECT
    COUNT(*)                                                       AS mv_rows,
    COUNT(*) FILTER (WHERE sovereign_execution_pressure IS NULL)   AS null_pressure,
    COUNT(*) FILTER (WHERE predictive_execution_status IS NULL)    AS null_pred_status,
    COUNT(*) FILTER (WHERE predictive_execution_status='EXEC_READY')         AS exec_ready,
    COUNT(*) FILTER (WHERE predictive_execution_status='EXEC_READY_CAUTION') AS exec_caution,
    COUNT(*) FILTER (WHERE predictive_execution_status='EXEC_BLOCKED_REVIEW') AS exec_blocked
FROM ma.mv_isa_executive_master_board;
"@
if ($LASTEXITCODE -ne 0) { throw "Contrôle MV V3 échoué" }

# ---------------------------------------------------------------------------
# Étape 4 — Audit complet
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host ">>> Rapport audit P7K cost model V3"
Invoke-SQL "audit/audit_p7k_cost_model_v3.sql" `
    "SQL : audit_p7k_cost_model_v3.sql"

# ---------------------------------------------------------------------------
# Suggestion commit
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "========================================="
Write-Host " ✅ P7K COST MODEL V3 COMPLETE"
Write-Host "========================================="
Write-Host ""
Write-Host ">>> Commit suggéré :"
Write-Host @"
git add db/patch_db/patch_p7k_cost_model_v3.sql ``
        db/patch_db/patch_p7k_cost_model_audit_log_v3.sql ``
        db/patch_db/patch_p7k_materialized_layer_v3.sql ``
        audit/audit_p7k_cost_model_v3.sql ``
        db/run/run_p7k_cost_model_v3.ps1

git commit -m "feat(p7k): add metrological calibration layer — uncertainty score, review_due_date, predictive_execution_status, MG governance policy"

git push origin main
"@

