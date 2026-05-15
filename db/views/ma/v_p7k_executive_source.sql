CREATE OR REPLACE VIEW ma.v_p7k_executive_source AS
WITH matrix AS (
    SELECT
        country_iso3::TEXT AS country_iso3,
        year::INTEGER AS year,
        pillar_code::TEXT AS pillar_code,
        intervention_family_code::TEXT AS intervention_family_code,
        intervention_family_label::TEXT AS intervention_family_label,
        strategic_objective::TEXT AS strategic_objective,
        recommended_action::TEXT AS recommended_action,
        sovereign_alert_level::TEXT AS sovereign_alert_level,
        decision_priority_class::TEXT AS decision_priority_class,
        decision_label::TEXT AS decision_label,
        COALESCE(decision_priority_score, 0)::NUMERIC AS decision_priority_score,
        COALESCE(decision_confidence_score, 0)::NUMERIC AS decision_confidence_score,
        governance_track::TEXT AS governance_track,
        public_decision_scope::TEXT AS public_decision_scope,
        decision_timing_code::TEXT AS decision_timing_code,
        decision_timing_label::TEXT AS decision_timing_label,
        COALESCE(decision_max_months, 99)::INTEGER AS decision_max_months,
        COALESCE(central_isa_delta, 0)::NUMERIC AS central_isa_delta,
        COALESCE(ambitious_isa_delta, 0)::NUMERIC AS ambitious_isa_delta,
        COALESCE(stress_isa_delta, 0)::NUMERIC AS stress_isa_delta,
        decision_matrix_action::TEXT AS decision_matrix_action,
        decision_readiness_class::TEXT AS decision_readiness_class,
        decision_support_status::TEXT AS decision_support_status
    FROM ma.v_isa_intervention_decision_matrix
),
country AS (
    SELECT
        country_iso3::TEXT AS country_iso3,
        year::INTEGER AS year,
        nb_decision_items::INTEGER AS nb_decision_items,
        nb_pillars_with_decisions::INTEGER AS nb_pillars_with_decisions,
        nb_critical_decisions::INTEGER AS nb_critical_decisions,
        nb_high_decisions::INTEGER AS nb_high_decisions,
        nb_standard_decisions::INTEGER AS nb_standard_decisions,
        nb_monitor_decisions::INTEGER AS nb_monitor_decisions,
        COALESCE(country_decision_priority_score, 0)::NUMERIC AS country_decision_priority_score,
        COALESCE(country_max_decision_priority_score, 0)::NUMERIC AS country_max_decision_priority_score,
        COALESCE(country_decision_confidence_score, 0)::NUMERIC AS country_decision_confidence_score,
        country_decision_class::TEXT AS country_decision_class,
        country_decision_status::TEXT AS country_decision_status
    FROM ma.v_isa_decision_country_year
)
SELECT
    m.country_iso3,
    m.year,
    m.pillar_code,
    m.intervention_family_code,
    m.intervention_family_label,
    m.strategic_objective,
    m.recommended_action,
    m.sovereign_alert_level,
    m.decision_priority_class,
    m.decision_label,
    m.decision_priority_score,
    m.decision_confidence_score,
    m.governance_track,
    m.public_decision_scope,
    m.decision_timing_code,
    m.decision_timing_label,
    m.decision_max_months,
    m.central_isa_delta,
    m.ambitious_isa_delta,
    m.stress_isa_delta,
    m.decision_matrix_action,
    m.decision_readiness_class,
    m.decision_support_status,
    c.nb_decision_items,
    c.nb_pillars_with_decisions,
    c.nb_critical_decisions,
    c.nb_high_decisions,
    c.nb_standard_decisions,
    c.nb_monitor_decisions,
    c.country_decision_priority_score,
    c.country_max_decision_priority_score,
    c.country_decision_confidence_score,
    c.country_decision_class,
    c.country_decision_status
FROM matrix m
LEFT JOIN country c
  ON c.country_iso3 = m.country_iso3
 AND c.year = m.year;
