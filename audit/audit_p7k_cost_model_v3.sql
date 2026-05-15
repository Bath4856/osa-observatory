-- =============================================================================
-- OSA / ISA — AUDIT P7K COST MODEL V3 (DÉFINITIF)
-- Vérifie : cost model RF, gouvernance MG, MV v3, trigger, review_due
-- =============================================================================

\echo ''
\echo '========================================================'
\echo ' OSA / ISA — AUDIT P7K COST MODEL V3'
\echo '========================================================'

-- -----------------------------------------------------------------------------
-- 1. Cost model RF — couverture et calibration
-- -----------------------------------------------------------------------------
\echo ''
\echo '=== 1. Cost model RF — couverture complète ==='
SELECT
    pillar_code,
    intervention_family_code,
    ROUND(executive_cost_score,          3) AS cost,
    ROUND(execution_maturity_score,      3) AS maturity,
    ROUND(calibration_uncertainty_score, 3) AS uncertainty,
    calibration_status,
    calibration_method,
    calibration_review_due_date,
    calibration_version,
    LEFT(calibration_source, 55)            AS source_short
FROM rf.isa_executive_cost_model
ORDER BY pillar_code;

-- -----------------------------------------------------------------------------
-- 2. Gouvernance MG — politique par statut
-- -----------------------------------------------------------------------------
\echo ''
\echo '=== 2. Gouvernance MG — politique par statut ==='
SELECT
    calibration_status,
    usable_in_mv,
    eligible_predictive_execution,
    predictive_execution_value,
    uncertainty_threshold_max,
    review_trigger_months
FROM mg.isa_model_governance_policy
ORDER BY calibration_status;

-- -----------------------------------------------------------------------------
-- 3. Vue review_due — lignes en retard ou imminentes
-- -----------------------------------------------------------------------------
\echo ''
\echo '=== 3. Review due — statut des révisions ==='
SELECT
    intervention_family_code,
    pillar_code,
    calibration_status,
    ROUND(calibration_uncertainty_score, 3) AS uncertainty,
    calibration_review_due_date,
    days_overdue,
    review_status
FROM mg.v_cost_model_review_due
ORDER BY review_status, calibration_review_due_date;

-- -----------------------------------------------------------------------------
-- 4. MV v3 — volumétrie
-- -----------------------------------------------------------------------------
\echo ''
\echo '=== 4. MV v3 — volumétrie ==='
SELECT
    COUNT(*)                    AS mv_rows,
    COUNT(DISTINCT country_iso3) AS nb_countries,
    COUNT(DISTINCT year)         AS nb_years,
    COUNT(DISTINCT pillar_code)  AS nb_pillars
FROM ma.mv_isa_executive_master_board;

-- -----------------------------------------------------------------------------
-- 5. predictive_execution_status — distribution (anomalie corrigée ?)
-- -----------------------------------------------------------------------------
\echo ''
\echo '=== 5. predictive_execution_status — distribution ==='
SELECT
    predictive_execution_status,
    cost_model_coverage_flag,
    COUNT(*)                                           AS nb,
    ROUND(AVG(executive_priority_score),   3)          AS avg_priority,
    ROUND(AVG(execution_maturity_score),   3)          AS avg_maturity,
    ROUND(AVG(calibration_uncertainty_score), 3)       AS avg_uncertainty
FROM ma.mv_isa_executive_master_board
GROUP BY predictive_execution_status, cost_model_coverage_flag
ORDER BY predictive_execution_status, nb DESC;

-- -----------------------------------------------------------------------------
-- 6. executive_master_status — distribution avec pression souveraine
-- -----------------------------------------------------------------------------
\echo ''
\echo '=== 6. executive_master_status — distribution ==='
SELECT
    executive_master_status,
    COUNT(*)                                           AS nb,
    ROUND(AVG(sovereign_execution_pressure), 3)        AS avg_pressure,
    ROUND(AVG(executive_priority_score),     3)        AS avg_priority
FROM ma.mv_isa_executive_master_board
GROUP BY executive_master_status
ORDER BY avg_pressure DESC NULLS LAST;

-- -----------------------------------------------------------------------------
-- 7. Coverage cost model par pilier
-- -----------------------------------------------------------------------------
\echo ''
\echo '=== 7. Cost model coverage par pilier dans MV ==='
SELECT
    pillar_code,
    cost_model_coverage_flag,
    COUNT(*)                                           AS nb_rows,
    ROUND(AVG(executive_priority_score),   3)          AS avg_priority,
    ROUND(AVG(execution_maturity_score),   3)          AS avg_maturity,
    ROUND(AVG(calibration_uncertainty_score), 3)       AS avg_uncertainty
FROM ma.mv_isa_executive_master_board
GROUP BY pillar_code, cost_model_coverage_flag
ORDER BY pillar_code, cost_model_coverage_flag;

-- -----------------------------------------------------------------------------
-- 8. Top EXEC_READY_CAUTION — meilleurs candidats prédictifs
-- -----------------------------------------------------------------------------
\echo ''
\echo '=== 8. Top EXEC_READY_CAUTION — meilleurs candidats ==='
SELECT
    country_iso3,
    year,
    pillar_code,
    intervention_family_code,
    ROUND(executive_priority_score,        3) AS priority,
    ROUND(execution_maturity_score,        3) AS maturity,
    ROUND(sovereign_execution_pressure,    3) AS pressure,
    ROUND(calibration_uncertainty_score,   3) AS uncertainty,
    cost_calibration_status,
    predictive_execution_status
