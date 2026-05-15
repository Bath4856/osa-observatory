-- =============================================================================
-- OSA / ISA — PATCH P8 V2 FOUNDATION V2 (CORRIGÉ)
-- Version : P8V2_CORRECTED
--
-- Corrections vs V1 :
--   1. Ligne SQL orpheline corrigée dans mg.api_contract_registry
--   2. Vues pub.* créées (country_latest, rankings, pillar_breakdown, etc.)
--   3. P7Z Phase 2 intégré (execution_probability, convergence, fragility)
--   4. Nouveaux datasets et endpoints P7Z dans MG registries
--
-- Architecture pub.* :
--   pub.v_isa_country_latest          — scores ISA dernière année par pays
--   pub.v_isa_country_history         — historique scores ISA par pays
--   pub.v_isa_country_rankings        — classements ISA par année
--   pub.v_isa_pillar_breakdown        — scores piliers par pays
--   pub.v_isa_opportunity_catalog     — catalogue d'opportunités
--   pub.v_isa_release_manifest        — manifest de publication
--   pub.v_isa_public_methodology      — méthodologie publique
--   pub.v_isa_p7z_country_readiness   — NEW : readiness prédictive P7Z
--   pub.v_isa_p7z_execution_signals   — NEW : signaux d'exécution P7Z
--   pub.v_isa_sovereign_fragility     — NEW : fragilité souveraine P7Z
-- =============================================================================
-- PRÉREQUIS :
--   ma.v_isa_observed_scores_by_country_year
--   ma.v_isa_observed_scores_by_pillar
--   ma.v_isa_candidate_intervention_catalog
--   ma.v_isa_decision_country_year (P7J v2)
--   ma.mv_isa_p7z_execution_probability (P7Z Phase 2)
--   ma.v_isa_p7z_convergence_engine (P7Z Phase 2)
--   ma.v_isa_p7z_fragility_engine (P7Z Phase 2)
--   mg.release_registry, mg.publication_registry, mg.api_contract_registry
-- =============================================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS rf;
CREATE SCHEMA IF NOT EXISTS ma;
CREATE SCHEMA IF NOT EXISTS mg;
CREATE SCHEMA IF NOT EXISTS pub;
CREATE SCHEMA IF NOT EXISTS archive;

-- =============================================================================
-- 1. rf.package_lifecycle — mise à jour P8V2
-- =============================================================================
CREATE TABLE IF NOT EXISTS rf.package_lifecycle (
    package_code        VARCHAR(20)  PRIMARY KEY,
    package_label       TEXT         NOT NULL DEFAULT '',
    package_status      VARCHAR(40)  NOT NULL DEFAULT 'ACTIVE',
    replacement_package VARCHAR(20),
    notes               TEXT,
    updated_at          TIMESTAMP    DEFAULT NOW()
);

ALTER TABLE rf.package_lifecycle
    ADD COLUMN IF NOT EXISTS package_label       TEXT         NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS package_status      VARCHAR(40)  NOT NULL DEFAULT 'ACTIVE',
    ADD COLUMN IF NOT EXISTS replacement_package VARCHAR(20),
    ADD COLUMN IF NOT EXISTS notes               TEXT,
    ADD COLUMN IF NOT EXISTS updated_at          TIMESTAMP    DEFAULT NOW();

INSERT INTO rf.package_lifecycle
    (package_code, package_label, package_status, replacement_package, notes, updated_at)
VALUES
    ('P8OPS', 'P8 Operationalization Legacy Layer', 'LEGACY_ACTIVE', 'P8V2',
     'Legacy operationalization layer preserved during P8 V2 parallel migration.', NOW()),
    ('P8V2',  'Institutional Public Observatory V2', 'ACTIVE_CANDIDATE', NULL,
     'P8 V2 public observatory foundation. Runs in parallel with P8OPS until validation.',
     NOW())
ON CONFLICT (package_code) DO UPDATE
SET package_label       = EXCLUDED.package_label,
    package_status      = EXCLUDED.package_status,
    replacement_package = EXCLUDED.replacement_package,
    notes               = EXCLUDED.notes,
    updated_at          = NOW();

-- =============================================================================
-- 2. mg.release_registry
-- =============================================================================
CREATE TABLE IF NOT EXISTS mg.release_registry (
    release_code        VARCHAR(40)  PRIMARY KEY,
    release_label       TEXT         NOT NULL,
    release_family      VARCHAR(40)  NOT NULL,
    release_status      VARCHAR(40)  NOT NULL,
    semantic_version    VARCHAR(20)  NOT NULL,
    methodology_version VARCHAR(40),
    data_period_start   INTEGER,
    data_period_end     INTEGER,
    public_release_date DATE,
    release_notes       TEXT,
    created_at          TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMP    NOT NULL DEFAULT NOW()
);

