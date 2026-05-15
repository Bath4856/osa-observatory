/*
============================================================
OSA / ISA OBSERVATORY — P7I
Early Warning & Risk Intelligence
Patch RF/MG policies
============================================================
*/

BEGIN;

CREATE SCHEMA IF NOT EXISTS rf;
CREATE SCHEMA IF NOT EXISTS ma;
CREATE SCHEMA IF NOT EXISTS mg;

CREATE TABLE IF NOT EXISTS mg.package_lifecycle (
    package_code VARCHAR(20) PRIMARY KEY,
    package_label TEXT NOT NULL DEFAULT 'Unlabelled package',
    package_status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
    replacement_package VARCHAR(20),
    notes TEXT,
    updated_at TIMESTAMP DEFAULT now()
);

ALTER TABLE mg.package_lifecycle ADD COLUMN IF NOT EXISTS package_label TEXT;
ALTER TABLE mg.package_lifecycle ADD COLUMN IF NOT EXISTS package_status VARCHAR(30);
ALTER TABLE mg.package_lifecycle ADD COLUMN IF NOT EXISTS replacement_package VARCHAR(20);
ALTER TABLE mg.package_lifecycle ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE mg.package_lifecycle ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT now();

UPDATE mg.package_lifecycle
SET package_label = COALESCE(package_label, package_code, 'Unlabelled package'),
    package_status = COALESCE(package_status, 'ACTIVE'),
    updated_at = now()
WHERE package_label IS NULL OR package_status IS NULL;

INSERT INTO mg.package_lifecycle(package_code, package_label, package_status, replacement_package, notes, updated_at)
VALUES (
    'P7I',
    'Early Warning & Risk Intelligence Engine',
    'ACTIVE',
    NULL,
    'P7I transforms P7F diagnostics, P7G forecast intelligence and P7H scenario simulations into sovereign early-warning alerts: GREEN, YELLOW, ORANGE, RED.',
    now()
)
ON CONFLICT (package_code) DO UPDATE
SET package_label = EXCLUDED.package_label,
    package_status = EXCLUDED.package_status,
    replacement_package = EXCLUDED.replacement_package,
    notes = EXCLUDED.notes,
    updated_at = now();

DROP TABLE IF EXISTS rf.isa_early_warning_policy CASCADE;
CREATE TABLE rf.isa_early_warning_policy (
    alert_level VARCHAR(20) PRIMARY KEY,
    alert_rank INT NOT NULL,
    min_risk_score NUMERIC(6,3) NOT NULL,
    max_risk_score NUMERIC(6,3) NOT NULL,
    alert_label TEXT NOT NULL,
    recommended_governance_action TEXT NOT NULL,
    public_visibility BOOLEAN NOT NULL DEFAULT TRUE,
    policy_notes TEXT
);

INSERT INTO rf.isa_early_warning_policy (
    alert_level, alert_rank, min_risk_score, max_risk_score,
    alert_label, recommended_governance_action, public_visibility, policy_notes
) VALUES
('GREEN',  1, 0.000, 0.250, 'Situation suivie', 'Monitor through ordinary observatory cycle.', TRUE,  'Low sovereign risk signal.'),
('YELLOW', 2, 0.250, 0.500, 'Attention requise', 'Document risk evidence and open public/expert review.', TRUE, 'Moderate sovereign risk signal.'),
('ORANGE', 3, 0.500, 0.750, 'Alerte stratégique', 'Trigger policy review and intervention prioritization.', TRUE, 'High sovereign risk signal requiring intervention review.'),
('RED',    4, 0.750, 1.000, 'Alerte critique', 'Escalate to institutional review and urgent mitigation planning.', TRUE, 'Critical sovereign risk signal.');

DROP TABLE IF EXISTS rf.isa_early_warning_pillar_weight CASCADE;
CREATE TABLE rf.isa_early_warning_pillar_weight (
    pillar_code VARCHAR(20) PRIMARY KEY,
    pillar_label TEXT NOT NULL,
    systemic_weight NUMERIC(6,3) NOT NULL,
    fragility_weight NUMERIC(6,3) NOT NULL,
    propagation_weight NUMERIC(6,3) NOT NULL,
    policy_notes TEXT
);

