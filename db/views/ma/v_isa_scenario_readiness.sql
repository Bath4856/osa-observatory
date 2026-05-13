CREATE OR REPLACE VIEW ma.v_isa_scenario_readiness AS
SELECT
    scenario_code,
    scenario_label,
    scenario_family,
    pillar_code,
    COUNT(*)::INT AS nb_simulation_rows,
    COUNT(DISTINCT country_iso3)::INT AS nb_countries,
    COUNT(DISTINCT year)::INT AS nb_years,
    AVG(simulation_confidence)::NUMERIC(8,3) AS avg_simulation_confidence,
    AVG(simulated_isa_delta)::NUMERIC(8,3) AS avg_simulated_isa_delta,
    AVG(simulated_sovereignty_delta)::NUMERIC(8,3) AS avg_simulated_sovereignty_delta,
    AVG(simulated_vulnerability_delta)::NUMERIC(8,3) AS avg_simulated_vulnerability_delta,
    AVG(simulated_resilience_delta)::NUMERIC(8,3) AS avg_simulated_resilience_delta,
    SUM(CASE WHEN simulation_decision = 'SIMULATION_USABLE_FOR_POLICY_DISCUSSION' THEN 1 ELSE 0 END)::INT AS nb_policy_usable,
    SUM(CASE WHEN simulation_decision = 'SIMULATION_WITH_VOLATILITY_WARNING' THEN 1 ELSE 0 END)::INT AS nb_volatility_warning,
    SUM(CASE WHEN simulation_decision = 'SIMULATION_CONTEXTUAL_LOW_CONFIDENCE' THEN 1 ELSE 0 END)::INT AS nb_low_confidence,
    SUM(CASE WHEN simulation_decision = 'SIMULATION_INDICATIVE_REVIEW_REQUIRED' THEN 1 ELSE 0 END)::INT AS nb_review_required,
    CASE
        WHEN AVG(simulation_confidence) >= 0.700 THEN 'P7H_SCENARIO_READY_STRONG'
        WHEN AVG(simulation_confidence) >= 0.550 THEN 'P7H_SCENARIO_READY_CONTROLLED'
        WHEN AVG(simulation_confidence) >= 0.400 THEN 'P7H_SCENARIO_INDICATIVE'
        ELSE 'P7H_SCENARIO_REVIEW_REQUIRED'
    END::TEXT AS p7h_scenario_readiness_status
FROM ma.v_isa_scenario_simulation_engine
GROUP BY scenario_code, scenario_label, scenario_family, pillar_code;
