-- =============================================================================
-- OSA / ISA — PATCH P7K COST MODEL AUDIT LOG & GOVERNANCE V3 (DÉFINITIF)
-- Version : P7K_COST_V3
--
-- Schéma RF : rf.isa_cost_model_audit_log  — journal scientifique des révisions
--             trigger trg_cost_model_audit  — trace chaque champ modifié
-- Schéma MG : mg.isa_model_governance_policy   — règles institutionnelles
--             mg.v_cost_model_review_due        — vue des lignes en retard
--
-- Séparation RF / MG :
--   RF = paramètres scientifiques et leur traçabilité
--   MG = gouvernance institutionnelle des modèles (règles, seuils, deadlines)
-- =============================================================================
-- PRÉREQUIS : patch_p7k_cost_model_v3.sql appliqué
-- =============================================================================

BEGIN;

-- Schémas
CREATE SCHEMA IF NOT EXISTS rf;
CREATE SCHEMA IF NOT EXISTS mg;

-- =============================================================================
-- BLOC RF — Journal d'audit scientifique
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. rf.isa_cost_model_audit_log
--    Trace chaque modification de valeur sur rf.isa_executive_cost_model
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS rf.isa_cost_model_audit_log CASCADE;

CREATE TABLE rf.isa_cost_model_audit_log (
    log_id                      SERIAL          PRIMARY KEY,
    intervention_family_code    TEXT            NOT NULL,
    pillar_code                 TEXT            NOT NULL,
    field_revised               TEXT            NOT NULL,
    old_value                   TEXT,
    new_value                   TEXT,
    revision_method             TEXT            NOT NULL
                                    CHECK (revision_method IN
                                        ('SYSTEM','EXPERT_REVIEW',
                                         'LITERATURE_UPDATE','CORRECTION')),
    revision_source             TEXT,
    revision_date               TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    revised_by                  TEXT            NOT NULL DEFAULT 'SYSTEM',
    revision_note               TEXT
);

COMMENT ON TABLE rf.isa_cost_model_audit_log IS
    'Journal scientifique des révisions de rf.isa_executive_cost_model.
     Alimenté automatiquement par le trigger trg_cost_model_audit.
     Schéma RF : traçabilité scientifique des paramètres.';

CREATE INDEX idx_cost_audit_family_pillar
    ON rf.isa_cost_model_audit_log (intervention_family_code, pillar_code);
CREATE INDEX idx_cost_audit_date
    ON rf.isa_cost_model_audit_log (revision_date DESC);
CREATE INDEX idx_cost_audit_field
    ON rf.isa_cost_model_audit_log (field_revised);
CREATE INDEX idx_cost_audit_method
    ON rf.isa_cost_model_audit_log (revision_method);

