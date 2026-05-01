-- ================================================================
-- L2 PILOTE — PMON UNIQUEMENT
-- Validation de la formule sur le pilier reference qualite
-- Confiance 1.000, zero imputation, certification CERTIFIE
-- ================================================================

WITH bornes AS (
    SELECT
        v.indicator_code,
        MIN(v.processed_value)  AS min_val,
        MAX(v.processed_value)  AS max_val
    FROM ma.indicator_values v
    JOIN ma.v_indicators_active i ON i.code = v.indicator_code
    WHERE i.pillar_code = 'PMON'
      AND v.year BETWEEN 2010 AND 2024
      AND v.value_status IN ('OBSERVED','IMPUTED','INTERPOLATED')
      AND v.processed_value IS NOT NULL
    GROUP BY v.indicator_code
),
valeurs_norm AS (
    SELECT
        i.code                              AS indicator_code,
        i.name_fr                           AS indicateur,
        i.direction,
        v.country_iso3,
        v.year,
        v.processed_value,
        COALESCE(v.confidence_score, 0.5)   AS conf,
        v.value_status,
        CASE
            WHEN b.max_val = b.min_val THEN 0.5
            ELSE GREATEST(0, LEAST(1,
                (v.processed_value - b.min_val)
                / (b.max_val - b.min_val)
            ))
        END                                 AS norm_raw
    FROM ma.v_indicators_active i
    JOIN ma.indicator_values v
        ON  v.indicator_code = i.code
        AND v.year = 2020
        AND v.value_status IN ('OBSERVED','IMPUTED','INTERPOLATED')
        AND v.processed_value IS NOT NULL
    JOIN bornes b ON b.indicator_code = i.code
    WHERE i.pillar_code = 'PMON'
),
valeurs_dir AS (
    SELECT
        indicator_code,
        indicateur,
        country_iso3,
        year,
        direction,
        processed_value,
        conf,
        value_status,
        CASE WHEN direction = '+' THEN norm_raw
             ELSE 1.0 - norm_raw
        END                                 AS norm_final
    FROM valeurs_norm
)
SELECT
    country_iso3,
    year,
    COUNT(DISTINCT indicator_code)          AS nb_indicateurs,
    ROUND(
        SUM(norm_final * conf)
        / NULLIF(SUM(conf), 0)
    ::numeric, 4)                           AS score_pmon,
    ROUND(AVG(conf)::numeric, 3)            AS confiance_moy,
    COUNT(*) FILTER (WHERE value_status = 'OBSERVED')   AS obs_reelles,
    COUNT(*) FILTER (WHERE value_status = 'IMPUTED')    AS imputees
FROM valeurs_dir
GROUP BY country_iso3, year
HAVING COUNT(DISTINCT indicator_code) >= 6  -- seuil 70% de 9 indicateurs
ORDER BY score_pmon DESC
LIMIT 20;
