CREATE OR REPLACE VIEW ma.v_isa_executive_governance_readiness AS
SELECT
    pillar_code,
    executive_decision_class,
    executive_track,
    COUNT(*)::INTEGER AS nb_executive_rows,
    COUNT(DISTINCT country_iso3)::INTEGER AS nb_countries,
    COUNT(DISTINCT year)::INTEGER AS nb_years,
    ROUND(AVG(executive_priority_score), 3) AS avg_executive_priority_score,
    ROUND(AVG(budget_pressure_score), 3) AS avg_budget_pressure_score,
    ROUND(AVG(governance_risk_score), 3) AS avg_governance_risk_score,
    SUM(CASE WHEN executive_readiness_status = 'EXEC_REVIEW_EVIDENCE_FIRST' THEN 1 ELSE 0 END)::INTEGER AS nb_evidence_review,
    SUM(CASE WHEN executive_readiness_status = 'EXEC_READY_WITH_CAUTION' THEN 1 ELSE 0 END)::INTEGER AS nb_ready_with_caution,
    SUM(CASE WHEN executive_readiness_status = 'EXEC_READY' THEN 1 ELSE 0 END)::INTEGER AS nb_exec_ready,
    CASE
        WHEN executive_decision_class = 'EXEC_BOARD_PREPARED' THEN 'P7K_BOARD_DECISION_READY'
        WHEN SUM(CASE WHEN executive_readiness_status = 'EXEC_REVIEW_EVIDENCE_FIRST' THEN 1 ELSE 0 END) > COUNT(*) * 0.50
            THEN 'P7K_EXECUTIVE_REVIEW_REQUIRED'
        WHEN executive_decision_class = 'EXEC_FAST_TRACK_CANDIDATE' THEN 'P7K_FAST_TRACK_READY'
        WHEN executive_decision_class = 'EXEC_PROGRAMME_CANDIDATE' THEN 'P7K_PROGRAMME_READY'
        ELSE 'P7K_WATCHLIST_READY'
    END AS p7k_executive_readiness_status
FROM ma.v_isa_executive_priority_portfolio
GROUP BY pillar_code, executive_decision_class, executive_track;
