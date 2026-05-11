-- ============================================================
-- OSA / ISA — P7B4
-- Patch: Semantic Forecastability Policy
-- Role:
--   Defines the referential policy used to decide whether a
--   semantic signal can be forecast, limited, monitored, or kept
--   as context only.
--
-- Schema choice:
--   rf = referential / stable governance policy.
-- ============================================================

BEGIN;

CREATE TABLE IF NOT EXISTS rf.semantic_forecast_policy (
    semantic_code VARCHAR(30) PRIMARY KEY,
    forecast_policy VARCHAR(40) NOT NULL,
    base_forecastability NUMERIC(5,3) NOT NULL DEFAULT 0.600,
    min_forecast_confidence NUMERIC(5,3) NOT NULL DEFAULT 0.600,
    max_forecast_horizon_years SMALLINT NOT NULL DEFAULT 3,
    volatility_penalty NUMERIC(5,3) NOT NULL DEFAULT 0.050,
    locked_review_penalty NUMERIC(5,3) NOT NULL DEFAULT 0.250,
    event_forecast_allowed BOOLEAN NOT NULL DEFAULT TRUE,
    physical_forecast_requires_certification BOOLEAN NOT NULL DEFAULT FALSE,
    ml_forecast_weight NUMERIC(5,3) NOT NULL DEFAULT 0.750,
    smoothing_policy VARCHAR(40) NOT NULL DEFAULT 'STANDARD_SMOOTHING',
    drift_monitoring_policy VARCHAR(40) NOT NULL DEFAULT 'STANDARD_DRIFT_MONITORING',
    operational_notes TEXT,
    updated_at TIMESTAMP DEFAULT now(),
    CONSTRAINT semantic_forecast_policy_scores_chk CHECK (
        base_forecastability BETWEEN 0 AND 1
        AND min_forecast_confidence BETWEEN 0 AND 1
        AND volatility_penalty BETWEEN 0 AND 1
        AND locked_review_penalty BETWEEN 0 AND 1
        AND ml_forecast_weight BETWEEN 0 AND 1
    )
);

