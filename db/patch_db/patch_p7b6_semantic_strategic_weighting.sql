-- ============================================================
-- OSA / ISA — P7B6
-- Patch: Semantic Strategic Weighting Policy
-- Purpose:
--   Create RF policy table for dynamic strategic weighting.
--   This layer transforms P7B5 sovereignty signals into dynamic
--   ISA / ML / Forecast / Sovereignty / Vulnerability weights.
-- ============================================================

BEGIN;

CREATE TABLE IF NOT EXISTS rf.semantic_weighting_policy (
    semantic_code VARCHAR(30) PRIMARY KEY,

    isa_base_weight NUMERIC(6,3) NOT NULL DEFAULT 0.700,
    ml_base_weight NUMERIC(6,3) NOT NULL DEFAULT 0.700,
    forecast_base_weight NUMERIC(6,3) NOT NULL DEFAULT 0.650,
    sovereignty_base_weight NUMERIC(6,3) NOT NULL DEFAULT 0.750,
    vulnerability_base_weight NUMERIC(6,3) NOT NULL DEFAULT 0.500,

    strong_sovereignty_bonus NUMERIC(6,3) NOT NULL DEFAULT 0.080,
    controlled_sovereignty_bonus NUMERIC(6,3) NOT NULL DEFAULT 0.040,
    locked_gap_penalty NUMERIC(6,3) NOT NULL DEFAULT 0.200,
    weak_signal_penalty NUMERIC(6,3) NOT NULL DEFAULT 0.120,

    dependency_penalty_factor NUMERIC(6,3) NOT NULL DEFAULT 0.080,
    vulnerability_amplifier NUMERIC(6,3) NOT NULL DEFAULT 0.250,

    normalization_mode VARCHAR(40) NOT NULL DEFAULT 'CONFIDENCE_AWARE',
    weighting_mode VARCHAR(40) NOT NULL DEFAULT 'DYNAMIC_SEMANTIC',

    notes TEXT,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now()
);

