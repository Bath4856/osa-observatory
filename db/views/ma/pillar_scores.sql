CREATE OR REPLACE VIEW ma.pillar_scores AS
SELECT 
    v.country_iso3,
    i.pillar_code,
    AVG(v.value_weighted) AS score,
    COUNT(v.value_weighted) * 1.0 / COUNT(*) AS coverage
FROM ma.indicator_values_final v
JOIN rf.indicators i 
    ON v.indicator_code = i.code
WHERE v.value_weighted IS NOT NULL
GROUP BY v.country_iso3, i.pillar_code;
