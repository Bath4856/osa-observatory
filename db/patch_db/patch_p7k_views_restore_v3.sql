-- =============================================================================
-- OSA / ISA — PATCH P7K VIEWS RESTORE V3
-- Recrée les 3 vues droppées par CASCADE + ajoute predictive_gap_score dans MV
--
-- Corrections vs vues originales :
--   1. sovereign_dependency_score absent de rf.isa_executive_cost_model V3
--      → remplacé par calibration_uncertainty_score (proxy de dépendance inverse)
--   2. predictive_ready_flag (BOOLEAN) → predictive_execution_status (TEXT)
--      dans v_isa_predictive_readiness_registry
--   3. predictive_gap_score ajouté dans mv_isa_executive_master_board
--
-- Ordre de recréation obligatoire :
--   1. Ajouter predictive_gap_score dans MV (REFRESH)
--   2. v_isa_executive_cost_projection  (lit rf.isa_executive_cost_model)
--   3. v_isa_executive_master_board     (lit MV + v_isa_executive_cost_projection)
--   4. v_isa_predictive_readiness_registry (lit MV)
-- =============================================================================
-- PRÉREQUIS : patch_p7k_materialized_layer_v3.sql appliqué
-- =============================================================================

BEGIN;

-- =============================================================================
-- ÉTAPE 1 — Ajouter predictive_gap_score dans mv_isa_executive_master_board
-- La MV doit être reconstruite pour exposer la nouvelle colonne
-- =============================================================================

-- Drop vues dépendantes avant reconstruction MV
DROP VIEW IF EXISTS ma.v_isa_predictive_readiness_registry CASCADE;
DROP VIEW IF EXISTS ma.v_isa_executive_master_board CASCADE;
DROP VIEW IF EXISTS ma.v_isa_executive_cost_projection CASCADE;

-- Reconstruction MV avec predictive_gap_score
DROP MATERIALIZED VIEW IF EXISTS ma.mv_isa_executive_master_board CASCADE;

CREATE MATERIALIZED VIEW ma.mv_isa_executive_master_board AS

WITH cost AS (
    SELECT
        c.intervention_family_code,
        c.pillar_code,
        c.executive_cost_score,
        c.implementation_complexity,
        c.execution_horizon_years,
        COALESCE(c.execution_maturity_score, 0.40)::NUMERIC       AS execution_maturity_score,
        -- sovereign_dependency_score : proxy inverse de l'uncertainty
        -- plus l'uncertainty est faible, moins la dépendance externe est forte
        ROUND((1.0 - c.calibration_uncertainty_score)::NUMERIC, 3) AS sovereign_dependency_score,
        c.calibration_status,
        c.calibration_method,
        c.calibration_uncertainty_score,
        c.calibration_source,
        c.calibration_review_due_date,
        c.calibration_version,
        COALESCE(p.eligible_predictive_execution, FALSE)           AS eligible_predictive_execution,
        p.predictive_execution_value                               AS governance_predictive_value,
        COALESCE(p.uncertainty_threshold_max, 0.50)                AS uncertainty_threshold_max
    FROM rf.isa_executive_cost_model c
    LEFT JOIN mg.isa_model_governance_policy p
        ON p.calibration_status = c.calibration_status
),

portfolio AS (
    SELECT
        p.country_iso3,
        p.year,
        p.pillar_code,
        p.intervention_family_code,
        p.intervention_family_label,
        p.executive_decision_class,
        p.executive_priority_score,
        p.budget_pressure_score,
        p.governance_risk_score,
        p.central_isa_delta,
        p.ambitious_isa_delta,
        p.stress_isa_delta,
        p.decision_timing_code,
        p.decision_max_months,
        p.decision_support_status,
        p.executive_readiness_status,
        cy.country_decision_priority_score,
        cy.country_decision_class
    FROM ma.v_isa_executive_priority_portfolio p
    LEFT JOIN ma.v_isa_decision_country_year cy
        ON  cy.country_iso3 = p.country_iso3
        AND cy.year         = p.year
),

