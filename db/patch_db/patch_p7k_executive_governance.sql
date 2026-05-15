-- ============================================================
-- OSA / ISA OBSERVATORY
-- P7K — Executive Pre-Governance / Board Preparation
-- ============================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS rf;
CREATE SCHEMA IF NOT EXISTS ma;
CREATE SCHEMA IF NOT EXISTS mg;

CREATE TABLE IF NOT EXISTS rf.package_lifecycle (
    package_code VARCHAR(20) PRIMARY KEY,
    package_label TEXT NOT NULL DEFAULT '',
    package_status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
    replacement_package VARCHAR(20),
    notes TEXT,
    updated_at TIMESTAMP DEFAULT NOW()
);

ALTER TABLE rf.package_lifecycle
    ADD COLUMN IF NOT EXISTS package_label TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS package_status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
    ADD COLUMN IF NOT EXISTS replacement_package VARCHAR(20),
    ADD COLUMN IF NOT EXISTS notes TEXT,
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT NOW();

DELETE FROM rf.package_lifecycle WHERE package_code = 'P7K';

INSERT INTO rf.package_lifecycle (
    package_code, package_label, package_status, replacement_package, notes, updated_at
)
VALUES (
    'P7K',
    'Executive Pre-Governance / Board Preparation',
    'ACTIVE',
    NULL,
    'P7K Executive Pre-Governance layer. Prepares board-ready dossiers, structures sovereign portfolios and identifies pre-governance candidates. Pending P7Z predictive quantification and P8 publication. Not final executive arbitration — outputs are pre-governance signals.',
    NOW()
);

DROP TABLE IF EXISTS rf.isa_executive_governance_policy CASCADE;
CREATE TABLE rf.isa_executive_governance_policy (
    executive_decision_class VARCHAR(40) PRIMARY KEY,
    min_executive_score NUMERIC(6,3) NOT NULL,
    max_executive_score NUMERIC(6,3) NOT NULL,
    executive_rank INTEGER NOT NULL,
    executive_action_code VARCHAR(40) NOT NULL,
    executive_track VARCHAR(60) NOT NULL,
    board_visibility BOOLEAN NOT NULL DEFAULT TRUE,
    policy_note TEXT
);

INSERT INTO rf.isa_executive_governance_policy VALUES
    ('EXEC_BOARD_PREPARED', 0.750, 1.001, 4, 'SUBMIT_TO_BOARD', 'EXECUTIVE_BOARD', TRUE, 'Pre-board preparation ready. Requires P7Z impact quantification before final board submission. [P7K pre-governance signal, not final arbitration]'),
    ('EXEC_FAST_TRACK_CANDIDATE',     0.600, 0.750, 3, 'FAST_TRACK_REVIEW', 'HIGH_PRIORITY_PORTFOLIO', TRUE, 'Fast-track candidate for executive review. Pre-governance signal pending P7Z and P8 validation.'),
    ('EXEC_PROGRAMME_CANDIDATE',      0.400, 0.600, 2, 'PROGRAMME_PIPELINE', 'STANDARD_PROGRAMME', TRUE, 'Programme candidate. Pre-governance signal — programme note to be confirmed after P7Z quantification.'),
    ('EXEC_WATCHLIST',      0.000, 0.400, 1, 'WATCH_AND_DOCUMENT', 'OBSERVATORY_WATCHLIST', FALSE, 'Monitoring, documentation and periodic update.');

DROP TABLE IF EXISTS rf.isa_executive_budget_band_policy CASCADE;
CREATE TABLE rf.isa_executive_budget_band_policy (
    budget_band_code VARCHAR(40) PRIMARY KEY,
    min_budget_pressure NUMERIC(6,3) NOT NULL,
    max_budget_pressure NUMERIC(6,3) NOT NULL,
    budget_arbitration_label TEXT NOT NULL,
    budget_action_code VARCHAR(40) NOT NULL,
    policy_note TEXT
);

