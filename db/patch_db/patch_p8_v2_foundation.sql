-- ============================================================
-- OSA / ISA OBSERVATORY
-- P8 V2 — Institutional Public Observatory Foundation
-- ============================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS rf;
CREATE SCHEMA IF NOT EXISTS ma;
CREATE SCHEMA IF NOT EXISTS mg;
CREATE SCHEMA IF NOT EXISTS pub;
CREATE SCHEMA IF NOT EXISTS archive;

CREATE TABLE IF NOT EXISTS rf.package_lifecycle (
    package_code VARCHAR(20) PRIMARY KEY,
    package_label TEXT NOT NULL DEFAULT '',
    package_status VARCHAR(40) NOT NULL DEFAULT 'ACTIVE',
    replacement_package VARCHAR(20),
    notes TEXT,
    updated_at TIMESTAMP DEFAULT NOW()
);

ALTER TABLE rf.package_lifecycle
    ADD COLUMN IF NOT EXISTS package_label TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS package_status VARCHAR(40) NOT NULL DEFAULT 'ACTIVE',
    ADD COLUMN IF NOT EXISTS replacement_package VARCHAR(20),
    ADD COLUMN IF NOT EXISTS notes TEXT,
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT NOW();

INSERT INTO rf.package_lifecycle(package_code, package_label, package_status, replacement_package, notes, updated_at)
VALUES (
    'P8OPS',
    'P8 Operationalization Legacy Layer',
    'LEGACY_ACTIVE',
    'P8V2',
    'Legacy operationalization layer preserved during P8 V2 parallel migration.',
    NOW()
)
ON CONFLICT (package_code) DO UPDATE
SET package_label = EXCLUDED.package_label,
    package_status = 'LEGACY_ACTIVE',
    replacement_package = 'P8V2',
    notes = EXCLUDED.notes,
    updated_at = NOW();

INSERT INTO rf.package_lifecycle(package_code, package_label, package_status, replacement_package, notes, updated_at)
VALUES (
    'P8V2',
    'Institutional Public Observatory V2',
    'ACTIVE_CANDIDATE',
    NULL,
    'P8 V2 public observatory foundation. Runs in parallel with P8OPS until validation and switch.',
    NOW()
)
ON CONFLICT (package_code) DO UPDATE
SET package_label = EXCLUDED.package_label,
    package_status = 'ACTIVE_CANDIDATE',
    replacement_package = NULL,
    notes = EXCLUDED.notes,
    updated_at = NOW();

