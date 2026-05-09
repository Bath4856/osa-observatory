BEGIN;

-- ============================================================
-- 1. TABLE HISTORIQUE ISA
-- ============================================================

CREATE TABLE IF NOT EXISTS ma.isa_timeseries (
    country_iso3        CHAR(3)     NOT NULL,
    year                INT         NOT NULL,
    isa_score           NUMERIC(6,4),
    physical_score      NUMERIC(6,4),
    intermediate_score  NUMERIC(6,4),
    composite_score     NUMERIC(6,4),
    data_coverage       NUMERIC(6,4),
    imbalance_penalty   NUMERIC(6,4),
    dependency_penalty  NUMERIC(6,4),
    created_at          TIMESTAMP   DEFAULT NOW(),

    CONSTRAINT isa_timeseries_pk 
    PRIMARY KEY (country_iso3, year)
);

-- Index utile pour requêtes temporelles
CREATE INDEX IF NOT EXISTS idx_isa_timeseries_year 
ON ma.isa_timeseries(year);

CREATE INDEX IF NOT EXISTS idx_isa_timeseries_country 
ON ma.isa_timeseries(country_iso3);

-- ============================================================
-- 2. INSERT / UPSERT (année courante)
-- ============================================================

INSERT INTO ma.isa_timeseries (
    country_iso3,
    year,
    isa_score,
    physical_score,
    intermediate_score,
    composite_score,
    data_coverage,
    imbalance_penalty,
    dependency_penalty
)
SELECT
    country_iso3,
    EXTRACT(YEAR FROM CURRENT_DATE)::INT AS year,
    isa_score,
    physical_score,
    intermediate_score,
    composite_score,
    data_coverage,
    imbalance_penalty,
    dependency_penalty
FROM ma.isa_final

ON CONFLICT (country_iso3, year)
DO UPDATE SET
    isa_score          = EXCLUDED.isa_score,
    physical_score     = EXCLUDED.physical_score,
    intermediate_score = EXCLUDED.intermediate_score,
    composite_score    = EXCLUDED.composite_score,
    data_coverage      = EXCLUDED.data_coverage,
    imbalance_penalty  = EXCLUDED.imbalance_penalty,
    dependency_penalty = EXCLUDED.dependency_penalty,
    created_at         = NOW();

-- ============================================================
-- 3. CONTRÔLE
-- ============================================================

DO $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count 
    FROM ma.isa_timeseries
    WHERE year = EXTRACT(YEAR FROM CURRENT_DATE);

    RAISE NOTICE 'ISA TIMESERIES — Lignes année courante : %', v_count;
END $$;

COMMIT;
