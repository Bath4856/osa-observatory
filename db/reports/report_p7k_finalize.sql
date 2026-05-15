\echo ''
\echo '========================================='
\echo ' OSA / ISA — P7K FINAL REPORT'
\echo '========================================='

--------------------------------------------------
-- MASTER SUMMARY
--------------------------------------------------

SELECT
    COUNT(*) AS master_rows,
    COUNT(DISTINCT country_iso3) AS nb_countries,
    COUNT(DISTINCT year) AS nb_years,
    COUNT(DISTINCT pillar_code) AS nb_pillars
FROM ma.mv_isa_executive_master_board;

--------------------------------------------------
-- EXECUTIVE DISTRIBUTION
--------------------------------------------------

SELECT
    executive_master_status,
    COUNT(*) AS nb,
    ROUND(
        AVG(sovereign_execution_pressure)::numeric,
        3
    ) AS avg_pressure

FROM ma.mv_isa_executive_master_board

GROUP BY executive_master_status
ORDER BY avg_pressure DESC;

--------------------------------------------------
-- PREDICTIVE READINESS
--------------------------------------------------

SELECT
    pillar_code,
    nb_rows,
    avg_priority,
    avg_pressure,
    nb_predictive_ready

FROM ma.v_isa_predictive_readiness_registry

ORDER BY avg_pressure DESC;

--------------------------------------------------
-- TOP EXECUTIVE PRESSURE
--------------------------------------------------

SELECT
    country_iso3,
    year,
    pillar_code,
    intervention_family_code,
    sovereign_execution_pressure

FROM ma.mv_isa_executive_master_board

ORDER BY sovereign_execution_pressure DESC
LIMIT 25;

\echo ''
\echo '✅ P7K FINALIZATION REPORT COMPLETE'