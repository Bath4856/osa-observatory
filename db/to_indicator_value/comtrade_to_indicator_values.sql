-- Transfert COMTRADE vers ma.indicator_values
-- Filtrer annee 2025 (suspecte)
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
    0.85,
    1
FROM collect.raw_data rd
JOIN collect.provider_endpoints pe ON pe.id = rd.endpoint_id
WHERE pe.endpoint_code = 'COMTRADE_MINERALS'
AND rd.indicator_code IN ('MIN_EXP_ORE','MIN_EXP_PRC','MIN_EXP_FUL')
AND rd.year BETWEEN 2010 AND 2024
ON CONFLICT DO NOTHING;

SELECT
    indicator_code,
    COUNT(*)                     AS nb_obs,
    COUNT(DISTINCT country_iso3) AS nb_pays,
    COUNT(DISTINCT year)         AS nb_ans,
    MIN(year) AS debut,
    MAX(year) AS fin,
    ROUND(AVG(confidence_score)::numeric,3) AS confiance
FROM ma.indicator_values
WHERE indicator_code LIKE 'MIN_%'
GROUP BY indicator_code
ORDER BY indicator_code;