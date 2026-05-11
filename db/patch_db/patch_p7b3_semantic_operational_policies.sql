-- ============================================================
-- OSA / ISA — P7B3
-- Patch: Semantic Operational Policies
-- Role:
--   Transform semantic governance + confidence into operational ISA policies.
--
-- Creates:
--   rf.semantic_operational_policy
--
-- Depends on:
--   rf.semantic_governance_matrix
--   rf.semantic_confidence_policy
--
-- Notes:
--   This patch is idempotent.
-- ============================================================

BEGIN;

CREATE TABLE IF NOT EXISTS rf.semantic_operational_policy (
    semantic_code VARCHAR(30) PRIMARY KEY,

    -- ISA/L2/L3 operational decisions
    isa_inclusion_policy VARCHAR(30) NOT NULL DEFAULT 'INCLUDE_WITH_CONFIDENCE',
    imputation_operational_policy VARCHAR(30) NOT NULL DEFAULT 'STANDARD',
    normalization_policy VARCHAR(30) NOT NULL DEFAULT 'STANDARD',
    aggregation_policy VARCHAR(30) NOT NULL DEFAULT 'CONFIDENCE_WEIGHTED',

    -- Thresholds
    min_dynamic_confidence NUMERIC(5,3) NOT NULL DEFAULT 0.600,
    min_governance_score NUMERIC(5,3) NOT NULL DEFAULT 0.700,
    max_imputation_ratio NUMERIC(5,3) NOT NULL DEFAULT 0.350,
    exclusion_warning_threshold NUMERIC(5,3) NOT NULL DEFAULT 0.450,

    -- Multipliers
    isa_weight_multiplier NUMERIC(5,3) NOT NULL DEFAULT 1.000,
    ml_weight_multiplier NUMERIC(5,3) NOT NULL DEFAULT 1.000,
    vulnerability_weight NUMERIC(5,3) NOT NULL DEFAULT 0.500,

    -- Operational flags
    requires_certified_source BOOLEAN NOT NULL DEFAULT FALSE,
    allow_long_gap_imputation BOOLEAN NOT NULL DEFAULT FALSE,
    allow_ml_forecast BOOLEAN NOT NULL DEFAULT TRUE,
    requires_manual_review_if_critical BOOLEAN NOT NULL DEFAULT TRUE,

    operational_risk_class VARCHAR(30) NOT NULL DEFAULT 'MEDIUM',
    notes TEXT,
    updated_at TIMESTAMP DEFAULT now()
);

