CREATE OR REPLACE VIEW ma.isa_classification AS
SELECT
    t.country_iso3,
    t.avg_5y,
    t.trend_5y,
    f.isa_score,

    CASE
        -- 🔥 Leaders
        WHEN f.isa_score > 0.33 
             AND t.trend_5y > 0.01
            THEN 'LEADER'

        -- 🚀 Emergents (corrigé)
        WHEN f.isa_score > 0.30 
             AND t.avg_5y > 0.27
             AND t.trend_5y > 0.02
            THEN 'EMERGENT'

        -- ⚖️ Stable
        WHEN f.isa_score > 0.27
            THEN 'STABLE'

        -- 🔻 Déclin
        WHEN t.trend_5y < 0
            THEN 'DECLINANT'

        -- ⚠️ Fragile
        ELSE 'FRAGILE'
    END AS category

FROM ma.isa_trend_5y t
JOIN ma.isa_final f 
    ON t.country_iso3 = f.country_iso3
WHERE t.end_year = 2026;