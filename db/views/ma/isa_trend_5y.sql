CREATE OR REPLACE VIEW ma.isa_trend_5y AS

WITH base AS (
    SELECT
        country_iso3,
        year,
        isa_score
    FROM ma.isa_timeseries
),

windows AS (
    SELECT
        country_iso3,
        year AS end_year,

        -- fenêtre glissante 5 ans
        AVG(isa_score) OVER (
            PARTITION BY country_iso3
            ORDER BY year
            ROWS BETWEEN 4 PRECEDING AND CURRENT ROW
        ) AS avg_5y,

        -- pente simple (diff début/fin)
        isa_score
        -
        LAG(isa_score, 4) OVER (
            PARTITION BY country_iso3
            ORDER BY year
        ) AS trend_5y

    FROM base
)

SELECT
    country_iso3,
    end_year,
    ROUND(avg_5y::numeric,4)   AS avg_5y,
    ROUND(trend_5y::numeric,4) AS trend_5y

FROM windows
WHERE trend_5y IS NOT NULL;