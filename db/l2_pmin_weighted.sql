-- ================================================================
-- L2 PMIN : Calcul score pilier avec ponderation 40/40/20
-- PHYSIQUE 40% + EXPLOITATION 40% + PRESSION 20%
-- OSA Observatory - Mai 2026
-- ================================================================

-- Suppression scores PMIN existants
DELETE FROM ma.pillar_scores WHERE pillar_code = 'PMIN';

-- Bornes normalisation par indicateur (serie 2010-2024)
WITH bornes AS (
    SELECT indicator_code,
           MIN(processed_value) AS min_val,
           MAX(processed_value) AS max_val
    FROM ma.indicator_values iv
    JOIN rf.indicators i ON i.code = iv.indicator_code
    WHERE i.pillar_code = 'PMIN'
    AND iv.processed_value IS NOT NULL
    AND iv.year BETWEEN 2010 AND 2024
    GROUP BY indicator_code
),
-- Valeurs normalisees
valeurs_norm AS (
    SELECT
        i.indicator_group,
        i.code AS indicator_code,
        i.direction,
        iv.country_iso3,
        iv.year,
        COALESCE(iv.confidence_score, 0.85) AS conf,
        CASE
            WHEN b.max_val = b.min_val THEN 0.5
            WHEN i.direction = '+'
                THEN GREATEST(0, LEAST(1,
                    (iv.processed_value - b.min_val)
                    / (b.max_val - b.min_val)))
            ELSE GREATEST(0, LEAST(1,
                (b.max_val - iv.processed_value)
                / (b.max_val - b.min_val)))
        END AS norm_val
    FROM rf.indicators i
    JOIN ma.indicator_values iv ON iv.indicator_code = i.code
        AND iv.processed_value IS NOT NULL
        AND iv.year BETWEEN 2020 AND 2024
    JOIN bornes b ON b.indicator_code = i.code
    WHERE i.pillar_code = 'PMIN'
    AND i.indicator_group IS NOT NULL
),
-- Score par groupe pour chaque pays/annee
scores_groupes AS (
    SELECT
        vn.country_iso3,
        vn.year,
        vn.indicator_group,
        ROUND(SUM(vn.norm_val * vn.conf)
              / NULLIF(SUM(vn.conf), 0)::numeric, 6) AS score_groupe,
        COUNT(DISTINCT vn.indicator_code) AS nb_ind,
        ROUND(AVG(vn.conf)::numeric, 3) AS conf_moy
    FROM valeurs_norm vn
    GROUP BY vn.country_iso3, vn.year, vn.indicator_group
),
-- Score final PMIN = somme ponderee des 3 groupes
score_final AS (
    SELECT
        sg.country_iso3,
        sg.year,
        ROUND(SUM(sg.score_groupe * pw.weight)
              / NULLIF(SUM(pw.weight), 0)::numeric, 6) AS score,
        COUNT(DISTINCT sg.indicator_group) AS nb_groupes,
        SUM(sg.nb_ind) AS nb_ind_total,
        ROUND(AVG(sg.conf_moy)::numeric, 3) AS conf_moy,
        CASE
            WHEN COUNT(DISTINCT sg.indicator_group) = 3
                 AND AVG(sg.score_groupe) > 0 THEN 'CERTIFIE'
            WHEN COUNT(DISTINCT sg.indicator_group) >= 2 THEN 'CONDITIONNEL'
            ELSE 'MODELISE'
        END AS certification
    FROM scores_groupes sg
    JOIN ma.pillar_weights pw
        ON pw.pillar_code = 'PMIN'
        AND pw.indicator_group = sg.indicator_group
    GROUP BY sg.country_iso3, sg.year
)
INSERT INTO ma.pillar_scores
    (pillar_code, country_iso3, year, score,
     indicators_used, indicators_total, coverage_pct,
     method_version_id, certification)
SELECT
    'PMIN',
    sf.country_iso3,
    sf.year,
    sf.score,
    sf.nb_ind_total::smallint,
    27::smallint,
    ROUND(sf.nb_ind_total * 100.0 / 27, 1),
    1,
    sf.certification
FROM score_final sf;

-- Verification
SELECT
    certification,
    COUNT(*) AS nb_scores,
    COUNT(DISTINCT country_iso3) AS nb_pays,
    ROUND(AVG(score)::numeric, 4) AS score_moy,
    ROUND(MIN(score)::numeric, 4) AS score_min,
    ROUND(MAX(score)::numeric, 4) AS score_max
FROM ma.pillar_scores
WHERE pillar_code = 'PMIN'
GROUP BY certification
ORDER BY certification;