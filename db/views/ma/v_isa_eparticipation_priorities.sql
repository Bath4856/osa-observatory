CREATE OR REPLACE VIEW ma.v_isa_eparticipation_priorities AS
SELECT
    t.country_iso3,
    t.year,
    t.pillar_code,
    t.project_family_code,
    t.project_family_label,
    t.swot_strategic_role,
    t.strategic_priority_score,
    t.premium_feasibility_trigger,
    CASE
        WHEN t.swot_strategic_role = 'THREAT_TO_MITIGATE' THEN 'RISK_EVIDENCE_AND_EXPERT_REVIEW'
        WHEN t.swot_strategic_role = 'WEAKNESS_TO_FIX' THEN 'PUBLIC_COMMENTS_AND_DIAGNOSTIC_REVIEW'
        WHEN t.swot_strategic_role = 'OPPORTUNITY_TO_ACCELERATE' THEN 'CO_DESIGN_AND_INVESTOR_FEEDBACK'
        WHEN t.swot_strategic_role = 'STRENGTH_TO_SCALE' THEN 'BENCHMARK_AND_REPLICATION_FEEDBACK'
        ELSE 'GENERAL_OBSERVATORY_FEEDBACK'
    END AS eparticipation_topic_type,
    CASE
        WHEN t.strategic_priority_score >= 0.80 THEN 'EPARTICIPATION_HIGH_PRIORITY'
        WHEN t.strategic_priority_score >= 0.65 THEN 'EPARTICIPATION_STANDARD_PRIORITY'
        ELSE 'EPARTICIPATION_MONITORING'
    END AS eparticipation_priority,
    t.recommendation_evidence_status
FROM ma.v_isa_premium_feasibility_triggers t;
