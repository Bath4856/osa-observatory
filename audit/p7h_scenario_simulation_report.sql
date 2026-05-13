\echo ''
\echo '========================================================'
\echo ' OSA / ISA — P7H SCENARIO SIMULATION REPORT'
\echo '========================================================'
\echo ''
\echo '=== 0. Colonnes sources P7H ==='
\i audit/list_p7h_source_columns.sql

\echo ''
\echo '=== 1. Package lifecycle ==='
SELECT package_code, package_status, replacement_package, notes
FROM mg.package_lifecycle
WHERE package_code = 'P7H';

\echo ''
\echo '=== 2. Politiques scénarios ==='
SELECT scenario_code, scenario_family, intervention_intensity, risk_adjustment_factor, confidence_adjustment_factor, include_in_public_simulation
FROM rf.isa_scenario_policy
ORDER BY scenario_code;

\echo ''
\echo '=== 3. Source P7H volumétrie ==='
SELECT COUNT(*) AS source_rows, COUNT(DISTINCT country_iso3) AS nb_countries, COUNT(DISTINCT year) AS nb_years, COUNT(DISTINCT pillar_code) AS nb_pillars
FROM ma.v_p7h_scenario_source;

\echo ''
\echo '=== 4. Simulation decisions ==='
SELECT scenario_code, simulation_decision, COUNT(*) AS nb, ROUND(AVG(simulation_confidence),3) AS avg_confidence, ROUND(AVG(simulated_isa_delta),3) AS avg_delta
FROM ma.v_isa_scenario_simulation_engine
GROUP BY scenario_code, simulation_decision
ORDER BY scenario_code, nb DESC;

\echo ''
\echo '=== 5. Delta ISA moyen par scénario/pilier ==='
SELECT scenario_code, pillar_code, COUNT(*) AS nb, ROUND(AVG(simulated_isa_delta),3) AS avg_isa_delta, ROUND(AVG(simulation_confidence),3) AS avg_confidence
FROM ma.v_isa_scenario_simulation_engine
GROUP BY scenario_code, pillar_code
ORDER BY scenario_code, avg_isa_delta DESC;

\echo ''
\echo '=== 6. Country scenario status ==='
SELECT scenario_code, country_scenario_status, COUNT(*) AS nb, ROUND(AVG(country_simulated_isa_delta),3) AS avg_country_delta
FROM ma.v_isa_scenario_country_year
GROUP BY scenario_code, country_scenario_status
ORDER BY scenario_code, nb DESC;

\echo ''
\echo '=== 7. Readiness P7H ==='
SELECT scenario_code, pillar_code, nb_countries, nb_years, avg_simulation_confidence, avg_simulated_isa_delta, p7h_scenario_readiness_status
FROM ma.v_isa_scenario_readiness
ORDER BY scenario_code, pillar_code;

\echo ''
\echo '=== 8. Top simulated ISA delta ==='
SELECT country_iso3, year, pillar_code, scenario_code, strategic_diagnostic_role, forecast_blocking_reason, simulated_isa_delta, simulation_confidence, simulation_decision
FROM ma.v_isa_scenario_simulation_engine
WHERE scenario_code IN ('CONSERVATIVE','CENTRAL','AMBITIOUS')
ORDER BY simulated_isa_delta DESC, simulation_confidence DESC
LIMIT 50;

\echo ''
\echo '=== RAPPORT P7H TERMINÉ ==='
