CREATE OR REPLACE VIEW ma.v_isa_governance_heatmap AS
SELECT
    country_iso3,
    year,
    pillar_code,
    COUNT(*)::INTEGER AS nb_executive_items,
    ROUND(AVG(executive_priority_score), 3) AS avg_executive_priority_score,
    ROUND(MAX(executive_priority_score), 3) AS max_executive_priority_score,
    ROUND(AVG(budget_pressure_score), 3) AS avg_budget_pressure_score,
    ROUND(AVG(governance_risk_score), 3) AS avg_governance_risk_score,
    SUM(CASE WHEN executive_decision_class = 'EXEC_BOARD_PREPARED' THEN 1 ELSE 0 END)::INTEGER AS nb_board_decisions,
    SUM(CASE WHEN executive_decision_class = 'EXEC_FAST_TRACK_CANDIDATE' THEN 1 ELSE 0 END)::INTEGER AS nb_fast_track,
    SUM(CASE WHEN executive_decision_class = 'EXEC_PROGRAMME_CANDIDATE' THEN 1 ELSE 0 END)::INTEGER AS nb_programme,
    SUM(CASE WHEN executive_decision_class = 'EXEC_WATCHLIST' THEN 1 ELSE 0 END)::INTEGER AS nb_watchlist,
    CASE
        WHEN MAX(executive_priority_score) >= 0.750 THEN 'HEATMAP_BOARD_DECISION'
        WHEN MAX(executive_priority_score) >= 0.600 THEN 'HEATMAP_FAST_TRACK'
        WHEN AVG(executive_priority_score) >= 0.400 THEN 'HEATMAP_PROGRAMME'
        ELSE 'HEATMAP_WATCHLIST'
    END AS governance_heatmap_class
FROM ma.v_isa_executive_priority_portfolio
GROUP BY country_iso3, year, pillar_code;
