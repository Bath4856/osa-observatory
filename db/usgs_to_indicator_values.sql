INSERT INTO ma.indicator_values
    (indicator_code, country_iso3, year,
     raw_value, processed_value,
     value_status, confidence_score, layer_id)
SELECT
    rd.indicator_code,
    rd.country_iso3,
    rd.year,
    rd.value_raw,
    rd.value_raw,
    'OBSERVED',
    0.92,
    1
FROM collect.raw_data rd
JOIN collect.provider_endpoints pe ON pe.id = rd.endpoint_id
WHERE pe.endpoint_code = 'USGS_MYB_AFRICA'
AND rd.indicator_code LIKE 'MIN_PRD_%'
ON CONFLICT DO NOTHING;

SELECT
    indicator_code,
    COUNT(*)                     AS nb_obs,
    COUNT(DISTINCT country_iso3) AS nb_pays,
    COUNT(DISTINCT year)         AS nb_ans,
    MIN(year) AS debut,
    MAX(year) AS fin
FROM ma.indicator_values
WHERE indicator_code LIKE 'MIN_PRD_%'
GROUP BY indicator_code
ORDER BY indicator_code;