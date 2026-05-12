-- ============================================================
-- OSA / ISA — P7G Forecast Intelligence Engine
-- Patch: RF policies + lifecycle
-- Purpose:
--   Prepare deterministic, auditable forecast intelligence based on
--   P7E observed scores and P7F strategic diagnostics.
--
-- Doctrine:
--   P7E observes.
--   P7F diagnoses.
--   P7G forecasts trends with uncertainty bands.
--   P7G does NOT simulate policy scenarios and does NOT certify delivery.
-- ============================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS rf;
CREATE SCHEMA IF NOT EXISTS ma;
CREATE SCHEMA IF NOT EXISTS mg;

-- ------------------------------------------------------------
-- Package lifecycle registry
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mg.package_lifecycle (
    package_code VARCHAR(20) PRIMARY KEY,
    package_label TEXT NOT NULL DEFAULT 'UNSPECIFIED_PACKAGE',
    package_status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
    replacement_package VARCHAR(20),
    activated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    archived_at TIMESTAMP,
    notes TEXT
);

-- Harden lifecycle registry against older P7F/P8 attempts with partial schemas.
ALTER TABLE mg.package_lifecycle ADD COLUMN IF NOT EXISTS package_label TEXT;
ALTER TABLE mg.package_lifecycle ADD COLUMN IF NOT EXISTS package_status VARCHAR(30);
ALTER TABLE mg.package_lifecycle ADD COLUMN IF NOT EXISTS replacement_package VARCHAR(20);
ALTER TABLE mg.package_lifecycle ADD COLUMN IF NOT EXISTS activated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE mg.package_lifecycle ADD COLUMN IF NOT EXISTS archived_at TIMESTAMP;
ALTER TABLE mg.package_lifecycle ADD COLUMN IF NOT EXISTS notes TEXT;

UPDATE mg.package_lifecycle
SET package_label = COALESCE(package_label, package_code),
    package_status = COALESCE(package_status, 'ACTIVE'),
    activated_at = COALESCE(activated_at, CURRENT_TIMESTAMP)
WHERE package_label IS NULL
   OR package_status IS NULL
   OR activated_at IS NULL;

ALTER TABLE mg.package_lifecycle ALTER COLUMN package_label SET NOT NULL;
ALTER TABLE mg.package_lifecycle ALTER COLUMN package_status SET NOT NULL;

INSERT INTO mg.package_lifecycle (
    package_code, package_label, package_status, replacement_package, notes
)
VALUES
    ('P7G', 'P7G — Forecast Intelligence Engine', 'ACTIVE', NULL,
     'P7G produces deterministic forecast intelligence from P7E observed scores and P7F diagnostic intelligence.')
ON CONFLICT (package_code) DO UPDATE
SET package_label = EXCLUDED.package_label,
    package_status = EXCLUDED.package_status,
    replacement_package = EXCLUDED.replacement_package,
    notes = EXCLUDED.notes,
    archived_at = NULL;

-- ------------------------------------------------------------
-- Forecast policy
-- ------------------------------------------------------------
DROP TABLE IF EXISTS rf.isa_forecast_policy CASCADE;

