-- =============================================================================
-- OSA / ISA — PATCH P7Z PHASE 1 FOUNDATIONS
-- Version : P7Z_V1
-- Schémas : RF (paramètres scientifiques) + MG (gouvernance)
--
-- Contenu :
--   rf.isa_p7z_baseline_registry     : snapshot des gaps au lancement P7Z
--   rf.isa_p7z_probability_model     : paramètres du modèle probabiliste
--   mg.isa_p7z_governance_policy     : règles d'éligibilité aux simulations
--   mg.v_p7z_simulation_eligibility  : vue des lignes éligibles à P7Z
--
-- Principe :
--   P7Z consomme predictive_gap_score, calibration_uncertainty_score,
--   execution_maturity_score depuis ma.mv_isa_executive_master_board (P7K V3).
--   La baseline capture l'état au moment du lancement — point de référence
--   pour mesurer la convergence vers EXEC_READY_CAUTION.
-- =============================================================================
-- PRÉREQUIS :
--   P7K V3 FROZEN (mg.isa_package_freeze_registry)
--   ma.mv_isa_executive_master_board opérationnelle
--   mg.isa_model_governance_policy installée
-- =============================================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS rf;
CREATE SCHEMA IF NOT EXISTS mg;

-- =============================================================================
-- 1. rf.isa_p7z_baseline_registry
--    Snapshot des gaps prédictifs au moment du lancement P7Z
--    Sert de point zéro pour mesurer la convergence
-- =============================================================================
DROP TABLE IF EXISTS rf.isa_p7z_baseline_registry CASCADE;

CREATE TABLE rf.isa_p7z_baseline_registry (
    baseline_id                     SERIAL          PRIMARY KEY,
    -- Identifiants
    country_iso3                    TEXT            NOT NULL,
    year                            INTEGER         NOT NULL,
    pillar_code                     TEXT            NOT NULL,
    intervention_family_code        TEXT            NOT NULL,

    -- Scores P7K au moment du snapshot
    executive_priority_score        NUMERIC(5,3)    NOT NULL,
    execution_maturity_score        NUMERIC(5,3)    NOT NULL,
    sovereign_execution_pressure    NUMERIC(5,3)    NOT NULL,
    calibration_uncertainty_score   NUMERIC(5,3)    NOT NULL,
    predictive_gap_score            NUMERIC(5,3)    NOT NULL,
    predictive_execution_status     TEXT            NOT NULL,
    executive_master_status         TEXT            NOT NULL,
    cost_calibration_status         TEXT            NOT NULL,

    -- Métadonnées baseline
    baseline_version                TEXT            NOT NULL DEFAULT 'P7Z_V1',
    baseline_date                   TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    source_package_version          TEXT            NOT NULL DEFAULT 'P7K_V3',

    UNIQUE (country_iso3, year, pillar_code,
            intervention_family_code, baseline_version)
);

COMMENT ON TABLE rf.isa_p7z_baseline_registry IS
    'Snapshot des gaps prédictifs P7K V3 au lancement de P7Z.
     Sert de point zéro pour mesurer la convergence vers EXEC_READY_CAUTION.
     predictive_gap_score = 0 → seuil EXEC_READY_CAUTION atteint.
     Ne pas modifier après insertion — c''est une baseline immuable.
     Schéma RF : paramètres scientifiques de référence.';

COMMENT ON COLUMN rf.isa_p7z_baseline_registry.predictive_gap_score IS
    'Distance au seuil EXEC_READY_CAUTION au moment du snapshot.
     0.0 = seuil atteint. Calculé comme MAX(0, 0.75 - priority, 0.60 - maturity).
     P7Z utilisera ce score comme variable cible de convergence.';

-- Index pour requêtes P7Z fréquentes
CREATE INDEX idx_p7z_baseline_country_year
    ON rf.isa_p7z_baseline_registry (country_iso3, year);
CREATE INDEX idx_p7z_baseline_pillar
    ON rf.isa_p7z_baseline_registry (pillar_code);
CREATE INDEX idx_p7z_baseline_gap
    ON rf.isa_p7z_baseline_registry (predictive_gap_score);