combined AS (
    SELECT
        p.*,
        c.executive_cost_score,
        c.implementation_complexity,
        c.execution_horizon_years,
        c.execution_maturity_score,
        c.sovereign_dependency_score,
        c.calibration_status                                        AS cost_calibration_status,
        c.calibration_method                                        AS cost_calibration_method,
        c.calibration_uncertainty_score,
        c.calibration_source                                        AS cost_calibration_source,
        c.calibration_review_due_date,
        c.calibration_version                                       AS cost_calibration_version,
        COALESCE(c.eligible_predictive_execution, FALSE)            AS eligible_predictive_execution,
        c.governance_predictive_value,
        COALESCE(c.uncertainty_threshold_max, 0.50)                 AS uncertainty_threshold_max
    FROM portfolio p
    LEFT JOIN cost c
        ON  c.intervention_family_code = p.intervention_family_code
        AND c.pillar_code              = p.pillar_code
),

scored AS (
    SELECT
        *,
        ROUND(LEAST(1.0, GREATEST(0.0,
            0.40 * executive_priority_score
          + 0.25 * budget_pressure_score
          + 0.20 * governance_risk_score
          + 0.15 * COALESCE(executive_cost_score, executive_priority_score)
        ))::NUMERIC, 3)                                             AS sovereign_execution_pressure
    FROM combined
),

classified AS (
    SELECT
        *,

        -- executive_master_status
        CASE
            WHEN sovereign_execution_pressure >= 0.80 THEN 'EXECUTIVE_CRITICAL'
            WHEN sovereign_execution_pressure >= 0.65 THEN 'EXECUTIVE_PRIORITY'
            WHEN sovereign_execution_pressure >= 0.45 THEN 'EXECUTIVE_PROGRAMME'
            ELSE                                            'EXECUTIVE_MONITOR'
        END::TEXT                                                   AS executive_master_status,

        -- predictive_execution_status
        CASE
            WHEN executive_cost_score IS NULL
                THEN 'EXEC_BLOCKED_REVIEW'
            WHEN eligible_predictive_execution = FALSE
                THEN 'EXEC_BLOCKED_REVIEW'
            WHEN calibration_uncertainty_score > uncertainty_threshold_max
                THEN 'EXEC_BLOCKED_REVIEW'
            WHEN executive_priority_score  >= 0.75
             AND execution_maturity_score  >= 0.60
             AND cost_calibration_status   = 'VALIDATED'
             AND calibration_uncertainty_score <= 0.30
                THEN 'EXEC_READY'
            WHEN executive_priority_score  >= 0.75
             AND execution_maturity_score  >= 0.60
             AND cost_calibration_status   = 'PROVISIONAL'
             AND calibration_uncertainty_score <= uncertainty_threshold_max
                THEN 'EXEC_READY_CAUTION'
            ELSE
                'EXEC_BLOCKED_REVIEW'
        END::TEXT                                                   AS predictive_execution_status,

        -- predictive_gap_score : écart au seuil EXEC_READY_CAUTION
        -- 0.0 = seuil atteint, >0 = effort restant
        ROUND(GREATEST(0.0,
            GREATEST(
                0.75 - executive_priority_score,
                0.60 - COALESCE(execution_maturity_score, 0.0)
            )
        )::NUMERIC, 3)                                              AS predictive_gap_score,

        -- cost_model_coverage_flag
        CASE
            WHEN executive_cost_score IS NULL
                THEN 'COST_MODEL_NOT_COVERED'
            WHEN cost_calibration_status = 'REVIEW_REQUIRED'
                THEN 'COST_MODEL_REVIEW_REQUIRED'
            WHEN calibration_uncertainty_score > uncertainty_threshold_max
                THEN 'COST_MODEL_HIGH_UNCERTAINTY'
            WHEN cost_calibration_status = 'PROVISIONAL'
                THEN 'COST_MODEL_PROVISIONAL'
            WHEN cost_calibration_status = 'VALIDATED'
                THEN 'COST_MODEL_VALIDATED'
            ELSE 'COST_MODEL_UNKNOWN'
        END::TEXT                                                   AS cost_model_coverage_flag,

        -- review_due_flag
        CASE
            WHEN calibration_review_due_date IS NULL
                THEN 'NO_DUE_DATE'
            WHEN CURRENT_DATE > calibration_review_due_date
                THEN 'REVIEW_OVERDUE'
            WHEN CURRENT_DATE > calibration_review_due_date - INTERVAL '30 days'
                THEN 'REVIEW_DUE_SOON'
            ELSE
                'REVIEW_ON_TRACK'
        END::TEXT                                                   AS review_due_flag

    FROM scored
)

