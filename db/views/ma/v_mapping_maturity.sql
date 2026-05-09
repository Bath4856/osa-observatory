-- ============================================================
-- VIEW : ma.v_mapping_maturity
-- Score de maturité mapping par indicateur.
-- ============================================================

CREATE OR REPLACE VIEW ma.v_mapping_maturity AS
WITH base AS (
    SELECT
        q.indicator_code,
        q.pillar_code,
        q.mapping_exists,
        q.mapping_active,
        q.coverage_score,
        q.provider_score,
        q.data_confidence,
        q.registry_score,
        q.mapping_quality_score,
        q.quality_class,
        q.isa_status,
        q.orphan_flag,
        COALESCE(n.nature_code, 'UNCLASSIFIED') AS nature_code,
        COALESCE(n.confidence_policy, 'UNKNOWN') AS confidence_policy,
        COALESCE(n.physical_weight, 0.50) AS physical_weight,
        COALESCE(n.imputation_allowed, TRUE) AS imputation_allowed,
        COALESCE(n.exclusion_threshold, 0.40) AS exclusion_threshold
    FROM ma.v_mapping_quality_score q
    LEFT JOIN rf.indicator_nature n ON n.indicator_code = q.indicator_code
)
SELECT
    indicator_code,
    pillar_code,
    nature_code,
    confidence_policy,
    mapping_exists,
    mapping_active,
    coverage_score,
    provider_score,
    data_confidence,
    registry_score,
    mapping_quality_score,
    physical_weight,
    imputation_allowed,
    exclusion_threshold,
    orphan_flag,
    isa_status,
    ROUND(
        0.40 * COALESCE(coverage_score, 0)
      + 0.25 * COALESCE(mapping_quality_score, 0)
      + 0.20 * COALESCE(provider_score, 0)
      + 0.15 * COALESCE(registry_score, 0)
    , 3) AS mapping_maturity_score,
    CASE
        WHEN (0.40*COALESCE(coverage_score,0)+0.25*COALESCE(mapping_quality_score,0)+0.20*COALESCE(provider_score,0)+0.15*COALESCE(registry_score,0)) >= 0.85 THEN 'A — INDUSTRIEL'
        WHEN (0.40*COALESCE(coverage_score,0)+0.25*COALESCE(mapping_quality_score,0)+0.20*COALESCE(provider_score,0)+0.15*COALESCE(registry_score,0)) >= 0.70 THEN 'B — STABLE'
        WHEN (0.40*COALESCE(coverage_score,0)+0.25*COALESCE(mapping_quality_score,0)+0.20*COALESCE(provider_score,0)+0.15*COALESCE(registry_score,0)) >= 0.55 THEN 'C — PARTIEL'
        WHEN (0.40*COALESCE(coverage_score,0)+0.25*COALESCE(mapping_quality_score,0)+0.20*COALESCE(provider_score,0)+0.15*COALESCE(registry_score,0)) >= 0.40 THEN 'D — FRAGILE'
        ELSE 'E — CRITIQUE'
    END AS maturity_class,
    CASE
        WHEN orphan_flag = 'ORPHELIN' THEN 'CORRIGER_MAPPING'
        WHEN mapping_exists = 0 THEN 'CONNECTER_SOURCE'
        WHEN nature_code = 'PHYSICAL' AND imputation_allowed = TRUE THEN 'REVOIR_IMPUTATION_PHYSIQUE'
        WHEN mapping_quality_score < exclusion_threshold THEN 'EXCLURE_OU_REQUALIFIER'
        WHEN registry_score = 0 AND mapping_exists = 1 THEN 'COMPLETER_REGISTRY'
        ELSE 'OK'
    END AS recommended_action
FROM base;
