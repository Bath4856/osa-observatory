-- ============================================================
-- OSA / ISA — P7B3
-- View: ma.v_isa_semantic_operations
-- Role:
--   Aggregated operational layer by pillar / semantic family.
-- ============================================================

CREATE OR REPLACE VIEW ma.v_isa_semantic_operations AS

SELECT
    pillar_code,
    semantic_code,
    COUNT(*) AS nb_indicators,

    ROUND(AVG(semantic_confidence_dynamic), 3) AS avg_dynamic_confidence,
    ROUND(AVG(semantic_operational_score), 3) AS avg_operational_score,
    ROUND(AVG(isa_semantic_weight), 3) AS avg_isa_semantic_weight,
    ROUND(AVG(ml_semantic_weight), 3) AS avg_ml_semantic_weight,
    ROUND(AVG(semantic_operational_vulnerability), 3) AS avg_operational_vulnerability,

    SUM(CASE WHEN semantic_operational_status = 'OPERATION_LOCKED_REVIEW' THEN 1 ELSE 0 END) AS nb_locked_review,
    SUM(CASE WHEN semantic_operational_status = 'OPERATION_READY_STRONG' THEN 1 ELSE 0 END) AS nb_ready_strong,
    SUM(CASE WHEN semantic_operational_status = 'OPERATION_READY_CONTROLLED' THEN 1 ELSE 0 END) AS nb_ready_controlled,
    SUM(CASE WHEN semantic_operational_status = 'OPERATION_MONITOR' THEN 1 ELSE 0 END) AS nb_monitor,
    SUM(CASE WHEN semantic_operational_status = 'OPERATION_LIMITED_LOW_CONFIDENCE' THEN 1 ELSE 0 END) AS nb_limited_low_confidence,

    SUM(CASE WHEN isa_operational_decision = 'ISA_INCLUDE_AS_GAP_LOCKED' THEN 1 ELSE 0 END) AS nb_isa_gap_locked,
    SUM(CASE WHEN l2_imputation_decision = 'NO_IMPUTATION_CERTIFICATION_REQUIRED' THEN 1 ELSE 0 END) AS nb_no_imputation_cert_required,
    SUM(CASE WHEN ml_operational_decision = 'ML_FORECAST_DISABLED' THEN 1 ELSE 0 END) AS nb_ml_forecast_disabled,

    CASE
        WHEN SUM(CASE WHEN semantic_operational_status = 'OPERATION_LOCKED_REVIEW' THEN 1 ELSE 0 END) > 0
            THEN 'NEEDS_OPERATIONAL_REVIEW'
        WHEN AVG(semantic_operational_score) >= 0.820
            THEN 'OPERATIONALLY_STRONG'
        WHEN AVG(semantic_operational_score) >= 0.700
            THEN 'OPERATIONALLY_CONTROLLED'
        ELSE 'OPERATIONALLY_WEAK'
    END AS operational_priority_status

FROM ma.v_semantic_operational_policy_engine
GROUP BY pillar_code, semantic_code;
