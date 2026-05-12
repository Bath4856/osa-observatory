-- ============================================================
-- OSA / ISA — P7F
-- View: ma.v_isa_candidate_intervention_catalog
-- Purpose: diagnostic candidate interventions only.
-- No premium, no feasibility trigger, no forecast validation.
-- ============================================================

CREATE OR REPLACE VIEW ma.v_isa_candidate_intervention_catalog AS
SELECT
    d.country_iso3,
    d.year,
    d.pillar_code,
    f.intervention_family_code,
    f.intervention_family_label,
    f.strategic_objective,
    CASE
        WHEN d.strategic_diagnostic_role = 'WEAKNESS_TO_FIX' THEN 'ATTENUATE_OBSERVED_WEAKNESS'
        WHEN d.strategic_diagnostic_role = 'THREAT_TO_MITIGATE' THEN 'MITIGATE_OBSERVED_THREAT'
        WHEN d.strategic_diagnostic_role = 'STRENGTH_TO_SCALE' THEN 'DOCUMENT_AND_SCALE_STRENGTH'
        WHEN d.strategic_diagnostic_role = 'OPPORTUNITY_TO_ACCELERATE' THEN 'QUALIFY_OBSERVED_OPPORTUNITY'
        ELSE 'DOCUMENT_AND_MONITOR'
    END AS recommended_action,
    d.strategic_diagnostic_role,
    d.strategic_attention_class,
    d.diagnostic_priority_score AS priority_score,
    CASE
        WHEN d.swot_data_status IN ('FULL_SWOT_AVAILABLE','WKN_THR_AVAILABLE') THEN 'COMPUTED_SWOT_DIAGNOSTIC'
        WHEN d.swot_data_status IN ('WKN_AVAILABLE','THR_AVAILABLE','PARTIAL_SWOT_AVAILABLE') THEN 'PARTIAL_COMPUTED_SWOT_DIAGNOSTIC'
        ELSE 'OBSERVED_ONLY_DIAGNOSTIC'
    END AS diagnostic_evidence_status,
    CASE
        WHEN d.diagnostic_priority_score >= 0.75 THEN 'CANDIDATE_INTERVENTION_HIGH_PRIORITY'
        WHEN d.diagnostic_priority_score >= 0.55 THEN 'CANDIDATE_INTERVENTION_STANDARD_PRIORITY'
        ELSE 'CANDIDATE_INTERVENTION_MONITORING'
    END AS candidate_intervention_status,
    'P7F_DIAGNOSTIC_ONLY_NOT_FORECAST_VALIDATED'::TEXT AS validation_scope
FROM ma.v_isa_strategic_diagnostic_engine d
LEFT JOIN rf.isa_candidate_intervention_family f
  ON f.pillar_code = d.pillar_code;
