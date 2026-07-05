-- ============================================================
-- Sprint 31 -- Creation des vues manquantes pour l'endpoint
-- GET /api/v2/sovereign-projects/recommendation/{iso3}/{pillar}
-- 3 juillet 2026
-- ============================================================
-- Dependances confirmees presentes avant execution :
--   ma.v_isa_swot_signal_engine   (vue, existante)
--   rf.swot_signal_policy         (table, 5 lignes)
--   rf.structuring_project_catalog (table, 10 lignes)
-- ============================================================
-- EXECUTION :
--   docker exec -i osa-db psql -U postgres -d osa_db \
--     < sprint31_create_recommendation_views.sql
-- ============================================================

BEGIN;

-- 1) ma.v_isa_strategic_recommendation_engine
--    Depend de ma.v_isa_swot_signal_engine + rf.swot_signal_policy
CREATE OR REPLACE VIEW ma.v_isa_strategic_recommendation_engine AS
SELECT
    s.country_iso3,
    s.year,
    s.pillar_code,
    s.publication_status,
    s.isa_observed_score,
    s.sovereignty_observed_score,
    s.vulnerability_observed_score,
    s.resilience_observed_score,
    s.weakness_score,
    s.threat_score,
    s.strength_score,
    s.opportunity_score,
    s.strategic_risk_score,
    s.strategic_upside_score,
    s.swot_strategic_role,
    COALESCE(p.default_action,
        CASE s.swot_strategic_role
            WHEN 'THREAT_TO_MITIGATE' THEN 'MITIGATE_THREAT'
            WHEN 'WEAKNESS_TO_FIX' THEN 'ATTENUATE_WEAKNESS'
            WHEN 'OPPORTUNITY_TO_ACCELERATE' THEN 'ACCELERATE_OPPORTUNITY'
            WHEN 'STRENGTH_TO_SCALE' THEN 'SCALE_STRENGTH'
            ELSE 'MONITOR_AND_DOCUMENT'
        END) AS strategic_recommendation_action,
    ROUND(GREATEST(
        s.strategic_risk_score,
        s.strategic_upside_score,
        COALESCE(p.priority_weight,0.65) * 0.75
    )::numeric,3) AS strategic_priority_score,
    COALESCE(p.open_data_policy,'PUBLISH_MONITORING_NOTE') AS open_data_policy,
    COALESCE(p.premium_policy,'NO_PREMIUM_TRIGGER') AS premium_policy,
    COALESCE(p.eparticipation_policy,'OPEN_GENERAL_COMMENTS') AS eparticipation_policy,
    s.swot_data_status,
    s.strategic_attention_class,
    CASE
        WHEN s.swot_data_status = 'NO_COMPUTED_SWOT_ATTACHED' THEN 'OBSERVED_ONLY_RECOMMENDATION'
        ELSE 'SWOT_COMPUTED_RECOMMENDATION'
    END AS recommendation_evidence_status
FROM ma.v_isa_swot_signal_engine s
LEFT JOIN rf.swot_signal_policy p
  ON p.strategic_role = s.swot_strategic_role
  OR p.swot_type = CASE
        WHEN s.swot_strategic_role='WEAKNESS_TO_FIX' THEN 'WKN'
        WHEN s.swot_strategic_role='THREAT_TO_MITIGATE' THEN 'THR'
        WHEN s.swot_strategic_role='STRENGTH_TO_SCALE' THEN 'STR'
        WHEN s.swot_strategic_role='OPPORTUNITY_TO_ACCELERATE' THEN 'OPP'
        ELSE 'OBS'
     END;

-- 2) ma.v_isa_project_opportunity_catalog
--    Depend de ma.v_isa_strategic_recommendation_engine (cree ci-dessus)
--    + rf.structuring_project_catalog
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
    COALESCE(c.open_data_deliverable,'Note d''opportunité publique') AS open_data_deliverable,
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

COMMIT;

-- Verification post-execution
SELECT 'v_isa_strategic_recommendation_engine' AS vue, count(*) AS lignes FROM ma.v_isa_strategic_recommendation_engine
UNION ALL
SELECT 'v_isa_project_opportunity_catalog', count(*) FROM ma.v_isa_project_opportunity_catalog;