INSERT INTO rf.isa_executive_budget_band_policy VALUES
    ('LOW_BUDGET_PRESSURE',      0.000, 0.350, 'Low budget pressure', 'FINANCE_WITHIN_PROGRAMME', 'Can be handled through ordinary programme planning.'),
    ('MEDIUM_BUDGET_PRESSURE',   0.350, 0.600, 'Medium budget pressure', 'REQUIRE_BUDGET_ARBITRATION', 'Requires budget phasing or targeted financing.'),
    ('HIGH_BUDGET_PRESSURE',     0.600, 0.800, 'High budget pressure', 'REQUIRE_EXECUTIVE_ARBITRATION', 'Requires executive-level budget arbitration.'),
    ('CRITICAL_BUDGET_PRESSURE', 0.800, 1.001, 'Critical budget pressure', 'ESCALATE_TO_FINANCE_BOARD', 'Requires board-level financing decision.');

DROP TABLE IF EXISTS rf.isa_executive_escalation_policy CASCADE;
CREATE TABLE rf.isa_executive_escalation_policy (
    escalation_level_code VARCHAR(40) PRIMARY KEY,
    min_governance_risk NUMERIC(6,3) NOT NULL,
    max_governance_risk NUMERIC(6,3) NOT NULL,
    escalation_target TEXT NOT NULL,
    escalation_action TEXT NOT NULL,
    policy_note TEXT
);

INSERT INTO rf.isa_executive_escalation_policy VALUES
    ('MINISTRY_TRACK',    0.000, 0.400, 'Line ministry / technical authority', 'Prepare technical note and monitoring update.', 'Technical monitoring level.'),
    ('CABINET_TRACK',    0.400, 0.600, 'Cabinet / interministerial committee', 'Prepare interministerial decision memo.', 'Requires cross-sector coordination.'),
    ('PRIMATURE_TRACK',  0.600, 0.800, 'Prime Minister / national coordination', 'Escalate to national coordination review.', 'Requires national coordination.'),
    ('PRESIDENCY_TRACK', 0.800, 1.001, 'Presidency / sovereign board', 'Escalate to sovereign executive board.', 'Highest sovereign escalation level.');

DROP TABLE IF EXISTS rf.isa_executive_pillar_weight CASCADE;
CREATE TABLE rf.isa_executive_pillar_weight (
    pillar_code VARCHAR(20) PRIMARY KEY,
    executive_weight NUMERIC(6,3) NOT NULL,
    budget_pressure_weight NUMERIC(6,3) NOT NULL,
    governance_complexity_weight NUMERIC(6,3) NOT NULL,
    pillar_governance_note TEXT
);

INSERT INTO rf.isa_executive_pillar_weight VALUES
    ('PMON', 1.15, 0.75, 1.10, 'Monetary and financial sovereignty has strong executive sensitivity.'),
    ('PRES', 1.12, 0.95, 0.95, 'Energy and water sovereignty often require investment and infrastructure arbitration.'),
    ('PNUM', 1.10, 0.85, 0.85, 'Digital sovereignty has high transformation leverage.'),
    ('PTRA', 1.08, 1.00, 0.90, 'Transport and logistics often require capital-intensive phasing.'),
    ('PGEO', 1.05, 0.55, 1.20, 'Geopolitical issues require governance and diplomatic coordination.'),
    ('PMIL', 1.04, 0.90, 1.10, 'Security resilience requires controlled governance escalation.'),
    ('PMIN', 1.03, 0.85, 0.95, 'Mining value chains require investment and regulatory governance.'),
    ('PENV', 1.02, 0.75, 0.90, 'Environmental resilience requires medium-term programme governance.'),
    ('PECO', 1.00, 0.70, 0.80, 'Economic diversification is portfolio-sensitive.'),
    ('PHUM', 1.00, 0.65, 0.80, 'Human capital is strategic but often programme-based.');

DO $$
DECLARE n1 INTEGER; n2 INTEGER; n3 INTEGER; n4 INTEGER;
BEGIN
    SELECT COUNT(*) INTO n1 FROM rf.isa_executive_governance_policy;
    SELECT COUNT(*) INTO n2 FROM rf.isa_executive_budget_band_policy;
    SELECT COUNT(*) INTO n3 FROM rf.isa_executive_escalation_policy;
    SELECT COUNT(*) INTO n4 FROM rf.isa_executive_pillar_weight;
    RAISE NOTICE 'P7K policies: governance=%, budget=%, escalation=%, pillar_weight=%', n1, n2, n3, n4;
END $$;

COMMIT;