SELECT
    country_iso3, year, pillar_code,
    intervention_family_code, intervention_family_label,
    executive_decision_class,
    ROUND(executive_priority_score,       3)    AS executive_priority_score,
    ROUND(budget_pressure_score,          3)    AS budget_pressure_score,
    ROUND(governance_risk_score,          3)    AS governance_risk_score,
    ROUND(COALESCE(executive_cost_score,  0), 3) AS executive_cost_score,
    ROUND(COALESCE(implementation_complexity, 0), 3) AS implementation_complexity,
    execution_horizon_years,
    ROUND(execution_maturity_score,       3)    AS execution_maturity_score,
    ROUND(sovereign_dependency_score,     3)    AS sovereign_dependency_score,
    cost_calibration_status,
    cost_calibration_method,
    ROUND(COALESCE(calibration_uncertainty_score, 0), 3) AS calibration_uncertainty_score,
    cost_calibration_source,
    calibration_review_due_date,
    cost_calibration_version,
    ROUND(COALESCE(country_decision_priority_score, 0), 3) AS country_decision_priority_score,
    country_decision_class,
    ROUND(COALESCE(central_isa_delta,   0), 3)  AS central_isa_delta,
    ROUND(COALESCE(ambitious_isa_delta, 0), 3)  AS ambitious_isa_delta,
    ROUND(COALESCE(stress_isa_delta,    0), 3)  AS stress_isa_delta,
    decision_timing_code, decision_max_months,
    decision_support_status, executive_readiness_status,
    ROUND(sovereign_execution_pressure,   3)    AS sovereign_execution_pressure,
    executive_master_status,
    predictive_execution_status,
    predictive_gap_score,
    cost_model_coverage_flag,
    review_due_flag
FROM classified
WITH DATA;

-- Index
CREATE INDEX idx_mv_exec_master_country_year
    ON ma.mv_isa_executive_master_board (country_iso3, year);
CREATE INDEX idx_mv_exec_master_pillar
    ON ma.mv_isa_executive_master_board (pillar_code);
CREATE INDEX idx_mv_exec_master_status
    ON ma.mv_isa_executive_master_board (executive_master_status);
CREATE INDEX idx_mv_exec_master_predictive
    ON ma.mv_isa_executive_master_board (predictive_execution_status);
CREATE INDEX idx_mv_exec_master_gap
    ON ma.mv_isa_executive_master_board (predictive_gap_score);
CREATE INDEX idx_mv_exec_master_cost_coverage
    ON ma.mv_isa_executive_master_board (cost_model_coverage_flag);
CREATE INDEX idx_mv_exec_master_review_due
    ON ma.mv_isa_executive_master_board (review_due_flag)
    WHERE review_due_flag IN ('REVIEW_OVERDUE','REVIEW_DUE_SOON');

ANALYZE ma.mv_isa_executive_master_board;

-- =============================================================================
-- ÉTAPE 2 — v_isa_executive_cost_projection
-- Corrigé : sovereign_dependency_score lu depuis MV (plus depuis cost model)
-- =============================================================================
CREATE OR REPLACE VIEW ma.v_isa_executive_cost_projection AS
SELECT
    p.country_iso3,
    p.year,
    p.pillar_code,
    p.intervention_family_code,
    p.intervention_family_label,
    p.executive_cost_score,
    p.implementation_complexity,
    p.sovereign_dependency_score,
    p.execution_maturity_score,
    p.execution_horizon_years,
    p.sovereign_execution_pressure
FROM ma.mv_isa_executive_master_board p;

-- =============================================================================
-- ÉTAPE 3 — v_isa_executive_master_board (vue légère sur MV)
-- Corrigé : predictive_ready_flag recalculé depuis predictive_execution_status
--           systemic_cascade_score recalculé depuis MV
-- =============================================================================
CREATE OR REPLACE VIEW ma.v_isa_executive_master_board AS
SELECT
    m.country_iso3,
    m.year,
    m.pillar_code,
    m.intervention_family_code,
    m.intervention_family_label,
    m.executive_decision_class,
    m.executive_priority_score,
    m.budget_pressure_score,
    m.governance_risk_score,
    m.executive_cost_score,
    m.implementation_complexity,
    m.execution_horizon_years,
    m.sovereign_execution_pressure,
    m.executive_master_status,
    -- predictive_ready_flag maintenu pour compatibilité ascendante
    -- TRUE uniquement pour EXEC_READY (VALIDATED) — EXEC_READY_CAUTION exclu
    CASE
        WHEN m.predictive_execution_status = 'EXEC_READY' THEN TRUE
        ELSE FALSE
    END::BOOLEAN                                        AS predictive_ready_flag,
    -- predictive_execution_status : statut V3 complet
    m.predictive_execution_status,
    -- predictive_gap_score : nouveau V3
    m.predictive_gap_score,
    -- systemic_cascade_score recalculé
    ROUND((
        m.governance_risk_score * 0.50
        + m.sovereign_dependency_score * 0.50
    )::NUMERIC, 3)                                      AS systemic_cascade_score
