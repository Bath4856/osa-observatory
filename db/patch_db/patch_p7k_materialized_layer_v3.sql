-- =============================================================================
-- OSA / ISA — PATCH P7K MATERIALIZED LAYER V3 (DÉFINITIF)
-- Version : P7K_COST_V3
--
-- Corrections vs V2 :
--   + predictive_ready_flag (BOOLEAN) → predictive_execution_status (TEXT)
--     EXEC_READY / EXEC_READY_CAUTION / EXEC_BLOCKED_REVIEW
--   + Jointure sur mg.isa_model_governance_policy (schéma MG)
--   + calibration_uncertainty_score intégré dans la MV
--   + calibration_review_due_date exposé pour monitoring
--   + cost_model_coverage_flag pour diagnostic piliers non couverts
--   + COALESCE sur tous les scores optionnels
-- =============================================================================
-- PRÉREQUIS (dans cet ordre) :
--   1. patch_p7k_cost_model_v3.sql
--   2. patch_p7k_cost_model_audit_log_v3.sql
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. Drop MV et dépendances
-- -----------------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS ma.mv_isa_executive_master_board CASCADE;
DROP TABLE IF EXISTS ma.tmp_exec_master_board;

-- -----------------------------------------------------------------------------
-- 2. MV v3 — définitive
-- -----------------------------------------------------------------------------
CREATE MATERIALIZED VIEW ma.mv_isa_executive_master_board AS

