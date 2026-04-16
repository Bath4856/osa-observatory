CREATE OR REPLACE VIEW ma.isa_final AS

-- ============================================================
-- 1. SCORES PAR PILIER
-- ============================================================

WITH pillar_scores AS (
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

-- ============================================================
-- 2. PROXY PORTUAIRE (PTRA)
-- ============================================================

port_proxy AS (
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
        ) AS port_score,

        COUNT(*) AS nb_corridors

    FROM rf.v_port_agreements_current
    WHERE statut = 'ACTIF'
    GROUP BY landlocked_iso3
),

-- ============================================================
-- 3. CORRECTION PTRA (ENCLAVEMENT)
-- ============================================================

ptra_corrected AS (
    SELECT
        p.country_iso3,

        CASE 
            WHEN pp.port_score IS NOT NULL THEN
                (
                    0.6 * p.score +
                    0.4 * pp.port_score
                )
                *
                CASE 
                    WHEN pp.nb_corridors = 1 THEN 0.80
                    WHEN pp.nb_corridors >= 3 THEN 1.05
                    ELSE 1.0
                END
            ELSE
                p.score * 0.55   -- 🔥 enclavement sévère
        END AS score

    FROM pillar_scores p
    LEFT JOIN port_proxy pp 
        ON p.country_iso3 = pp.country_iso3
    WHERE p.pillar_code = 'PTRA'
),

-- ============================================================
-- 4. RECONSTRUCTION DES PILIERS
-- ============================================================

pillar_scores_final AS (
    SELECT country_iso3, pillar_code, score
    FROM pillar_scores
    WHERE pillar_code <> 'PTRA'

    UNION ALL

    SELECT country_iso3, 'PTRA', score
    FROM ptra_corrected
),

-- ============================================================
-- 5. AGRÉGATION PAR BLOCS
-- ============================================================

level_scores AS (
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
        ) AS composite,

        AVG(CASE WHEN score IS NOT NULL THEN 1.0 ELSE 0.0 END) AS coverage

    FROM pillar_scores_final
    GROUP BY country_iso3
),

-- ============================================================
-- 6. CALCUL FINAL
-- ============================================================

final_scores AS (
    SELECT
        country_iso3,
        physical,
        intermediate,
        composite,
        coverage,

        -- 🔥 pondération V5
        (
            0.35 * COALESCE(physical,0) +
            0.45 * COALESCE(intermediate,0) +
            0.20 * COALESCE(composite,0)
        ) AS base_score,

        -- 🔥 déséquilibre
        (
            ABS(COALESCE(physical,0) - COALESCE(intermediate,0)) +
            ABS(COALESCE(intermediate,0) - COALESCE(composite,0)) +
            ABS(COALESCE(physical,0) - COALESCE(composite,0))
        ) / 3.0 AS imbalance,

        -- 🔥 dépendance économique
        GREATEST(0, COALESCE(physical,0) - COALESCE(intermediate,0)) AS dependency_penalty

    FROM level_scores
)

-- ============================================================
-- 7. SCORE FINAL ISA
-- ============================================================

SELECT
    country_iso3,

    ROUND(
        GREATEST(
            0,
            LEAST(
                1,
                (
                    (
                        base_score
                        - 0.20 * imbalance
                        - 0.05 * dependency_penalty
                    )
                    * (0.5 + 0.5 * coverage)
                    +
                    CASE 
                        WHEN intermediate > 0.33 
                             AND ABS(physical - intermediate) < 0.08
                        THEN 0.015
                        ELSE 0
                    END
                )
            )
        )::numeric
    ,4) AS isa_score,

    ROUND(physical::numeric,4)      AS physical_score,
    ROUND(intermediate::numeric,4)  AS intermediate_score,
    ROUND(composite::numeric,4)     AS composite_score,

    ROUND(coverage::numeric,4)      AS data_coverage,
    ROUND(imbalance::numeric,4)     AS imbalance_penalty,
    ROUND(dependency_penalty::numeric,4) AS dependency_penalty

FROM final_scores
ORDER BY isa_score DESC;