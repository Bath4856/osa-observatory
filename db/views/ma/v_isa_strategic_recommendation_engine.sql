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
