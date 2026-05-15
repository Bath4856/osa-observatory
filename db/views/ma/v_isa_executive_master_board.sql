CREATE OR REPLACE VIEW ma.v_isa_executive_master_board AS
SELECT
    m.country_iso3,
    m.year,
    m.pillar_code,
    m.intervention_family_code,
    m.intervention_family_label,
    m.executive_decision_class,
    m.executive_priority_score,
    m.budget_pressure_score,
    m.governance_risk_score,
    m.executive_cost_score,
    m.implementation_complexity,
    m.execution_horizon_years,
    m.sovereign_execution_pressure,
    m.executive_master_status,
    -- predictive_ready_flag : maintenu pour compatibilité ascendante
    -- TRUE uniquement pour EXEC_READY (VALIDATED) — EXEC_READY_CAUTION exclu
    CASE
        WHEN m.predictive_execution_status = 'EXEC_READY' THEN TRUE
        ELSE FALSE
    END::BOOLEAN                                        AS predictive_ready_flag,
    -- predictive_execution_status : statut V3 complet
    m.predictive_execution_status,
    -- predictive_gap_score : écart au seuil EXEC_READY_CAUTION (0 = seuil atteint)
    m.predictive_gap_score,
    -- systemic_cascade_score
    ROUND((
        m.governance_risk_score * 0.50
        + m.sovereign_dependency_score * 0.50
    )::NUMERIC, 3)                                      AS systemic_cascade_score
FROM ma.mv_isa_executive_master_board m;
