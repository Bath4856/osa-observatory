CREATE OR REPLACE VIEW ma.v_isa_scenario_country_year AS
SELECT
    country_iso3,
    year,
    scenario_code,
    scenario_label,
    scenario_family,
    COUNT(DISTINCT pillar_code)::INT AS nb_pillars_simulated,
    AVG(simulation_confidence)::NUMERIC(8,3) AS country_simulation_confidence,
    AVG(simulated_isa_delta)::NUMERIC(8,3) AS country_simulated_isa_delta,
    AVG(simulated_sovereignty_delta)::NUMERIC(8,3) AS country_simulated_sovereignty_delta,
    AVG(simulated_vulnerability_delta)::NUMERIC(8,3) AS country_simulated_vulnerability_delta,
    AVG(simulated_resilience_delta)::NUMERIC(8,3) AS country_simulated_resilience_delta,
    AVG(simulated_isa_score)::NUMERIC(8,3) AS country_simulated_isa_score,
    SUM(CASE WHEN simulation_decision = 'SIMULATION_USABLE_FOR_POLICY_DISCUSSION' THEN 1 ELSE 0 END)::INT AS nb_policy_usable_pillars,
    SUM(CASE WHEN simulation_decision = 'SIMULATION_WITH_VOLATILITY_WARNING' THEN 1 ELSE 0 END)::INT AS nb_volatility_warning_pillars,
    SUM(CASE WHEN simulation_decision = 'SIMULATION_CONTEXTUAL_LOW_CONFIDENCE' THEN 1 ELSE 0 END)::INT AS nb_low_confidence_pillars,
    SUM(CASE WHEN simulation_decision = 'STRESS_TEST_ONLY' THEN 1 ELSE 0 END)::INT AS nb_stress_pillars,
    CASE
        WHEN AVG(simulation_confidence) >= 0.700 THEN 'COUNTRY_SCENARIO_READY_STRONG'
        WHEN AVG(simulation_confidence) >= 0.550 THEN 'COUNTRY_SCENARIO_READY_CONTROLLED'
        WHEN AVG(simulation_confidence) >= 0.400 THEN 'COUNTRY_SCENARIO_INDICATIVE'
        ELSE 'COUNTRY_SCENARIO_REVIEW_REQUIRED'
    END::TEXT AS country_scenario_status
FROM ma.v_isa_scenario_simulation_engine
GROUP BY country_iso3, year, scenario_code, scenario_label, scenario_family;
