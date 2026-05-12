\echo ''
\echo '========================================================'
\echo ' OSA / ISA — P7X SWOT STRATEGIC INTELLIGENCE REPORT'
\echo '========================================================'

\echo ''
\echo '=== 0. Colonnes sources P7X ==='
\i audit/list_p7x_source_columns.sql

\echo ''
\echo '=== 1. Présence SWOT computed ==='
SELECT
    SUM(CASE WHEN swot_type='WKN' THEN 1 ELSE 0 END) AS nb_wkn_rows,
    SUM(CASE WHEN swot_type='THR' THEN 1 ELSE 0 END) AS nb_thr_rows,
    SUM(CASE WHEN swot_type='STR' THEN 1 ELSE 0 END) AS nb_str_rows,
    SUM(CASE WHEN swot_type='OPP' THEN 1 ELSE 0 END) AS nb_opp_rows
FROM ma.v_p7x_computed_swot_source;

\echo ''
\echo '=== 2. Signaux stratégiques ==='
SELECT swot_strategic_role, swot_data_status, COUNT(*) AS nb
FROM ma.v_isa_swot_signal_engine
GROUP BY swot_strategic_role, swot_data_status
ORDER BY nb DESC;

\echo ''
\echo '=== 3. Recommandations stratégiques ==='
SELECT strategic_recommendation_action, recommendation_evidence_status, COUNT(*) AS nb,
       ROUND(AVG(strategic_priority_score),3) AS avg_priority
FROM ma.v_isa_strategic_recommendation_engine
GROUP BY strategic_recommendation_action, recommendation_evidence_status
ORDER BY avg_priority DESC, nb DESC;

\echo ''
\echo '=== 4. Catalogue projets structurants ==='
SELECT project_family_code, project_orientation, COUNT(*) AS nb,
       ROUND(AVG(strategic_priority_score),3) AS avg_priority
FROM ma.v_isa_project_opportunity_catalog
GROUP BY project_family_code, project_orientation
ORDER BY avg_priority DESC, nb DESC;

\echo ''
\echo '=== 5. Triggers premium ==='
SELECT premium_feasibility_trigger, premium_priority_class, COUNT(*) AS nb,
       ROUND(AVG(strategic_priority_score),3) AS avg_priority
FROM ma.v_isa_premium_feasibility_triggers
GROUP BY premium_feasibility_trigger, premium_priority_class
ORDER BY avg_priority DESC, nb DESC;

\echo ''
\echo '=== 6. Priorités e-participation ==='
SELECT eparticipation_topic_type, eparticipation_priority, COUNT(*) AS nb
FROM ma.v_isa_eparticipation_priorities
GROUP BY eparticipation_topic_type, eparticipation_priority
ORDER BY nb DESC;

\echo ''
\echo '=== RAPPORT P7X TERMINÉ ==='