INSERT INTO rf.semantic_forecast_policy (
    semantic_code,
    forecast_policy,
    base_forecastability,
    min_forecast_confidence,
    max_forecast_horizon_years,
    volatility_penalty,
    locked_review_penalty,
    event_forecast_allowed,
    physical_forecast_requires_certification,
    ml_forecast_weight,
    smoothing_policy,
    drift_monitoring_policy,
    operational_notes
)
VALUES
('STRUCTURAL', 'FORECAST_READY',       0.780, 0.650, 7, 0.030, 0.180, TRUE,  FALSE, 0.900, 'TREND_SMOOTHING',       'MEDIUM_DRIFT_MONITORING', 'Capacités structurelles : bonnes candidates au forecast.'),
('STOCK',      'FORECAST_READY',       0.760, 0.680, 5, 0.020, 0.200, TRUE,  FALSE, 0.850, 'ROBUST_STOCK_SMOOTHING', 'LOW_DRIFT_MONITORING',    'Stocks/réserves : forecast possible si source stable.'),
('PHYSICAL',   'FORECAST_CERTIFIED',   0.720, 0.700, 5, 0.030, 0.300, TRUE,  TRUE,  0.880, 'ROBUST_PHYSICAL',        'LOW_DRIFT_MONITORING',    'Physique : forecast seulement si source certifiée ou signal non verrouillé.'),
('NETWORK',    'FORECAST_LIMITED',     0.680, 0.620, 4, 0.050, 0.220, TRUE,  FALSE, 0.820, 'NETWORK_SMOOTHING',      'MEDIUM_DRIFT_MONITORING', 'Réseaux : forecast utile mais sensible aux ruptures.'),
('FLOW',       'FORECAST_LIMITED',     0.660, 0.600, 3, 0.070, 0.200, TRUE,  FALSE, 0.800, 'FLOW_SMOOTHING',         'HIGH_DRIFT_MONITORING',   'Flux : forecast contrôlé avec surveillance de volatilité.'),
('GOVERNANCE', 'FORECAST_LIMITED',     0.640, 0.620, 3, 0.050, 0.180, TRUE,  FALSE, 0.820, 'GOVERNANCE_SMOOTHING',   'MEDIUM_DRIFT_MONITORING', 'Gouvernance : forecast prudent, utile en contexte ML.'),
('RESILIENCE', 'FORECAST_LIMITED',     0.700, 0.620, 5, 0.040, 0.180, TRUE,  FALSE, 0.850, 'RESILIENCE_SMOOTHING',   'MEDIUM_DRIFT_MONITORING', 'Résilience : forecast possible par tendances longues.'),
('COMPOSITE',  'FORECAST_COMPONENTS',  0.640, 0.600, 3, 0.050, 0.180, TRUE,  FALSE, 0.780, 'COMPONENT_AWARE',        'MEDIUM_DRIFT_MONITORING', 'Composite : forecast dépendant des composants.'),
('DEPENDENCY', 'CONTEXT_FORECAST',     0.560, 0.620, 2, 0.080, 0.220, TRUE,  FALSE, 0.760, 'RISK_AWARE',             'HIGH_DRIFT_MONITORING',   'Dépendance : surtout signal de vulnérabilité.'),
('PRESSURE',   'CONTEXT_FORECAST',     0.550, 0.600, 2, 0.090, 0.220, TRUE,  FALSE, 0.750, 'RISK_AWARE',             'HIGH_DRIFT_MONITORING',   'Pression : utile comme contexte, forecast limité.'),
('GEO',        'CONTEXT_FORECAST',     0.530, 0.600, 2, 0.100, 0.240, TRUE,  FALSE, 0.740, 'CONTEXT_AWARE',          'HIGH_DRIFT_MONITORING',   'Géopolitique : signal contextuel instable.'),
('EVENT',      'FORECAST_DISABLED',    0.420, 0.580, 1, 0.120, 0.250, FALSE, FALSE, 0.650, 'NO_LONG_SMOOTHING',      'EVENT_MONITORING',        'Événement : pas de forecast structurel, seulement monitoring.'),
('PERCEPTION', 'CONTEXT_ONLY',         0.500, 0.560, 2, 0.060, 0.180, TRUE,  FALSE, 0.600, 'BIAS_AWARE',             'BIAS_DRIFT_MONITORING',   'Perception : contexte avec biais.' )
ON CONFLICT (semantic_code) DO UPDATE SET
    forecast_policy = EXCLUDED.forecast_policy,
    base_forecastability = EXCLUDED.base_forecastability,
    min_forecast_confidence = EXCLUDED.min_forecast_confidence,
    max_forecast_horizon_years = EXCLUDED.max_forecast_horizon_years,
    volatility_penalty = EXCLUDED.volatility_penalty,
    locked_review_penalty = EXCLUDED.locked_review_penalty,
    event_forecast_allowed = EXCLUDED.event_forecast_allowed,
    physical_forecast_requires_certification = EXCLUDED.physical_forecast_requires_certification,
    ml_forecast_weight = EXCLUDED.ml_forecast_weight,
    smoothing_policy = EXCLUDED.smoothing_policy,
    drift_monitoring_policy = EXCLUDED.drift_monitoring_policy,
    operational_notes = EXCLUDED.operational_notes,
    updated_at = now();

CREATE INDEX IF NOT EXISTS idx_semantic_forecast_policy_policy
    ON rf.semantic_forecast_policy(forecast_policy);

DO $$
BEGIN
    RAISE NOTICE 'P7B4 semantic forecast policy lignes : %',
        (SELECT COUNT(*) FROM rf.semantic_forecast_policy);
END $$;

COMMIT;
