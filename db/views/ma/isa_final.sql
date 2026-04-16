CREATE OR REPLACE VIEW ma.isa_final AS

WITH pillar_scores AS (
    -- Score moyen par pilier
    SELECT 
        v.country_iso3,
        i.pillar_code,
        AVG(v.value_weighted) AS score
    FROM ma.indicator_values_final v
    JOIN rf.indicators i 
        ON v.indicator_code = i.code
    WHERE v.value_weighted IS NOT NULL
    GROUP BY v.country_iso3, i.pillar_code
),

port_proxy AS (
    -- Score d'accès portuaire basé sur les accords actifs
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
),

ptra_corrected AS (
    -- Correction du pilier transport (PTRA)
    SELECT
        p.country_iso3,
        CASE 
            WHEN pp.port_score IS NOT NULL THEN
                0.6 * p.score + 0.4 * pp.port_score
            ELSE
                p.score
        END AS score
    FROM pillar_scores p
    LEFT JOIN port_proxy pp 
        ON p.country_iso3 = pp.country_iso3
    WHERE p.pillar_code = 'PTRA'
),

pillar_scores_final AS (
    -- Remplacement du PTRA par la version corrigée
    SELECT 
        country_iso3,
        pillar_code,
        score
    FROM pillar_scores
    WHERE pillar_code <> 'PTRA'

    UNION ALL

    SELECT 
        country_iso3,
        'PTRA' AS pillar_code,
        score
    FROM ptra_corrected
),

level_scores AS (
    -- Agrégation par niveaux stratégiques
    SELECT
        country_iso3,

        AVG(CASE 
            WHEN pillar_code IN ('PMIN','PTRA','PMIL','PENV') 
            THEN score END
        ) AS physical,

        AVG(CASE 
            WHEN pillar_code IN ('PECO','PMON','PNUM','PHUM') 
            THEN score END
        ) AS intermediate,

        AVG(CASE 
            WHEN pillar_code IN ('PGEO','PRES') 
            THEN score END
        ) AS composite

    FROM pillar_scores_final
    GROUP BY country_iso3
)

-- Calcul final ISA
SELECT
    country_iso3,

    ROUND(
        (
            0.4 * COALESCE(physical, 0) +
            0.35 * COALESCE(intermediate, 0) +
            0.25 * COALESCE(composite, 0)
        )::numeric
    , 4) AS isa_score,

    ROUND(physical::numeric, 4) AS physical_score,
    ROUND(intermediate::numeric, 4) AS intermediate_score,
    ROUND(composite::numeric, 4) AS composite_score

FROM level_scores
ORDER BY isa_score DESC;