-- -----------------------------------------------------------------------------
-- 2. Fonction trigger — trace chaque champ modifié individuellement
--    Champs surveillés : tous les scores + colonnes de calibration
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION rf.fn_cost_model_audit_trigger()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_note TEXT;
BEGIN
    v_note := 'Auto-logged on UPDATE — version: '
               || COALESCE(NEW.calibration_version, 'unknown');

    -- executive_cost_score
    IF OLD.executive_cost_score IS DISTINCT FROM NEW.executive_cost_score THEN
        INSERT INTO rf.isa_cost_model_audit_log
            (intervention_family_code, pillar_code, field_revised,
             old_value, new_value, revision_method, revision_source,
             revised_by, revision_note)
        VALUES (NEW.intervention_family_code, NEW.pillar_code,
            'executive_cost_score',
            OLD.executive_cost_score::TEXT, NEW.executive_cost_score::TEXT,
            COALESCE(NEW.calibration_method, 'SYSTEM'),
            NEW.calibration_source, 'SYSTEM', v_note);
    END IF;

    -- implementation_complexity
    IF OLD.implementation_complexity IS DISTINCT FROM NEW.implementation_complexity THEN
        INSERT INTO rf.isa_cost_model_audit_log
            (intervention_family_code, pillar_code, field_revised,
             old_value, new_value, revision_method, revision_source,
             revised_by, revision_note)
        VALUES (NEW.intervention_family_code, NEW.pillar_code,
            'implementation_complexity',
            OLD.implementation_complexity::TEXT, NEW.implementation_complexity::TEXT,
            COALESCE(NEW.calibration_method, 'SYSTEM'),
            NEW.calibration_source, 'SYSTEM', v_note);
    END IF;

    -- execution_horizon_years
    IF OLD.execution_horizon_years IS DISTINCT FROM NEW.execution_horizon_years THEN
        INSERT INTO rf.isa_cost_model_audit_log
            (intervention_family_code, pillar_code, field_revised,
             old_value, new_value, revision_method, revision_source,
             revised_by, revision_note)
        VALUES (NEW.intervention_family_code, NEW.pillar_code,
            'execution_horizon_years',
            OLD.execution_horizon_years::TEXT, NEW.execution_horizon_years::TEXT,
            COALESCE(NEW.calibration_method, 'SYSTEM'),
            NEW.calibration_source, 'SYSTEM', v_note);
    END IF;

    -- execution_maturity_score
    IF OLD.execution_maturity_score IS DISTINCT FROM NEW.execution_maturity_score THEN
        INSERT INTO rf.isa_cost_model_audit_log
            (intervention_family_code, pillar_code, field_revised,
             old_value, new_value, revision_method, revision_source,
             revised_by, revision_note)
        VALUES (NEW.intervention_family_code, NEW.pillar_code,
            'execution_maturity_score',
            OLD.execution_maturity_score::TEXT, NEW.execution_maturity_score::TEXT,
            COALESCE(NEW.calibration_method, 'SYSTEM'),
            NEW.calibration_source, 'SYSTEM', v_note);
    END IF;

    -- calibration_uncertainty_score (nouveau V3)
    IF OLD.calibration_uncertainty_score IS DISTINCT FROM NEW.calibration_uncertainty_score THEN
        INSERT INTO rf.isa_cost_model_audit_log
            (intervention_family_code, pillar_code, field_revised,
             old_value, new_value, revision_method, revision_source,
             revised_by, revision_note)
        VALUES (NEW.intervention_family_code, NEW.pillar_code,
            'calibration_uncertainty_score',
            OLD.calibration_uncertainty_score::TEXT, NEW.calibration_uncertainty_score::TEXT,
            COALESCE(NEW.calibration_method, 'SYSTEM'),
            NEW.calibration_source, 'SYSTEM', v_note);
    END IF;

    -- calibration_status (transition de statut)
    IF OLD.calibration_status IS DISTINCT FROM NEW.calibration_status THEN
        INSERT INTO rf.isa_cost_model_audit_log
            (intervention_family_code, pillar_code, field_revised,
             old_value, new_value, revision_method, revision_source,
             revised_by, revision_note)
        VALUES (NEW.intervention_family_code, NEW.pillar_code,
            'calibration_status',
            OLD.calibration_status, NEW.calibration_status,
            COALESCE(NEW.calibration_method, 'SYSTEM'),
            NEW.calibration_source, 'SYSTEM',
            'Status transition: ' || OLD.calibration_status
            || ' → ' || NEW.calibration_status
            || ' — ' || v_note);
    END IF;

    -- calibration_review_due_date (nouveau V3)
    IF OLD.calibration_review_due_date IS DISTINCT FROM NEW.calibration_review_due_date THEN
        INSERT INTO rf.isa_cost_model_audit_log
            (intervention_family_code, pillar_code, field_revised,
             old_value, new_value, revision_method, revision_source,
             revised_by, revision_note)
        VALUES (NEW.intervention_family_code, NEW.pillar_code,
            'calibration_review_due_date',
            OLD.calibration_review_due_date::TEXT, NEW.calibration_review_due_date::TEXT,
            COALESCE(NEW.calibration_method, 'SYSTEM'),
            NEW.calibration_source, 'SYSTEM', v_note);
    END IF;

    -- calibration_source
    IF OLD.calibration_source IS DISTINCT FROM NEW.calibration_source THEN
        INSERT INTO rf.isa_cost_model_audit_log
            (intervention_family_code, pillar_code, field_revised,
             old_value, new_value, revision_method, revision_source,
             revised_by, revision_note)
        VALUES (NEW.intervention_family_code, NEW.pillar_code,
            'calibration_source',
            LEFT(OLD.calibration_source, 200), LEFT(NEW.calibration_source, 200),
            COALESCE(NEW.calibration_method, 'SYSTEM'),
            NEW.calibration_source, 'SYSTEM', v_note);
    END IF;

    RETURN NEW;
END;
$$;

-- Attacher le trigger
DROP TRIGGER IF EXISTS trg_cost_model_audit ON rf.isa_executive_cost_model;
CREATE TRIGGER trg_cost_model_audit
    AFTER UPDATE ON rf.isa_executive_cost_model
    FOR EACH ROW
    EXECUTE FUNCTION rf.fn_cost_model_audit_trigger();

-- =============================================================================
-- BLOC MG — Gouvernance institutionnelle des modèles
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 3. mg.isa_model_governance_policy
--    Règles institutionnelles par statut de calibration
--    Déplacé de RF vers MG : c'est de la gouvernance, pas de la science
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS mg.isa_model_governance_policy CASCADE;

CREATE TABLE mg.isa_model_governance_policy (
    calibration_status              TEXT        PRIMARY KEY,
    usable_in_mv                    BOOLEAN     NOT NULL,
    eligible_predictive_execution   BOOLEAN     NOT NULL,
    predictive_execution_value      TEXT        NOT NULL
                                        CHECK (predictive_execution_value IN
                                            ('EXEC_READY',
                                             'EXEC_READY_CAUTION',
                                             'EXEC_BLOCKED_REVIEW')),
    uncertainty_threshold_max       NUMERIC(5,3) NOT NULL
                                        CHECK (uncertainty_threshold_max BETWEEN 0 AND 1),
    review_trigger_months           INTEGER     NOT NULL,
    policy_note                     TEXT        NOT NULL
);