INSERT INTO rf.semantic_weighting_policy (
    semantic_code,
    isa_base_weight,
    ml_base_weight,
    forecast_base_weight,
    sovereignty_base_weight,
    vulnerability_base_weight,
    strong_sovereignty_bonus,
    controlled_sovereignty_bonus,
    locked_gap_penalty,
    weak_signal_penalty,
    dependency_penalty_factor,
    vulnerability_amplifier,
    normalization_mode,
    weighting_mode,
    notes
)
VALUES
('PHYSICAL',   0.950, 0.900, 0.780, 0.980, 0.650, 0.100, 0.050, 0.300, 0.140, 0.060, 0.300, 'ROBUST_PHYSICAL',    'CERTIFICATION_AWARE', 'Physical sovereignty: high ISA value, strict lock if not certified.'),
('STOCK',      0.900, 0.850, 0.820, 0.920, 0.580, 0.090, 0.045, 0.220, 0.120, 0.050, 0.260, 'ROBUST_STOCK',       'DYNAMIC_SEMANTIC',   'Stocks and reserves: strong sovereignty but depletion-sensitive.'),
('STRUCTURAL', 0.880, 0.900, 0.850, 0.900, 0.520, 0.090, 0.045, 0.180, 0.100, 0.050, 0.230, 'CAPACITY_AWARE',     'DYNAMIC_SEMANTIC',   'Structural capacity: core ISA weighting family.'),
('GOVERNANCE', 0.820, 0.860, 0.700, 0.850, 0.560, 0.080, 0.040, 0.170, 0.100, 0.070, 0.250, 'GOVERNANCE_AWARE',   'DYNAMIC_SEMANTIC',   'Governance: institutional sovereignty and policy capacity.'),
('RESILIENCE', 0.800, 0.850, 0.760, 0.830, 0.480, 0.080, 0.040, 0.160, 0.090, 0.050, 0.220, 'RESILIENCE_AWARE',   'DYNAMIC_SEMANTIC',   'Resilience: stabilizing capacity and absorption of shocks.'),
('DEPENDENCY', 0.720, 0.860, 0.580, 0.760, 0.760, 0.060, 0.030, 0.220, 0.150, 0.180, 0.350, 'VULNERABILITY_AWARE','VULNERABILITY_WEIGHTED', 'Dependency: sovereignty exposure and strategic vulnerability.'),
('PRESSURE',   0.720, 0.840, 0.600, 0.740, 0.740, 0.060, 0.030, 0.200, 0.140, 0.120, 0.330, 'RISK_AWARE',         'VULNERABILITY_WEIGHTED', 'Pressure: systemic constraint, risk and vulnerability signal.'),
('GEO',        0.700, 0.840, 0.570, 0.740, 0.730, 0.060, 0.030, 0.220, 0.150, 0.120, 0.340, 'GEO_AWARE',          'CONTEXT_WEIGHTED',   'Geopolitical context: strategic but volatile.'),
('NETWORK',    0.760, 0.830, 0.720, 0.780, 0.540, 0.070, 0.035, 0.190, 0.110, 0.060, 0.240, 'NETWORK_AWARE',      'DYNAMIC_SEMANTIC',   'Network capacity: digital, transport, connectivity sovereignty.'),
('FLOW',       0.720, 0.800, 0.680, 0.720, 0.560, 0.060, 0.030, 0.180, 0.120, 0.080, 0.260, 'FLOW_AWARE',         'CONFIDENCE_WEIGHTED','Flows: useful but volatility-sensitive.'),
('COMPOSITE',  0.700, 0.800, 0.650, 0.700, 0.520, 0.060, 0.030, 0.170, 0.120, 0.070, 0.240, 'COMPONENT_AWARE',    'DEPENDENT_WEIGHTED', 'Composite: weight depends on component trust.'),
('PERCEPTION', 0.520, 0.620, 0.450, 0.500, 0.620, 0.030, 0.020, 0.160, 0.140, 0.080, 0.270, 'BIAS_AWARE',         'CONTEXT_WEIGHTED',   'Perception: contextual, bias-sensitive, limited core weighting.'),
('EVENT',      0.500, 0.700, 0.000, 0.460, 0.820, 0.020, 0.010, 0.230, 0.180, 0.100, 0.420, 'EVENT_AWARE',        'VULNERABILITY_WEIGHTED', 'Event: anti-sovereignty shock signal, not forecast core.')
ON CONFLICT (semantic_code) DO UPDATE SET
    isa_base_weight = EXCLUDED.isa_base_weight,
    ml_base_weight = EXCLUDED.ml_base_weight,
    forecast_base_weight = EXCLUDED.forecast_base_weight,
    sovereignty_base_weight = EXCLUDED.sovereignty_base_weight,
    vulnerability_base_weight = EXCLUDED.vulnerability_base_weight,
    strong_sovereignty_bonus = EXCLUDED.strong_sovereignty_bonus,
    controlled_sovereignty_bonus = EXCLUDED.controlled_sovereignty_bonus,
    locked_gap_penalty = EXCLUDED.locked_gap_penalty,
    weak_signal_penalty = EXCLUDED.weak_signal_penalty,
    dependency_penalty_factor = EXCLUDED.dependency_penalty_factor,
    vulnerability_amplifier = EXCLUDED.vulnerability_amplifier,
    normalization_mode = EXCLUDED.normalization_mode,
    weighting_mode = EXCLUDED.weighting_mode,
    notes = EXCLUDED.notes,
    updated_at = now();

CREATE INDEX IF NOT EXISTS idx_semantic_weighting_policy_mode
    ON rf.semantic_weighting_policy(weighting_mode);

DO $$
BEGIN
    RAISE NOTICE 'P7B6 semantic weighting policy lignes : %',
        (SELECT COUNT(*) FROM rf.semantic_weighting_policy);
END $$;

COMMIT;
