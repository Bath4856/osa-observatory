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
    CASE
        WHEN pe.endpoint_code = 'FAO_FOREST_CSV' THEN 0.88
        WHEN pe.endpoint_code = 'GFW_GLOBAL_XLS' THEN 0.85
        ELSE 0.80
    END,
    1
FROM collect.raw_data rd
JOIN collect.provider_endpoints pe ON pe.id = rd.endpoint_id
WHERE rd.indicator_code IN (
    'PRES_PRB','PRES_BEN','PRES_CAR',
    'ECO_EXB','ECO_VAF','ECO_INB',
    'ENV_DEF','ENV_REF'
)
AND pe.endpoint_code IN ('FAO_FOREST_CSV','GFW_GLOBAL_XLS')
ON CONFLICT DO NOTHING;

SELECT
    indicator_code,
    COUNT(*)                     AS nb_obs,
    COUNT(DISTINCT country_iso3) AS nb_pays,
    COUNT(DISTINCT year)         AS nb_ans,
    MIN(year) AS debut,
    MAX(year) AS fin,
    ROUND(AVG(confidence_score)::numeric, 3) AS confiance_moy
FROM ma.indicator_values
WHERE indicator_code IN (
    'PRES_PRB','PRES_BEN','PRES_CAR',
    'ECO_EXB','ECO_VAF','ECO_INB',
    'ENV_DEF','ENV_REF'
)
GROUP BY indicator_code
ORDER BY indicator_code;