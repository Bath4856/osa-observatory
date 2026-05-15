-- ============================================================
-- P7J source view
-- Sources: P7I priority alerts + P7H scenario simulations
-- ============================================================

CREATE OR REPLACE VIEW ma.v_p7j_decision_source AS
WITH scenario AS (
    SELECT
        country_iso3::TEXT AS country_iso3,
        year::INTEGER AS year,
        pillar_code::TEXT AS pillar_code,
        MAX(CASE WHEN scenario_code = 'CENTRAL' THEN simulated_isa_delta END)::NUMERIC AS central_isa_delta,
        MAX(CASE WHEN scenario_code = 'AMBITIOUS' THEN simulated_isa_delta END)::NUMERIC AS ambitious_isa_delta,
        MAX(CASE WHEN scenario_code = 'STRESS' THEN simulated_isa_delta END)::NUMERIC AS stress_isa_delta,
        MAX(CASE WHEN scenario_code = 'CENTRAL' THEN simulation_confidence END)::NUMERIC AS central_simulation_confidence,
        MAX(CASE WHEN scenario_code = 'AMBITIOUS' THEN simulation_confidence END)::NUMERIC AS ambitious_simulation_confidence,
        MAX(CASE WHEN scenario_code = 'STRESS' THEN simulation_confidence END)::NUMERIC AS stress_simulation_confidence,
        MAX(CASE WHEN scenario_code = 'CENTRAL' THEN simulation_decision END)::TEXT AS central_simulation_decision,
        MAX(CASE WHEN scenario_code = 'STRESS' THEN simulation_decision END)::TEXT AS stress_simulation_decision
    FROM ma.v_isa_scenario_simulation_engine
    GROUP BY country_iso3, year, pillar_code
)
SELECT
    a.country_iso3::TEXT AS country_iso3,
    a.year::INTEGER AS year,
    a.pillar_code::TEXT AS pillar_code,
    a.intervention_family_code::TEXT AS intervention_family_code,
    a.intervention_family_label::TEXT AS intervention_family_label,
    a.strategic_objective::TEXT AS strategic_objective,
    a.recommended_action::TEXT AS recommended_action,
    a.candidate_intervention_status::TEXT AS candidate_intervention_status,
    a.sovereign_alert_level::TEXT AS sovereign_alert_level,
    a.early_warning_class::TEXT AS early_warning_class,
    COALESCE(a.early_warning_score, 0)::NUMERIC AS early_warning_score,
    COALESCE(a.early_warning_confidence, 0)::NUMERIC AS early_warning_confidence,
    COALESCE(a.intervention_alert_priority_score, 0)::NUMERIC AS intervention_alert_priority_score,
    a.intervention_priority_class::TEXT AS intervention_priority_class,
    a.intervention_priority_label::TEXT AS intervention_priority_label,
    a.priority_intervention_action::TEXT AS priority_intervention_action,
    a.priority_intervention_alert_status::TEXT AS priority_intervention_alert_status,
    COALESCE(s.central_isa_delta, 0)::NUMERIC AS central_isa_delta,
    COALESCE(s.ambitious_isa_delta, 0)::NUMERIC AS ambitious_isa_delta,
    COALESCE(s.stress_isa_delta, 0)::NUMERIC AS stress_isa_delta,
    COALESCE(s.central_simulation_confidence, 0)::NUMERIC AS central_simulation_confidence,
    COALESCE(s.ambitious_simulation_confidence, 0)::NUMERIC AS ambitious_simulation_confidence,
    COALESCE(s.stress_simulation_confidence, 0)::NUMERIC AS stress_simulation_confidence,
    COALESCE(s.central_simulation_decision, 'NO_CENTRAL_SIMULATION')::TEXT AS central_simulation_decision,
    COALESCE(s.stress_simulation_decision, 'NO_STRESS_SIMULATION')::TEXT AS stress_simulation_decision
FROM ma.v_isa_priority_intervention_alerts a
LEFT JOIN scenario s
  ON s.country_iso3 = a.country_iso3::TEXT
 AND s.year = a.year::INTEGER
 AND s.pillar_code = a.pillar_code::TEXT;
