CREATE OR REPLACE VIEW ma.v_isa_board_decision_pack AS
WITH ranked AS (
    SELECT
        p.*,
        ROW_NUMBER() OVER (
            PARTITION BY country_iso3, year
            ORDER BY executive_priority_score DESC, governance_risk_score DESC, decision_confidence_score DESC
        ) AS board_item_rank
    FROM ma.v_isa_executive_priority_portfolio p
    WHERE board_visibility = TRUE
)
SELECT
    country_iso3,
    year,
    board_item_rank,
    pillar_code,
    intervention_family_code,
    intervention_family_label,
    strategic_objective,
    recommended_action,
    sovereign_alert_level,
    decision_priority_class,
    executive_decision_class,
    executive_priority_score,
    budget_pressure_score,
    governance_risk_score,
    executive_action_code,
    executive_track,
    executive_deliverable_type,
    decision_timing_code,
    decision_timing_label,
    decision_max_months,
    ambitious_isa_delta,
    stress_isa_delta,
    executive_readiness_status,
    CASE
        WHEN board_item_rank <= 5
          AND executive_decision_class IN ('EXEC_BOARD_PREPARED','EXEC_FAST_TRACK_CANDIDATE')
            THEN 'BOARD_TOP_5'
        WHEN board_item_rank <= 10 THEN 'BOARD_TOP_10'
        ELSE 'BOARD_APPENDIX'
    END AS board_pack_section,
    CASE
        WHEN executive_decision_class = 'EXEC_BOARD_PREPARED' THEN 'Prepare board dossier. Final approval pending P7Z predictive quantification and P8 publication. [P7K pre-governance signal]'
        WHEN executive_decision_class = 'EXEC_FAST_TRACK_CANDIDATE' THEN 'Validate fast-track candidate preparation. Pre-governance signal pending P7Z and P8. [P7K pre-governance signal]'
        WHEN executive_decision_class = 'EXEC_PROGRAMME_CANDIDATE' THEN 'Request programme candidate note. Pre-governance signal pending P7Z quantification. [P7K pre-governance signal]'
        ELSE 'Keep on executive watchlist.'
    END AS board_recommended_decision
FROM ranked;