CREATE TABLE IF NOT EXISTS mg.release_registry (
    release_code VARCHAR(40) PRIMARY KEY,
    release_label TEXT NOT NULL,
    release_family VARCHAR(40) NOT NULL,
    release_status VARCHAR(40) NOT NULL,
    semantic_version VARCHAR(20) NOT NULL,
    methodology_version VARCHAR(40),
    data_period_start INTEGER,
    data_period_end INTEGER,
    public_release_date DATE,
    release_notes TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

INSERT INTO mg.release_registry(
    release_code, release_label, release_family, release_status, semantic_version,
    methodology_version, data_period_start, data_period_end, public_release_date, release_notes, updated_at
)
VALUES (
    'P8V2_2026_CANDIDATE',
    'OSA / ISA Public Observatory V2 — Candidate Release',
    'P8V2',
    'ACTIVE_CANDIDATE',
    '2.0.0-candidate',
    'ISA_DEV_P8V2',
    2010,
    2024,
    NULL,
    'Candidate institutional public observatory release. P8OPS remains LEGACY_ACTIVE until parallel validation is complete.',
    NOW()
)
ON CONFLICT (release_code) DO UPDATE
SET release_status = EXCLUDED.release_status,
    semantic_version = EXCLUDED.semantic_version,
    methodology_version = EXCLUDED.methodology_version,
    data_period_start = EXCLUDED.data_period_start,
    data_period_end = EXCLUDED.data_period_end,
    release_notes = EXCLUDED.release_notes,
    updated_at = NOW();

CREATE TABLE IF NOT EXISTS mg.asset_registry (
    asset_id BIGSERIAL PRIMARY KEY,
    asset_code VARCHAR(120) UNIQUE NOT NULL,
    asset_name TEXT NOT NULL,
    asset_type VARCHAR(40) NOT NULL,
    current_location TEXT NOT NULL,
    target_location TEXT,
    classification VARCHAR(40) NOT NULL,
    migration_status VARCHAR(40) NOT NULL,
    release_code VARCHAR(40),
    notes TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_asset_registry_classification ON mg.asset_registry(classification);
CREATE INDEX IF NOT EXISTS idx_asset_registry_release_code ON mg.asset_registry(release_code);

INSERT INTO mg.asset_registry(asset_code, asset_name, asset_type, current_location, target_location, classification, migration_status, release_code, notes, updated_at)
VALUES
('P8OPS_VIEW_CERTIFICATION','P8 OPS Certification Engine','SQL_VIEW','ma.v_isa_certification_engine','pub.v_isa_release_manifest','LEGACY_PARALLEL','TO_BE_VALIDATED','P8V2_2026_CANDIDATE','Legacy certification view preserved.',NOW()),
('P8OPS_VIEW_PUBLICATION','P8 OPS Publication Governance','SQL_VIEW','ma.v_isa_publication_governance','pub.v_isa_release_manifest','LEGACY_PARALLEL','TO_BE_VALIDATED','P8V2_2026_CANDIDATE','Legacy publication governance preserved.',NOW()),
('P8OPS_VIEW_OPEN_DATA','P8 OPS Open Data Catalog','SQL_VIEW','ma.v_isa_open_data_catalog','pub.v_isa_open_data_catalog','MIGRATE_TO_P8V2','PENDING','P8V2_2026_CANDIDATE','Open data catalog will migrate to pub schema.',NOW()),
('P8OPS_VIEW_PREMIUM','P8 OPS Premium Catalog','SQL_VIEW','ma.v_isa_premium_catalog','pub.v_isa_premium_catalog','MIGRATE_TO_P8V2','PENDING','P8V2_2026_CANDIDATE','Premium catalog metadata will migrate to pub schema.',NOW()),
('P8OPS_VIEW_API','P8 OPS API Registry','SQL_VIEW','ma.v_isa_api_registry','pub.v_isa_api_contracts','MIGRATE_TO_P8V2','PENDING','P8V2_2026_CANDIDATE','API registry becomes API contract registry.',NOW()),
('P8V2_SCHEMA_PUB','P8 V2 Public Schema','SCHEMA','pub','pub','ACTIVE_TO_KEEP','CREATED','P8V2_2026_CANDIDATE','Public publication schema.',NOW()),
('P8V2_SCHEMA_ARCHIVE','P8 V2 Archive Schema','SCHEMA','archive','archive','ACTIVE_TO_KEEP','CREATED','P8V2_2026_CANDIDATE','Controlled archive schema.',NOW())
ON CONFLICT (asset_code) DO UPDATE
SET asset_name = EXCLUDED.asset_name,
    asset_type = EXCLUDED.asset_type,
    current_location = EXCLUDED.current_location,
    target_location = EXCLUDED.target_location,
    classification = EXCLUDED.classification,
    migration_status = EXCLUDED.migration_status,
    release_code = EXCLUDED.release_code,
    notes = EXCLUDED.notes,
    updated_at = NOW();

CREATE TABLE IF NOT EXISTS mg.publication_registry (
    dataset_code VARCHAR(80) PRIMARY KEY,
    dataset_label TEXT NOT NULL,
    dataset_family VARCHAR(40) NOT NULL,
    source_view TEXT NOT NULL,
    target_view TEXT NOT NULL,
    access_class VARCHAR(40) NOT NULL,
    publication_status VARCHAR(40) NOT NULL,
    release_code VARCHAR(40) NOT NULL,
    public_api_path TEXT,
    notes TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

INSERT INTO mg.publication_registry(dataset_code, dataset_label, dataset_family, source_view, target_view, access_class, publication_status, release_code, public_api_path, notes, updated_at)
VALUES
('ISA_COUNTRY_LATEST','ISA latest country scores','COUNTRY','ma.v_isa_observed_scores_by_country_year','pub.v_isa_country_latest','PUBLIC','P8V2_CANDIDATE','P8V2_2026_CANDIDATE','/api/v2/countries','Latest public country scores.',NOW()),
('ISA_COUNTRY_HISTORY','ISA country score history','COUNTRY','ma.v_isa_observed_scores_by_country_year','pub.v_isa_country_history','PUBLIC','P8V2_CANDIDATE','P8V2_2026_CANDIDATE','/api/v2/countries/{iso3}/history','Country-year historical scores.',NOW()),
('ISA_COUNTRY_RANKINGS','ISA country rankings','RANKING','ma.v_isa_observed_scores_by_country_year','pub.v_isa_country_rankings','PUBLIC','P8V2_CANDIDATE','P8V2_2026_CANDIDATE','/api/v2/rankings/latest','Public country rankings.',NOW()),
('ISA_PILLAR_BREAKDOWN','ISA pillar breakdown','PILLAR','ma.v_isa_observed_scores_by_pillar','pub.v_isa_pillar_breakdown','PUBLIC','P8V2_CANDIDATE','P8V2_2026_CANDIDATE','/api/v2/countries/{iso3}/pillars','Public pillar-level scores.',NOW()),
('ISA_OPPORTUNITIES','ISA opportunity catalog','OPPORTUNITY','ma.v_isa_candidate_intervention_catalog','pub.v_isa_opportunity_catalog','PUBLIC_LIMITED','P8V2_CANDIDATE','P8V2_2026_CANDIDATE','/api/v2/opportunities','Opportunity catalog derived from diagnostic intelligence.',NOW()),
('ISA_FEASIBILITY','ISA feasibility catalog','FEASIBILITY','ma.v_isa_candidate_intervention_catalog','pub.v_isa_feasibility_catalog','EXPERT','P8V2_CANDIDATE','P8V2_2026_CANDIDATE','/api/v2/feasibility','Expert feasibility metadata.',NOW()),
('ISA_METHODOLOGY','ISA public methodology','METHODOLOGY','mg.release_registry','pub.v_isa_public_methodology','PUBLIC','P8V2_CANDIDATE','P8V2_2026_CANDIDATE','/api/v2/methodology','Public methodology and release metadata.',NOW()),
('ISA_RELEASE_MANIFEST','ISA release manifest','RELEASE','mg.release_registry','pub.v_isa_release_manifest','PUBLIC','P8V2_CANDIDATE','P8V2_2026_CANDIDATE','/api/v2/release','Public release manifest.',NOW())
ON CONFLICT (dataset_code) DO UPDATE
SET dataset_label=EXCLUDED.dataset_label,
    dataset_family=EXCLUDED.dataset_family,
    source_view=EXCLUDED.source_view,
    target_view=EXCLUDED.target_view,
    access_class=EXCLUDED.access_class,
    publication_status=EXCLUDED.publication_status,
    release_code=EXCLUDED.release_code,
    public_api_path=EXCLUDED.public_api_path,
    notes=EXCLUDED.notes,
    updated_at=NOW();

CREATE TABLE IF NOT EXISTS mg.api_contract_registry (
    endpoint_code VARCHAR(80) PRIMARY KEY,
    api_version VARCHAR(20) NOT NULL,
    http_method VARCHAR(10) NOT NULL,
    api_path TEXT NOT NULL,
    source_view TEXT NOT NULL,
    access_class VARCHAR(40) NOT NULL,
    auth_required BOOLEAN NOT NULL DEFAULT FALSE,
    contract_status VARCHAR(40) NOT NULL,
    breaking_change BOOLEAN NOT NULL DEFAULT FALSE,
    release_code VARCHAR(40) NOT NULL,
    response_contract_note TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

INSERT INTO mg.api_contract_registry(endpoint_code, api_version, http_method, api_path, source_view, access_class, auth_required, contract_status, breaking_change, release_code, response_contract_note, updated_at)
VALUES
('V2_COUNTRIES_LIST','v2','GET','/api/v2/countries','pub.v_isa_country_latest','PUBLIC',FALSE,'CANDIDATE',FALSE,'P8V2_2026_CANDIDATE','Returns latest public country scores.',NOW()),
('V2_COUNTRY_PROFILE','v2','GET','/api/v2/countries/{iso3}','pub.v_isa_country_profile','PUBLIC',FALSE,'CANDIDATE',FALSE,'P8V2_2026_CANDIDATE','Returns latest public country profile.',NOW()),
('V2_COUNTRY_HISTORY','v2','GET','/api/v2/countries/{iso3}/history','pub.v_isa_country_history','PUBLIC',FALSE,'CANDIDATE',FALSE,'P8V2_2026_CANDIDATE','Returns country history.',NOW()),
('V2_COUNTRY_PILLARS','v2','GET','/api/v2/countries/{iso3}/pillars','pub.v_isa_pillar_breakdown','PUBLIC',FALSE,'CANDIDATE',FALSE,'P8V2_2026_CANDIDATE','Returns pillar breakdown.',NOW()),
('V2_RANKINGS_LATEST','v2','GET','/api/v2/rankings/latest','pub.v_isa_country_rankings','PUBLIC',FALSE,'CANDIDATE',FALSE,'P8V2_2026_CANDIDATE','Returns latest rankings.',NOW()),
('V2_RANKINGS_YEAR','v2','GET','/api/v2/rankings/year/{year}','pub.v_isa_country_rankings','PUBLIC',FALSE,'CANDIDATE',FALSE,'P8V2_2026_CANDIDATE','Returns rankings for year.',NOW()),
('V2_OPPORTUNITIES','v2','GET','/api/v2/opportunities','pub.v_isa_opportunity_catalog','PUBLIC_LIMITED',FALSE,'CANDIDATE',FALSE,'P8V2_2026_CANDIDATE','Returns public opportunity catalog.',NOW()),
('V2_FEASIBILITY','v2','GET','/api/v2/feasibility','pub.v_isa_feasibility_catalog','EXPERT',TRUE,'CANDIDATE',FALSE,'P8V2_2026_CANDIDATE','Returns expert feasibility metadata.',NOW()),
('V2_METHODOLOGY','v2','GET','/api/v2/methodology','pub.v_isa_public_methodology','PUBLIC',FALSE,'CANDIDATE',FALSE,'P8V2_2026_CANDIDATE','Returns public methodology.',NOW()),
('V2_RELEASE','v2','GET','/api/v2/release','pub.v_isa_release_manifest','PUBLIC',FALSE,'CANDIDATE',FALSE,'P8V2_2026_CANDIDATE','Returns release manifest.',NOW())
ON CONFLICT (endpoint_code) DO UPDATE
SET api_version=EXCLUDED.api_version,
    http_method=EXCLUDED.http_method,
    api_path=EXCLUDED.api_path,
    source_view=EXCLUDED.source_view,
    access_class=EXCLUDED.access_class,
    auth_required=EXCLUDED.auth_required,
    contract_status=EXCLUDED.contract_status,
    breaking_change=EXCLUDED.breaking_change,
    release_code=EXCLUDED.release_code,
    response_contract_note=EXCLUDED.response_contract_note,
    updated_at=NOW();

CREATE TABLE IF NOT EXISTS mg.publication_audit_log (
    audit_id BIGSERIAL PRIMARY KEY,
    release_code VARCHAR(40) NOT NULL,
    audit_event VARCHAR(80) NOT NULL,
    audit_status VARCHAR(40) NOT NULL,
    object_type VARCHAR(40),
    object_name TEXT,
    audit_message TEXT,
    audit_payload JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

INSERT INTO mg.publication_audit_log(release_code, audit_event, audit_status, object_type, object_name, audit_message, audit_payload)
VALUES (
    'P8V2_2026_CANDIDATE',
    'P8V2_FOUNDATION_CREATED',
    'OK',
    'RELEASE',
    'P8V2',
    'P8 V2 foundation patch executed successfully. P8OPS preserved as LEGACY_ACTIVE.',
    jsonb_build_object('schemas', jsonb_build_array('pub','archive'))
);

DO $$
DECLARE
    n_release INTEGER;
    n_assets INTEGER;
    n_pub INTEGER;
    n_api INTEGER;
BEGIN
    SELECT COUNT(*) INTO n_release FROM mg.release_registry WHERE release_family = 'P8V2';
    SELECT COUNT(*) INTO n_assets FROM mg.asset_registry WHERE release_code = 'P8V2_2026_CANDIDATE';
    SELECT COUNT(*) INTO n_pub FROM mg.publication_registry WHERE release_code = 'P8V2_2026_CANDIDATE';
    SELECT COUNT(*) INTO n_api FROM mg.api_contract_registry WHERE release_code = 'P8V2_2026_CANDIDATE';

    RAISE NOTICE 'P8 V2 foundation: releases=%, assets=%, publication_datasets=%, api_contracts=%',
        n_release, n_assets, n_pub, n_api;
END $$;

COMMIT;
