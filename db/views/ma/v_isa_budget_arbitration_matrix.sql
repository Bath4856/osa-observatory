CREATE OR REPLACE VIEW ma.v_isa_budget_arbitration_matrix AS
SELECT
    p.country_iso3,
    p.year,
    p.pillar_code,
    p.intervention_family_code,
    p.intervention_family_label,
    p.executive_decision_class,
    p.executive_priority_score,
    p.budget_pressure_score,
    p.governance_risk_score,
    p.ambitious_isa_delta,
    p.stress_isa_delta,
    b.budget_band_code,
    b.budget_arbitration_label,
    b.budget_action_code,
    CASE
        WHEN p.executive_decision_class = 'EXEC_BOARD_PREPARED'
          AND b.budget_band_code IN ('HIGH_BUDGET_PRESSURE','CRITICAL_BUDGET_PRESSURE')
            THEN 'BOARD_FINANCING_ARBITRATION'
        WHEN p.executive_decision_class IN ('EXEC_BOARD_PREPARED','EXEC_FAST_TRACK_CANDIDATE')
            THEN 'PRIORITY_BUDGET_ALLOCATION'
        WHEN p.executive_decision_class = 'EXEC_PROGRAMME_CANDIDATE'
            THEN 'PROGRAMME_BUDGET_PIPELINE'
        ELSE 'NO_IMMEDIATE_BUDGET_DECISION'
    END AS budget_arbitration_decision,
    CASE
        WHEN p.budget_pressure_score >= 0.800 THEN 'Budget pressure critical: dedicated financing or sovereign fund review.'
        WHEN p.budget_pressure_score >= 0.600 THEN 'Budget pressure high: pre-governance arbitration signal — final arbitration pending P7Z and P8. [P7K pre-governance signal, not final arbitration]'
        WHEN p.budget_pressure_score >= 0.350 THEN 'Budget pressure medium: programme budget planning required.'
        ELSE 'Budget pressure low: ordinary monitoring.'
    END AS budget_arbitration_note
FROM ma.v_isa_executive_priority_portfolio p
JOIN rf.isa_executive_budget_band_policy b
  ON p.budget_pressure_score >= b.min_budget_pressure
 AND p.budget_pressure_score < b.max_budget_pressure;
