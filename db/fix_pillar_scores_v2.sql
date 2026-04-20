-- ============================================================
-- OSA Observatory — fix_pillar_scores_v2.sql
-- Sprint 6 — Avril 2026
-- ============================================================
-- 1. Poids SOV_PTRA, SOV_PRES, SOV_PMIL, SOV_PNUM
--    pour les codes indicateurs Sprint 6
-- 2. compute_pillar_score corrigé :
--    - v_total_ind depuis indicator_meta_links (pas rf.indicators)
--    - seuil dynamique >= 50% des indicateurs avec poids
--    - indicators_total dynamique
-- ============================================================

-- ── 1. Poids Sprint 6 ────────────────────────────────────

BEGIN;

-- SOV_PRES — 10 indicateurs Sprint 6
INSERT INTO ma.indicator_meta_links
    (meta_code, indicator_code, weight, ref_year)
SELECT
    'SOV_PRES',
    i.code,
    ROUND(1.0 / COUNT(*) OVER (PARTITION BY y.year), 6),
    y.year::smallint
FROM rf.indicators i
CROSS JOIN generate_series(2010, 2024) AS y(year)
WHERE i.pillar_code = 'PRES'
  AND i.is_active = true
  AND i.code IN (
    'PRES_ENRG_USE_CAP', 'PRES_ENRG_PROD_IEA',
    'PRES_RENEW_CAP_IRENA', 'PRES_RENEW_SHARE_FEC',
    'PRES_FOSSIL_RENTS_EIA', 'PRES_OIL_RENTS', 'PRES_GAS_RENTS',
    'PRES_WATER_FRESH', 'PRES_WATER_WITHDRAWAL', 'PRES_WATER_AGRI'
  )
ON CONFLICT (meta_code, indicator_code, ref_year) DO UPDATE
    SET weight = EXCLUDED.weight;

-- SOV_PMIL — 5 indicateurs Sprint 6
INSERT INTO ma.indicator_meta_links
    (meta_code, indicator_code, weight, ref_year)
SELECT
    'SOV_PMIL',
    i.code,
    ROUND(1.0 / COUNT(*) OVER (PARTITION BY y.year), 6),
    y.year::smallint
FROM rf.indicators i
CROSS JOIN generate_series(2010, 2024) AS y(year)
WHERE i.pillar_code = 'PMIL'
  AND i.is_active = true
  AND i.code IN (
    'PMIL_DEF_BUDGET_GDP', 'PMIL_DEF_BUDGET_GOV',
    'PMIL_ARMED_FORCES', 'PMIL_HOMICIDE_RATE', 'PMIL_STABILITY_WGI'
  )
ON CONFLICT (meta_code, indicator_code, ref_year) DO UPDATE
    SET weight = EXCLUDED.weight;

-- SOV_PNUM — 7 indicateurs Sprint 6
INSERT INTO ma.indicator_meta_links
    (meta_code, indicator_code, weight, ref_year)
SELECT
    'SOV_PNUM',
    i.code,
    ROUND(1.0 / COUNT(*) OVER (PARTITION BY y.year), 6),
    y.year::smallint
FROM rf.indicators i
CROSS JOIN generate_series(2010, 2024) AS y(year)
WHERE i.pillar_code = 'PNUM'
  AND i.is_active = true
  AND i.code IN (
    'PNUM_INTERNET_USERS', 'PNUM_BROADBAND_FIXED', 'PNUM_BROADBAND_MOBILE',
    'PNUM_MOBILE_SUBSCRIPTIONS', 'PNUM_SECURE_SERVERS',
    'PNUM_TERTIARY_ENROLL', 'PNUM_GOV_EFFECTIVENESS'
  )
ON CONFLICT (meta_code, indicator_code, ref_year) DO UPDATE
    SET weight = EXCLUDED.weight;

-- SOV_PTRA — 9 indicateurs Sprint 6
INSERT INTO ma.indicator_meta_links
    (meta_code, indicator_code, weight, ref_year)
SELECT
    'SOV_PTRA',
    i.code,
    ROUND(1.0 / COUNT(*) OVER (PARTITION BY y.year), 6),
    y.year::smallint
