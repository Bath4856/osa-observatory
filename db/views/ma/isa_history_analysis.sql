CREATE OR REPLACE VIEW ma.isa_history_analysis AS
WITH history AS (
    SELECT 
        country_iso3,
        year,
        isa_score,
        LAG(isa_score) OVER (PARTITION BY country_iso3 ORDER BY year) AS prev_score
    FROM ma.isa_timeseries   -- ⚠️ table à avoir
),

metrics AS (
    SELECT
        country_iso3,

        AVG(isa_score) AS avg_score,

        -- 📈 tendance
        AVG(isa_score - prev_score) AS trend,

        -- 📉 volatilité
        STDDEV(isa_score) AS volatility,

        -- 🚀 momentum
        MAX(isa_score) - MIN(isa_score) FILTER (WHERE year >= EXTRACT(YEAR FROM CURRENT_DATE) - 2) AS momentum

    FROM history
    WHERE prev_score IS NOT NULL
    GROUP BY country_iso3
)

SELECT * FROM metrics;