CREATE INDEX idx_p7z_baseline_status
    ON rf.isa_p7z_baseline_registry (predictive_execution_status);
CREATE INDEX idx_p7z_baseline_version
    ON rf.isa_p7z_baseline_registry (baseline_version);

-- Insertion du snapshot depuis P7K V3
INSERT INTO rf.isa_p7z_baseline_registry (
    country_iso3, year, pillar_code, intervention_family_code,
    executive_priority_score, execution_maturity_score,
    sovereign_execution_pressure, calibration_uncertainty_score,
    predictive_gap_score, predictive_execution_status,
    executive_master_status, cost_calibration_status,
    baseline_version, baseline_date, source_package_version
)
SELECT
    country_iso3, year, pillar_code, intervention_family_code,
    executive_priority_score, execution_maturity_score,
    sovereign_execution_pressure, calibration_uncertainty_score,
    predictive_gap_score, predictive_execution_status,
    executive_master_status,
    COALESCE(cost_calibration_status, 'UNKNOWN'),
    'P7Z_V1', NOW(), 'P7K_V3'
FROM ma.mv_isa_executive_master_board;

-- =============================================================================
-- 2. rf.isa_p7z_probability_model
--    Paramètres du modèle probabiliste P7Z
--    Analogue à rf.isa_executive_cost_model pour P7K
--    Calibrés par pilier — définissent comment P7Z calcule les probabilités
-- =============================================================================
DROP TABLE IF EXISTS rf.isa_p7z_probability_model CASCADE;

CREATE TABLE rf.isa_p7z_probability_model (
    pillar_code                     TEXT            NOT NULL,

    -- Paramètres de convergence
    -- gap_decay_rate : vitesse à laquelle le gap se réduit naturellement
    -- 0.05 = réduction de 5% par an sans intervention
    gap_decay_rate                  NUMERIC(5,3)    NOT NULL
                                        CHECK (gap_decay_rate BETWEEN 0 AND 1),

    -- convergence_horizon_years : années estimées pour atteindre EXEC_READY_CAUTION
    -- calculé comme gap_moyen / gap_decay_rate
    convergence_horizon_years       NUMERIC(5,1)    NOT NULL
                                        CHECK (convergence_horizon_years BETWEEN 0 AND 50),

    -- Paramètres de fragilité systémique
    -- systemic_fragility_weight : poids du pilier dans la fragilité souveraine globale
    systemic_fragility_weight       NUMERIC(5,3)    NOT NULL
                                        CHECK (systemic_fragility_weight BETWEEN 0 AND 1),

    -- cascade_failure_probability : probabilité qu'une défaillance dans ce pilier
    -- se propage à d'autres piliers
    cascade_failure_probability     NUMERIC(5,3)    NOT NULL
                                        CHECK (cascade_failure_probability BETWEEN 0 AND 1),

    -- Paramètres d'exécutabilité
    -- execution_probability_base : probabilité de base d'exécution réussie
    -- avant toute correction de gap ou d'uncertainty
    execution_probability_base      NUMERIC(5,3)    NOT NULL
                                        CHECK (execution_probability_base BETWEEN 0 AND 1),

    -- uncertainty_penalty : réduction de probabilité par unité d'uncertainty
    -- ex: 0.30 → une uncertainty de 0.20 réduit la probabilité de 6%
    uncertainty_penalty             NUMERIC(5,3)    NOT NULL
                                        CHECK (uncertainty_penalty BETWEEN 0 AND 1),

    -- Calibration
    calibration_method              TEXT            NOT NULL
                                        CHECK (calibration_method IN
                                            ('EXPERT','LITERATURE','PROXY','DEFAULT')),
    calibration_status              TEXT            NOT NULL
                                        CHECK (calibration_status IN
                                            ('VALIDATED','PROVISIONAL','REVIEW_REQUIRED')),
    calibration_uncertainty_score   NUMERIC(5,3)    NOT NULL
                                        CHECK (calibration_uncertainty_score BETWEEN 0 AND 1),
    calibration_source              TEXT            NOT NULL,
    calibration_date                DATE            NOT NULL DEFAULT CURRENT_DATE,
    calibration_review_due_date     DATE            NOT NULL,
    calibration_version             TEXT            NOT NULL DEFAULT 'V1',

    PRIMARY KEY (pillar_code),

    CONSTRAINT chk_p7z_review_due
        CHECK (calibration_review_due_date > calibration_date)
);

