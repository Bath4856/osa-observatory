CREATE OR REPLACE VIEW ma.isa_final AS
WITH pillar_scores AS (
    SELECT 
        v.country_iso3,
        i.pillar_code,
        AVG(v.value_weighted) AS score
    FROM ma.indicator_values_final v
    JOIN rf.indicators i ON v.indicator_code = i.code
    WHERE v.value_weighted IS NOT NULL
    GROUP BY v.country_iso3, i.pillar_code
),

ptra_corrected AS (
    SELECT
        c.iso3 AS country_iso3,
        CASE 
            WHEN c.is_landlocked THEN
                0.6 * p.score + 0.4 * COALESCE(pp.port_score, p.score)
            ELSE
                p.score
        END AS score
    FROM rf.countries c
    LEFT JOIN pillar_scores p 
        ON c.iso3 = p.country_iso3 AND p.pillar_code = 'PTRA'
    LEFT JOIN (
        SELECT
            landlocked_iso3 AS country_iso3,
            AVG(
                confidence * 
                CASE 
                    WHEN agreement_type = 'REGIONAL' THEN 1.0
                    WHEN agreement_type = 'BILATERAL' THEN 0.9
                    WHEN agreement_type = 'DEFACTO' THEN 0.7
                    ELSE 0.8
                END
            ) AS port_score
        FROM rf.v_port_agreements_current
        WHERE statut = 'ACTIF'
        GROUP BY landlocked_iso3
    ) pp ON c.iso3 = pp.country_iso3
),

pillar_scores_final AS (
    SELECT country_iso3, pillar_code, score
    FROM pillar_scores
    WHERE pillar_code <> 'PTRA'

    UNION ALL

    SELECT country_iso3, 'PTRA', score
    FROM ptra_corrected
),

level_scores AS (
    SELECT
        country_iso3,

        AVG(CASE WHEN pillar_code IN ('PMIN','PTRA','PMIL','PENV') THEN score END) AS physical,

        AVG(CASE WHEN pillar_code IN ('PECO','PMON','PNUM','PHUM') THEN score END) AS intermediate,

        AVG(CASE WHEN pillar_code IN ('PGEO','PRES') THEN score END) AS composite

    FROM pillar_scores_final
    GROUP BY country_iso3
)

SELECT
    country_iso3,
    ROUND(
        (0.4 * physical +
         0.35 * intermediate +
         0.25 * composite)::numeric
    ,4) AS isa_score,
    ROUND(physical::numeric,4) AS physical_score,
    ROUND(intermediate::numeric,4) AS intermediate_score,
    ROUND(composite::numeric,4) AS composite_score
FROM level_scores;