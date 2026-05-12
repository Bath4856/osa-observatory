-- ============================================================
-- OSA / ISA — P8D Open Data Delivery
-- ============================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS rf;

DROP TABLE IF EXISTS rf.isa_open_data_dataset_policy CASCADE;

CREATE TABLE rf.isa_open_data_dataset_policy (
    dataset_code VARCHAR(50) PRIMARY KEY,
    dataset_name TEXT NOT NULL,
    source_view TEXT NOT NULL,
    access_class VARCHAR(30) NOT NULL DEFAULT 'OPEN_DATA',
    delivery_formats TEXT[] NOT NULL DEFAULT ARRAY['JSON','CSV'],
    is_public BOOLEAN NOT NULL DEFAULT TRUE,
    requires_certification BOOLEAN NOT NULL DEFAULT TRUE,
    api_path TEXT,
    dataset_note TEXT,
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

INSERT INTO rf.isa_open_data_dataset_policy (
    dataset_code, dataset_name, source_view, access_class, delivery_formats,
    is_public, requires_certification, api_path, dataset_note
)
VALUES
('ISA_COUNTRY_YEAR', 'ISA par pays et année', 'ma.v_isa_observed_scores_by_country_year', 'OPEN_DATA', ARRAY['JSON','CSV'], TRUE, TRUE, '/api/v1/isa/country/{iso3}', 'Scores ISA observés par pays/année.'),
('ISA_PILLAR', 'ISA par pilier', 'ma.v_isa_observed_scores_by_pillar', 'OPEN_DATA', ARRAY['JSON','CSV'], TRUE, TRUE, '/api/v1/isa/pillar/{pillar}', 'Scores ISA observés par pilier.'),
('ISA_REGION', 'ISA par région', 'ma.v_isa_observed_scores_by_region_year', 'OPEN_DATA', ARRAY['JSON','CSV'], TRUE, TRUE, '/api/v1/isa/region/{region}', 'Scores ISA observés par région.'),
('ISA_SWOT', 'Signaux SWOT stratégiques', 'ma.v_isa_swot_signal_engine', 'OPEN_DATA', ARRAY['JSON','CSV'], TRUE, FALSE, '/api/v1/isa/swot/{country}', 'Signaux SWOT issus de l’observation.'),
('PROJECT_OPPORTUNITIES', 'Opportunités de projets structurants', 'ma.v_isa_project_opportunity_catalog', 'OPEN_DATA', ARRAY['JSON','CSV'], TRUE, FALSE, '/api/v1/projects/opportunity', 'Catalogue open data d’études d’opportunité.')
ON CONFLICT (dataset_code) DO UPDATE SET
    dataset_name = EXCLUDED.dataset_name,
    source_view = EXCLUDED.source_view,
    access_class = EXCLUDED.access_class,
    delivery_formats = EXCLUDED.delivery_formats,
    is_public = EXCLUDED.is_public,
    requires_certification = EXCLUDED.requires_certification,
    api_path = EXCLUDED.api_path,
    dataset_note = EXCLUDED.dataset_note,
    updated_at = NOW();

DO $$
BEGIN
    RAISE NOTICE 'P8D open data dataset policy lignes : %',
        (SELECT COUNT(*) FROM rf.isa_open_data_dataset_policy);
END $$;

COMMIT;