FROM ma.mv_isa_executive_master_board
WHERE predictive_execution_status IN ('EXEC_READY', 'EXEC_READY_CAUTION')
ORDER BY sovereign_execution_pressure DESC,
         executive_priority_score DESC
LIMIT 20;

-- -----------------------------------------------------------------------------
-- 9. review_due_flag dans MV — diagnostic
-- -----------------------------------------------------------------------------
\echo ''
\echo '=== 9. review_due_flag distribution dans MV ==='
SELECT
    review_due_flag,
    COUNT(*)                                AS nb,
    COUNT(DISTINCT pillar_code)             AS nb_pillars
FROM ma.mv_isa_executive_master_board
GROUP BY review_due_flag
ORDER BY review_due_flag;

-- -----------------------------------------------------------------------------
-- 10. Trigger installé ?
-- -----------------------------------------------------------------------------
\echo ''
\echo '=== 10. Trigger audit RF installé ? ==='
SELECT
    t.tgname                                AS trigger_name,
    n.nspname || '.' || c.relname           AS table_name,
    CASE t.tgenabled WHEN 'O' THEN 'ENABLED' ELSE 'DISABLED' END AS status
FROM pg_trigger t
JOIN pg_class     c ON c.oid = t.tgrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'rf'
  AND c.relname = 'isa_executive_cost_model'
  AND t.tgname  = 'trg_cost_model_audit';

-- -----------------------------------------------------------------------------
-- 11. Checks critiques — tous doivent retourner 0
-- -----------------------------------------------------------------------------
\echo ''
\echo '=== 11. Checks critiques (tous doivent être 0 ou OK) ==='
SELECT
    -- NULL sur sovereign_execution_pressure
    (SELECT COUNT(*) FROM ma.mv_isa_executive_master_board
     WHERE sovereign_execution_pressure IS NULL)
        AS null_pressure,

    -- NULL sur predictive_execution_status
    (SELECT COUNT(*) FROM ma.mv_isa_executive_master_board
     WHERE predictive_execution_status IS NULL)
        AS null_predictive_status,

    -- Scores hors bornes
    (SELECT COUNT(*) FROM ma.mv_isa_executive_master_board
     WHERE executive_priority_score    NOT BETWEEN 0 AND 1
        OR sovereign_execution_pressure NOT BETWEEN 0 AND 1)
        AS out_of_bounds_scores,

    -- Lignes sans calibration_status (cost model)
    (SELECT COUNT(*) FROM rf.isa_executive_cost_model
     WHERE calibration_status IS NULL
        OR calibration_uncertainty_score IS NULL
        OR calibration_review_due_date IS NULL)
        AS uncalibrated_rows,

    -- Lignes cost model sans review_due_date valide
    (SELECT COUNT(*) FROM rf.isa_executive_cost_model
     WHERE calibration_review_due_date <= calibration_date)
        AS invalid_review_due_date,

    -- Politique MG complète
    (SELECT CASE WHEN COUNT(*) = 3 THEN 'OK' ELSE 'INCOMPLETE' END
     FROM mg.isa_model_governance_policy)
        AS governance_policy_status,

    -- predictive_execution_status valeurs invalides
    (SELECT COUNT(*) FROM ma.mv_isa_executive_master_board
     WHERE predictive_execution_status NOT IN
        ('EXEC_READY','EXEC_READY_CAUTION','EXEC_BLOCKED_REVIEW'))
        AS invalid_predictive_values;

-- -----------------------------------------------------------------------------
-- 12. Statut final
-- -----------------------------------------------------------------------------
\echo ''
\echo '=== 12. Statut audit final ==='
SELECT
    CASE
        WHEN
            (SELECT COUNT(*) FROM ma.mv_isa_executive_master_board
             WHERE sovereign_execution_pressure IS NULL) = 0
        AND (SELECT COUNT(*) FROM ma.mv_isa_executive_master_board
             WHERE predictive_execution_status IS NULL) = 0
        AND (SELECT COUNT(*) FROM rf.isa_executive_cost_model
             WHERE calibration_status IS NULL
                OR calibration_uncertainty_score IS NULL
                OR calibration_review_due_date IS NULL) = 0
        AND (SELECT COUNT(*) FROM mg.isa_model_governance_policy) = 3
        AND (SELECT COUNT(*) FROM pg_trigger t
             JOIN pg_class c     ON c.oid = t.tgrelid
             JOIN pg_namespace n ON n.oid = c.relnamespace
             WHERE n.nspname='rf'
               AND c.relname='isa_executive_cost_model'
               AND t.tgname='trg_cost_model_audit') = 1
        THEN 'AUDIT_OK'
        ELSE 'AUDIT_FAILED'
    END AS p7k_cost_model_v3_audit_status;

\echo ''
\echo '✅ AUDIT P7K COST MODEL V3 COMPLETE'
\echo ''