FROM rf.indicators i
CROSS JOIN generate_series(2010, 2024) AS y(year)
WHERE i.pillar_code = 'PTRA'
  AND i.is_active = true
  AND i.code IN (
    'PTRA_RD_DENSITY', 'PTRA_RD_PAVED', 'PTRA_RD_QUALITY',
    'PTRA_AIR_PASSENGERS', 'PTRA_AIR_CARGO', 'PTRA_AIR_AIRPORTS',
    'PTRA_PORT_CAP', 'PTRA_PORT_CONNECT', 'PTRA_LOG_LPI'
  )
ON CONFLICT (meta_code, indicator_code, ref_year) DO UPDATE
    SET weight = EXCLUDED.weight;

DO $$
DECLARE
    v_pres INT; v_pmil INT; v_pnum INT; v_ptra INT;
BEGIN
    SELECT COUNT(DISTINCT indicator_code) INTO v_pres
        FROM ma.indicator_meta_links
        WHERE meta_code = 'SOV_PRES' AND ref_year = 2022;
    SELECT COUNT(DISTINCT indicator_code) INTO v_pmil
        FROM ma.indicator_meta_links
        WHERE meta_code = 'SOV_PMIL' AND ref_year = 2022;
    SELECT COUNT(DISTINCT indicator_code) INTO v_pnum
        FROM ma.indicator_meta_links
        WHERE meta_code = 'SOV_PNUM' AND ref_year = 2022;
    SELECT COUNT(DISTINCT indicator_code) INTO v_ptra
        FROM ma.indicator_meta_links
        WHERE meta_code = 'SOV_PTRA' AND ref_year = 2022;
    RAISE NOTICE 'Poids 2022 — PRES:% PMIL:% PNUM:% PTRA:%',
        v_pres, v_pmil, v_pnum, v_ptra;
END;
$$;

COMMIT;

-- ── 2. compute_pillar_score corrigé ──────────────────────
-- v_total_ind depuis indicator_meta_links (indicateurs avec poids)
-- seuil dynamique >= 50% des indicateurs avec poids

CREATE OR REPLACE FUNCTION ma.compute_pillar_score(
    p_pillar         VARCHAR,
    p_year           SMALLINT,
    p_method_version INT DEFAULT 1
) RETURNS INT LANGUAGE plpgsql AS $$
DECLARE
    v_inserted      INT;
    v_total_ind     INT;
    v_min_ind       INT;
BEGIN
    -- Nombre d'indicateurs avec poids définis pour ce pilier/année
    SELECT COUNT(DISTINCT ml.indicator_code) INTO v_total_ind
    FROM ma.indicator_meta_links ml
    JOIN rf.indicators i ON i.code = ml.indicator_code AND i.is_active = true
    WHERE ml.meta_code = 'SOV_' || p_pillar
      AND ml.ref_year  = p_year;

    IF v_total_ind = 0 THEN RETURN 0; END IF;

    -- Seuil : >= 50% des indicateurs avec poids (minimum 1)
    v_min_ind := GREATEST(1, FLOOR(v_total_ind * 0.5));

    INSERT INTO ma.pillar_scores
        (pillar_code, country_iso3, year, score,
         indicators_used, indicators_total, coverage_pct,
         method_version_id)
    SELECT
        p_pillar,
        iv.country_iso3,
        p_year,
        LEAST(1.0, GREATEST(0.0, SUM(iv.processed_value * ml.weight))) AS score,
        COUNT(DISTINCT iv.indicator_code)             AS indicators_used,
        v_total_ind                                   AS indicators_total,
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
    HAVING COUNT(DISTINCT iv.indicator_code) >= v_min_ind
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

-- ── 3. Vérification ──────────────────────────────────────
DO $$
BEGIN
    RAISE NOTICE 'fix_pillar_scores_v2.sql OK';
    RAISE NOTICE '  Poids PRES/PMIL/PNUM/PTRA insérés pour 2010-2024';
    RAISE NOTICE '  compute_pillar_score : v_total_ind depuis meta_links';
    RAISE NOTICE '  Seuil dynamique >= 50%% des indicateurs avec poids';
END;
$$;
