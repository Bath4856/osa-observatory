CREATE OR REPLACE VIEW ma.v_isa_executive_priority_portfolio AS
WITH src AS (
    SELECT
        s.*,
        COALESCE(w.executive_weight, 1.000)::NUMERIC AS executive_weight,
        COALESCE(w.budget_pressure_weight, 0.750)::NUMERIC AS budget_pressure_weight,
        COALESCE(w.governance_complexity_weight, 0.850)::NUMERIC AS governance_complexity_weight
    FROM ma.v_p7k_executive_source s
    LEFT JOIN rf.isa_executive_pillar_weight w
      ON w.pillar_code = s.pillar_code
),
scored AS (
    SELECT
        *,
        LEAST(1.000, GREATEST(0.000,
              (0.42 * decision_priority_score)
            + (0.20 * country_decision_priority_score)
            + (0.16 * LEAST(1.000, GREATEST(0.000, ambitious_isa_delta * 6.0)))
            + (0.12 * LEAST(1.000, GREATEST(0.000, ABS(stress_isa_delta) * 6.0)))
            + (0.10 * decision_confidence_score)
        ) * executive_weight)::NUMERIC AS executive_priority_score,
        LEAST(1.000, GREATEST(0.000,
              (0.45 * budget_pressure_weight)
            + (0.25 * LEAST(1.000, GREATEST(0.000, ambitious_isa_delta * 5.0)))
            + (0.20 * CASE
                        WHEN decision_timing_code = 'IMMEDIATE_0_3_MONTHS' THEN 1.0
                        WHEN decision_timing_code = 'SHORT_TERM_3_12_MONTHS' THEN 0.75
                        WHEN decision_timing_code = 'MEDIUM_TERM_1_3_YEARS' THEN 0.45
                        ELSE 0.20
                      END)
            + (0.10 * CASE WHEN decision_support_status = 'DECISION_LOW_CONFIDENCE_REVIEW' THEN 0.35 ELSE 0.65 END)
        ))::NUMERIC AS budget_pressure_score,
        LEAST(1.000, GREATEST(0.000,
              (0.40 * governance_complexity_weight)
            + (0.25 * CASE
                        WHEN sovereign_alert_level = 'RED' THEN 1.0
                        WHEN sovereign_alert_level = 'ORANGE' THEN 0.75
                        WHEN sovereign_alert_level = 'YELLOW' THEN 0.45
                        ELSE 0.15
                      END)
            + (0.20 * CASE
                        WHEN country_decision_class = 'COUNTRY_DECISION_HIGH' THEN 0.80
                        WHEN country_decision_class = 'COUNTRY_DECISION_STANDARD' THEN 0.45
                        ELSE 0.20
                      END)
            + (0.15 * CASE WHEN decision_support_status = 'DECISION_LOW_CONFIDENCE_REVIEW' THEN 0.85 ELSE 0.30 END)
        ))::NUMERIC AS governance_risk_score
    FROM src
),
classified AS (
    SELECT
        s.*,
        p.executive_decision_class,
        p.executive_rank,
        p.executive_action_code,
        p.executive_track,
        p.board_visibility,
        p.policy_note AS executive_policy_note
    FROM scored s
    JOIN rf.isa_executive_governance_policy p
      ON s.executive_priority_score >= p.min_executive_score
     AND s.executive_priority_score < p.max_executive_score
)
SELECT
    country_iso3,
    year,
    pillar_code,
    intervention_family_code,
    intervention_family_label,
    strategic_objective,
    recommended_action,
    sovereign_alert_level,
    decision_priority_class,
    decision_priority_score,
    decision_confidence_score,
    country_decision_class,
    country_decision_priority_score,
    ROUND(executive_priority_score, 3) AS executive_priority_score,
    ROUND(budget_pressure_score, 3) AS budget_pressure_score,
    ROUND(governance_risk_score, 3) AS governance_risk_score,
    executive_decision_class,
    executive_rank,
    executive_action_code,
    executive_track,
    board_visibility,
    decision_timing_code,
    decision_timing_label,
    decision_max_months,
    central_isa_delta,
    ambitious_isa_delta,
    stress_isa_delta,
    decision_support_status,
    CASE
        WHEN executive_decision_class = 'EXEC_BOARD_PREPARED' THEN 'BOARD_MEMO_REQUIRED'
        WHEN executive_decision_class = 'EXEC_FAST_TRACK_CANDIDATE' THEN 'EXECUTIVE_BRIEF_REQUIRED'
        WHEN executive_decision_class = 'EXEC_PROGRAMME_CANDIDATE' THEN 'PROGRAMME_NOTE_REQUIRED'
        ELSE 'WATCHLIST_UPDATE'
    END AS executive_deliverable_type,
    CASE
        WHEN decision_support_status = 'DECISION_LOW_CONFIDENCE_REVIEW' THEN 'EXEC_REVIEW_EVIDENCE_FIRST'
        WHEN executive_decision_class IN ('EXEC_BOARD_PREPARED','EXEC_FAST_TRACK_CANDIDATE') THEN 'EXEC_READY_WITH_CAUTION'
        ELSE 'EXEC_READY'
    END AS executive_readiness_status
FROM classified;
