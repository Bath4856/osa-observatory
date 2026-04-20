-- ============================================================
-- OSA Observatory — fix_pillar_scores.sql
-- Sprint 6 — Avril 2026
-- ============================================================
-- 1. Ajoute les poids manquants SOV_PTRA et SOV_PRES
-- 2. Corrige compute_pillar_score :
--    - seuil dynamique (>= 50% des indicateurs disponibles)
--    - indicators_total dynamique (pas en dur à 15)
--    - method_version_id optionnel
-- ============================================================

BEGIN;

-- ── 1. Poids SOV_PTRA ────────────────────────────────────
-- 15 indicateurs PTRA — poids égaux (1/15 ≈ 0.0667)
-- Années 2010–2024

INSERT INTO ma.indicator_meta_links
    (meta_code, indicator_code, weight, ref_year)
SELECT
    'SOV_PTRA',
    i.code,
    ROUND(1.0 / COUNT(*) OVER (PARTITION BY 1), 6),
    y.year
FROM rf.indicators i
CROSS JOIN generate_series(2010, 2024) AS y(year)
WHERE i.pillar_code = 'PTRA'
  AND i.is_active = true
ON CONFLICT (meta_code, indicator_code, ref_year) DO NOTHING;

-- ── 2. Poids SOV_PRES ────────────────────────────────────
INSERT INTO ma.indicator_meta_links
    (meta_code, indicator_code, weight, ref_year)
SELECT
    'SOV_PRES',
    i.code,
    ROUND(1.0 / COUNT(*) OVER (PARTITION BY 1), 6),
    y.year
FROM rf.indicators i
CROSS JOIN generate_series(2010, 2024) AS y(year)
WHERE i.pillar_code = 'PRES'
  AND i.is_active = true
ON CONFLICT (meta_code, indicator_code, ref_year) DO NOTHING;

-- ── 3. Vérification insertions ───────────────────────────
DO $$
DECLARE
    v_ptra INT;
    v_pres INT;
BEGIN
    SELECT COUNT(*) INTO v_ptra FROM ma.indicator_meta_links WHERE meta_code = 'SOV_PTRA';
    SELECT COUNT(*) INTO v_pres FROM ma.indicator_meta_links WHERE meta_code = 'SOV_PRES';
    RAISE NOTICE 'SOV_PTRA : % lignes', v_ptra;
    RAISE NOTICE 'SOV_PRES : % lignes', v_pres;
END;
$$;

COMMIT;

-- ── Poids pour les nouveaux codes Sprint 6 ───────────────
BEGIN;

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
    'PRES_ENRG_USE_CAP','PRES_ENRG_PROD_IEA','PRES_RENEW_CAP_IRENA',
    'PRES_RENEW_SHARE_FEC','PRES_FOSSIL_RENTS_EIA','PRES_OIL_RENTS',
    'PRES_GAS_RENTS','PRES_WATER_FRESH','PRES_WATER_WITHDRAWAL','PRES_WATER_AGRI'
  )
ON CONFLICT (meta_code, indicator_code, ref_year) DO UPDATE
    SET weight = EXCLUDED.weight;

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
    'PMIL_DEF_BUDGET_GDP','PMIL_DEF_BUDGET_GOV','PMIL_ARMED_FORCES',
    'PMIL_HOMICIDE_RATE','PMIL_STABILITY_WGI'
  )
ON CONFLICT (meta_code, indicator_code, ref_year) DO UPDATE
    SET weight = EXCLUDED.weight;

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
    'PNUM_INTERNET_USERS','PNUM_BROADBAND_FIXED','PNUM_BROADBAND_MOBILE',
    'PNUM_MOBILE_SUBSCRIPTIONS','PNUM_SECURE_SERVERS','PNUM_TERTIARY_ENROLL',
    'PNUM_GOV_EFFECTIVENESS'
  )
ON CONFLICT (meta_code, indicator_code, ref_year) DO UPDATE
    SET weight = EXCLUDED.weight;

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
    'PTRA_RD_DENSITY','PTRA_RD_PAVED','PTRA_RD_QUALITY',
    'PTRA_AIR_PASSENGERS','PTRA_AIR_CARGO','PTRA_AIR_AIRPORTS',
    'PTRA_PORT_CAP','PTRA_PORT_CONNECT','PTRA_LOG_LPI'
  )
ON CONFLICT (meta_code, indicator_code, ref_year) DO UPDATE
    SET weight = EXCLUDED.weight;

COMMIT;

-- ── 4. compute_pillar_score corrigé ──────────────────────
-- Seuil dynamique : >= 50% des indicateurs actifs du pilier
-- indicators_total dynamique depuis rf.indicators

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
    -- Nombre d'indicateurs actifs pour ce pilier
    SELECT COUNT(*) INTO v_total_ind
    FROM rf.indicators
    WHERE pillar_code = p_pillar AND is_active = true;

    IF v_total_ind = 0 THEN RETURN 0; END IF;

    -- Seuil minimum : 50% des indicateurs actifs (minimum 1)
    v_min_ind := GREATEST(1, FLOOR(v_total_ind * 0.5));

    INSERT INTO ma.pillar_scores
        (pillar_code, country_iso3, year, score,
         indicators_used, indicators_total, coverage_pct,
         method_version_id)
    SELECT
        p_pillar,
        iv.country_iso3,
        p_year,
        SUM(iv.processed_value * ml.weight)          AS score,
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
       AND ml.meta_code = 'SOV_' || p_pillar
       AND ml.ref_year = p_year
    WHERE iv.year    = p_year
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

DO $$
BEGIN
    RAISE NOTICE 'fix_pillar_scores.sql OK';
    RAISE NOTICE '  SOV_PTRA et SOV_PRES ajoutés';
    RAISE NOTICE '  compute_pillar_score : seuil dynamique 50%%';
END;
$$;
