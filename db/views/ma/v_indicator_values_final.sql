-- ======================================================
-- VIEW : ma.v_indicator_values_final
-- ======================================================

CREATE OR REPLACE VIEW ma.v_indicator_values_final AS

SELECT
    v.indicator_code,
    v.country_iso3,
    v.year,

    v.processed_value,

    v.confidence_score,
    mq.mapping_quality_score,

    -- valeur pondérée ISA
    (v.processed_value * mq.mapping_quality_score) AS value_weighted,

    mq.quality_class,
    mq.isa_status,
    mq.orphan_flag

FROM ma.indicator_values v

LEFT JOIN ma.v_mapping_quality_score mq
    ON mq.indicator_code = v.indicator_code

WHERE
    mq.isa_status = 'OK';