WITH cost AS (
    -- Cost model + gouvernance MG
    -- Jointure sur calibration_status pour récupérer les règles institutionnelles
    SELECT
        c.intervention_family_code,
        c.pillar_code,
        c.executive_cost_score,
        c.implementation_complexity,
        c.execution_horizon_years,
        COALESCE(c.execution_maturity_score, 0.40)::NUMERIC       AS execution_maturity_score,
        c.calibration_status,
        c.calibration_method,
        c.calibration_uncertainty_score,
        c.calibration_source,
        c.calibration_review_due_date,
        c.calibration_version,
        -- Depuis MG : règles institutionnelles
        p.eligible_predictive_execution,
        p.predictive_execution_value                               AS governance_predictive_value,
        p.uncertainty_threshold_max
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
        -- sovereign_execution_pressure
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

        -- predictive_execution_status (remplace le booléen V2)
        -- Logique :
        --   EXEC_BLOCKED_REVIEW si :
        --     - cost model non couvert (NULL)
        --     - calibration_status = REVIEW_REQUIRED
        --     - uncertainty > uncertainty_threshold_max
        --     - eligible_predictive_execution = FALSE
        --   EXEC_READY si :
        --     - executive_priority_score >= 0.75
        --     - execution_maturity_score >= 0.60
        --     - calibration_status = VALIDATED
        --     - uncertainty <= 0.30
        --   EXEC_READY_CAUTION si :
        --     - executive_priority_score >= 0.75
        --     - execution_maturity_score >= 0.60
        --     - calibration_status = PROVISIONAL
        --     - uncertainty <= uncertainty_threshold_max
        --   EXEC_BLOCKED_REVIEW dans tous les autres cas
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

        -- cost_model_coverage_flag — diagnostic
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
            ELSE
                'COST_MODEL_UNKNOWN'
        END::TEXT                                                   AS cost_model_coverage_flag,

        -- review_due_flag — alerte de révision imminente ou dépassée
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
    -- Identifiants
    country_iso3,
    year,
    pillar_code,
    intervention_family_code,
    intervention_family_label,

    -- Scores P7K
    executive_decision_class,
    ROUND(executive_priority_score,       3)    AS executive_priority_score,
    ROUND(budget_pressure_score,          3)    AS budget_pressure_score,
    ROUND(governance_risk_score,          3)    AS governance_risk_score,

    -- Scores cost model
    ROUND(COALESCE(executive_cost_score, 0), 3) AS executive_cost_score,
    ROUND(COALESCE(implementation_complexity, 0), 3) AS implementation_complexity,
    execution_horizon_years,
    ROUND(execution_maturity_score,       3)    AS execution_maturity_score,

    -- Calibration scientifique (RF)
    cost_calibration_status,
    cost_calibration_method,
    ROUND(COALESCE(calibration_uncertainty_score, 0), 3) AS calibration_uncertainty_score,
    cost_calibration_source,
    calibration_review_due_date,
    cost_calibration_version,

    -- Niveau pays
    ROUND(COALESCE(country_decision_priority_score, 0), 3) AS country_decision_priority_score,
    country_decision_class,

    -- Scénarios
    ROUND(COALESCE(central_isa_delta,   0), 3)  AS central_isa_delta,
    ROUND(COALESCE(ambitious_isa_delta, 0), 3)  AS ambitious_isa_delta,
    ROUND(COALESCE(stress_isa_delta,    0), 3)  AS stress_isa_delta,

    -- Timing décisionnel
    decision_timing_code,
    decision_max_months,
    decision_support_status,
    executive_readiness_status,

    -- Scores dérivés
    ROUND(sovereign_execution_pressure,   3)    AS sovereign_execution_pressure,
    executive_master_status,

    -- Statut prédictif V3 (remplace predictive_ready_flag booléen)
    predictive_execution_status,

    -- Flags de diagnostic
    cost_model_coverage_flag,
    review_due_flag

FROM classified

WITH DATA;

-- -----------------------------------------------------------------------------
-- 3. Index
-- -----------------------------------------------------------------------------
CREATE INDEX idx_mv_exec_master_country_year
    ON ma.mv_isa_executive_master_board (country_iso3, year);

CREATE INDEX idx_mv_exec_master_pillar
    ON ma.mv_isa_executive_master_board (pillar_code);

CREATE INDEX idx_mv_exec_master_status
    ON ma.mv_isa_executive_master_board (executive_master_status);

CREATE INDEX idx_mv_exec_master_predictive
    ON ma.mv_isa_executive_master_board (predictive_execution_status);

CREATE INDEX idx_mv_exec_master_cost_coverage
    ON ma.mv_isa_executive_master_board (cost_model_coverage_flag);

CREATE INDEX idx_mv_exec_master_review_due
    ON ma.mv_isa_executive_master_board (review_due_flag)
    WHERE review_due_flag IN ('REVIEW_OVERDUE','REVIEW_DUE_SOON');

ANALYZE ma.mv_isa_executive_master_board;

-- -----------------------------------------------------------------------------
-- 4. Validation
-- -----------------------------------------------------------------------------
DO $$
DECLARE
    v_rows          INTEGER;
    v_null_pressure INTEGER;
    v_exec_ready    INTEGER;
    v_exec_caution  INTEGER;
    v_exec_blocked  INTEGER;
    v_overdue       INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_rows
        FROM ma.mv_isa_executive_master_board;
    SELECT COUNT(*) INTO v_null_pressure
        FROM ma.mv_isa_executive_master_board
        WHERE sovereign_execution_pressure IS NULL;
    SELECT COUNT(*) INTO v_exec_ready
        FROM ma.mv_isa_executive_master_board
        WHERE predictive_execution_status = 'EXEC_READY';
    SELECT COUNT(*) INTO v_exec_caution
        FROM ma.mv_isa_executive_master_board
        WHERE predictive_execution_status = 'EXEC_READY_CAUTION';
    SELECT COUNT(*) INTO v_exec_blocked
        FROM ma.mv_isa_executive_master_board
        WHERE predictive_execution_status = 'EXEC_BLOCKED_REVIEW';
    SELECT COUNT(*) INTO v_overdue
        FROM ma.mv_isa_executive_master_board
        WHERE review_due_flag = 'REVIEW_OVERDUE';

    RAISE NOTICE
        'P7K MV V3 : rows=%, null_pressure=%, '
        'exec_ready=%, exec_caution=%, exec_blocked=%, review_overdue=%',
        v_rows, v_null_pressure,
        v_exec_ready, v_exec_caution, v_exec_blocked, v_overdue;

    IF v_rows = 0 THEN
        RAISE EXCEPTION 'ABORT : mv_isa_executive_master_board vide';
    END IF;
    IF v_null_pressure > 0 THEN
        RAISE EXCEPTION 'ABORT : % lignes avec sovereign_execution_pressure NULL',
            v_null_pressure;
    END IF;
    -- Un booléen NULL dans predictive_execution_status serait un bug
    IF (SELECT COUNT(*) FROM ma.mv_isa_executive_master_board
        WHERE predictive_execution_status IS NULL) > 0 THEN
        RAISE EXCEPTION 'ABORT : predictive_execution_status contient des NULL';
    END IF;
END $$;

COMMIT;
