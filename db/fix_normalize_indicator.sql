-- ============================================================
-- OSA Observatory — fix_normalize_indicator_v2.sql
-- Sprint 6 — Avril 2026
-- ============================================================

-- ── 1. normalize_indicator (SMALLINT) ────────────────────
CREATE OR REPLACE FUNCTION ma.normalize_indicator(
    p_indicator      VARCHAR,
    p_year           SMALLINT,
    p_method_version INT DEFAULT 1
) RETURNS INT LANGUAGE plpgsql AS $$
DECLARE
    v_min       NUMERIC;
    v_max       NUMERIC;
    v_direction CHAR(1);
    v_inserted  INT;
BEGIN
    SELECT direction INTO v_direction
    FROM rf.indicators WHERE code = p_indicator;

    IF v_direction IS NULL THEN RETURN 0; END IF;

    SELECT MIN(raw_value), MAX(raw_value)
    INTO   v_min, v_max
    FROM   ma.indicator_values
    WHERE  indicator_code = p_indicator
      AND  year           = p_year
      AND  layer_id       = 2
      AND  raw_value IS NOT NULL;

    IF v_min IS NULL OR v_max = v_min THEN RETURN 0; END IF;

    INSERT INTO ma.indicator_values
        (indicator_code, country_iso3, year, layer_id,
         raw_value, processed_value, quality_flag)
    SELECT
        indicator_code, country_iso3, year, 3,
        raw_value,
        CASE WHEN v_direction = '+'
            THEN (raw_value - v_min) / (v_max - v_min)
            ELSE (v_max - raw_value) / (v_max - v_min)
        END,
        quality_flag
    FROM ma.indicator_values
    WHERE indicator_code = p_indicator
      AND year = p_year AND layer_id = 2
      AND raw_value IS NOT NULL
    ON CONFLICT DO NOTHING;

    GET DIAGNOSTICS v_inserted = ROW_COUNT;
    RETURN v_inserted;
END;
$$;

-- ── 2. normalize_indicator (INTEGER surcharge) ───────────
CREATE OR REPLACE FUNCTION ma.normalize_indicator(
    p_indicator VARCHAR, p_year INTEGER, p_method_version INT DEFAULT 1
) RETURNS INT LANGUAGE plpgsql AS $$
BEGIN
    RETURN ma.normalize_indicator(p_indicator, p_year::SMALLINT, p_method_version);
END;
$$;

-- ── 3. compute_pillar_score (INTEGER surcharge) ──────────
CREATE OR REPLACE FUNCTION ma.compute_pillar_score(
    p_pillar VARCHAR, p_year INTEGER, p_method_version INT DEFAULT 1
) RETURNS INT LANGUAGE plpgsql AS $$
BEGIN
    RETURN ma.compute_pillar_score(p_pillar, p_year::SMALLINT, p_method_version);
END;
$$;

-- ── 4. compute_isa — version unique ──────────────────────
-- Suppression de toutes les versions existantes
DROP FUNCTION IF EXISTS ma.compute_isa(integer,integer,integer,boolean,boolean);
DROP FUNCTION IF EXISTS ma.compute_isa(integer,integer);
DROP FUNCTION IF EXISTS ma.compute_isa(smallint,integer);
DROP FUNCTION IF EXISTS ma.compute_isa(integer,integer,integer);

CREATE FUNCTION ma.compute_isa(
    p_year           INTEGER,
    p_method_version INTEGER DEFAULT 1
) RETURNS TABLE(
    country_iso3  CHAR(3),
    year          INTEGER,
    isa_score     NUMERIC,
    pillar_count  INT,
    inserted      BOOLEAN
) LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    WITH pillar_avg AS (
        SELECT
            ps.country_iso3,
            ps.year::INTEGER              AS yr,
            AVG(ps.score)                 AS isa_score,
            COUNT(DISTINCT ps.pillar_code)::INT AS pillar_count
        FROM ma.pillar_scores ps
        JOIN rf.pillars p ON p.code = ps.pillar_code
                          AND p.is_active = true
        WHERE ps.year = p_year
        GROUP BY ps.country_iso3, ps.year
        HAVING COUNT(DISTINCT ps.pillar_code) >= 4
    )
    SELECT
        pa.country_iso3,
        pa.yr,
        ROUND(pa.isa_score * 100, 2),
        pa.pillar_count,
        true
    FROM pillar_avg pa;
END;
$$;

-- ── 5. Vérification ──────────────────────────────────────
DO $$
BEGIN
    RAISE NOTICE 'fix_normalize_indicator_v2.sql OK';
    RAISE NOTICE '  normalize_indicator (smallint + integer)';
    RAISE NOTICE '  compute_pillar_score (integer)';
    RAISE NOTICE '  compute_isa (integer, integer) — version unique';
END;
$$;