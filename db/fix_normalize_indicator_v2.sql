-- ============================================================
-- OSA Observatory — fix_normalize_indicator_v2.sql
-- Sprint 7 — Avril 2026
-- ============================================================
-- Consolidation de toutes les fonctions du pipeline L3/L5/L7.
-- Philosophie : l'absence de pilier est une information souveraine.
-- Aucun seuil sur le nombre de piliers ou d'indicateurs.
-- ============================================================

-- ── 1. normalize_indicator (SMALLINT) ────────────────────
-- Lit depuis L2 (données imputées) → insère en L3 (normalisé)
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

-- ── 3. compute_pillar_score (SMALLINT) ───────────────────
-- Seuil = 1 indicateur minimum — tous les pays inclus
-- coverage_pct indique la fiabilité du score
CREATE OR REPLACE FUNCTION ma.compute_pillar_score(
    p_pillar         VARCHAR,
    p_year           SMALLINT,
    p_method_version INT DEFAULT 1
) RETURNS INT LANGUAGE plpgsql AS $$
DECLARE
    v_inserted  INT;
    v_total_ind INT;
BEGIN
    -- Nombre d'indicateurs avec poids pour ce pilier/année
    SELECT COUNT(DISTINCT ml.indicator_code) INTO v_total_ind
    FROM ma.indicator_meta_links ml
    JOIN rf.indicators i
        ON i.code = ml.indicator_code
       AND i.is_active = true
    WHERE ml.meta_code = 'SOV_' || p_pillar
      AND ml.ref_year  = p_year;

    IF v_total_ind = 0 THEN RETURN 0; END IF;

    INSERT INTO ma.pillar_scores
        (pillar_code, country_iso3, year, score,
         indicators_used, indicators_total, coverage_pct,
         method_version_id)
    SELECT
        p_pillar,
        iv.country_iso3,
        p_year,
        LEAST(1.0, GREATEST(0.0,
            SUM(iv.processed_value * ml.weight)
        ))                                                    AS score,
        COUNT(DISTINCT iv.indicator_code)                     AS indicators_used,
        v_total_ind                                           AS indicators_total,
        ROUND(COUNT(DISTINCT iv.indicator_code) * 100.0 / v_total_ind, 1) AS coverage_pct,
        p_method_version
    FROM ma.indicator_values iv
    JOIN rf.indicators i
        ON i.code = iv.indicator_code
       AND i.pillar_code = p_pillar
       AND i.is_active = true
    JOIN ma.indicator_meta_links ml
        ON ml.indicator_code = iv.indicator_code
       AND ml.meta_code      = 'SOV_' || p_pillar
       AND ml.ref_year       = p_year
    WHERE iv.year     = p_year
      AND iv.layer_id = 3
      AND iv.processed_value IS NOT NULL
    GROUP BY iv.country_iso3
    HAVING COUNT(DISTINCT iv.indicator_code) >= 1  -- seuil minimum = 1
    ON CONFLICT (pillar_code, country_iso3, year, method_version_id)
        DO UPDATE SET
            score           = EXCLUDED.score,
            indicators_used = EXCLUDED.indicators_used,
            coverage_pct    = EXCLUDED.coverage_pct,
            computed_at     = now();

    GET DIAGNOSTICS v_inserted = ROW_COUNT;
    RETURN v_inserted;
END;
$$;

-- ── 4. compute_pillar_score (INTEGER surcharge) ──────────
CREATE OR REPLACE FUNCTION ma.compute_pillar_score(
    p_pillar VARCHAR, p_year INTEGER, p_method_version INT DEFAULT 1
) RETURNS INT LANGUAGE plpgsql AS $$
BEGIN
    RETURN ma.compute_pillar_score(p_pillar, p_year::SMALLINT, p_method_version);
END;
$$;

-- ── 5. compute_isa — sans seuil piliers ──────────────────
-- Tous les pays inclus quel que soit le nombre de piliers.
-- coverage_pct = nb piliers disponibles / nb piliers actifs total
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
    pillar_total  INT,
    coverage_pct  NUMERIC,
    inserted      BOOLEAN
) LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    WITH pillar_agg AS (
        SELECT
            ps.country_iso3,
            ps.year::INTEGER                    AS yr,
            AVG(ps.score)                       AS isa_score,
            COUNT(DISTINCT ps.pillar_code)::INT  AS pillar_count
        FROM ma.pillar_scores ps
        JOIN rf.pillars p
            ON p.code = ps.pillar_code
           AND p.is_active = true
        WHERE ps.year = p_year
        GROUP BY ps.country_iso3, ps.year
        -- Aucun seuil — tous les pays inclus
    ),
    total_pillars AS (
        SELECT COUNT(*)::INT AS n
        FROM rf.pillars
        WHERE is_active = true
    )
    SELECT
        pa.country_iso3,
        pa.yr,
        ROUND(pa.isa_score * 100, 2)              AS isa_score,
        pa.pillar_count,
        tp.n                                       AS pillar_total,
        ROUND(pa.pillar_count * 100.0 / tp.n, 1)  AS coverage_pct,
        true                                       AS inserted
    FROM pillar_agg pa
    CROSS JOIN total_pillars tp
    ORDER BY isa_score DESC;
END;
$$;

-- ── 6. Vérification ──────────────────────────────────────
DO $$
BEGIN
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'fix_normalize_indicator_v2.sql — Sprint 7 OK';
    RAISE NOTICE '  normalize_indicator  : L2 → L3, smallint + integer';
    RAISE NOTICE '  compute_pillar_score : seuil = 1 indicateur';
    RAISE NOTICE '  compute_isa          : sans seuil piliers, coverage_pct';
    RAISE NOTICE '==============================================';
END;
$$;
