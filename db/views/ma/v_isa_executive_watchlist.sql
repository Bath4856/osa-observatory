CREATE OR REPLACE VIEW ma.v_isa_executive_watchlist AS
SELECT
    country_iso3,
    year,
    pillar_code,
    intervention_family_code,
    intervention_family_label,
    sovereign_alert_level,
    decision_priority_class,
    executive_decision_class,
    executive_priority_score,
    budget_pressure_score,
    governance_risk_score,
    decision_confidence_score,
    decision_support_status,
    executive_readiness_status,
    CASE
        WHEN decision_confidence_score < 0.450 THEN 'WATCH_LOW_CONFIDENCE'
        WHEN governance_risk_score >= 0.750 THEN 'WATCH_GOVERNANCE_RISK'
        WHEN budget_pressure_score >= 0.750 THEN 'WATCH_BUDGET_PRESSURE'
        WHEN executive_readiness_status = 'EXEC_READY_WITH_CAUTION' THEN 'WATCH_SCENARIO_CAUTION'
        ELSE 'WATCH_STANDARD'
    END AS watchlist_reason,
    CASE
        WHEN decision_confidence_score < 0.450 THEN 'Improve evidence and source confidence before board decision.'
        WHEN governance_risk_score >= 0.750 THEN 'Prepare governance risk memo and escalation options.'
        WHEN budget_pressure_score >= 0.750 THEN 'Prepare budget arbitration note.'
        WHEN executive_readiness_status = 'EXEC_READY_WITH_CAUTION' THEN 'Attach scenario caveat to executive memo.'
        ELSE 'Monitor through OSA executive dashboard.'
    END AS watchlist_action
FROM ma.v_isa_executive_priority_portfolio
WHERE decision_confidence_score < 0.450
   OR governance_risk_score >= 0.650
   OR budget_pressure_score >= 0.650
   OR executive_readiness_status <> 'EXEC_READY';