FROM ma.mv_isa_executive_master_board m;

-- =============================================================================
-- ÉTAPE 4 — v_isa_predictive_readiness_registry
-- Corrigé : predictive_ready_flag → predictive_execution_status
--           + predictive_gap_score agrégé
-- =============================================================================
CREATE OR REPLACE VIEW ma.v_isa_predictive_readiness_registry AS
SELECT
    pillar_code,
    COUNT(*)                                            AS nb_rows,
    ROUND(AVG(executive_priority_score)::NUMERIC, 3)   AS avg_priority,
    ROUND(AVG(systemic_cascade_score)::NUMERIC,   3)   AS avg_cascade,
    ROUND(AVG(sovereign_execution_pressure)::NUMERIC,3) AS avg_pressure,
    ROUND(AVG(predictive_gap_score)::NUMERIC,     3)   AS avg_predictive_gap,
    ROUND(MIN(predictive_gap_score)::NUMERIC,     3)   AS min_predictive_gap,
    -- nb_predictive_ready : EXEC_READY uniquement (VALIDATED)
    SUM(CASE WHEN predictive_ready_flag = TRUE THEN 1 ELSE 0 END)
                                                        AS nb_predictive_ready,
    -- nb_predictive_caution : EXEC_READY_CAUTION (PROVISIONAL)
    SUM(CASE WHEN predictive_execution_status = 'EXEC_READY_CAUTION' THEN 1 ELSE 0 END)
                                                        AS nb_predictive_caution,
    -- nb_predictive_blocked : EXEC_BLOCKED_REVIEW
    SUM(CASE WHEN predictive_execution_status = 'EXEC_BLOCKED_REVIEW' THEN 1 ELSE 0 END)
                                                        AS nb_predictive_blocked
FROM ma.v_isa_executive_master_board
GROUP BY pillar_code
ORDER BY avg_predictive_gap ASC;

-- =============================================================================
-- Validation finale
-- =============================================================================
DO $$
DECLARE
    v_mv_rows       INTEGER;
    v_gap_nulls     INTEGER;
    v_dep_nulls     INTEGER;
    v_view_cp       INTEGER;
    v_view_mb       INTEGER;
    v_view_prr      INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_mv_rows   FROM ma.mv_isa_executive_master_board;
    SELECT COUNT(*) INTO v_gap_nulls FROM ma.mv_isa_executive_master_board
        WHERE predictive_gap_score IS NULL;
    SELECT COUNT(*) INTO v_dep_nulls FROM ma.mv_isa_executive_master_board
        WHERE sovereign_dependency_score IS NULL;
    SELECT COUNT(*) INTO v_view_cp
        FROM information_schema.views
        WHERE table_schema='ma' AND table_name='v_isa_executive_cost_projection';
    SELECT COUNT(*) INTO v_view_mb
        FROM information_schema.views
        WHERE table_schema='ma' AND table_name='v_isa_executive_master_board';
    SELECT COUNT(*) INTO v_view_prr
        FROM information_schema.views
        WHERE table_schema='ma' AND table_name='v_isa_predictive_readiness_registry';

    RAISE NOTICE
        'P7K views restore V3 : mv_rows=%, gap_nulls=%, dep_nulls=%, '
        'view_cost_projection=%, view_master_board=%, view_readiness=%',
        v_mv_rows, v_gap_nulls, v_dep_nulls,
        v_view_cp, v_view_mb, v_view_prr;

    IF v_mv_rows = 0 THEN
        RAISE EXCEPTION 'ABORT : MV vide';
    END IF;
    IF v_gap_nulls > 0 THEN
        RAISE EXCEPTION 'ABORT : % NULL sur predictive_gap_score', v_gap_nulls;
    END IF;
    IF v_view_cp + v_view_mb + v_view_prr <> 3 THEN
        RAISE EXCEPTION 'ABORT : vues manquantes (cp=%, mb=%, prr=%)',
            v_view_cp, v_view_mb, v_view_prr;
    END IF;
END $$;

COMMIT;