COMMENT ON TABLE rf.isa_p7z_probability_model IS
    'Paramètres du modèle probabiliste P7Z par pilier.
     Analogue à rf.isa_executive_cost_model pour P7K.
     gap_decay_rate : vitesse naturelle de réduction du predictive_gap_score.
     cascade_failure_probability : propagation systémique des défaillances.
     execution_probability_base : probabilité de base avant corrections.
     Schéma RF : paramètres scientifiques.';

-- Insertion des 10 piliers
-- Valeurs calibrées par proxy depuis la baseline P7Z_V1
-- gap_decay_rate estimé depuis avg_priority et tendance ISA 2010-2024
INSERT INTO rf.isa_p7z_probability_model (
    pillar_code,
    gap_decay_rate, convergence_horizon_years,
    systemic_fragility_weight, cascade_failure_probability,
    execution_probability_base, uncertainty_penalty,
    calibration_method, calibration_status, calibration_uncertainty_score,
    calibration_source, calibration_date, calibration_review_due_date,
    calibration_version
) VALUES

-- PRES : min_gap=0.050, avg_priority=0.504 → convergence rapide
-- Énergie/eau : forte dynamique africaine, décennale d'investissement
('PRES',
 0.080, 3.1, 0.15, 0.25, 0.62, 0.25,
 'PROXY', 'PROVISIONAL', 0.20,
 'P7Z_V1 baseline snapshot — PRES min_gap=0.050, avg_priority=0.504, IEA Africa 2023',
 CURRENT_DATE, CURRENT_DATE + INTERVAL '12 months', 'V1'),

-- PMON : min_gap=0.055, avg_priority=0.456 → convergence modérée
-- Monétaire : institutions UEMOA/CEMAC en renforcement progressif
('PMON',
 0.065, 4.5, 0.18, 0.35, 0.58, 0.20,
 'PROXY', 'PROVISIONAL', 0.20,
 'P7Z_V1 baseline snapshot — PMON min_gap=0.055, avg_priority=0.456, IMF WEO 2023',
 CURRENT_DATE, CURRENT_DATE + INTERVAL '12 months', 'V1'),

-- PNUM : min_gap=0.069, avg_priority=0.465 → convergence rapide
-- Numérique : secteur en forte croissance, maturité en hausse
('PNUM',
 0.075, 3.7, 0.12, 0.20, 0.60, 0.18,
 'PROXY', 'PROVISIONAL', 0.18,
 'P7Z_V1 baseline snapshot — PNUM min_gap=0.069, avg_priority=0.465, ITU IDI 2023',
 CURRENT_DATE, CURRENT_DATE + INTERVAL '12 months', 'V1'),

-- PTRA : min_gap=0.109, avg_priority=0.425 → convergence modérée
-- Transport : LPI en progression mais infrastructure lente
('PTRA',
 0.055, 5.5, 0.14, 0.30, 0.52, 0.22,
 'PROXY', 'PROVISIONAL', 0.25,
 'P7Z_V1 baseline snapshot — PTRA min_gap=0.109, avg_priority=0.425, WB LPI 2023',
 CURRENT_DATE, CURRENT_DATE + INTERVAL '12 months', 'V1'),

-- PHUM : avg_priority=0.380 → convergence lente
-- Capital humain : horizon long, mais programmes solides
('PHUM',
 0.045, 8.2, 0.16, 0.28, 0.55, 0.18,
 'PROXY', 'PROVISIONAL', 0.18,
 'P7Z_V1 baseline snapshot — PHUM avg_priority=0.380, UNDP HDR 2023',
 CURRENT_DATE, CURRENT_DATE + INTERVAL '12 months', 'V1'),

