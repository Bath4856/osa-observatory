CREATE OR REPLACE VIEW ma.indicator_values_final AS
SELECT 
    v.id,
    v.indicator_code,
    v.country_iso3,
    v.year,
    v.layer_id,
    v.raw_value,
    v.processed_value,
    v.confidence_score,
    v.value_status,

    -- 🔥 valeur normalisée pondérée
    CASE 
        WHEN v.confidence_score < 0.4 THEN NULL
        WHEN v.processed_value IS NULL THEN NULL
        ELSE v.processed_value * v.confidence_score
    END AS value_weighted

FROM ma.indicator_values v;