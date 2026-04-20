-- ============================================================
-- OSA Observatory — fix_compute_isa_no_threshold.sql
-- Sprint 7 — Avril 2026
-- ============================================================
-- Modifications :
--   1. compute_isa — supprime le seuil >= N piliers
--      Tous les pays sont inclus, quel que soit le nombre
--      de piliers disponibles.
--      Ajout de pillar_count et coverage_pct dans le résultat
--      pour garder la traçabilité.
--
--   2. compute_pillar_score — supprime le seuil >= 50%
--      Tous les pays ayant au moins 1 indicateur pour un
--      pilier reçoivent un score pour ce pilier.
--      coverage_pct indique la fiabilité du score.
--
-- Philosophie :
--   L'absence de données est une information souveraine.
--   Un pays avec peu de piliers n'est pas exclu — son score
--   partiel est présenté avec son indicateur de complétude.
-- ============================================================

-- ── 1. Supprimer les anciennes versions ──────────────────
DROP FUNCTION IF EXISTS ma.compute_isa(integer, integer);
DROP FUNCTION IF EXISTS ma.compute_isa(integer, integer, integer, boolean, boolean);
DROP FUNCTION IF EXISTS ma.compute_isa(smallint, integer);

-- ── 2. compute_isa — tous les pays, sans seuil ───────────
CREATE FUNCTION ma.compute_isa(
    p_year           INTEGER,
    p_method_version INTEGER DEFAULT 1
) RETURNS TABLE(
    country_iso3   CHAR(3),
    year           INTEGER,
    isa_score      NUMERIC,
    pillar_count   INT,
    pillar_total   INT,
    coverage_pct   NUMERIC,
    inserted       BOOLEAN
) LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    WITH pillar_agg AS (
        SELECT
            ps.country_iso3,
            ps.year::INTEGER                        AS yr,
            AVG(ps.score)                           AS isa_score,
            COUNT(DISTINCT ps.pillar_code)::INT      AS pillar_count
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
        ROUND(pa.isa_score * 100, 2)                        AS isa_score,
        pa.pillar_count,
        tp.n                                                 AS pillar_total,
        ROUND(pa.pillar_count * 100.0 / tp.n, 1)            AS coverage_pct,
        true                                                 AS inserted
    FROM pillar_agg pa
    CROSS JOIN total_pillars tp
    ORDER BY isa_score DESC;
END;
$$;

-- ── 3. compute_pillar_score — seuil abaissé à 1 ──────────
-- Tout pays avec au moins 1 indicateur reçoit un score.
-- coverage_pct indique la fiabilité.

CREATE OR REPLACE FUNCTION ma.compute_pillar_score(
    p_pillar         VARCHAR,
    p_year           SMALLINT,
    p_method_version INT DEFAULT 1
) RETURNS INT LANGUAGE plpgsql AS $$
DECLARE
    v_inserted      INT;
    v_total_ind     INT;
BEGIN
    -- Nombre d'indicateurs avec poids définis pour ce pilier/année
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
        ))                                                   AS score,
        COUNT(DISTINCT iv.indicator_code)                    AS indicators_used,
        v_total_ind                                          AS indicators_total,
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
    HAVING COUNT(DISTINCT iv.indicator_code) >= 1  -- seuil = 1 indicateur minimum
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

-- Surcharge INTEGER
CREATE OR REPLACE FUNCTION ma.compute_pillar_score(
    p_pillar VARCHAR, p_year INTEGER, p_method_version INT DEFAULT 1
) RETURNS INT LANGUAGE plpgsql AS $$
BEGIN
    RETURN ma.compute_pillar_score(p_pillar, p_year::SMALLINT, p_method_version);
END;
$$;

-- ── 4. Vider pillar_scores et ISA pour recalcul propre ───
TRUNCATE ma.pillar_scores;

-- ── 5. Vérification ──────────────────────────────────────
DO $$
BEGIN
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'fix_compute_isa_no_threshold.sql — OK';
    RAISE NOTICE '  compute_isa        : sans seuil piliers';
    RAISE NOTICE '  compute_pillar_score: seuil = 1 indicateur';
    RAISE NOTICE '  pillar_scores      : vidé pour recalcul';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'Lancer : CALL ma.run_pipeline_historical(2010::smallint, 2024::smallint, 1);';
END;
$$;