INSERT INTO rf.semantic_operational_policy (
    semantic_code,
    isa_inclusion_policy,
    imputation_operational_policy,
    normalization_policy,
    aggregation_policy,
    min_dynamic_confidence,
    min_governance_score,
    max_imputation_ratio,
    exclusion_warning_threshold,
    isa_weight_multiplier,
    ml_weight_multiplier,
    vulnerability_weight,
    requires_certified_source,
    allow_long_gap_imputation,
    allow_ml_forecast,
    requires_manual_review_if_critical,
    operational_risk_class,
    notes
)
VALUES
('PHYSICAL',   'INCLUDE_WITH_CERTIFICATION', 'STRICT_LIMITED',     'ROBUST_PHYSICAL', 'CONFIDENCE_WEIGHTED', 0.700, 0.780, 0.120, 0.600, 1.150, 1.050, 0.750, TRUE,  FALSE, TRUE,  TRUE, 'HIGH',   'Physical resources: never exclude, but lock unsafe imputation until certified.'),
('STOCK',      'INCLUDE_WITH_CONFIDENCE',    'STRICT_STABLE',      'ROBUST_STOCK',    'CONFIDENCE_WEIGHTED', 0.680, 0.760, 0.180, 0.550, 1.100, 1.000, 0.650, TRUE,  FALSE, TRUE,  TRUE, 'HIGH',   'Stocks/reserves: stable but certification matters.'),
('STRUCTURAL', 'INCLUDE_WITH_CONFIDENCE',    'CONTROLLED',         'STANDARD',        'CONFIDENCE_WEIGHTED', 0.650, 0.740, 0.300, 0.500, 1.050, 1.050, 0.550, FALSE, TRUE,  TRUE,  TRUE, 'MEDIUM', 'Structural capacities: suitable for ISA and ML with confidence weighting.'),
('GOVERNANCE', 'INCLUDE_WITH_CONFIDENCE',    'FLEXIBLE_GOVERNED',  'STANDARD',        'CONFIDENCE_WEIGHTED', 0.620, 0.720, 0.400, 0.480, 1.000, 1.050, 0.550, FALSE, TRUE,  TRUE,  TRUE, 'MEDIUM', 'Governance signals: imputable with caution and explainability.'),
('DEPENDENCY', 'INCLUDE_AS_VULNERABILITY',   'CAUTIOUS',           'RISK_AWARE',      'VULNERABILITY_WEIGHTED', 0.620, 0.720, 0.250, 0.500, 1.050, 1.100, 0.850, FALSE, FALSE, TRUE,  TRUE, 'HIGH',   'Dependency signals must inform vulnerability, not be discarded.'),
('GEO',        'INCLUDE_AS_CONTEXT',         'CAUTIOUS',           'RISK_AWARE',      'VULNERABILITY_WEIGHTED', 0.600, 0.700, 0.220, 0.500, 0.950, 1.050, 0.800, FALSE, FALSE, TRUE,  TRUE, 'HIGH',   'Geopolitical signals are volatile but strategically informative.'),
('PRESSURE',   'INCLUDE_AS_RISK',            'CAUTIOUS',           'RISK_AWARE',      'VULNERABILITY_WEIGHTED', 0.600, 0.700, 0.250, 0.500, 1.000, 1.050, 0.850, FALSE, FALSE, TRUE,  TRUE, 'HIGH',   'Pressure signals should feed threat/weakness layers.'),
('RESILIENCE', 'INCLUDE_WITH_CONFIDENCE',    'CONTROLLED',         'STANDARD',        'CONFIDENCE_WEIGHTED', 0.620, 0.700, 0.350, 0.470, 1.000, 1.050, 0.450, FALSE, TRUE,  TRUE,  TRUE, 'MEDIUM', 'Resilience signals are useful for corrections and policy response.'),
('NETWORK',    'INCLUDE_WITH_CONFIDENCE',    'CONTROLLED',         'STANDARD',        'CONFIDENCE_WEIGHTED', 0.620, 0.700, 0.350, 0.470, 0.980, 1.050, 0.600, FALSE, TRUE,  TRUE,  TRUE, 'MEDIUM', 'Network/connectivity signals support digital and transport sovereignty.'),
('FLOW',       'INCLUDE_WITH_CONFIDENCE',    'CONTROLLED',         'STANDARD',        'CONFIDENCE_WEIGHTED', 0.600, 0.690, 0.380, 0.450, 0.950, 1.000, 0.650, FALSE, TRUE,  TRUE,  TRUE, 'MEDIUM', 'Flows are informative but volatile.'),
('EVENT',      'INCLUDE_AS_EVENT_SIGNAL',    'VERY_STRICT',        'EVENT_AWARE',     'VULNERABILITY_WEIGHTED', 0.580, 0.680, 0.100, 0.450, 0.900, 0.950, 0.900, FALSE, FALSE, FALSE, TRUE, 'HIGH',   'Events should not be long-imputed; use as shock/context signals.'),
('COMPOSITE',  'INCLUDE_WITH_DEPENDENCY',    'DEPENDENT',          'COMPONENT_AWARE', 'CONFIDENCE_WEIGHTED', 0.600, 0.680, 0.300, 0.450, 0.900, 0.950, 0.500, FALSE, TRUE,  TRUE,  TRUE, 'MEDIUM', 'Composite confidence depends on components.'),
('PERCEPTION', 'INCLUDE_WITH_BIAS_WARNING',  'FLEXIBLE_LIMITED',   'BIAS_AWARE',      'CONFIDENCE_WEIGHTED', 0.560, 0.650, 0.400, 0.420, 0.750, 0.800, 0.450, FALSE, TRUE,  TRUE,  TRUE, 'MEDIUM', 'Perception indicators are useful but bias-aware.')
ON CONFLICT (semantic_code) DO UPDATE SET
    isa_inclusion_policy = EXCLUDED.isa_inclusion_policy,
    imputation_operational_policy = EXCLUDED.imputation_operational_policy,
    normalization_policy = EXCLUDED.normalization_policy,
    aggregation_policy = EXCLUDED.aggregation_policy,
    min_dynamic_confidence = EXCLUDED.min_dynamic_confidence,
    min_governance_score = EXCLUDED.min_governance_score,
    max_imputation_ratio = EXCLUDED.max_imputation_ratio,
    exclusion_warning_threshold = EXCLUDED.exclusion_warning_threshold,
    isa_weight_multiplier = EXCLUDED.isa_weight_multiplier,
    ml_weight_multiplier = EXCLUDED.ml_weight_multiplier,
    vulnerability_weight = EXCLUDED.vulnerability_weight,
    requires_certified_source = EXCLUDED.requires_certified_source,
    allow_long_gap_imputation = EXCLUDED.allow_long_gap_imputation,
    allow_ml_forecast = EXCLUDED.allow_ml_forecast,
    requires_manual_review_if_critical = EXCLUDED.requires_manual_review_if_critical,
    operational_risk_class = EXCLUDED.operational_risk_class,
    notes = EXCLUDED.notes,
    updated_at = now();

CREATE INDEX IF NOT EXISTS idx_semantic_operational_policy_risk
    ON rf.semantic_operational_policy (operational_risk_class);

DO $$
BEGIN
    RAISE NOTICE 'P7B3 semantic operational policy lignes : %',
        (SELECT COUNT(*) FROM rf.semantic_operational_policy);
END $$;

COMMIT;
