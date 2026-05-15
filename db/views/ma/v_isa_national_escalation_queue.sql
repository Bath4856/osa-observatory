CREATE OR REPLACE VIEW ma.v_isa_national_escalation_queue AS
WITH p AS (
    SELECT
        e.*,
        CASE
            WHEN executive_decision_class = 'EXEC_BOARD_PREPARED' THEN 1.000
            WHEN executive_decision_class = 'EXEC_FAST_TRACK_CANDIDATE' THEN 0.700
            WHEN executive_decision_class = 'EXEC_PROGRAMME_CANDIDATE' THEN 0.450
            ELSE 0.200
        END AS executive_class_risk
    FROM ma.v_isa_executive_priority_portfolio e
),
risk AS (
    SELECT
        *,
        LEAST(1.000, GREATEST(0.000,
              0.35 * governance_risk_score
            + 0.25 * budget_pressure_score
            + 0.25 * executive_priority_score
            + 0.15 * executive_class_risk
        ))::NUMERIC AS national_escalation_score
    FROM p
)
SELECT
    r.country_iso3,
    r.year,
    r.pillar_code,
    r.intervention_family_code,
    r.intervention_family_label,
    r.executive_decision_class,
    r.executive_priority_score,
    r.budget_pressure_score,
    r.governance_risk_score,
    ROUND(r.national_escalation_score, 3) AS national_escalation_score,
    e.escalation_level_code,
    e.escalation_target,
    e.escalation_action,
    CASE
        WHEN r.national_escalation_score >= 0.800 THEN 'ESCALATE_IMMEDIATELY'
        WHEN r.national_escalation_score >= 0.600 THEN 'ESCALATE_NEXT_EXECUTIVE_CYCLE'
        WHEN r.national_escalation_score >= 0.400 THEN 'ESCALATE_TO_TECHNICAL_COMMITTEE'
        ELSE 'NO_ESCALATION_MONITOR'
    END AS national_escalation_status
FROM risk r
JOIN rf.isa_executive_escalation_policy e
  ON r.national_escalation_score >= e.min_governance_risk
 AND r.national_escalation_score < e.max_governance_risk;