COMMENT ON TABLE mg.isa_model_governance_policy IS
    'Gouvernance institutionnelle des statuts de calibration du cost model.
     Schéma MG : règles institutionnelles (séparé des paramètres scientifiques RF).
     Détermine predictive_execution_status dans mv_isa_executive_master_board.
     uncertainty_threshold_max : seuil au-delà duquel le statut est dégradé.';

INSERT INTO mg.isa_model_governance_policy VALUES
(
  'VALIDATED',
  TRUE,   -- usable_in_mv
  TRUE,   -- eligible_predictive_execution
  'EXEC_READY',
  0.30,   -- uncertainty max toléré pour VALIDATED
  24,     -- révision tous les 24 mois
  'Valeur validée par expert ou littérature primaire. Plein usage sans restriction. '
  || 'predictive_execution_status = EXEC_READY. Révision obligatoire tous les 24 mois.'
),
(
  'PROVISIONAL',
  TRUE,   -- usable_in_mv
  TRUE,   -- eligible_predictive_execution
  'EXEC_READY_CAUTION',
  0.50,   -- uncertainty max toléré pour PROVISIONAL
  12,     -- révision tous les 12 mois
  'Valeur proxy calibrée sur source OSA connue. Usage autorisé avec flag CAUTION. '
  || 'predictive_execution_status = EXEC_READY_CAUTION. Révision obligatoire tous les 12 mois. '
  || 'Si calibration_uncertainty_score > 0.50, dégrade vers EXEC_BLOCKED_REVIEW.'
),
(
  'REVIEW_REQUIRED',
  TRUE,   -- visible dans MV pour diagnostic
  FALSE,  -- exclu du predictif
  'EXEC_BLOCKED_REVIEW',
  1.00,   -- aucun seuil — toujours bloqué
  3,      -- révision obligatoire sous 3 mois
  'Valeur incertaine, outdatée ou dépassant le seuil d''uncertainty. '
  || 'Visible dans MV à titre diagnostique uniquement. '
  || 'predictive_execution_status = EXEC_BLOCKED_REVIEW. Révision sous 3 mois.'
);

-- -----------------------------------------------------------------------------
-- 4. mg.v_cost_model_review_due
--    Vue des lignes dont la date de révision est dépassée ou imminente
--    Permet de détecter les calibrations PROVISIONAL devenues obsolètes
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS mg.v_cost_model_review_due;

CREATE VIEW mg.v_cost_model_review_due AS
SELECT
    c.intervention_family_code,
    c.pillar_code,
    c.calibration_status,
    c.calibration_uncertainty_score,
    c.calibration_review_due_date,
    c.calibration_version,
    c.calibration_source,
    CURRENT_DATE - c.calibration_review_due_date       AS days_overdue,
    CASE
        WHEN CURRENT_DATE > c.calibration_review_due_date
            THEN 'OVERDUE'
        WHEN CURRENT_DATE > c.calibration_review_due_date - INTERVAL '30 days'
            THEN 'DUE_SOON'
        ELSE
            'ON_TRACK'
    END                                                AS review_status,
    p.review_trigger_months,
    p.policy_note
FROM rf.isa_executive_cost_model c
JOIN mg.isa_model_governance_policy p
    ON p.calibration_status = c.calibration_status
ORDER BY
    CASE WHEN CURRENT_DATE > c.calibration_review_due_date THEN 0
         WHEN CURRENT_DATE > c.calibration_review_due_date - INTERVAL '30 days' THEN 1
         ELSE 2 END,
    c.calibration_review_due_date ASC;

COMMENT ON VIEW mg.v_cost_model_review_due IS
    'Vue de gouvernance MG : lignes du cost model dont la révision est due ou dépassée.
     review_status = OVERDUE   : calibration_review_due_date dépassée.
     review_status = DUE_SOON  : révision dans les 30 prochains jours.
     review_status = ON_TRACK  : dans les délais.';

-- -----------------------------------------------------------------------------
-- 5. Validation finale
-- -----------------------------------------------------------------------------
DO $$
DECLARE
    v_policy    INTEGER;
    v_trigger   INTEGER;
    v_audit_idx INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_policy
        FROM mg.isa_model_governance_policy;
    SELECT COUNT(*) INTO v_trigger
        FROM pg_trigger t
        JOIN pg_class c     ON c.oid = t.tgrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'rf'
          AND c.relname = 'isa_executive_cost_model'
          AND t.tgname  = 'trg_cost_model_audit';
    SELECT COUNT(*) INTO v_audit_idx
        FROM pg_indexes
        WHERE schemaname = 'rf'
          AND tablename  = 'isa_cost_model_audit_log';

    RAISE NOTICE 'P7K audit log & governance V3 : policy_rows=%, trigger=%, audit_indexes=%',
        v_policy, v_trigger, v_audit_idx;

    IF v_policy <> 3 THEN
        RAISE EXCEPTION 'ABORT : mg.isa_model_governance_policy incomplete (expected 3, got %)',
            v_policy;
    END IF;
    IF v_trigger = 0 THEN
        RAISE EXCEPTION 'ABORT : trigger trg_cost_model_audit non installé';
    END IF;
END $$;

COMMIT;
