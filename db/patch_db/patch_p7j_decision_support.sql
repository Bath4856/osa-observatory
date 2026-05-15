-- ============================================================
-- OSA / ISA OBSERVATORY
-- P7J — Decision Support & Intervention Prioritization
-- Patch: policies and lifecycle
-- ============================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS rf;
CREATE SCHEMA IF NOT EXISTS ma;
CREATE SCHEMA IF NOT EXISTS mg;

-- Package lifecycle, compatible with prior P7 packages
CREATE TABLE IF NOT EXISTS mg.package_lifecycle (
    package_code        VARCHAR(20) PRIMARY KEY,
    package_label       TEXT NOT NULL DEFAULT '',
    package_status      VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
    replacement_package VARCHAR(20),
    notes               TEXT,
    updated_at          TIMESTAMP NOT NULL DEFAULT NOW()
);

ALTER TABLE mg.package_lifecycle ADD COLUMN IF NOT EXISTS package_label TEXT NOT NULL DEFAULT '';
ALTER TABLE mg.package_lifecycle ADD COLUMN IF NOT EXISTS package_status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE';
ALTER TABLE mg.package_lifecycle ADD COLUMN IF NOT EXISTS replacement_package VARCHAR(20);
ALTER TABLE mg.package_lifecycle ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE mg.package_lifecycle ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP NOT NULL DEFAULT NOW();

DELETE FROM mg.package_lifecycle WHERE package_code = 'P7J';
INSERT INTO mg.package_lifecycle (
    package_code,
    package_label,
    package_status,
    replacement_package,
    notes,
    updated_at
) VALUES (
    'P7J',
    'Decision Support & Intervention Prioritization',
    'ACTIVE',
    NULL,
    'P7J transforms P7F diagnostics, P7H scenario simulations and P7I early-warning alerts into decision priorities: what to do, where, when, and with what level of urgency.',
    NOW()
);

-- Decision priority policy
DROP TABLE IF EXISTS rf.isa_decision_priority_policy CASCADE;
CREATE TABLE rf.isa_decision_priority_policy (
    decision_priority_class VARCHAR(40) PRIMARY KEY,
    min_decision_score      NUMERIC(6,3) NOT NULL,
    max_decision_score      NUMERIC(6,3) NOT NULL,
    decision_rank           INTEGER NOT NULL,
    decision_label          TEXT NOT NULL,
    decision_action         TEXT NOT NULL,
    governance_track        TEXT NOT NULL,
    public_decision_scope   TEXT NOT NULL,
    policy_notes            TEXT
);

INSERT INTO rf.isa_decision_priority_policy VALUES
('DECISION_MONITOR',       0.000, 0.350, 1, 'Monitoring',              'Document and monitor through observatory follow-up.',              'OBSERVATORY_MONITORING',     'OPEN_DATA_DIAGNOSTIC', 'Low decision urgency.'),
('DECISION_STANDARD',      0.350, 0.550, 2, 'Standard intervention',   'Prepare a structured opportunity note and stakeholder review.',    'STANDARD_POLICY_REVIEW',     'OPEN_DATA_OPPORTUNITY', 'Normal decision support.'),
('DECISION_HIGH',          0.550, 0.750, 3, 'High-priority decision',  'Trigger policy prioritization and technical scoping.',             'HIGH_PRIORITY_REVIEW',       'EXPERT_REVIEW', 'Strong decision signal.'),
('DECISION_CRITICAL',      0.750, 1.001, 4, 'Critical decision',       'Escalate to institutional decision board and urgent action plan.',  'CRITICAL_DECISION_BOARD',    'INSTITUTIONAL_REVIEW', 'Critical sovereign decision signal.');

-- Timing policy
DROP TABLE IF EXISTS rf.isa_decision_timing_policy CASCADE;
CREATE TABLE rf.isa_decision_timing_policy (
    decision_timing_code VARCHAR(40) PRIMARY KEY,
    timing_rank          INTEGER NOT NULL,
    timing_label         TEXT NOT NULL,
    timing_rule          TEXT NOT NULL,
    max_months           INTEGER,
    policy_notes         TEXT
);

INSERT INTO rf.isa_decision_timing_policy VALUES
('IMMEDIATE_0_3_MONTHS',  4, 'Immediate',     'Critical or RED-related action.',       3,  'Act in the current institutional cycle.'),
('SHORT_TERM_3_12_MONTHS',3, 'Short term',    'High-priority action.',                12, 'Prepare and launch within one year.'),
('MEDIUM_TERM_1_3_YEARS', 2, 'Medium term',   'Standard policy action.',              36, 'Integrate into strategic planning.'),
('MONITORING_ONLY',       1, 'Monitoring',    'Observation and evidence improvement.', NULL, 'No immediate intervention required.');

-- Decision pillar sensitivity policy
DROP TABLE IF EXISTS rf.isa_decision_pillar_sensitivity CASCADE;
CREATE TABLE rf.isa_decision_pillar_sensitivity (
    pillar_code              VARCHAR(10) PRIMARY KEY,
    decision_sensitivity     NUMERIC(6,3) NOT NULL,
    systemic_importance      NUMERIC(6,3) NOT NULL,
    intervention_complexity  NUMERIC(6,3) NOT NULL,
    sensitivity_notes        TEXT
);

INSERT INTO rf.isa_decision_pillar_sensitivity VALUES
('PMIN', 1.050, 1.050, 0.850, 'Mining value-chain and strategic resource leverage.'),
('PMON', 1.120, 1.150, 0.900, 'Monetary and financial systemic sovereignty.'),
('PECO', 1.080, 1.100, 0.850, 'Economic diversification and productive capacity.'),
('PGEO', 0.850, 1.000, 1.100, 'Geopolitical context requires expert interpretation.'),
('PMIL', 1.000, 1.100, 1.050, 'Security and defense readiness.'),
('PHUM', 1.050, 1.050, 0.800, 'Human capital and social resilience.'),
('PENV', 1.050, 1.100, 0.950, 'Environmental and climate resilience.'),
('PNUM', 1.100, 1.050, 0.800, 'Digital sovereignty and GovTech leverage.'),
('PRES', 1.120, 1.150, 0.900, 'Energy, water and resource sovereignty.'),
('PTRA', 1.050, 1.050, 0.850, 'Transport, logistics and territorial integration.');

DO $$
DECLARE
    c1 INTEGER;
    c2 INTEGER;
    c3 INTEGER;
BEGIN
    SELECT COUNT(*) INTO c1 FROM rf.isa_decision_priority_policy;
    SELECT COUNT(*) INTO c2 FROM rf.isa_decision_timing_policy;
    SELECT COUNT(*) INTO c3 FROM rf.isa_decision_pillar_sensitivity;
    RAISE NOTICE 'P7J policies: priority=%, timing=%, pillar_sensitivity=%', c1, c2, c3;
END $$;

COMMIT;