-- PECO : avg_priority=0.403 → convergence modérée
-- Diversification : dépend des politiques commerciales
('PECO',
 0.050, 6.9, 0.17, 0.32, 0.50, 0.22,
 'PROXY', 'PROVISIONAL', 0.20,
 'P7Z_V1 baseline snapshot — PECO avg_priority=0.403, UNCTAD TDR 2023',
 CURRENT_DATE, CURRENT_DATE + INTERVAL '12 months', 'V1'),

-- PENV : avg_priority=0.407 → convergence modérée
-- Environnement : NDC en progression, horizon 4 ans
('PENV',
 0.048, 7.3, 0.13, 0.22, 0.48, 0.20,
 'PROXY', 'PROVISIONAL', 0.20,
 'P7Z_V1 baseline snapshot — PENV avg_priority=0.407, UNEP NDC 2023',
 CURRENT_DATE, CURRENT_DATE + INTERVAL '12 months', 'V1'),

-- PMIL : avg_priority=0.361 → convergence lente + forte fragilité
-- Sécurité : dépendance externe élevée, cascade élevée
('PMIL',
 0.035, 11.0, 0.20, 0.55, 0.42, 0.30,
 'PROXY', 'PROVISIONAL', 0.25,
 'P7Z_V1 baseline snapshot — PMIL avg_priority=0.361, SIPRI MED 2023',
 CURRENT_DATE, CURRENT_DATE + INTERVAL '12 months', 'V1'),

-- PMIN : avg_priority=0.385 → convergence lente
-- Mines : transformation locale lente, horizon 4+ ans
('PMIN',
 0.040, 9.5, 0.15, 0.38, 0.50, 0.25,
 'PROXY', 'PROVISIONAL', 0.25,
 'P7Z_V1 baseline snapshot — PMIN avg_priority=0.385, EITI Africa 2022',
 CURRENT_DATE, CURRENT_DATE + INTERVAL '12 months', 'V1'),

-- PGEO : avg_priority=0.311 → convergence très lente + fragilité max
-- Gouvernance : WGI le plus faible, cascade systémique maximale
('PGEO',
 0.025, 18.8, 0.22, 0.65, 0.38, 0.35,
 'PROXY', 'PROVISIONAL', 0.20,
 'P7Z_V1 baseline snapshot — PGEO avg_priority=0.311, WB WGI 2022',
 CURRENT_DATE, CURRENT_DATE + INTERVAL '12 months', 'V1');

-- =============================================================================
-- 3. mg.isa_p7z_governance_policy
--    Règles d'éligibilité aux simulations P7Z
--    Détermine quelles lignes peuvent entrer dans le moteur probabiliste
-- =============================================================================
DROP TABLE IF EXISTS mg.isa_p7z_governance_policy CASCADE;

CREATE TABLE mg.isa_p7z_governance_policy (
    eligibility_class               TEXT        PRIMARY KEY,
    -- Seuils d'éligibilité
    max_predictive_gap              NUMERIC(5,3) NOT NULL,
    max_uncertainty                 NUMERIC(5,3) NOT NULL,
    min_execution_maturity          NUMERIC(5,3) NOT NULL,
    -- Ce que P7Z peut calculer pour cette classe
    eligible_convergence_modelling  BOOLEAN     NOT NULL,
    eligible_cascade_modelling      BOOLEAN     NOT NULL,
    eligible_fragility_scoring      BOOLEAN     NOT NULL,
    eligible_isa_projection         BOOLEAN     NOT NULL,
    -- Label et note
    eligibility_label               TEXT        NOT NULL,
    policy_note                     TEXT        NOT NULL
);

COMMENT ON TABLE mg.isa_p7z_governance_policy IS
    'Règles d''éligibilité aux simulations P7Z par classe.
     Schéma MG : gouvernance institutionnelle du moteur probabiliste.
     Détermine ce que P7Z peut calculer selon le gap et l''uncertainty.';

INSERT INTO mg.isa_p7z_governance_policy VALUES

-- Classe 1 : prêt pour simulation complète
('P7Z_SIMULATION_READY',
 0.15, 0.30, 0.55,
 TRUE, TRUE, TRUE, TRUE,
 'Prêt pour simulation complète',
 'gap <= 0.15, uncertainty <= 0.30, maturity >= 0.55. '
 || 'Tous les modules P7Z activés : convergence, cascade, fragilité, projection ISA.'),

