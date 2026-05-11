-- ============================================================
-- OSA / ISA — P7C
-- Patch RF : Dynamic Aggregation Policy
-- Purpose:
--   Define aggregation policy by semantic family for ISA dynamic aggregation.
-- ============================================================

BEGIN;

CREATE TABLE IF NOT EXISTS rf.dynamic_aggregation_policy (
    semantic_code VARCHAR(30) PRIMARY KEY,
    aggregation_mode VARCHAR(40) NOT NULL,
    pillar_weight_factor NUMERIC(6,3) NOT NULL DEFAULT 1.000,
    isa_score_factor NUMERIC(6,3) NOT NULL DEFAULT 1.000,
    vulnerability_factor NUMERIC(6,3) NOT NULL DEFAULT 1.000,
    resilience_factor NUMERIC(6,3) NOT NULL DEFAULT 1.000,
    min_aggregation_weight NUMERIC(6,3) NOT NULL DEFAULT 0.050,
    max_aggregation_weight NUMERIC(6,3) NOT NULL DEFAULT 1.250,
    include_in_core_isa BOOLEAN NOT NULL DEFAULT TRUE,
    include_in_vulnerability_index BOOLEAN NOT NULL DEFAULT TRUE,
    include_in_resilience_index BOOLEAN NOT NULL DEFAULT TRUE,
    notes TEXT,
    updated_at TIMESTAMP DEFAULT now()
);

INSERT INTO rf.dynamic_aggregation_policy (
    semantic_code,
    aggregation_mode,
    pillar_weight_factor,
    isa_score_factor,
    vulnerability_factor,
    resilience_factor,
    min_aggregation_weight,
    max_aggregation_weight,
    include_in_core_isa,
    include_in_vulnerability_index,
    include_in_resilience_index,
    notes
)
VALUES
('PHYSICAL',   'CERTIFIED_CORE',        1.150, 1.120, 0.850, 0.950, 0.050, 1.250, TRUE,  TRUE,  TRUE,  'Physical signals: core only when not locked; otherwise gap-aware.'),
('STOCK',      'RESOURCE_STOCK_CORE',   1.100, 1.080, 0.850, 0.950, 0.050, 1.200, TRUE,  TRUE,  TRUE,  'Stocks and reserves: strong sovereign capacity when trusted.'),
('STRUCTURAL', 'STRUCTURAL_CORE',       1.080, 1.100, 0.800, 1.050, 0.050, 1.200, TRUE,  TRUE,  TRUE,  'Structural capacity: core ISA and resilience.'),
('GOVERNANCE', 'GOVERNANCE_CORE',       1.000, 1.000, 0.900, 0.950, 0.050, 1.150, TRUE,  TRUE,  TRUE,  'Governance: institutional sovereignty.'),
('RESILIENCE', 'RESILIENCE_CORE',       1.000, 1.000, 0.750, 1.150, 0.050, 1.150, TRUE,  TRUE,  TRUE,  'Resilience: stabilizing factor.'),
('NETWORK',    'NETWORK_CONTROLLED',    0.950, 0.950, 0.950, 0.900, 0.050, 1.100, TRUE,  TRUE,  TRUE,  'Network signals: controlled operational aggregation.'),
('FLOW',       'FLOW_CONTROLLED',       0.900, 0.900, 1.000, 0.850, 0.050, 1.050, TRUE,  TRUE,  TRUE,  'Flows: dynamic but volatile.'),
('COMPOSITE',  'COMPONENT_DEPENDENT',   0.850, 0.850, 0.900, 0.850, 0.050, 1.000, TRUE,  TRUE,  TRUE,  'Composite: dependent on component quality.'),
('DEPENDENCY', 'VULNERABILITY_SIGNAL',  0.700, 0.650, 1.250, 0.650, 0.050, 1.250, FALSE, TRUE,  FALSE, 'Dependency: vulnerability signal, not core sovereign capacity.'),
('PRESSURE',   'RISK_SIGNAL',           0.700, 0.650, 1.250, 0.650, 0.050, 1.250, FALSE, TRUE,  FALSE, 'Pressure: systemic risk signal.'),
('GEO',        'CONTEXT_SIGNAL',        0.700, 0.650, 1.150, 0.700, 0.050, 1.150, FALSE, TRUE,  FALSE, 'Geopolitical context: vulnerability-aware aggregation.'),
('EVENT',      'EVENT_VULNERABILITY',   0.500, 0.300, 1.300, 0.500, 0.050, 1.300, FALSE, TRUE,  FALSE, 'Events: not core ISA; vulnerability only.'),
('PERCEPTION', 'CONTEXT_ONLY',          0.450, 0.450, 0.900, 0.600, 0.050, 0.900, FALSE, TRUE,  FALSE, 'Perception: contextual and bias-aware.')
ON CONFLICT (semantic_code) DO UPDATE SET
    aggregation_mode = EXCLUDED.aggregation_mode,
    pillar_weight_factor = EXCLUDED.pillar_weight_factor,
    isa_score_factor = EXCLUDED.isa_score_factor,
    vulnerability_factor = EXCLUDED.vulnerability_factor,
    resilience_factor = EXCLUDED.resilience_factor,
    min_aggregation_weight = EXCLUDED.min_aggregation_weight,
    max_aggregation_weight = EXCLUDED.max_aggregation_weight,
    include_in_core_isa = EXCLUDED.include_in_core_isa,
    include_in_vulnerability_index = EXCLUDED.include_in_vulnerability_index,
    include_in_resilience_index = EXCLUDED.include_in_resilience_index,
    notes = EXCLUDED.notes,
    updated_at = now();

CREATE INDEX IF NOT EXISTS idx_dynamic_aggregation_policy_mode
    ON rf.dynamic_aggregation_policy(aggregation_mode);

DO $$
BEGIN
    RAISE NOTICE 'P7C dynamic aggregation policy lignes : %',
        (SELECT COUNT(*) FROM rf.dynamic_aggregation_policy);
END $$;

COMMIT;
