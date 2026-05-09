CREATE OR REPLACE VIEW ma.v_pmin_industrial_quality AS
SELECT
    i.pillar_code,
    i.code AS indicator_code,
    i.name_fr,
    COALESCE(n.nature_code, 'UNCLASSIFIED') AS nature_code,
    COALESCE(n.confidence_policy, 'UNKNOWN') AS confidence_policy,
    COALESCE(n.physical_weight, 0.50) AS physical_weight,
    COALESCE(n.imputation_allowed, TRUE) AS imputation_allowed,
    COALESCE(n.exclusion_threshold, 0.40) AS exclusion_threshold,
    mq.mapping_exists,
    mq.mapping_active,
    mq.coverage_score,
    mq.provider_score,
    mq.data_confidence,
    mq.registry_score,
    mq.mapping_quality_score,
    mq.quality_class,
    mq.isa_status,
    mq.orphan_flag,
    mm.mapping_maturity_score,
    mm.maturity_class,
    mm.recommended_action,
    CASE
        WHEN COALESCE(n.nature_code, 'UNCLASSIFIED') = 'PHYSICAL'
             AND mq.mapping_quality_score < COALESCE(n.exclusion_threshold, 0.60)
        THEN 'PHYSICAL_RISK'
        WHEN mq.orphan_flag = 'ORPHELIN' THEN 'ORPHAN'
        WHEN COALESCE(n.nature_code, 'UNCLASSIFIED') = 'UNCLASSIFIED' THEN 'NATURE_MISSING'
        ELSE 'OK'
    END AS pmin_quality_flag
FROM rf.indicators i
LEFT JOIN rf.indicator_nature n ON n.indicator_code = i.code
LEFT JOIN ma.v_mapping_quality_score mq ON mq.indicator_code = i.code
LEFT JOIN ma.v_mapping_maturity mm ON mm.indicator_code = i.code
WHERE i.pillar_code = 'PMIN';
