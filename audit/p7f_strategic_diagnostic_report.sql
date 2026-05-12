\echo ''
\echo '========================================================'
\echo ' OSA / ISA — P7F STRATEGIC DIAGNOSTIC REPORT'
\echo '========================================================'
\echo ''
\echo '=== 0. Colonnes sources P7F ==='
\i audit/list_p7f_source_columns.sql

\echo ''
\echo '=== 1. Package lifecycle ==='
SELECT package_code, package_status, replacement_package, notes
FROM mg.package_lifecycle
WHERE package_code IN ('P7X','P7F')
ORDER BY package_code;

\echo ''
\echo '=== 2. Présence SWOT computed ==='
SELECT
    COUNT(*) FILTER (WHERE swot_type='WKN') AS nb_wkn_rows,
    COUNT(*) FILTER (WHERE swot_type='THR') AS nb_thr_rows,
    COUNT(*) FILTER (WHERE swot_type='STR') AS nb_str_rows,
    COUNT(*) FILTER (WHERE swot_type='OPP') AS nb_opp_rows
FROM ma.v_p7f_computed_swot_source;

\echo ''
\echo '=== 3. Diagnostics stratégiques ==='
SELECT strategic_diagnostic_role, swot_data_status, COUNT(*) AS nb, ROUND(AVG(diagnostic_priority_score),3) AS avg_priority
FROM ma.v_isa_strategic_diagnostic_engine
GROUP BY strategic_diagnostic_role, swot_data_status
ORDER BY avg_priority DESC, nb DESC;

\echo ''
\echo '=== 4. Classes attention diagnostic ==='
SELECT strategic_attention_class, COUNT(*) AS nb
FROM ma.v_isa_strategic_diagnostic_engine
GROUP BY strategic_attention_class
ORDER BY nb DESC;

\echo ''
\echo '=== 5. Catalogue interventions candidates ==='
SELECT intervention_family_code, recommended_action, COUNT(*) AS nb, ROUND(AVG(priority_score),3) AS avg_priority
FROM ma.v_isa_candidate_intervention_catalog
GROUP BY intervention_family_code, recommended_action
ORDER BY avg_priority DESC, nb DESC;

\echo ''
\echo '=== 6. Consultations publiques ==='
SELECT consultation_topic_type, consultation_priority, COUNT(*) AS nb
FROM ma.v_isa_public_consultation_topics
GROUP BY consultation_topic_type, consultation_priority
ORDER BY nb DESC;

\echo ''
\echo '=== 7. Top diagnostics à attention forte ==='
SELECT country_iso3, year, pillar_code, strategic_diagnostic_role, strategic_attention_class,
       diagnostic_priority_score, weakness_score, threat_score, strength_score, opportunity_score,
       swot_data_status
FROM ma.v_isa_strategic_diagnostic_engine
ORDER BY diagnostic_priority_score DESC, strategic_risk_score DESC
LIMIT 50;

\echo ''
\echo '=== RAPPORT P7F TERMINÉ ==='