-- Classe 2 : simulation partielle — convergence et fragilité uniquement
('P7Z_SIMULATION_PARTIAL',
 0.35, 0.50, 0.40,
 TRUE, FALSE, TRUE, FALSE,
 'Simulation partielle — convergence et fragilité',
 'gap <= 0.35, uncertainty <= 0.50, maturity >= 0.40. '
 || 'Modules activés : convergence, fragilité. '
 || 'Cascade et projection ISA désactivés (gap trop élevé).'),

-- Classe 3 : monitoring uniquement — aucune simulation
('P7Z_MONITORING_ONLY',
 1.00, 1.00, 0.00,
 FALSE, FALSE, FALSE, FALSE,
 'Monitoring uniquement — aucune simulation',
 'Toutes les lignes non éligibles aux classes supérieures. '
 || 'Aucun module P7Z activé. '
 || 'Suivre l''évolution du gap via mg.v_p7z_simulation_eligibility.');

-- =============================================================================
-- 4. mg.v_p7z_simulation_eligibility
--    Vue des lignes éligibles à P7Z avec leur classe
--    Agrégée par pilier pour le monitoring
-- =============================================================================
DROP VIEW IF EXISTS mg.v_p7z_simulation_eligibility;

CREATE VIEW mg.v_p7z_simulation_eligibility AS
WITH classified AS (
    SELECT
        b.country_iso3,
        b.year,
        b.pillar_code,
        b.intervention_family_code,
        b.executive_priority_score,
        b.execution_maturity_score,
        b.predictive_gap_score,
        b.calibration_uncertainty_score,
        b.predictive_execution_status,
        b.executive_master_status,
        -- Classification P7Z
        CASE
            WHEN b.predictive_gap_score        <= 0.15
             AND b.calibration_uncertainty_score <= 0.30
             AND b.execution_maturity_score     >= 0.55
                THEN 'P7Z_SIMULATION_READY'
            WHEN b.predictive_gap_score        <= 0.35
             AND b.calibration_uncertainty_score <= 0.50
             AND b.execution_maturity_score     >= 0.40
                THEN 'P7Z_SIMULATION_PARTIAL'
            ELSE 'P7Z_MONITORING_ONLY'
        END                                             AS p7z_eligibility_class,
        -- Convergence estimée
        pm.gap_decay_rate,
        pm.convergence_horizon_years,
        pm.execution_probability_base,
        pm.cascade_failure_probability,
        pm.systemic_fragility_weight,
        -- Probabilité d'exécution estimée (calcul simplifié Phase 1)
        -- P7Z Phase 2 affinera ce calcul avec le moteur probabiliste complet
        ROUND(GREATEST(0.0, LEAST(1.0,
            pm.execution_probability_base
            - (b.predictive_gap_score * 0.50)
            - (b.calibration_uncertainty_score * pm.uncertainty_penalty)
        ))::NUMERIC, 3)                                 AS estimated_execution_probability
    FROM rf.isa_p7z_baseline_registry b
    LEFT JOIN rf.isa_p7z_probability_model pm
        ON pm.pillar_code = b.pillar_code
)
SELECT
    c.*,
    p.eligible_convergence_modelling,
    p.eligible_cascade_modelling,
    p.eligible_fragility_scoring,
    p.eligible_isa_projection,
    p.eligibility_label
FROM classified c
LEFT JOIN mg.isa_p7z_governance_policy p
    ON p.eligibility_class = c.p7z_eligibility_class;

COMMENT ON VIEW mg.v_p7z_simulation_eligibility IS
    'Vue d''éligibilité P7Z : classe de simulation pour chaque ligne de la baseline.
     P7Z_SIMULATION_READY   : tous les modules activés.
     P7Z_SIMULATION_PARTIAL : convergence et fragilité uniquement.
     P7Z_MONITORING_ONLY    : aucune simulation — gap trop élevé.
     estimated_execution_probability : approximation Phase 1, affinée en Phase 2.';

