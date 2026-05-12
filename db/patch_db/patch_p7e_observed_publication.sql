-- ============================================================
-- OSA / ISA — P7E
-- Patch RF: Observed Publication Engine policy
-- Purpose:
--   Publication policy for observed ISA scores by country/year/pillar.
--   This patch intentionally avoids assumptions about existing country
--   region tables by creating a lightweight RF override table.
-- ============================================================

BEGIN;

CREATE TABLE IF NOT EXISTS rf.isa_publication_policy (
    policy_code VARCHAR(40) PRIMARY KEY,
    publication_status VARCHAR(40) NOT NULL,
    description TEXT,
    is_public BOOLEAN NOT NULL DEFAULT FALSE,
    is_official BOOLEAN NOT NULL DEFAULT FALSE,
    publication_note TEXT,
    updated_at TIMESTAMP NOT NULL DEFAULT now()
);

TRUNCATE rf.isa_publication_policy;

INSERT INTO rf.isa_publication_policy (
    policy_code,
    publication_status,
    description,
    is_public,
    is_official,
    publication_note
) VALUES
('OFFICIAL_CONSOLIDATED', 'OFFICIAL_CONSOLIDATED', 'Scores officiels consolidés sur les cinq dernières années jusqu’à N-2.', TRUE, TRUE, 'Publication officielle consolidée.'),
('PROVISIONAL_N1', 'PROVISIONAL_N1', 'Score provisoire N-1 avant consolidation complète.', TRUE, FALSE, 'Données incomplètes ou en cours de consolidation.'),
('CURRENT_YEAR_MONITORING', 'CURRENT_YEAR_MONITORING', 'Année N en cours de collecte/monitoring, non publiée officiellement.', FALSE, FALSE, 'Année courante en monitoring.'),
('EXCLUDED_NOT_READY', 'EXCLUDED_NOT_READY', 'Année hors fenêtre de publication ou insuffisamment prête.', FALSE, FALSE, 'Non publié.'),
('NO_OBSERVED_DATA', 'NO_OBSERVED_DATA', 'Aucune donnée observée exploitable.', FALSE, FALSE, 'Non publié faute de données observées.');

CREATE TABLE IF NOT EXISTS rf.isa_country_region_override (
    country_iso3 VARCHAR(3) PRIMARY KEY,
    region_code VARCHAR(80),
    economic_region_code VARCHAR(80),
    region_label TEXT,
    economic_region_label TEXT,
    notes TEXT,
    updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_isa_country_region_override_region
    ON rf.isa_country_region_override(region_code);

CREATE TABLE IF NOT EXISTS rf.isa_methodology_version (
    methodology_code VARCHAR(40) PRIMARY KEY,
    methodology_label TEXT NOT NULL,
    methodology_status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
    valid_from_year INT,
    valid_to_year INT,
    notes TEXT,
    updated_at TIMESTAMP NOT NULL DEFAULT now()
);

INSERT INTO rf.isa_methodology_version (
    methodology_code,
    methodology_label,
    methodology_status,
    valid_from_year,
    valid_to_year,
    notes
) VALUES (
    'ISA_P7E_V1',
    'ISA P7E observed publication methodology v1',
    'ACTIVE',
    2010,
    NULL,
    'Publication observée : valeurs observées × logique dynamique P7D, avec statut temporel automatique N/N-1/N-2.'
)
ON CONFLICT (methodology_code) DO UPDATE SET
    methodology_label = EXCLUDED.methodology_label,
    methodology_status = EXCLUDED.methodology_status,
    notes = EXCLUDED.notes,
    updated_at = now();

DO $$
DECLARE
    n_policy INT;
BEGIN
    SELECT COUNT(*) INTO n_policy FROM rf.isa_publication_policy;
    RAISE NOTICE 'P7E ISA publication policy lignes : %', n_policy;
END $$;

COMMIT;
