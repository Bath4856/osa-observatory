CREATE OR REPLACE FUNCTION ma.compute_pillar_score(
    p_pillar character varying,
    p_year smallint,
    p_method_version integer DEFAULT 1
)
RETURNS integer
LANGUAGE plpgsql
AS $function$
DECLARE
    v_inserted      INT;
    v_total_ind     INT;
BEGIN
    SELECT COUNT(DISTINCT ml.indicator_code) INTO v_total_ind
    FROM ma.indicator_meta_links ml
    JOIN rf.indicators i ON i.code = ml.indicator_code AND i.is_active = true
    WHERE ml.meta_code = 'SOV_' || p_pillar
      AND ml.ref_year  = p_year
      AND ml.is_active = true;

    IF v_total_ind = 0 THEN RETURN 0; END IF;

    INSERT INTO ma.pillar_scores
        (pillar_code, country_iso3, year, score,
         indicators_used, indicators_total, coverage_pct,
         method_version_id)
    SELECT
        p_pillar,
        iv.country_iso3,
        p_year,
        LEAST(1.0, GREATEST(0.0, SUM(iv.processed_value * ml.weight))) AS score,
        COUNT(DISTINCT iv.indicator_code)                               AS indicators_used,
        v_total_ind                                                     AS indicators_total,
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
       AND ml.is_active      = true
    WHERE iv.year     = p_year
      AND iv.layer_id = 3
      AND iv.processed_value IS NOT NULL
    GROUP BY iv.country_iso3
    HAVING COUNT(DISTINCT iv.indicator_code) >= 1
    ON CONFLICT (pillar_code, country_iso3, year, method_version_id)
        DO UPDATE SET
            score           = EXCLUDED.score,
            indicators_used = EXCLUDED.indicators_used,
            coverage_pct    = EXCLUDED.coverage_pct,
            computed_at     = now();

    GET DIAGNOSTICS v_inserted = ROW_COUNT;
    RETURN v_inserted;
END;
$function$;
