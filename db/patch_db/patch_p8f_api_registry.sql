-- ============================================================
-- OSA / ISA — P8F API Registry / Gateway Governance
-- ============================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS rf;

DROP TABLE IF EXISTS rf.isa_api_endpoint_registry CASCADE;

CREATE TABLE rf.isa_api_endpoint_registry (
    endpoint_code VARCHAR(60) PRIMARY KEY,
    api_version VARCHAR(20) NOT NULL DEFAULT 'v1',
    http_method VARCHAR(10) NOT NULL DEFAULT 'GET',
    api_path TEXT NOT NULL UNIQUE,
    backing_view TEXT,
    access_class VARCHAR(30) NOT NULL,
    auth_required BOOLEAN NOT NULL DEFAULT FALSE,
    rate_limit_policy VARCHAR(30) NOT NULL DEFAULT 'STANDARD',
    monetization_class VARCHAR(30) NOT NULL DEFAULT 'OPEN_DATA',
    certification_dependency VARCHAR(30) NOT NULL DEFAULT 'NONE',
    is_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    endpoint_note TEXT,
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

INSERT INTO rf.isa_api_endpoint_registry (
    endpoint_code, api_version, http_method, api_path, backing_view, access_class,
    auth_required, rate_limit_policy, monetization_class, certification_dependency,
    is_enabled, endpoint_note
)
VALUES
('ISA_COUNTRY', 'v1', 'GET', '/api/v1/isa/country/{iso3}', 'ma.v_isa_observed_scores_by_country_year', 'PUBLIC', FALSE, 'STANDARD', 'OPEN_DATA', 'CERTIFIED_OR_PROVISIONAL', TRUE, 'Scores ISA par pays.'),
('ISA_PILLAR', 'v1', 'GET', '/api/v1/isa/pillar/{pillar}', 'ma.v_isa_observed_scores_by_pillar', 'PUBLIC', FALSE, 'STANDARD', 'OPEN_DATA', 'CERTIFIED_OR_PROVISIONAL', TRUE, 'Scores ISA par pilier.'),
('ISA_REGION', 'v1', 'GET', '/api/v1/isa/region/{region}', 'ma.v_isa_observed_scores_by_region_year', 'PUBLIC', FALSE, 'STANDARD', 'OPEN_DATA', 'CERTIFIED_OR_PROVISIONAL', TRUE, 'Scores ISA par région.'),
('ISA_SWOT', 'v1', 'GET', '/api/v1/isa/swot/{country}', 'ma.v_isa_swot_signal_engine', 'PUBLIC', FALSE, 'STANDARD', 'OPEN_DATA', 'OBSERVED', TRUE, 'Signaux SWOT publics.'),
('PROJECT_OPPORTUNITY', 'v1', 'GET', '/api/v1/projects/opportunity', 'ma.v_isa_project_opportunity_catalog', 'PUBLIC', FALSE, 'STANDARD', 'OPEN_DATA', 'OBSERVED', TRUE, 'Catalogue opportunités de projets.'),
('PREMIUM_FEASIBILITY', 'v1', 'GET', '/api/v1/premium/feasibility', 'ma.v_isa_premium_feasibility_triggers', 'PRIVATE', TRUE, 'PREMIUM', 'PREMIUM', 'OBSERVED', TRUE, 'Déclencheurs premium faisabilité.'),
('CERTIFICATION', 'v1', 'GET', '/api/v1/certification', 'ma.v_isa_certification_engine', 'PRIVATE', TRUE, 'GOVERNANCE', 'GOVERNANCE', 'CERTIFIED', TRUE, 'État de certification.'),
('EPARTICIPATION', 'v1', 'GET', '/api/v1/eparticipation/queue', 'ma.v_isa_eparticipation_queue', 'PUBLIC', FALSE, 'STANDARD', 'OPEN_DATA', 'OBSERVED', TRUE, 'File e-participation.')
ON CONFLICT (endpoint_code) DO UPDATE SET
    api_version = EXCLUDED.api_version,
    http_method = EXCLUDED.http_method,
    api_path = EXCLUDED.api_path,
    backing_view = EXCLUDED.backing_view,
    access_class = EXCLUDED.access_class,
    auth_required = EXCLUDED.auth_required,
    rate_limit_policy = EXCLUDED.rate_limit_policy,
    monetization_class = EXCLUDED.monetization_class,
    certification_dependency = EXCLUDED.certification_dependency,
    is_enabled = EXCLUDED.is_enabled,
    endpoint_note = EXCLUDED.endpoint_note,
    updated_at = NOW();

DO $$
BEGIN
    RAISE NOTICE 'P8F API registry lignes : %',
        (SELECT COUNT(*) FROM rf.isa_api_endpoint_registry);
END $$;

COMMIT;
