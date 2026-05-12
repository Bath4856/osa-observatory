CREATE OR REPLACE VIEW ma.v_isa_premium_feasibility_triggers AS
SELECT
    p.country_iso3,
    p.year,
    p.pillar_code,
    p.project_family_code,
    p.project_family_label,
    p.swot_strategic_role,
    p.strategic_priority_score,
    p.project_orientation,
    p.premium_deliverable,
    CASE
        WHEN p.strategic_priority_score >= 0.80 AND p.swot_strategic_role IN ('THREAT_TO_MITIGATE','WEAKNESS_TO_FIX') THEN 'FEASIBILITY_STUDY_URGENT'
        WHEN p.strategic_priority_score >= 0.70 AND p.swot_strategic_role IN ('OPPORTUNITY_TO_ACCELERATE','STRENGTH_TO_SCALE') THEN 'PROTOTYPE_OR_POC'
        WHEN p.strategic_priority_score >= 0.65 THEN 'FEASIBILITY_STUDY_STANDARD'
        ELSE 'OPEN_DATA_OPPORTUNITY_STUDY_ONLY'
    END AS premium_feasibility_trigger,
    CASE
        WHEN p.strategic_priority_score >= 0.80 THEN 'PREMIUM_HIGH'
        WHEN p.strategic_priority_score >= 0.65 THEN 'PREMIUM_MEDIUM'
        ELSE 'OPEN_DATA_ONLY'
    END AS premium_priority_class,
    p.recommendation_evidence_status
FROM ma.v_isa_project_opportunity_catalog p;
