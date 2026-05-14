CREATE OR REPLACE VIEW ma.v_isa_intervention_decision_matrix AS
SELECT country_iso3, year, pillar_code, intervention_family_code, intervention_family_label,
       strategic_objective, recommended_action, sovereign_alert_level,
       decision_priority_class, decision_label, decision_priority_score, decision_confidence_score,
       governance_track, public_decision_scope, decision_timing_code, decision_timing_label,
       decision_max_months, central_isa_delta, ambitious_isa_delta, stress_isa_delta,
       CASE WHEN decision_priority_class='DECISION_CRITICAL' THEN 'DO_NOW'
            WHEN decision_priority_class='DECISION_HIGH' THEN 'PLAN_AND_VALIDATE'
            WHEN decision_priority_class='DECISION_STANDARD' THEN 'PREPARE_OPPORTUNITY_NOTE'
            ELSE 'MONITOR' END AS decision_matrix_action,
       CASE WHEN decision_support_status='DECISION_LOW_CONFIDENCE_REVIEW' THEN 'REVIEW_EVIDENCE_BEFORE_BOARD'
            WHEN decision_support_status='DECISION_WITH_SCENARIO_CAUTION' THEN 'BOARD_READY_WITH_CAUTION'
            ELSE 'BOARD_READY' END AS decision_readiness_class,
       decision_support_status
FROM ma.v_isa_decision_priority_engine;
