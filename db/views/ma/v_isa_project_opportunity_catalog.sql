CREATE OR REPLACE VIEW ma.v_isa_project_opportunity_catalog AS
SELECT
    r.country_iso3,
    r.year,
    r.pillar_code,
    COALESCE(c.project_family_code,
        CASE r.pillar_code
            WHEN 'PGEO' THEN 'GOVERNANCE_CAPACITY'
            WHEN 'PNUM' THEN 'DIGITAL_SOVEREIGNTY'
            WHEN 'PRES' THEN 'ENERGY_WATER_CERTIFICATION'
            WHEN 'PTRA' THEN 'TRANSPORT_LOGISTICS'
            WHEN 'PMIN' THEN 'MINING_VALUE_CHAIN'
            WHEN 'PHUM' THEN 'HUMAN_CAPITAL'
            WHEN 'PECO' THEN 'ECONOMIC_DIVERSIFICATION'
            WHEN 'PMON' THEN 'MONETARY_FINANCIAL_RESILIENCE'
            WHEN 'PENV' THEN 'ENVIRONMENTAL_RESILIENCE'
            WHEN 'PMIL' THEN 'SECURITY_RESILIENCE'
            ELSE 'GENERAL_SOVEREIGNTY_PROJECT'
        END) AS project_family_code,
    COALESCE(c.project_family_label,'Projet structurant de souveraineté') AS project_family_label,
    COALESCE(c.strategic_objective,'Transformer un signal observé en projet structurant') AS strategic_objective,
    r.swot_strategic_role,
    r.strategic_recommendation_action,
    r.strategic_priority_score,
    COALESCE(c.open_data_deliverable,'Note d’opportunité publique') AS open_data_deliverable,
    COALESCE(c.premium_deliverable,'Étude de faisabilité premium') AS premium_deliverable,
    CASE
        WHEN r.strategic_priority_score >= 0.80 THEN 'OPEN_DATA_HIGH_PRIORITY_OPPORTUNITY_STUDY'
        WHEN r.strategic_priority_score >= 0.65 THEN 'OPEN_DATA_STANDARD_OPPORTUNITY_STUDY'
        ELSE 'OPEN_DATA_MONITORING_NOTE'
    END AS opportunity_study_level,
    CASE
        WHEN r.swot_strategic_role IN ('THREAT_TO_MITIGATE','WEAKNESS_TO_FIX') THEN 'ATTENUATION_PROJECT'
        WHEN r.swot_strategic_role IN ('STRENGTH_TO_SCALE','OPPORTUNITY_TO_ACCELERATE') THEN 'ACCELERATION_PROJECT'
        ELSE 'MONITORING_PROJECT'
    END AS project_orientation,
    r.recommendation_evidence_status
FROM ma.v_isa_strategic_recommendation_engine r
LEFT JOIN rf.structuring_project_catalog c
  ON c.pillar_code = r.pillar_code;
