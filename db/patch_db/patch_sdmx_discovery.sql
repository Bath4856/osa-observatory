-- ============================================================
-- OSA / ISA OBSERVATORY
-- Patch: discovery SDMX automatique (IMF + OECD)
-- ============================================================
BEGIN;
CREATE SCHEMA IF NOT EXISTS collect;
CREATE TABLE IF NOT EXISTS collect.sdmx_discovery_runs (
    id BIGSERIAL PRIMARY KEY,
    provider_code VARCHAR(20) NOT NULL,
    run_type VARCHAR(20) NOT NULL DEFAULT 'DISCOVERY',
    started_at TIMESTAMP NOT NULL DEFAULT now(),
    completed_at TIMESTAMP,
    status VARCHAR(15) NOT NULL DEFAULT 'RUNNING' CHECK (status IN ('RUNNING', 'SUCCESS', 'FAILED')),
    datasets_count INT NOT NULL DEFAULT 0,
    notes TEXT
);
CREATE INDEX IF NOT EXISTS idx_sdmx_runs_provider ON collect.sdmx_discovery_runs(provider_code, started_at DESC);
CREATE TABLE IF NOT EXISTS collect.sdmx_datasets (
    id BIGSERIAL PRIMARY KEY,
    provider_code VARCHAR(20) NOT NULL,
    dataset_id VARCHAR(120) NOT NULL,
    dataset_name TEXT,
    agency VARCHAR(80),
    version VARCHAR(40) NOT NULL DEFAULT 'latest',
    source_url TEXT,
    structure_hash CHAR(64),
    first_seen_at TIMESTAMP NOT NULL DEFAULT now(),
    last_seen_at TIMESTAMP NOT NULL DEFAULT now(),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE (provider_code, dataset_id, version)
);
CREATE INDEX IF NOT EXISTS idx_sdmx_datasets_provider ON collect.sdmx_datasets(provider_code, dataset_id);
CREATE TABLE IF NOT EXISTS collect.sdmx_dataset_versions (
    id BIGSERIAL PRIMARY KEY,
    provider_code VARCHAR(20) NOT NULL,
    dataset_id VARCHAR(120) NOT NULL,
    version VARCHAR(40) NOT NULL,
    structure_hash CHAR(64) NOT NULL,
    detected_at TIMESTAMP NOT NULL DEFAULT now(),
    UNIQUE (
        provider_code,
        dataset_id,
        version,
        structure_hash
    )
);
CREATE TABLE IF NOT EXISTS collect.sdmx_dimensions (
    id BIGSERIAL PRIMARY KEY,
    provider_code VARCHAR(20) NOT NULL,
    dataset_id VARCHAR(120) NOT NULL,
    dimension_id VARCHAR(120) NOT NULL,
    concept_ref VARCHAR(120),
    codelist_id VARCHAR(120),
    UNIQUE (provider_code, dataset_id, dimension_id)
);
CREATE INDEX IF NOT EXISTS idx_sdmx_dimensions_ds ON collect.sdmx_dimensions(provider_code, dataset_id);
CREATE TABLE IF NOT EXISTS collect.sdmx_codelist_codes (
    id BIGSERIAL PRIMARY KEY,
    provider_code VARCHAR(20) NOT NULL,
    dataset_id VARCHAR(120) NOT NULL,
    codelist_id VARCHAR(120) NOT NULL,
    code_value VARCHAR(120) NOT NULL,
    code_name TEXT,
    UNIQUE (
        provider_code,
        dataset_id,
        codelist_id,
        code_value
    )
);
CREATE INDEX IF NOT EXISTS idx_sdmx_codes_lookup ON collect.sdmx_codelist_codes(provider_code, dataset_id, codelist_id);
-- Zone d'ingestion brute SDMX (sans validation métier)
CREATE TABLE IF NOT EXISTS collect.sdmx_raw_observations (
    id BIGSERIAL PRIMARY KEY,
    provider_code VARCHAR(20) NOT NULL,
    dataset_id VARCHAR(120) NOT NULL,
    series_key JSONB,
    period VARCHAR(20) NOT NULL,
    value_raw NUMERIC(24, 8),
    attrs JSONB,
    ingested_at TIMESTAMP NOT NULL DEFAULT now(),
    source_url TEXT,
    UNIQUE (provider_code, dataset_id, series_key, period)
);
CREATE INDEX IF NOT EXISTS idx_sdmx_raw_ds_period ON collect.sdmx_raw_observations(provider_code, dataset_id, period);
-- Mapping assisté: suggestions automatiques à valider manuellement
CREATE TABLE IF NOT EXISTS collect.sdmx_mapping_suggestions (
    id BIGSERIAL PRIMARY KEY,
    provider_code VARCHAR(20) NOT NULL,
    dataset_id VARCHAR(120) NOT NULL,
    candidate_code VARCHAR(120) NOT NULL,
    suggested_indicator_code VARCHAR(30),
    score NUMERIC(5, 2) NOT NULL DEFAULT 0,
    rationale TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED')),
    reviewer VARCHAR(120),
    reviewed_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_sdmx_mapping_pending ON collect.sdmx_mapping_suggestions(status, provider_code);
-- Mapping officiel (seulement après revue humaine APPROVED)
CREATE TABLE IF NOT EXISTS collect.sdmx_indicator_mapping (
    id BIGSERIAL PRIMARY KEY,
    provider_code VARCHAR(20) NOT NULL,
    dataset_id VARCHAR(120) NOT NULL,
    candidate_code VARCHAR(120) NOT NULL,
    indicator_code VARCHAR(30) NOT NULL,
    mapping_source VARCHAR(30) NOT NULL DEFAULT 'HUMAN_APPROVAL',
    suggestion_id BIGINT REFERENCES collect.sdmx_mapping_suggestions(id),
    approved_score NUMERIC(5, 2),
    approved_by VARCHAR(120),
    approved_at TIMESTAMP NOT NULL DEFAULT now(),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    updated_at TIMESTAMP NOT NULL DEFAULT now(),
    UNIQUE (provider_code, dataset_id, candidate_code)
);
CREATE INDEX IF NOT EXISTS idx_sdmx_official_mapping_provider ON collect.sdmx_indicator_mapping(provider_code, dataset_id);
COMMIT;