-- ============================================================
-- OSA / ISA — P7I-AMAR Extension
-- Production merge pack v2
-- KEEP P7G / KEEP P7I CORE / ADD AMAR DOMAIN ONLY
-- ============================================================

BEGIN;

-- Required schemas
CREATE SCHEMA IF NOT EXISTS mg;

-- ------------------------------------------------------------
-- 1. Register P7I-AMAR as extension, without replacing P7I
-- ------------------------------------------------------------

INSERT INTO mg.package_registry (
    package_code,
    package_name,
    status,
    parent_package_code,
    description,
    created_at,
    updated_at
)
VALUES (
    'P7I-AMAR',
    'P7I-AMAR — Atrocity & Mass Atrocity Risk Extension',
    'ACTIVE',
    'P7I',
    'P7I-AMAR extends the existing P7I Early Warning & Risk Intelligence Engine with atrocity precursor and civilian protection early-warning classification. It does not legally qualify genocide, crimes against humanity, or war crimes.',
    NOW(),
    NOW()
)
ON CONFLICT (package_code)
DO UPDATE SET
    package_name = EXCLUDED.package_name,
    status = EXCLUDED.status,
    parent_package_code = EXCLUDED.parent_package_code,
    description = EXCLUDED.description,
    updated_at = NOW();

-- ------------------------------------------------------------
-- 2. Risk taxonomy extension
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS mg.risk_taxonomy (
    risk_code VARCHAR(50) PRIMARY KEY,
    risk_name TEXT NOT NULL,
    description TEXT,
    severity_order INTEGER NOT NULL DEFAULT 0,
    public_visible BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

INSERT INTO mg.risk_taxonomy (
    risk_code,
    risk_name,
    description,
    severity_order,
    public_visible
)
VALUES
('ATROCITY_PRECURSOR',
 'Atrocity Precursor Risk',
 'Early-warning risk domain for mass violence and atrocity precursor conditions. This is a preventive signal, not a legal qualification.',
 60,
 TRUE),
('CIVILIAN_PROTECTION',
 'Civilian Protection Risk',
 'Risk domain focused on civilian exposure, humanitarian stress, fragility and escalation dynamics.',
 61,
 TRUE)
ON CONFLICT (risk_code)
DO UPDATE SET
    risk_name = EXCLUDED.risk_name,
    description = EXCLUDED.description,
    severity_order = EXCLUDED.severity_order,
    public_visible = EXCLUDED.public_visible,
    updated_at = NOW();

-- ------------------------------------------------------------
-- 3. P7I alert persistence table
--    Does not replace existing P7I views.
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS mg.early_warning_alerts (
    id BIGSERIAL PRIMARY KEY,
    country_iso3 VARCHAR(3) NOT NULL,
    year INTEGER NOT NULL,
    risk_code VARCHAR(50) NOT NULL REFERENCES mg.risk_taxonomy(risk_code),
    risk_band VARCHAR(20) NOT NULL,
    risk_score NUMERIC(8,3) NOT NULL,
    confidence_score NUMERIC(6,3),
    source_engine VARCHAR(100) NOT NULL DEFAULT 'P7I-AMAR',
    public_narrative TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(country_iso3, year, risk_code, source_engine)
);

CREATE INDEX IF NOT EXISTS idx_early_warning_alerts_country_year
ON mg.early_warning_alerts(country_iso3, year);

CREATE INDEX IF NOT EXISTS idx_early_warning_alerts_risk_band
ON mg.early_warning_alerts(risk_code, risk_band);

CREATE INDEX IF NOT EXISTS idx_early_warning_alerts_source
ON mg.early_warning_alerts(source_engine);

COMMIT;
