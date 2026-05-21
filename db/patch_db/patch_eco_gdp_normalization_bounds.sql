BEGIN;

DELETE FROM rf.normalization_bounds
WHERE indicator_code = 'ECO_GDP'
  AND freeze_version = 'v1_2026'
  AND reference_from_year = 2010
  AND reference_to_year   = 2020;

INSERT INTO rf.normalization_bounds
    (indicator_code, freeze_version, min_value, max_value,
     reference_from_year, reference_to_year,
     nb_observations, nb_countries, coverage_pct,
     is_active, freeze_reason)
VALUES (
    'ECO_GDP', 'v1_2026',
    1.19, 19481.65,
    2010, 2020,
    1188, 54, 100.0,
    TRUE,
    'Sprint 9C - fix imputer_v3 Sprint 8. Min 1.19 USD, Max 19481 USD.'
);

DO \$\$
DECLARE v_min NUMERIC; v_max NUMERIC;
BEGIN
    SELECT min_value, max_value INTO v_min, v_max
    FROM rf.normalization_bounds
    WHERE indicator_code = 'ECO_GDP' AND freeze_version = 'v1_2026';
    RAISE NOTICE 'ECO_GDP bornes gelees : MIN=% MAX=%', v_min, v_max;
END;
\$\$;

COMMIT;
