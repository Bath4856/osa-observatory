-- ================================================================
-- D9 : Recalcul L2 complet -- Couverture universelle
-- Seuil exclusion = 0 -- tout pays avec >= 1 indicateur recoit un score
-- Certification CERTIFIE/CONDITIONNEL/MODELISE selon couverture
-- OSA Observatory -- Mai 2026
-- ================================================================

-- Sauvegarde des scores PMIN (calcul pondere different)
CREATE TEMP TABLE pmin_scores_backup AS
SELECT * FROM ma.pillar_scores WHERE pillar_code = 'PMIN';

-- Suppression et recalcul de tous les piliers sauf PMIN
DELETE FROM ma.pillar_scores WHERE pillar_code != 'PMIN';

WITH bornes AS (
    SELECT indicator_code,
           MIN(processed_value) AS min_val,
           MAX(processed_value) AS max_val
    FROM ma.indicator_values
    WHERE year BETWEEN 2010 AND 2024
      AND value_status IN ('OBSERVED','IMPUTED','INTERPOLATED')
      AND processed_value IS NOT NULL
    GROUP BY indicator_code
),
valeurs_dir AS (
    SELECT
        i.pillar_code,
        i.code AS indicator_code,
        v.country_iso3,
        v.year,
        COALESCE(v.confidence_score, 1.0) AS conf,
        CASE
            WHEN b.max_val = b.min_val THEN 0.5
            ELSE GREATEST(0, LEAST(1,
                (v.processed_value - b.min_val)
                / (b.max_val - b.min_val)))
        END *
        CASE WHEN i.direction = '+' THEN 1 ELSE -1 END +
        CASE WHEN i.direction = '+' THEN 0 ELSE 1 END
        AS norm_final
    FROM ma.v_indicators_active i
    JOIN ma.indicator_values v
        ON  v.indicator_code = i.code
        AND v.year BETWEEN 2020 AND 2024
        AND v.value_status IN ('OBSERVED','IMPUTED','INTERPOLATED')
        AND v.processed_value IS NOT NULL
    JOIN bornes b ON b.indicator_code = i.code
    WHERE i.pillar_code != 'PMIN'
),
ind_alimentes AS (
    SELECT ia.pillar_code,
           COUNT(DISTINCT iv.indicator_code) AS nb_alimentes
    FROM ma.v_indicators_active ia
    JOIN ma.indicator_values iv
        ON  iv.indicator_code = ia.code
        AND iv.year BETWEEN 2010 AND 2024
        AND iv.processed_value IS NOT NULL
    GROUP BY ia.pillar_code
),
scores AS (
    SELECT
        vd.pillar_code,
        vd.country_iso3,
        vd.year,
        COUNT(DISTINCT vd.indicator_code)   AS indicators_used,
        ia.nb_alimentes                     AS indicators_total,
        ROUND(COUNT(DISTINCT vd.indicator_code) * 100.0
              / ia.nb_alimentes, 1)         AS coverage_pct,
        ROUND(SUM(vd.norm_final * vd.conf)
              / NULLIF(SUM(vd.conf), 0)
        ::numeric, 6)                       AS score,
        CASE
            WHEN COUNT(DISTINCT vd.indicator_code) * 1.0
                 / ia.nb_alimentes >= 0.70 THEN 'CERTIFIE'
            WHEN COUNT(DISTINCT vd.indicator_code) * 1.0
                 / ia.nb_alimentes >= 0.40 THEN 'CONDITIONNEL'
            ELSE 'MODELISE'
        END AS certification
    FROM valeurs_dir vd
    JOIN ind_alimentes ia ON ia.pillar_code = vd.pillar_code
    GROUP BY vd.pillar_code, vd.country_iso3, vd.year, ia.nb_alimentes
    HAVING COUNT(DISTINCT vd.indicator_code) >= 1
)
INSERT INTO ma.pillar_scores
    (pillar_code, country_iso3, year, score,
     indicators_used, indicators_total, coverage_pct,
     method_version_id, certification)
SELECT pillar_code, country_iso3, year, score,
       indicators_used, indicators_total, coverage_pct,
       1, certification
FROM scores
ON CONFLICT (pillar_code, country_iso3, year, method_version_id)
DO UPDATE SET
    score           = EXCLUDED.score,
    indicators_used = EXCLUDED.indicators_used,
    coverage_pct    = EXCLUDED.coverage_pct,
    certification   = EXCLUDED.certification,
    computed_at     = now();

-- Verification
SELECT pillar_code,
       COUNT(DISTINCT country_iso3) AS nb_pays,
       COUNT(*) FILTER (WHERE certification = 'CERTIFIE') AS certifie,
       COUNT(*) FILTER (WHERE certification = 'CONDITIONNEL') AS conditionnel,
       COUNT(*) FILTER (WHERE certification = 'MODELISE') AS modelise
FROM ma.pillar_scores
WHERE pillar_code != 'PMIN'
GROUP BY pillar_code
ORDER BY pillar_code;