-- =============================================================================
-- 5. Mise à jour package_lifecycle P7Z
-- =============================================================================
INSERT INTO rf.package_lifecycle (package_code)
VALUES ('P7Z')
ON CONFLICT (package_code) DO NOTHING;

ALTER TABLE rf.package_lifecycle
    ADD COLUMN IF NOT EXISTS package_label       TEXT,
    ADD COLUMN IF NOT EXISTS package_status      TEXT,
    ADD COLUMN IF NOT EXISTS replacement_package TEXT,
    ADD COLUMN IF NOT EXISTS notes               TEXT,
    ADD COLUMN IF NOT EXISTS updated_at          TIMESTAMPTZ;

DELETE FROM rf.package_lifecycle WHERE package_code = 'P7Z';
INSERT INTO rf.package_lifecycle (
    package_code, package_label, package_status,
    replacement_package, notes, updated_at
) VALUES (
    'P7Z',
    'P7Z Predictive Sovereign Intelligence — Phase 1 Foundations',
    'ACTIVE',
    NULL,
    'P7Z Phase 1 : rf.isa_p7z_baseline_registry (snapshot P7K V3), '
    || 'rf.isa_p7z_probability_model (10 piliers, PROVISIONAL), '
    || 'mg.isa_p7z_governance_policy (3 classes d''éligibilité), '
    || 'mg.v_p7z_simulation_eligibility. '
    || 'Dépend de P7K V3 FROZEN. Prépare P7Z Phase 2 (moteur probabiliste).',
    NOW()
);

-- =============================================================================
-- 6. Validation finale
-- =============================================================================
DO $$
DECLARE
    v_baseline_rows     INTEGER;
    v_baseline_countries INTEGER;
    v_prob_rows         INTEGER;
    v_gov_rows          INTEGER;
    v_ready             INTEGER;
    v_partial           INTEGER;
    v_monitoring        INTEGER;
    v_null_prob         INTEGER;
BEGIN
    SELECT COUNT(*), COUNT(DISTINCT country_iso3)
        INTO v_baseline_rows, v_baseline_countries
        FROM rf.isa_p7z_baseline_registry;

    SELECT COUNT(*) INTO v_prob_rows
        FROM rf.isa_p7z_probability_model;

    SELECT COUNT(*) INTO v_gov_rows
        FROM mg.isa_p7z_governance_policy;

    SELECT COUNT(*) INTO v_ready
        FROM mg.v_p7z_simulation_eligibility
        WHERE p7z_eligibility_class = 'P7Z_SIMULATION_READY';

    SELECT COUNT(*) INTO v_partial
        FROM mg.v_p7z_simulation_eligibility
        WHERE p7z_eligibility_class = 'P7Z_SIMULATION_PARTIAL';

    SELECT COUNT(*) INTO v_monitoring
        FROM mg.v_p7z_simulation_eligibility
        WHERE p7z_eligibility_class = 'P7Z_MONITORING_ONLY';

    SELECT COUNT(*) INTO v_null_prob
        FROM mg.v_p7z_simulation_eligibility
        WHERE estimated_execution_probability IS NULL;

    RAISE NOTICE
        'P7Z Phase 1 : baseline_rows=%, countries=%, prob_model=%, '
        'gov_policy=%, ready=%, partial=%, monitoring=%, null_prob=%',
        v_baseline_rows, v_baseline_countries, v_prob_rows, v_gov_rows,
        v_ready, v_partial, v_monitoring, v_null_prob;

    IF v_baseline_rows = 0 THEN
        RAISE EXCEPTION 'ABORT : baseline P7Z vide';
    END IF;
    IF v_prob_rows <> 10 THEN
        RAISE EXCEPTION 'ABORT : probability model incomplet (attendu 10, obtenu %)',
            v_prob_rows;
    END IF;
    IF v_gov_rows <> 3 THEN
        RAISE EXCEPTION 'ABORT : governance policy incomplète (attendu 3, obtenu %)',
            v_gov_rows;
    END IF;
    IF v_null_prob > 0 THEN
        RAISE EXCEPTION 'ABORT : % lignes avec estimated_execution_probability NULL',
            v_null_prob;
    END IF;
END $$;

COMMIT;
