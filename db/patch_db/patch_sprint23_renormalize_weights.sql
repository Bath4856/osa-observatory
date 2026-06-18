BEGIN;

-- Renormalisation des poids : chaque indicateur actif recoit 1/nb_actifs par meta_code/ref_year
UPDATE ma.indicator_meta_links ml
SET weight = 1.0 / sub.nb_actifs
FROM (
    SELECT meta_code, ref_year, COUNT(*) AS nb_actifs
    FROM ma.indicator_meta_links
    WHERE is_active = true
    GROUP BY meta_code, ref_year
) sub
WHERE ml.meta_code = sub.meta_code
  AND ml.ref_year  = sub.ref_year
  AND ml.is_active = true;

-- Verification : toutes les sommes doivent etre a 1.0 (+/- 0.001)
SELECT meta_code, ref_year,
       COUNT(*) AS nb_actifs,
       ROUND(SUM(weight)::numeric, 6) AS sum_weight
FROM ma.indicator_meta_links
WHERE is_active = true
GROUP BY meta_code, ref_year
HAVING ABS(SUM(weight) - 1.0) > 0.01
ORDER BY meta_code, ref_year;

COMMIT;
