WITH bornes AS (
    SELECT
        v.indicator_code,
        MIN(v.processed_value) AS min_val,
        MAX(v.processed_value) AS max_val
    FROM ma.indicator_values v
    WHERE v.year BETWEEN 2010 AND 2024
      AND v.value_status IN ('OBSERVED','IMPUTED','INTERPOLATED')
      AND v.processed_value IS NOT NULL
    GROUP BY v.indicator_code
),
valeurs_norm AS (
    SELECT
        i.pillar_code,
        i.code                              AS indicator_code,
        i.direction,
        v.country_iso3,
        v.year,
        v.value_status,
        COALESCE(v.confidence_score, 1.0)   AS conf,
        CASE
            WHEN b.max_val = b.min_val THEN 0.5
            ELSE GREATEST(0, LEAST(1,
                (v.processed_value - b.min_val)
                / (b.max_val - b.min_val)))
        END AS norm_raw
    FROM ma.v_indicators_active i
    JOIN ma.indicator_values v
        ON  v.indicator_code = i.code
        AND v.year BETWEEN 2020 AND 2024
        AND v.value_status IN ('OBSERVED','IMPUTED','INTERPOLATED')
        AND v.processed_value IS NOT NULL
    JOIN bornes b ON b.indicator_code = i.code
),
valeurs_dir AS (
    SELECT
        pillar_code,
        indicator_code,
        country_iso3,
        year,
        value_status,
        conf,
        CASE
            WHEN direction = '+' THEN norm_raw
            ELSE 1.0 - norm_raw
        END AS norm_final
    FROM valeurs_norm
),
ind_alimentes AS (
    SELECT
        ia.pillar_code,
        COUNT(DISTINCT iv.indicator_code) AS nb_alimentes
    FROM ma.v_indicators_active ia
    JOIN ma.indicator_values iv
        ON  iv.indicator_code = ia.code
        AND iv.year BETWEEN 2010 AND 2024
        AND iv.processed_value IS NOT NULL
    GROUP BY ia.pillar_code
)
SELECT
    vd.pillar_code,
    p.name_fr                               AS pilier_nom,
    pt.pillar_type,
    pt.niveau_certification,
    pt.seuil_exclusion,
    vd.country_iso3,
    vd.year,
    COUNT(DISTINCT vd.indicator_code)       AS nb_ind_utilises,
    ia.nb_alimentes                         AS nb_ind_reference,
    ROUND(COUNT(DISTINCT vd.indicator_code) * 100.0
          / ia.nb_alimentes, 1)             AS taux_couverture_pct,
    ROUND(
        SUM(vd.norm_final * vd.conf)
        / NULLIF(SUM(vd.conf), 0)
    ::numeric, 4)                           AS score_pilier,
    COUNT(vd.indicator_code)
        FILTER (WHERE vd.value_status = 'OBSERVED')     AS nb_obs_reelles,
    COUNT(vd.indicator_code)
        FILTER (WHERE vd.value_status = 'IMPUTED')      AS nb_imputees,
    COUNT(vd.indicator_code)
        FILTER (WHERE vd.value_status = 'INTERPOLATED') AS nb_interpolees,
    ROUND(AVG(vd.conf)::numeric, 3)         AS confiance_moy
FROM valeurs_dir vd
JOIN rf.pillars p       ON p.code         = vd.pillar_code
JOIN ma.pillar_type pt  ON pt.pillar_code = vd.pillar_code
JOIN ind_alimentes ia   ON ia.pillar_code = vd.pillar_code
GROUP BY
    vd.pillar_code, p.name_fr, pt.pillar_type,
    pt.niveau_certification, pt.seuil_exclusion,
    vd.country_iso3, vd.year, ia.nb_alimentes
HAVING
    COUNT(DISTINCT vd.indicator_code) * 1.0
    / ia.nb_alimentes >= pt.seuil_exclusion
ORDER BY
    vd.pillar_code, vd.country_iso3, vd.year;