INSERT INTO rf.isa_early_warning_pillar_weight (
    pillar_code, pillar_label, systemic_weight, fragility_weight, propagation_weight, policy_notes
) VALUES
('PGEO', 'Geopolitical sovereignty',       1.250, 1.300, 1.250, 'Geopolitics is treated as systemic early-warning signal, even when forecast confidence is low.'),
('PMIL', 'Military and security',          1.150, 1.200, 1.150, 'Security deterioration may propagate to other pillars.'),
('PMON', 'Monetary sovereignty',           1.100, 1.100, 1.150, 'Monetary stress can amplify macroeconomic fragility.'),
('PENV', 'Environmental sovereignty',      1.050, 1.150, 1.100, 'Climate/environmental stress may trigger structural vulnerabilities.'),
('PRES', 'Energy and water sovereignty',   1.100, 1.150, 1.100, 'Energy/water stress is a critical resilience risk.'),
('PTRA', 'Transport and logistics',        1.000, 1.000, 1.050, 'Transport fragility affects territorial continuity.'),
('PNUM', 'Digital sovereignty',            1.000, 1.000, 1.050, 'Digital fragility affects service continuity.'),
('PMIN', 'Mining sovereignty',             0.950, 0.950, 1.000, 'Mining stress matters through dependence and value chain exposure.'),
('PECO', 'Economic sovereignty',           1.000, 1.000, 1.100, 'Economic stress affects multiple pillars.'),
('PHUM', 'Human sovereignty',              1.050, 1.100, 1.050, 'Human fragility is core to sovereign resilience.');

DROP TABLE IF EXISTS rf.isa_risk_escalation_policy CASCADE;
CREATE TABLE rf.isa_risk_escalation_policy (
    escalation_class VARCHAR(40) PRIMARY KEY,
    min_risk_delta NUMERIC(6,3) NOT NULL,
    max_risk_delta NUMERIC(6,3) NOT NULL,
    escalation_label TEXT NOT NULL,
    escalation_action TEXT NOT NULL
);

INSERT INTO rf.isa_risk_escalation_policy (
    escalation_class, min_risk_delta, max_risk_delta, escalation_label, escalation_action
) VALUES
('RISK_DE_ESCALATING', -1.000, -0.050, 'Risque en baisse', 'Maintain monitoring and document improvement evidence.'),
('RISK_STABLE',       -0.050,  0.050, 'Risque stable', 'Continue ordinary monitoring.'),
('RISK_ESCALATING',    0.050,  0.150, 'Risque en hausse', 'Open targeted diagnostic review.'),
('RISK_SURGING',       0.150,  1.000, 'Risque en forte hausse', 'Trigger urgent strategic warning review.');

DROP TABLE IF EXISTS rf.isa_priority_alert_policy CASCADE;
CREATE TABLE rf.isa_priority_alert_policy (
    priority_class VARCHAR(40) PRIMARY KEY,
    min_priority_score NUMERIC(6,3) NOT NULL,
    max_priority_score NUMERIC(6,3) NOT NULL,
    priority_label TEXT NOT NULL,
    intervention_action TEXT NOT NULL
);

INSERT INTO rf.isa_priority_alert_policy (
    priority_class, min_priority_score, max_priority_score, priority_label, intervention_action
) VALUES
('PRIORITY_MONITOR',   0.000, 0.350, 'Suivi', 'Document and monitor.'),
('PRIORITY_STANDARD',  0.350, 0.600, 'Priorité standard', 'Prepare diagnostic note and public consultation.'),
('PRIORITY_HIGH',      0.600, 0.800, 'Priorité élevée', 'Prepare targeted intervention concept note.'),
('PRIORITY_CRITICAL',  0.800, 1.000, 'Priorité critique', 'Prepare urgent mitigation package and expert review.');

DO $$
DECLARE n1 INT; n2 INT; n3 INT; n4 INT;
BEGIN
    SELECT COUNT(*) INTO n1 FROM rf.isa_early_warning_policy;
    SELECT COUNT(*) INTO n2 FROM rf.isa_early_warning_pillar_weight;
    SELECT COUNT(*) INTO n3 FROM rf.isa_risk_escalation_policy;
    SELECT COUNT(*) INTO n4 FROM rf.isa_priority_alert_policy;
    RAISE NOTICE 'P7I policies : warning=%, pillar_weight=%, escalation=%, priority=%', n1, n2, n3, n4;
END $$;

COMMIT;
