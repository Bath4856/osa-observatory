-- ============================================================
-- OSA / ISA OBSERVATORY
-- P7H — Scenario Simulation Intelligence Engine
-- Patch RF/MG policies
-- ============================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS rf;
CREATE SCHEMA IF NOT EXISTS ma;
CREATE SCHEMA IF NOT EXISTS mg;

-- Package lifecycle — compatible with existing shape used by P7F/P7G
CREATE TABLE IF NOT EXISTS mg.package_lifecycle (
    package_code VARCHAR(20) PRIMARY KEY,
    package_label TEXT,
    package_status VARCHAR(30) NOT NULL,
    replacement_package VARCHAR(20),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE mg.package_lifecycle ADD COLUMN IF NOT EXISTS package_label TEXT;
ALTER TABLE mg.package_lifecycle ADD COLUMN IF NOT EXISTS package_status VARCHAR(30);
ALTER TABLE mg.package_lifecycle ADD COLUMN IF NOT EXISTS replacement_package VARCHAR(20);
ALTER TABLE mg.package_lifecycle ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE mg.package_lifecycle ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
UPDATE mg.package_lifecycle
SET package_label = COALESCE(package_label, package_code)
WHERE package_label IS NULL;

INSERT INTO mg.package_lifecycle (
    package_code, package_label, package_status, replacement_package, notes
) VALUES (
    'P7H',
    'Scenario Simulation Intelligence Engine',
    'ACTIVE',
    NULL,
    'P7H produces deterministic what-if and policy/investment scenario simulations from P7F diagnostics and P7G forecast intelligence. It does not publish, certify, or monetize outputs.'
)
ON CONFLICT (package_code) DO UPDATE SET
    package_label = EXCLUDED.package_label,
    package_status = EXCLUDED.package_status,
    replacement_package = EXCLUDED.replacement_package,
    notes = EXCLUDED.notes;

DROP TABLE IF EXISTS rf.isa_scenario_policy CASCADE;
CREATE TABLE rf.isa_scenario_policy (
    scenario_code VARCHAR(30) PRIMARY KEY,
    scenario_label TEXT NOT NULL,
    scenario_family VARCHAR(30) NOT NULL,
    intervention_intensity NUMERIC(6,3) NOT NULL,
    risk_adjustment_factor NUMERIC(6,3) NOT NULL,
    confidence_adjustment_factor NUMERIC(6,3) NOT NULL,
    max_positive_delta NUMERIC(6,3) NOT NULL,
    max_negative_delta NUMERIC(6,3) NOT NULL,
    include_in_public_simulation BOOLEAN NOT NULL DEFAULT TRUE,
    simulation_notes TEXT
);

INSERT INTO rf.isa_scenario_policy VALUES
('BASELINE',     'Baseline / inertiel',            'BASELINE',     0.000, 1.000, 1.000, 0.000, 0.000, TRUE,  'No policy shock. Reference trajectory.'),
('CONSERVATIVE', 'Scénario prudent',               'POLICY',       0.250, 0.850, 0.900, 0.040, 0.030, TRUE,  'Low-intensity reform or limited investment.'),
('CENTRAL',      'Scénario central',               'POLICY',       0.500, 1.000, 1.000, 0.080, 0.050, TRUE,  'Reasonable intervention path; preferred benchmark.'),
('AMBITIOUS',    'Scénario ambitieux',             'INVESTMENT',   0.800, 1.100, 0.950, 0.140, 0.070, TRUE,  'High-intensity policy and investment acceleration.'),
('STRESS',       'Scénario stress / choc négatif', 'STRESS',      -0.500, 1.200, 0.850, 0.000, 0.120, FALSE, 'Negative shock scenario for resilience testing.');

DROP TABLE IF EXISTS rf.isa_scenario_pillar_elasticity CASCADE;
CREATE TABLE rf.isa_scenario_pillar_elasticity (
    pillar_code VARCHAR(20) PRIMARY KEY,
    pillar_label TEXT NOT NULL,
    isa_elasticity NUMERIC(6,3) NOT NULL,
    sovereignty_elasticity NUMERIC(6,3) NOT NULL,
    vulnerability_elasticity NUMERIC(6,3) NOT NULL,
    resilience_elasticity NUMERIC(6,3) NOT NULL,
    simulation_floor NUMERIC(6,3) NOT NULL DEFAULT -0.150,
    simulation_ceiling NUMERIC(6,3) NOT NULL DEFAULT 0.150,
    notes TEXT
);

INSERT INTO rf.isa_scenario_pillar_elasticity VALUES
('PECO','Économie',                  0.100, 0.080, 0.060, 0.070, -0.150, 0.150, 'Economic diversification and employment impact.'),
('PENV','Environnement',             0.080, 0.070, 0.090, 0.100, -0.150, 0.140, 'Environmental resilience and risk attenuation.'),
('PGEO','Géopolitique',              0.040, 0.050, 0.120, 0.060, -0.160, 0.100, 'Contextual and risk-sensitive; simulations remain cautious.'),
('PHUM','Humain',                    0.090, 0.080, 0.070, 0.100, -0.140, 0.150, 'Human capital and social resilience.'),
('PMIL','Sécurité / militaire',      0.060, 0.070, 0.110, 0.080, -0.160, 0.120, 'Security resilience; high risk adjustment.'),
('PMIN','Mines',                     0.100, 0.120, 0.080, 0.070, -0.130, 0.160, 'Value chain, certification and extraction sovereignty.'),
('PMON','Monétaire',                 0.080, 0.100, 0.100, 0.080, -0.150, 0.130, 'Debt, reserves, exchange, financial autonomy.'),
('PNUM','Numérique',                 0.110, 0.100, 0.060, 0.080, -0.120, 0.170, 'Digital infrastructure and sovereignty acceleration.'),
('PRES','Énergie / eau',             0.120, 0.130, 0.090, 0.090, -0.150, 0.180, 'Energy-water certification and strategic infrastructure.'),
('PTRA','Transport / logistique',    0.110, 0.090, 0.070, 0.080, -0.130, 0.170, 'Corridors, roads, ports, airports and logistics.');

DROP TABLE IF EXISTS rf.isa_scenario_readiness_policy CASCADE;
CREATE TABLE rf.isa_scenario_readiness_policy (
    readiness_code VARCHAR(40) PRIMARY KEY,
    min_simulation_confidence NUMERIC(6,3) NOT NULL,
    min_scenario_rows INT NOT NULL,
    readiness_label TEXT NOT NULL,
    notes TEXT
);

INSERT INTO rf.isa_scenario_readiness_policy VALUES
('SCENARIO_READY_STRONG',      0.700, 100, 'Simulation robuste', 'Strong enough for controlled scenario interpretation.'),
('SCENARIO_READY_CONTROLLED',  0.550,  50, 'Simulation contrôlée', 'Use with monitoring and evidence review.'),
('SCENARIO_INDICATIVE',        0.400,   1, 'Simulation indicative', 'Use as indicative signal only.'),
('SCENARIO_REVIEW_REQUIRED',   0.000,   0, 'Revue requise', 'Insufficient simulation confidence or coverage.');

DO $$
DECLARE n INT;
BEGIN
    SELECT COUNT(*) INTO n FROM rf.isa_scenario_policy;
    RAISE NOTICE 'P7H scenario policy lignes : %', n;
END $$;

COMMIT;
