CREATE OR REPLACE VIEW ma.v_signal_trust_engine AS
WITH base AS (
    SELECT
        v.indicator_code,
        i.pillar_code,
        v.country_iso3,
        v.year,
        v.layer_id,
        v.raw_value,
        v.processed_value,
        v.value_status,
        v.quality_flag,
        v.is_estimated,
        COALESCE(v.confidence_score,0.00)::NUMERIC AS data_confidence,
        COALESCE(n.nature_code,'UNCLASSIFIED') AS nature_code,
        COALESCE(n.confidence_policy,'UNKNOWN') AS confidence_policy,
        COALESCE(n.physical_weight,0.50)::NUMERIC AS physical_weight,
        COALESCE(n.imputation_allowed,TRUE) AS imputation_allowed,
        COALESCE(n.exclusion_threshold,0.40)::NUMERIC AS governance_threshold,
        COALESCE(m.mapping_exists,0) AS mapping_exists,
        COALESCE(m.mapping_active,0) AS mapping_active,
        COALESCE(m.coverage_score,0.00)::NUMERIC AS coverage_score,
        COALESCE(m.provider_score,0.50)::NUMERIC AS provider_score,
        COALESCE(m.registry_score,0.00)::NUMERIC AS registry_score,
        COALESCE(m.mapping_quality_score,0.00)::NUMERIC AS mapping_quality_score,
        COALESCE(mm.mapping_maturity_score,0.00)::NUMERIC AS mapping_maturity_score
    FROM ma.indicator_values v
    JOIN rf.indicators i ON i.code = v.indicator_code
    LEFT JOIN rf.indicator_nature n ON n.indicator_code = v.indicator_code
    LEFT JOIN ma.v_mapping_quality_score m ON m.indicator_code = v.indicator_code
    LEFT JOIN ma.v_mapping_maturity mm ON mm.indicator_code = v.indicator_code
),
scored AS (
    SELECT
        b.*,
        p.weak_signal_threshold,
        (
            b.data_confidence * COALESCE(p.weight_data_confidence,0.25)
          + b.mapping_quality_score * COALESCE(p.weight_mapping_quality,0.25)
          + b.mapping_maturity_score * COALESCE(p.weight_mapping_maturity,0.15)
          + b.coverage_score * COALESCE(p.weight_coverage,0.15)
          + b.provider_score * COALESCE(p.weight_provider,0.20)
          - CASE WHEN b.nature_code='PHYSICAL' AND b.is_estimated THEN COALESCE(p.physical_penalty,0.15) ELSE 0 END
          - CASE WHEN b.is_estimated THEN COALESCE(p.imputation_penalty,0.08) ELSE 0 END
          - CASE WHEN b.nature_code='UNCLASSIFIED' THEN COALESCE(p.unclassified_penalty,0.10) ELSE 0 END
        ) AS trust_raw
    FROM base b
    LEFT JOIN ma.signal_trust_policy p ON p.nature_code = b.nature_code
)
SELECT
    indicator_code, pillar_code, country_iso3, year, layer_id,
    raw_value, processed_value, value_status, quality_flag, is_estimated,
    nature_code, confidence_policy, physical_weight, imputation_allowed, governance_threshold,
    data_confidence, mapping_exists, mapping_active, coverage_score, provider_score,
    registry_score, mapping_quality_score, mapping_maturity_score,
    ROUND(GREATEST(0,LEAST(1,trust_raw))::NUMERIC,3) AS signal_trust_score,
    ROUND(GREATEST(0,LEAST(1,
        1 - GREATEST(0,LEAST(1,trust_raw))
        + CASE WHEN nature_code='UNCLASSIFIED' THEN 0.15 ELSE 0 END
        + CASE WHEN mapping_exists=0 THEN 0.20 ELSE 0 END
        + CASE WHEN data_confidence < 0.50 THEN 0.10 ELSE 0 END
    ))::NUMERIC,3) AS signal_vulnerability_score,
    CASE
        WHEN GREATEST(0,LEAST(1,trust_raw)) >= 0.75 THEN 'TRUSTED_SIGNAL'
        WHEN GREATEST(0,LEAST(1,trust_raw)) >= COALESCE(weak_signal_threshold,0.50) THEN 'WEAK_BUT_INFORMATIVE'
        WHEN mapping_exists=0 OR coverage_score < 0.20 THEN 'STRUCTURAL_GAP'
        WHEN nature_code='UNCLASSIFIED' THEN 'NATURE_GAP'
        ELSE 'LOW_TRUST_SIGNAL'
    END AS signal_status,
    CASE
        WHEN nature_code='PHYSICAL' AND is_estimated THEN 'PHYSICAL_ESTIMATION_RISK'
        WHEN mapping_exists=0 THEN 'MAPPING_GAP'
        WHEN nature_code='UNCLASSIFIED' THEN 'NATURE_CLASSIFICATION_GAP'
        WHEN data_confidence < 0.50 THEN 'LOW_CONFIDENCE'
        WHEN coverage_score < 0.30 THEN 'LOW_COVERAGE'
        ELSE 'OBSERVED_OR_ACCEPTABLE'
    END AS vulnerability_reason
FROM scored;