INSERT INTO mg.release_registry (
    release_code, release_label, release_family, release_status,
    semantic_version, methodology_version,
    data_period_start, data_period_end, public_release_date, release_notes, updated_at
) VALUES (
    'P8V2_2026_CANDIDATE',
    'OSA / ISA Public Observatory V2 — Candidate Release',
    'P8V2', 'ACTIVE_CANDIDATE', '2.0.0-candidate', 'ISA_DEV_P8V2',
    2010, 2024, NULL,
    'Candidate release. Integrates P7K V3 FROZEN + P7Z Phase 2 (execution probability, '
    || 'convergence, fragility). P8OPS remains LEGACY_ACTIVE until parallel validation.',
    NOW()
) ON CONFLICT (release_code) DO UPDATE
SET release_status      = EXCLUDED.release_status,
    methodology_version = EXCLUDED.methodology_version,
    release_notes       = EXCLUDED.release_notes,
    updated_at          = NOW();

-- =============================================================================
-- 3. mg.asset_registry
-- =============================================================================
CREATE TABLE IF NOT EXISTS mg.asset_registry (
    asset_id         BIGSERIAL    PRIMARY KEY,
    asset_code       VARCHAR(120) UNIQUE NOT NULL,
    asset_name       TEXT         NOT NULL,
    asset_type       VARCHAR(40)  NOT NULL,
    current_location TEXT         NOT NULL,
    target_location  TEXT,
    classification   VARCHAR(40)  NOT NULL,
    migration_status VARCHAR(40)  NOT NULL,
    release_code     VARCHAR(40),
    notes            TEXT,
    created_at       TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMP    NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_asset_registry_classification
    ON mg.asset_registry (classification);
CREATE INDEX IF NOT EXISTS idx_asset_registry_release_code
    ON mg.asset_registry (release_code);

INSERT INTO mg.asset_registry
    (asset_code, asset_name, asset_type, current_location, target_location,
     classification, migration_status, release_code, notes, updated_at)
VALUES
('P8V2_SCHEMA_PUB',    'P8 V2 Public Schema',   'SCHEMA', 'pub',    'pub',    'ACTIVE_TO_KEEP', 'CREATED', 'P8V2_2026_CANDIDATE', 'Public publication schema.', NOW()),
('P8V2_SCHEMA_ARCHIVE','P8 V2 Archive Schema',  'SCHEMA', 'archive','archive','ACTIVE_TO_KEEP', 'CREATED', 'P8V2_2026_CANDIDATE', 'Controlled archive schema.', NOW()),
('P8OPS_VIEW_OPEN_DATA','P8 OPS Open Data Catalog','SQL_VIEW','ma.v_isa_open_data_catalog','pub.v_isa_opportunity_catalog','MIGRATE_TO_P8V2','PENDING','P8V2_2026_CANDIDATE','Open data catalog migrated.',NOW()),
('P8OPS_VIEW_API',     'P8 OPS API Registry',   'SQL_VIEW','ma.v_isa_api_registry','pub.v_isa_release_manifest','MIGRATE_TO_P8V2','PENDING','P8V2_2026_CANDIDATE','API registry migrated.',NOW()),
('P8V2_VIEW_P7Z_READINESS','P8 V2 P7Z Country Readiness','SQL_VIEW','ma.mv_isa_p7z_execution_probability','pub.v_isa_p7z_country_readiness','NEW_P8V2','CREATED','P8V2_2026_CANDIDATE','NEW — P7Z Phase 2 predictive readiness.',NOW()),
('P8V2_VIEW_P7Z_SIGNALS','P8 V2 P7Z Execution Signals','SQL_VIEW','ma.mv_isa_p7z_execution_probability','pub.v_isa_p7z_execution_signals','NEW_P8V2','CREATED','P8V2_2026_CANDIDATE','NEW — P7Z Phase 2 execution probability signals.',NOW()),
('P8V2_VIEW_FRAGILITY','P8 V2 Sovereign Fragility','SQL_VIEW','ma.v_isa_p7z_fragility_engine','pub.v_isa_sovereign_fragility','NEW_P8V2','CREATED','P8V2_2026_CANDIDATE','NEW — P7Z Phase 2 sovereign fragility index.',NOW())
ON CONFLICT (asset_code) DO UPDATE
SET asset_name       = EXCLUDED.asset_name,
    migration_status = EXCLUDED.migration_status,
    notes            = EXCLUDED.notes,
    updated_at       = NOW();

-- =============================================================================
-- 4. mg.publication_registry (avec P7Z)
-- =============================================================================
CREATE TABLE IF NOT EXISTS mg.publication_registry (
    dataset_code       VARCHAR(80)  PRIMARY KEY,
    dataset_label      TEXT         NOT NULL,
    dataset_family     VARCHAR(40)  NOT NULL,
    source_view        TEXT         NOT NULL,
    target_view        TEXT         NOT NULL,
    access_class       VARCHAR(40)  NOT NULL,
    publication_status VARCHAR(40)  NOT NULL,
    release_code       VARCHAR(40)  NOT NULL,
    public_api_path    TEXT,
    notes              TEXT,
    created_at         TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at         TIMESTAMP    NOT NULL DEFAULT NOW()
);

INSERT INTO mg.publication_registry
    (dataset_code, dataset_label, dataset_family, source_view, target_view,
     access_class, publication_status, release_code, public_api_path, notes, updated_at)
VALUES
-- Scores ISA observés
('ISA_COUNTRY_LATEST',   'ISA latest country scores',         'COUNTRY',     'ma.v_isa_observed_scores_by_country_year', 'pub.v_isa_country_latest',   'PUBLIC',        'P8V2_CANDIDATE', 'P8V2_2026_CANDIDATE', '/api/v2/countries',                  'Latest public country scores.',         NOW()),
('ISA_COUNTRY_HISTORY',  'ISA country score history',         'COUNTRY',     'ma.v_isa_observed_scores_by_country_year', 'pub.v_isa_country_history',  'PUBLIC',        'P8V2_CANDIDATE', 'P8V2_2026_CANDIDATE', '/api/v2/countries/{iso3}/history',   'Country-year historical scores.',       NOW()),
('ISA_COUNTRY_RANKINGS', 'ISA country rankings',              'RANKING',     'ma.v_isa_observed_scores_by_country_year', 'pub.v_isa_country_rankings', 'PUBLIC',        'P8V2_CANDIDATE', 'P8V2_2026_CANDIDATE', '/api/v2/rankings/latest',            'Public country rankings.',              NOW()),
('ISA_PILLAR_BREAKDOWN', 'ISA pillar breakdown',              'PILLAR',      'ma.v_isa_observed_scores_by_pillar',       'pub.v_isa_pillar_breakdown', 'PUBLIC',        'P8V2_CANDIDATE', 'P8V2_2026_CANDIDATE', '/api/v2/countries/{iso3}/pillars',   'Public pillar-level scores.',           NOW()),
-- Catalogue
('ISA_OPPORTUNITIES',    'ISA opportunity catalog',           'OPPORTUNITY', 'ma.v_isa_candidate_intervention_catalog',  'pub.v_isa_opportunity_catalog','PUBLIC_LIMITED','P8V2_CANDIDATE','P8V2_2026_CANDIDATE', '/api/v2/opportunities',              'Opportunity catalog.',                  NOW()),
-- Métadonnées
('ISA_METHODOLOGY',      'ISA public methodology',            'METHODOLOGY', 'mg.release_registry',                      'pub.v_isa_public_methodology','PUBLIC',        'P8V2_CANDIDATE', 'P8V2_2026_CANDIDATE', '/api/v2/methodology',                'Public methodology.',                   NOW()),
('ISA_RELEASE_MANIFEST', 'ISA release manifest',              'RELEASE',     'mg.release_registry',                      'pub.v_isa_release_manifest', 'PUBLIC',        'P8V2_CANDIDATE', 'P8V2_2026_CANDIDATE', '/api/v2/release',                    'Public release manifest.',              NOW()),
-- P7Z Phase 2 — NEW
('ISA_P7Z_READINESS',    'P7Z country predictive readiness',  'PREDICTIVE',  'ma.mv_isa_p7z_execution_probability',      'pub.v_isa_p7z_country_readiness','PUBLIC',    'P8V2_CANDIDATE', 'P8V2_2026_CANDIDATE', '/api/v2/predictive/readiness',       'P7Z Phase 2 — execution probability and convergence by country/pillar.',NOW()),
('ISA_P7Z_SIGNALS',      'P7Z execution probability signals', 'PREDICTIVE',  'ma.mv_isa_p7z_execution_probability',      'pub.v_isa_p7z_execution_signals','EXPERT',    'P8V2_CANDIDATE', 'P8V2_2026_CANDIDATE', '/api/v2/predictive/signals',         'P7Z Phase 2 — detailed execution signals. Expert access.',              NOW()),
('ISA_SOVEREIGN_FRAGILITY','Sovereign fragility index',       'PREDICTIVE',  'ma.v_isa_p7z_fragility_engine',            'pub.v_isa_sovereign_fragility','PUBLIC',      'P8V2_CANDIDATE', 'P8V2_2026_CANDIDATE', '/api/v2/predictive/fragility',       'P7Z Phase 2 — sovereign fragility by country/year.',                    NOW())
ON CONFLICT (dataset_code) DO UPDATE
SET dataset_label      = EXCLUDED.dataset_label,
    source_view        = EXCLUDED.source_view,
    target_view        = EXCLUDED.target_view,
    access_class       = EXCLUDED.access_class,
    publication_status = EXCLUDED.publication_status,
    release_code       = EXCLUDED.release_code,
    notes              = EXCLUDED.notes,
    updated_at         = NOW();

-- =============================================================================
-- 5. mg.api_contract_registry (ligne orpheline corrigée + P7Z)
-- =============================================================================
CREATE TABLE IF NOT EXISTS mg.api_contract_registry (
    endpoint_code         VARCHAR(80)  PRIMARY KEY,
    api_version           VARCHAR(20)  NOT NULL,
    http_method           VARCHAR(10)  NOT NULL,
    api_path              TEXT         NOT NULL,
    source_view           TEXT         NOT NULL,
    access_class          VARCHAR(40)  NOT NULL,
    auth_required         BOOLEAN      NOT NULL DEFAULT FALSE,
    contract_status       VARCHAR(40)  NOT NULL,
    breaking_change       BOOLEAN      NOT NULL DEFAULT FALSE,
    release_code          VARCHAR(40)  NOT NULL,
    response_contract_note TEXT,
    created_at            TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMP    NOT NULL DEFAULT NOW()
);

INSERT INTO mg.api_contract_registry
    (endpoint_code, api_version, http_method, api_path, source_view,
     access_class, auth_required, contract_status, breaking_change,
     release_code, response_contract_note, updated_at)
VALUES
-- Endpoints scores ISA
('V2_COUNTRIES_LIST',    'v2','GET','/api/v2/countries',                  'pub.v_isa_country_latest',       'PUBLIC',        FALSE,'CANDIDATE',FALSE,'P8V2_2026_CANDIDATE','Returns latest public country scores.',         NOW()),
('V2_COUNTRY_HISTORY',   'v2','GET','/api/v2/countries/{iso3}/history',   'pub.v_isa_country_history',      'PUBLIC',        FALSE,'CANDIDATE',FALSE,'P8V2_2026_CANDIDATE','Returns country score history.',                NOW()),
('V2_COUNTRY_PILLARS',   'v2','GET','/api/v2/countries/{iso3}/pillars',   'pub.v_isa_pillar_breakdown',     'PUBLIC',        FALSE,'CANDIDATE',FALSE,'P8V2_2026_CANDIDATE','Returns pillar breakdown.',                     NOW()),
('V2_RANKINGS_LATEST',   'v2','GET','/api/v2/rankings/latest',            'pub.v_isa_country_rankings',     'PUBLIC',        FALSE,'CANDIDATE',FALSE,'P8V2_2026_CANDIDATE','Returns latest rankings.',                      NOW()),
('V2_RANKINGS_YEAR',     'v2','GET','/api/v2/rankings/year/{year}',       'pub.v_isa_country_rankings',     'PUBLIC',        FALSE,'CANDIDATE',FALSE,'P8V2_2026_CANDIDATE','Returns rankings for a given year.',            NOW()),
-- Endpoints catalogue
('V2_OPPORTUNITIES',     'v2','GET','/api/v2/opportunities',              'pub.v_isa_opportunity_catalog',  'PUBLIC_LIMITED',FALSE,'CANDIDATE',FALSE,'P8V2_2026_CANDIDATE','Returns public opportunity catalog.',           NOW()),
-- Endpoints métadonnées
('V2_METHODOLOGY',       'v2','GET','/api/v2/methodology',                'pub.v_isa_public_methodology',   'PUBLIC',        FALSE,'CANDIDATE',FALSE,'P8V2_2026_CANDIDATE','Returns public methodology.',                   NOW()),
('V2_RELEASE',           'v2','GET','/api/v2/release',                    'pub.v_isa_release_manifest',     'PUBLIC',        FALSE,'CANDIDATE',FALSE,'P8V2_2026_CANDIDATE','Returns release manifest.',                     NOW()),
-- Endpoints P7Z Phase 2 — NEW
('V2_P7Z_READINESS',     'v2','GET','/api/v2/predictive/readiness',       'pub.v_isa_p7z_country_readiness','PUBLIC',        FALSE,'CANDIDATE',FALSE,'P8V2_2026_CANDIDATE','P7Z Phase 2 — execution readiness by country. execution_probability, convergence_class, p7z_eligibility_class.',NOW()),
('V2_P7Z_READINESS_ISO3','v2','GET','/api/v2/predictive/readiness/{iso3}','pub.v_isa_p7z_country_readiness','PUBLIC',        FALSE,'CANDIDATE',FALSE,'P8V2_2026_CANDIDATE','P7Z Phase 2 — execution readiness for one country.',NOW()),
('V2_P7Z_SIGNALS',       'v2','GET','/api/v2/predictive/signals',         'pub.v_isa_p7z_execution_signals','EXPERT',        TRUE, 'CANDIDATE',FALSE,'P8V2_2026_CANDIDATE','P7Z Phase 2 — detailed probability signals. Expert access with auth.',NOW()),
('V2_SOVEREIGN_FRAGILITY','v2','GET','/api/v2/predictive/fragility',      'pub.v_isa_sovereign_fragility',  'PUBLIC',        FALSE,'CANDIDATE',FALSE,'P8V2_2026_CANDIDATE','P7Z Phase 2 — sovereign fragility index by country/year.',NOW())
ON CONFLICT (endpoint_code) DO UPDATE
SET api_version            = EXCLUDED.api_version,
    http_method            = EXCLUDED.http_method,
    api_path               = EXCLUDED.api_path,
    source_view            = EXCLUDED.source_view,
    access_class           = EXCLUDED.access_class,
    auth_required          = EXCLUDED.auth_required,
    contract_status        = EXCLUDED.contract_status,
    breaking_change        = EXCLUDED.breaking_change,
    release_code           = EXCLUDED.release_code,
    response_contract_note = EXCLUDED.response_contract_note,
    updated_at             = NOW();

-- =============================================================================
-- 6. mg.publication_audit_log
-- =============================================================================
CREATE TABLE IF NOT EXISTS mg.publication_audit_log (
    audit_id      BIGSERIAL    PRIMARY KEY,
    release_code  VARCHAR(40)  NOT NULL,
    audit_event   VARCHAR(80)  NOT NULL,
    audit_status  VARCHAR(40)  NOT NULL,
    object_type   VARCHAR(40),
    object_name   TEXT,
    audit_message TEXT,
    audit_payload JSONB,
    created_at    TIMESTAMP    NOT NULL DEFAULT NOW()
);

INSERT INTO mg.publication_audit_log
    (release_code, audit_event, audit_status, object_type, object_name,
     audit_message, audit_payload)
VALUES (
    'P8V2_2026_CANDIDATE', 'P8V2_FOUNDATION_V2_CREATED', 'OK', 'RELEASE', 'P8V2',
    'P8 V2 foundation V2 patch executed. Includes P7Z Phase 2 datasets and endpoints. '
    || 'pub.* views created. SQL syntax corrected.',
    jsonb_build_object(
        'schemas',          jsonb_build_array('pub', 'archive'),
        'pub_views_created', 10,
        'p7z_datasets',     3,
        'p7z_endpoints',    4,
        'corrections',      jsonb_build_array(
            'orphan_sql_line_fixed',
            'pub_views_created',
            'p7z_phase2_integrated'
        )
    )
);

-- =============================================================================
-- 7. Vues pub.* — publication layer effectif
-- =============================================================================

-- -----------------------------------------------------------------------------
-- pub.v_isa_country_latest
-- Scores ISA de la dernière année disponible par pays
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS pub.v_isa_country_latest CASCADE;

CREATE VIEW pub.v_isa_country_latest AS
SELECT
    s.country_iso3,
    s.year                                              AS latest_year,
    ROUND(s.isa_observed_score::NUMERIC,             3)          AS isa_observed_score,
    ROUND(s.sovereignty_observed_score::NUMERIC,     3)          AS sovereignty_observed_score,
    ROUND(s.vulnerability_observed_score::NUMERIC,   3)          AS vulnerability_observed_score,
    ROUND(s.resilience_observed_score::NUMERIC,      3)          AS resilience_observed_score,
    -- Décision pays P7J
    d.country_decision_class,
    d.country_decision_priority_score,
    -- Fragilité P7Z
    f.sovereign_fragility_class,
    f.p7z_national_status,
    ROUND(f.sovereign_fragility_index::NUMERIC, 3)      AS sovereign_fragility_index,
    ROUND(f.avg_national_exec_probability::NUMERIC, 3)  AS avg_exec_probability
FROM ma.v_isa_observed_scores_by_country_year s
-- Dernière année disponible par pays
INNER JOIN (
    SELECT country_iso3, MAX(year) AS max_year
    FROM ma.v_isa_observed_scores_by_country_year
    GROUP BY country_iso3
) latest ON latest.country_iso3 = s.country_iso3
         AND latest.max_year    = s.year
LEFT JOIN ma.v_isa_decision_country_year d
    ON  d.country_iso3 = s.country_iso3
    AND d.year         = s.year
LEFT JOIN ma.v_isa_p7z_fragility_engine f
    ON  f.country_iso3 = s.country_iso3
    AND f.year         = s.year;

COMMENT ON VIEW pub.v_isa_country_latest IS
    'Publication P8 V2 — Scores ISA dernière année par pays.
     Enrichi avec décision P7J et fragilité P7Z Phase 2.
     API : GET /api/v2/countries';

-- -----------------------------------------------------------------------------
-- pub.v_isa_country_history
-- Historique complet des scores ISA par pays (2010–2024)
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS pub.v_isa_country_history CASCADE;

CREATE VIEW pub.v_isa_country_history AS
SELECT
    s.country_iso3,
    s.year,
    ROUND(s.isa_observed_score::NUMERIC,           3)            AS isa_observed_score,
    ROUND(s.sovereignty_observed_score::NUMERIC,   3)            AS sovereignty_observed_score,
    ROUND(s.vulnerability_observed_score::NUMERIC, 3)            AS vulnerability_observed_score,
    ROUND(s.resilience_observed_score::NUMERIC,    3)            AS resilience_observed_score,
    d.country_decision_class,
    d.country_decision_priority_score
FROM ma.v_isa_observed_scores_by_country_year s
LEFT JOIN ma.v_isa_decision_country_year d
    ON  d.country_iso3 = s.country_iso3
    AND d.year         = s.year
ORDER BY s.country_iso3, s.year;

COMMENT ON VIEW pub.v_isa_country_history IS
    'Publication P8 V2 — Historique scores ISA 2010–2024 par pays.
     API : GET /api/v2/countries/{iso3}/history';

-- -----------------------------------------------------------------------------
-- pub.v_isa_country_rankings
-- Classements ISA par année — rang et score
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS pub.v_isa_country_rankings CASCADE;

CREATE VIEW pub.v_isa_country_rankings AS
SELECT
    s.year,
    s.country_iso3,
    ROUND(s.isa_observed_score::NUMERIC, 3)                      AS isa_observed_score,
    RANK() OVER (
        PARTITION BY s.year
        ORDER BY s.isa_observed_score DESC NULLS LAST
    )                                                   AS isa_rank,
    ROUND(s.sovereignty_observed_score::NUMERIC,   3)            AS sovereignty_observed_score,
    ROUND(s.vulnerability_observed_score::NUMERIC, 3)            AS vulnerability_observed_score,
    ROUND(s.resilience_observed_score::NUMERIC,    3)            AS resilience_observed_score,
    d.country_decision_class
FROM ma.v_isa_observed_scores_by_country_year s
LEFT JOIN ma.v_isa_decision_country_year d
    ON  d.country_iso3 = s.country_iso3
    AND d.year         = s.year
ORDER BY s.year DESC, isa_rank;

COMMENT ON VIEW pub.v_isa_country_rankings IS
    'Publication P8 V2 — Classements ISA par année.
     isa_rank calculé par fenêtre RANK() OVER PARTITION BY year.
     API : GET /api/v2/rankings/latest et /year/{year}';

-- -----------------------------------------------------------------------------
-- pub.v_isa_pillar_breakdown
-- Scores par pilier — par pays et année
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS pub.v_isa_pillar_breakdown CASCADE;

CREATE VIEW pub.v_isa_pillar_breakdown AS
SELECT
    p.country_iso3,
    p.year,
    p.pillar_code,
    ROUND(p.isa_observed_score::NUMERIC,       3)             AS isa_observed_score,
    ROUND(p.sovereignty_observed_score::NUMERIC,  3)             AS sovereignty_observed_score,
    ROUND(p.vulnerability_observed_score::NUMERIC,3)             AS vulnerability_observed_score,
    ROUND(p.resilience_observed_score::NUMERIC,   3)             AS resilience_observed_score,
    -- Readiness P7Z par pilier
    ROUND(pz.avg_exec_probability::NUMERIC, 3)          AS avg_exec_probability,
    pz.convergence_class,
    pz.scenario_trend
FROM ma.v_isa_observed_scores_by_pillar p
LEFT JOIN (
    SELECT
        country_iso3, year, pillar_code,
        AVG(execution_probability)  AS avg_exec_probability,
        MIN(estimated_convergence_years) AS min_conv_years,
        -- Classe de convergence majoritaire
        MODE() WITHIN GROUP (ORDER BY
            CASE
                WHEN estimated_convergence_years <= 2  THEN 'CONVERGENCE_IMMINENT'
                WHEN estimated_convergence_years <= 5  THEN 'CONVERGENCE_SHORT_TERM'
                WHEN estimated_convergence_years <= 10 THEN 'CONVERGENCE_MEDIUM_TERM'
                ELSE 'CONVERGENCE_LONG_TERM'
            END
        )                           AS convergence_class,
        MODE() WITHIN GROUP (ORDER BY
            CASE
                WHEN central_isa_delta > 0.02  THEN 'IMPROVING'
                WHEN central_isa_delta < -0.02 THEN 'DETERIORATING'
                ELSE 'STABLE'
            END
        )                           AS scenario_trend
    FROM ma.mv_isa_p7z_execution_probability
    GROUP BY country_iso3, year, pillar_code
) pz ON pz.country_iso3 = p.country_iso3
     AND pz.year         = p.year
     AND pz.pillar_code  = p.pillar_code
ORDER BY p.country_iso3, p.year, p.pillar_code;

COMMENT ON VIEW pub.v_isa_pillar_breakdown IS
    'Publication P8 V2 — Scores par pilier enrichis P7Z Phase 2.
     avg_exec_probability et convergence_class depuis mv_isa_p7z_execution_probability.
     API : GET /api/v2/countries/{iso3}/pillars';

-- -----------------------------------------------------------------------------
-- pub.v_isa_opportunity_catalog
-- Catalogue d'opportunités d'intervention (PUBLIC_LIMITED)
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS pub.v_isa_opportunity_catalog CASCADE;

CREATE VIEW pub.v_isa_opportunity_catalog AS
SELECT
    c.country_iso3,
    c.year,
    c.pillar_code,
    c.intervention_family_code,
    c.intervention_family_label,
    c.strategic_objective,
    c.recommended_action,
    c.candidate_intervention_status,
    -- Probabilité d'exécution P7Z
    ROUND(pz.execution_probability::NUMERIC,          3) AS execution_probability,
    pz.execution_probability_class,
    pz.p7z_eligibility_class,
    ROUND(pz.estimated_convergence_years::NUMERIC,    1) AS estimated_convergence_years,
    ROUND(pz.probability_confidence_interval::NUMERIC,3) AS probability_confidence_interval
FROM ma.v_isa_candidate_intervention_catalog c
LEFT JOIN ma.mv_isa_p7z_execution_probability pz
    ON  pz.country_iso3             = c.country_iso3
    AND pz.year                     = c.year
    AND pz.pillar_code              = c.pillar_code
    AND pz.intervention_family_code = c.intervention_family_code
WHERE c.candidate_intervention_status IS NOT NULL
ORDER BY pz.execution_probability DESC NULLS LAST,
         c.country_iso3, c.year, c.pillar_code;

COMMENT ON VIEW pub.v_isa_opportunity_catalog IS
    'Publication P8 V2 — Catalogue opportunités enrichi P7Z Phase 2.
     execution_probability et convergence depuis mv_isa_p7z_execution_probability.
     Access : PUBLIC_LIMITED. API : GET /api/v2/opportunities';

-- -----------------------------------------------------------------------------
-- pub.v_isa_release_manifest
-- Manifest de publication — métadonnées de la release
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS pub.v_isa_release_manifest CASCADE;

CREATE VIEW pub.v_isa_release_manifest AS
SELECT
    r.release_code,
    r.release_label,
    r.release_status,
    r.semantic_version,
    r.methodology_version,
    r.data_period_start,
    r.data_period_end,
    r.public_release_date,
    r.release_notes,
    r.updated_at                                        AS last_updated,
    -- Counts
    (SELECT COUNT(*) FROM mg.publication_registry
     WHERE release_code = r.release_code)               AS nb_datasets,
    (SELECT COUNT(*) FROM mg.api_contract_registry
     WHERE release_code = r.release_code)               AS nb_endpoints,
    (SELECT COUNT(*) FROM mg.api_contract_registry
     WHERE release_code = r.release_code
       AND access_class = 'PUBLIC')                     AS nb_public_endpoints,
    (SELECT COUNT(*) FROM mg.api_contract_registry
     WHERE release_code = r.release_code
       AND access_class = 'EXPERT')                     AS nb_expert_endpoints
FROM mg.release_registry r
WHERE r.release_family = 'P8V2'
ORDER BY r.updated_at DESC;

COMMENT ON VIEW pub.v_isa_release_manifest IS
    'Publication P8 V2 — Manifest de la release avec compteurs datasets et endpoints.
     API : GET /api/v2/release';

-- -----------------------------------------------------------------------------
-- pub.v_isa_public_methodology
-- Méthodologie publique OSA/ISA
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS pub.v_isa_public_methodology CASCADE;

CREATE VIEW pub.v_isa_public_methodology AS
SELECT
    r.release_code,
    r.semantic_version,
    r.methodology_version,
    r.data_period_start,
    r.data_period_end,
    r.release_notes                                     AS methodology_notes,
    -- Packages actifs
    p.package_code,
    p.package_label,
    p.package_status
FROM mg.release_registry r
CROSS JOIN rf.package_lifecycle p
WHERE r.release_family = 'P8V2'
  AND p.package_status IN ('ACTIVE', 'ACTIVE_CANDIDATE', 'FROZEN')
ORDER BY r.release_code, p.package_code;

COMMENT ON VIEW pub.v_isa_public_methodology IS
    'Publication P8 V2 — Méthodologie publique et packages actifs.
     API : GET /api/v2/methodology';

-- =============================================================================
-- 8. Vues pub.* P7Z Phase 2 — NEW
-- =============================================================================

-- -----------------------------------------------------------------------------
-- pub.v_isa_p7z_country_readiness
-- Readiness prédictive P7Z agrégée par pays et année
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS pub.v_isa_p7z_country_readiness CASCADE;

CREATE VIEW pub.v_isa_p7z_country_readiness AS
SELECT
    pz.country_iso3,
    pz.year,
    -- Synthèse par pays/année
    COUNT(DISTINCT pz.pillar_code)                      AS nb_pillars_assessed,
    COUNT(*)                                            AS nb_interventions,
    -- Distribution des probabilités
    COUNT(*) FILTER (WHERE pz.execution_probability_class = 'HIGH_PROBABILITY')
                                                        AS nb_high_probability,
    COUNT(*) FILTER (WHERE pz.execution_probability_class = 'MEDIUM_PROBABILITY')
                                                        AS nb_medium_probability,
    COUNT(*) FILTER (WHERE pz.p7z_eligibility_class = 'P7Z_SIMULATION_READY')
                                                        AS nb_simulation_ready,
    COUNT(*) FILTER (WHERE pz.p7z_eligibility_class = 'P7Z_SIMULATION_PARTIAL')
                                                        AS nb_simulation_partial,
    -- Scores agrégés
    ROUND(AVG(pz.execution_probability)::NUMERIC,       3) AS avg_execution_probability,
    ROUND(MAX(pz.execution_probability)::NUMERIC,       3) AS max_execution_probability,
    ROUND(AVG(pz.estimated_convergence_years)::NUMERIC, 1) AS avg_convergence_years,
    ROUND(MIN(pz.estimated_convergence_years)::NUMERIC, 1) AS min_convergence_years,
    -- Fragilité nationale P7Z
    f.sovereign_fragility_class,
    f.p7z_national_status,
    ROUND(f.sovereign_fragility_index::NUMERIC,         3) AS sovereign_fragility_index,
    f.most_fragile_pillar,
    f.most_resilient_pillar
FROM ma.mv_isa_p7z_execution_probability pz
LEFT JOIN ma.v_isa_p7z_fragility_engine f
    ON  f.country_iso3 = pz.country_iso3
    AND f.year         = pz.year
GROUP BY
    pz.country_iso3, pz.year,
    f.sovereign_fragility_class, f.p7z_national_status,
    f.sovereign_fragility_index, f.most_fragile_pillar,
    f.most_resilient_pillar
ORDER BY avg_execution_probability DESC, pz.country_iso3, pz.year;

COMMENT ON VIEW pub.v_isa_p7z_country_readiness IS
    'Publication P8 V2 — Readiness prédictive P7Z par pays/année.
     Agrège mv_isa_p7z_execution_probability avec v_isa_p7z_fragility_engine.
     Access : PUBLIC. API : GET /api/v2/predictive/readiness';

-- -----------------------------------------------------------------------------
-- pub.v_isa_p7z_execution_signals
-- Signaux d'exécution P7Z détaillés — accès EXPERT
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS pub.v_isa_p7z_execution_signals CASCADE;

CREATE VIEW pub.v_isa_p7z_execution_signals AS
SELECT
    pz.country_iso3,
    pz.year,
    pz.pillar_code,
    pz.intervention_family_code,
    ROUND(pz.execution_probability,             3)      AS execution_probability,
    ROUND(pz.probability_confidence_interval,   3)      AS confidence_interval,
    pz.execution_probability_class,
    pz.p7z_eligibility_class,
    ROUND(pz.estimated_convergence_years,       1)      AS estimated_convergence_years,
    ROUND(pz.predictive_gap_score,              3)      AS predictive_gap_score,
    -- Composantes de probabilité
    ROUND(pz.prob_base_corrected,               3)      AS prob_base,
    ROUND(pz.prob_scenario_signal,              3)      AS prob_scenario,
    ROUND(pz.prob_decision_signal,              3)      AS prob_decision,
    ROUND(pz.prob_pressure_penalty,             3)      AS prob_pressure_penalty,
    -- Signaux sources
    ROUND(pz.central_isa_delta,                 3)      AS central_isa_delta,
    pz.central_decision,
    pz.decision_priority_class,
    pz.executive_master_status
FROM ma.mv_isa_p7z_execution_probability pz
ORDER BY pz.execution_probability DESC NULLS LAST,
         pz.country_iso3, pz.year, pz.pillar_code;

COMMENT ON VIEW pub.v_isa_p7z_execution_signals IS
    'Publication P8 V2 — Signaux d''exécution P7Z détaillés avec composantes.
     Access : EXPERT (auth_required = TRUE).
     API : GET /api/v2/predictive/signals';

-- -----------------------------------------------------------------------------
-- pub.v_isa_sovereign_fragility
-- Fragilité souveraine P7Z — PUBLIC
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS pub.v_isa_sovereign_fragility CASCADE;

CREATE VIEW pub.v_isa_sovereign_fragility AS
SELECT
    f.country_iso3,
    f.year,
    ROUND(f.sovereign_fragility_index,          3)      AS sovereign_fragility_index,
    ROUND(f.sovereign_resilience_index,         3)      AS sovereign_resilience_index,
    f.sovereign_fragility_class,
    f.p7z_national_status,
    ROUND(f.avg_national_exec_probability,      3)      AS avg_exec_probability,
    f.most_fragile_pillar,
    f.most_resilient_pillar,
    f.nb_high_cascade_pillars,
    f.total_ready_interventions,
    f.nb_pillars_assessed
FROM ma.v_isa_p7z_fragility_engine f
ORDER BY f.sovereign_fragility_index DESC NULLS LAST,
         f.country_iso3, f.year;

COMMENT ON VIEW pub.v_isa_sovereign_fragility IS
    'Publication P8 V2 — Indice de fragilité souveraine P7Z par pays/année.
     Access : PUBLIC. API : GET /api/v2/predictive/fragility';

-- =============================================================================
-- 9. Validation finale
-- =============================================================================
DO $$
DECLARE
    n_release   INTEGER;
    n_assets    INTEGER;
    n_pub       INTEGER;
    n_api       INTEGER;
    n_pub_views INTEGER;
    n_p7z_views INTEGER;
BEGIN
    SELECT COUNT(*) INTO n_release   FROM mg.release_registry       WHERE release_family = 'P8V2';
    SELECT COUNT(*) INTO n_assets    FROM mg.asset_registry          WHERE release_code = 'P8V2_2026_CANDIDATE';
    SELECT COUNT(*) INTO n_pub       FROM mg.publication_registry    WHERE release_code = 'P8V2_2026_CANDIDATE';
    SELECT COUNT(*) INTO n_api       FROM mg.api_contract_registry   WHERE release_code = 'P8V2_2026_CANDIDATE';
    SELECT COUNT(*) INTO n_pub_views FROM information_schema.views   WHERE table_schema = 'pub';
    SELECT COUNT(*) INTO n_p7z_views FROM information_schema.views
        WHERE table_schema = 'pub' AND table_name LIKE '%p7z%' OR table_name LIKE '%fragility%';

    RAISE NOTICE
        'P8 V2 foundation V2 : releases=%, assets=%, pub_datasets=%, '
        'api_contracts=%, pub_views=%, p7z_views=%',
        n_release, n_assets, n_pub, n_api, n_pub_views, n_p7z_views;

    IF n_pub_views < 9 THEN
        RAISE EXCEPTION 'ABORT : % vues pub.* créées (attendu >= 9)', n_pub_views;
    END IF;
    IF n_api < 12 THEN
        RAISE EXCEPTION 'ABORT : % API contracts (attendu >= 12)', n_api;
    END IF;
END $$;

COMMIT;