CREATE TABLE rf.isa_forecast_policy (
    forecast_policy_code VARCHAR(40) PRIMARY KEY,
    forecast_policy_label TEXT NOT NULL,
    min_history_years INTEGER NOT NULL,
    min_data_completeness NUMERIC(6,3) NOT NULL,
    min_observation_confidence NUMERIC(6,3) NOT NULL,
    short_horizon_years INTEGER NOT NULL,
    medium_horizon_years INTEGER NOT NULL,
    long_horizon_years INTEGER NOT NULL,
    min_forecast_confidence NUMERIC(6,3) NOT NULL,
    uncertainty_multiplier NUMERIC(6,3) NOT NULL,
    drift_warning_threshold NUMERIC(6,3) NOT NULL,
    notes TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO rf.isa_forecast_policy (
    forecast_policy_code,
    forecast_policy_label,
    min_history_years,
    min_data_completeness,
    min_observation_confidence,
    short_horizon_years,
    medium_horizon_years,
    long_horizon_years,
    min_forecast_confidence,
    uncertainty_multiplier,
    drift_warning_threshold,
    notes
)
VALUES
    ('ROBUST_FORECAST', 'Historique robuste — forecast exploitable', 5, 0.700, 0.600, 1, 3, 5, 0.650, 1.000, 0.120,
     'Forecast robuste lorsque la série pays/pilier dispose d’au moins cinq années et d’une bonne confiance.'),
    ('CONTROLLED_FORECAST', 'Historique contrôlé — forecast prudent', 4, 0.600, 0.500, 1, 2, 3, 0.550, 1.250, 0.160,
     'Forecast limité lorsque la profondeur historique est acceptable mais pas maximale.'),
    ('LIMITED_FORECAST', 'Historique limité — tendance indicative', 3, 0.500, 0.400, 1, 2, 2, 0.450, 1.600, 0.200,
     'Forecast indicatif ; usage analytique uniquement.'),
    ('NO_FORECAST', 'Historique insuffisant', 99, 0.999, 0.999, 0, 0, 0, 0.999, 2.000, 0.999,
     'Pas de forecast si la couverture historique ou la confiance est insuffisante.');

-- ------------------------------------------------------------
-- Horizon policy
-- ------------------------------------------------------------
DROP TABLE IF EXISTS rf.isa_forecast_horizon_policy CASCADE;

CREATE TABLE rf.isa_forecast_horizon_policy (
    horizon_code VARCHAR(20) PRIMARY KEY,
    horizon_years INTEGER NOT NULL,
    horizon_label TEXT NOT NULL,
    forecast_usage_scope TEXT NOT NULL,
    publication_scope TEXT NOT NULL,
    notes TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO rf.isa_forecast_horizon_policy (
    horizon_code, horizon_years, horizon_label,
    forecast_usage_scope, publication_scope, notes
)
VALUES
    ('H1', 1, 'Court terme — 1 an', 'operational_monitoring', 'open_data_limited',
     'Projection courte à publier avec prudence.'),
    ('H3', 3, 'Moyen terme — 3 ans', 'strategic_planning', 'expert_or_premium',
     'Projection stratégique à usage expert.'),
    ('H5', 5, 'Long terme — 5 ans', 'prospective_analysis', 'internal_or_premium',
     'Projection prospective ; ne doit pas être présentée comme score officiel.');

-- ------------------------------------------------------------
-- Forecast interpretation policy
-- ------------------------------------------------------------
DROP TABLE IF EXISTS rf.isa_forecast_interpretation_policy CASCADE;

CREATE TABLE rf.isa_forecast_interpretation_policy (
    trend_class VARCHAR(40) PRIMARY KEY,
    trend_label TEXT NOT NULL,
    recommended_use TEXT NOT NULL,
    warning_level TEXT NOT NULL,
    notes TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO rf.isa_forecast_interpretation_policy (
    trend_class, trend_label, recommended_use, warning_level, notes
)
VALUES
    ('IMPROVING', 'Tendance positive', 'Monitor and consolidate gains', 'LOW',
     'Le score projeté progresse selon la tendance historique observée.'),
    ('STABLE', 'Tendance stable', 'Maintain monitoring', 'LOW',
     'La série ne montre pas de variation prospective forte.'),
    ('DETERIORATING', 'Tendance négative', 'Trigger diagnostic review', 'MEDIUM',
     'La tendance historique suggère une détérioration.'),
    ('VOLATILE', 'Tendance volatile', 'Use with caution; require expert review', 'HIGH',
     'La variance historique rend la prévision fragile.');

DO $$
DECLARE n INT;
BEGIN
    SELECT COUNT(*) INTO n FROM rf.isa_forecast_policy;
    RAISE NOTICE 'P7G forecast policy lignes : %', n;
END $$;

COMMIT;
