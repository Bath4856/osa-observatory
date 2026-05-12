-- ============================================================
-- OSA / ISA — P7F
-- Strategic Diagnostic Intelligence Engine
-- Purpose:
--   Clean replacement for legacy P7X diagnostic layer.
--   P7F diagnoses; it does not forecast, simulate, certify, or sell.
-- ============================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS rf;
CREATE SCHEMA IF NOT EXISTS ma;
CREATE SCHEMA IF NOT EXISTS mg;

-- ------------------------------------------------------------
-- Package lifecycle registry: freeze P7X without deleting it.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mg.package_lifecycle (
    package_code        VARCHAR(20) PRIMARY KEY,
    package_label       TEXT NOT NULL,
    package_status      VARCHAR(30) NOT NULL,
    replacement_package VARCHAR(20),
    notes               TEXT,
    updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO mg.package_lifecycle (
    package_code, package_label, package_status, replacement_package, notes
)
VALUES
('P7X', 'Legacy SWOT Strategic Intelligence Engine', 'ARCHIVED', 'P7F',
 'P7X is frozen as a transitional diagnostic layer. Replaced by P7F clean diagnostic intelligence.'),
('P7F', 'Strategic Diagnostic Intelligence Engine', 'ACTIVE', NULL,
 'P7F produces diagnostic strategic signals, candidate interventions, and public consultation topics only.')
ON CONFLICT (package_code) DO UPDATE SET
    package_label = EXCLUDED.package_label,
    package_status = EXCLUDED.package_status,
    replacement_package = EXCLUDED.replacement_package,
    notes = EXCLUDED.notes,
    updated_at = CURRENT_TIMESTAMP;

-- ------------------------------------------------------------
-- SWOT diagnostic policy.
-- ------------------------------------------------------------
DROP TABLE IF EXISTS rf.isa_strategic_diagnostic_policy CASCADE;
CREATE TABLE rf.isa_strategic_diagnostic_policy (
    diagnostic_role             VARCHAR(40) PRIMARY KEY,
    role_label                  TEXT NOT NULL,
    min_priority_score          NUMERIC(5,3) NOT NULL DEFAULT 0.000,
    open_data_allowed           BOOLEAN NOT NULL DEFAULT TRUE,
    predictive_required         BOOLEAN NOT NULL DEFAULT FALSE,
    premium_allowed             BOOLEAN NOT NULL DEFAULT FALSE,
    notes                       TEXT,
    updated_at                  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO rf.isa_strategic_diagnostic_policy (
    diagnostic_role, role_label, min_priority_score, open_data_allowed,
    predictive_required, premium_allowed, notes
)
VALUES
('WEAKNESS_TO_FIX', 'Faiblesse à corriger', 0.550, TRUE, FALSE, FALSE,
 'Diagnostic: intervention candidate to attenuate observed weakness. No premium trigger at P7F.'),
('THREAT_TO_MITIGATE', 'Menace à atténuer', 0.600, TRUE, FALSE, FALSE,
 'Diagnostic: risk mitigation candidate based on observed threats and vulnerability.'),
('STRENGTH_TO_SCALE', 'Force à amplifier', 0.550, TRUE, FALSE, FALSE,
 'Diagnostic: scalable strength, to be validated later by P7G/P7H/P7J.'),
('OPPORTUNITY_TO_ACCELERATE', 'Opportunité à accélérer', 0.600, TRUE, FALSE, FALSE,
 'Diagnostic: opportunity candidate, not yet forecast-backed.'),
('OBSERVATION_TO_MONITOR', 'Observation à surveiller', 0.000, TRUE, FALSE, FALSE,
 'Diagnostic: monitoring theme without strong SWOT evidence.');

-- ------------------------------------------------------------
-- Candidate intervention family policy by pillar.
-- ------------------------------------------------------------
DROP TABLE IF EXISTS rf.isa_candidate_intervention_family CASCADE;
CREATE TABLE rf.isa_candidate_intervention_family (
    pillar_code                 VARCHAR(10) PRIMARY KEY,
    intervention_family_code    VARCHAR(60) NOT NULL,
    intervention_family_label   TEXT NOT NULL,
    strategic_objective         TEXT NOT NULL,
    default_recommended_action  TEXT NOT NULL,
    consultation_theme          TEXT NOT NULL,
    updated_at                  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO rf.isa_candidate_intervention_family (
    pillar_code, intervention_family_code, intervention_family_label,
    strategic_objective, default_recommended_action, consultation_theme
)
VALUES
('PECO','ECONOMIC_DIVERSIFICATION','Diversification économique','Réduire la vulnérabilité macroéconomique et renforcer la base productive.','DIAGNOSTIC_INTERVENTION_CANDIDATE','Débat public sur la diversification productive et les chaînes de valeur.'),
('PENV','ENVIRONMENTAL_RESILIENCE','Résilience environnementale','Réduire les pressions climatiques et environnementales observées.','DIAGNOSTIC_INTERVENTION_CANDIDATE','Consultation sur les risques climatiques, déchets, pollution et foncier écologique.'),
('PGEO','GOVERNANCE_AND_STABILITY','Gouvernance géopolitique et stabilité','Réduire les fragilités géopolitiques, territoriales et institutionnelles.','DIAGNOSTIC_INTERVENTION_CANDIDATE','Consultation sur stabilité, conflits, cohésion et influence régionale.'),
('PHUM','HUMAN_CAPITAL','Capital humain','Renforcer santé, éducation, pauvreté et inclusion sociale.','DIAGNOSTIC_INTERVENTION_CANDIDATE','Consultation sur capital humain, jeunesse, santé et pauvreté.'),
('PMIL','SECURITY_RESILIENCE','Résilience sécuritaire','Réduire les risques sécuritaires et renforcer la souveraineté de défense.','DIAGNOSTIC_INTERVENTION_CANDIDATE','Consultation sur sécurité intérieure, défense et résilience.'),
('PMIN','MINING_VALUE_CHAIN','Chaîne de valeur minière','Transformer les ressources minières en souveraineté productive.','DIAGNOSTIC_INTERVENTION_CANDIDATE','Consultation sur traçabilité, certification et transformation minière.'),
('PMON','MONETARY_FINANCIAL_RESILIENCE','Résilience monétaire et financière','Réduire les dépendances financières et monétaires observées.','DIAGNOSTIC_INTERVENTION_CANDIDATE','Consultation sur dette, inflation, change et autonomie monétaire.'),
('PNUM','DIGITAL_SOVEREIGNTY','Souveraineté numérique','Renforcer les infrastructures, compétences et gouvernance numériques.','DIAGNOSTIC_INTERVENTION_CANDIDATE','Consultation sur connectivité, cybersécurité, e-gouvernement et données.'),
('PRES','ENERGY_WATER_CERTIFICATION','Certification énergie-eau','Fiabiliser les données physiques énergie/eau et renforcer la souveraineté ressources.','DIAGNOSTIC_INTERVENTION_CANDIDATE','Consultation sur énergie, eau, données physiques et certification.'),
('PTRA','TRANSPORT_LOGISTICS','Transport et logistique','Renforcer corridors, infrastructures et résilience logistique.','DIAGNOSTIC_INTERVENTION_CANDIDATE','Consultation sur routes, ports, hubs, logistique et interconnexion.');

-- ------------------------------------------------------------
-- Public consultation policy.
-- ------------------------------------------------------------
DROP TABLE IF EXISTS rf.isa_public_consultation_policy CASCADE;
CREATE TABLE rf.isa_public_consultation_policy (
    consultation_topic_type VARCHAR(60) PRIMARY KEY,
    topic_label             TEXT NOT NULL,
    min_priority_score      NUMERIC(5,3) NOT NULL DEFAULT 0.000,
    public_open             BOOLEAN NOT NULL DEFAULT TRUE,
    notes                   TEXT,
    updated_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO rf.isa_public_consultation_policy (
    consultation_topic_type, topic_label, min_priority_score, public_open, notes
)
VALUES
('WEAKNESS_DIAGNOSTIC_REVIEW','Revue publique des faiblesses observées',0.550,TRUE,'Open consultation to review observed weaknesses.'),
('RISK_EVIDENCE_REVIEW','Revue des preuves de risque et menace',0.600,TRUE,'Evidence-oriented consultation for threats and risks.'),
('STRENGTH_REPLICATION_FEEDBACK','Retours sur forces réplicables',0.550,TRUE,'Consultation to document scalable strengths.'),
('OPPORTUNITY_EXPLORATION_FEEDBACK','Exploration publique des opportunités',0.600,TRUE,'Consultation to qualify opportunities before predictive validation.'),
('GENERAL_OBSERVATORY_FEEDBACK','Feedback général observatoire',0.000,TRUE,'General comments and diagnostic review.');

DO $$
DECLARE c INT;
BEGIN
    SELECT COUNT(*) INTO c FROM rf.isa_strategic_diagnostic_policy;
    RAISE NOTICE 'P7F diagnostic policy lignes : %', c;
END $$;

COMMIT;
