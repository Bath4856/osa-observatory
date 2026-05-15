\echo ''
\echo '========================================================'
\echo ' OSA / ISA — P7J DECISION SUPPORT REPORT'
\echo '========================================================'
\echo ''

\echo '=== 0. Colonnes sources P7J ==='
\i audit/list_p7j_source_columns.sql

\echo ''
\echo '=== 1. Package lifecycle ==='
SELECT package_code, package_status, replacement_package, notes
FROM mg.package_lifecycle
WHERE package_code = 'P7J';

\echo ''
\echo '=== 2. Politiques décisionnelles ==='
SELECT decision_priority_class, min_decision_score, max_decision_score, decision_rank, governance_track, public_decision_scope
FROM rf.isa_decision_priority_policy
ORDER BY decision_rank;

\echo ''
\echo '=== 3. Source P7J volumétrie ==='
SELECT COUNT(*) AS source_rows,
       COUNT(DISTINCT country_iso3) AS nb_countries,
       COUNT(DISTINCT year) AS nb_years,
       COUNT(DISTINCT pillar_code) AS nb_pillars
FROM ma.v_p7j_decision_source;

\echo ''
\echo '=== 4. Decision priority distribution ==='
SELECT decision_priority_class, decision_support_status, COUNT(*) AS nb,
       ROUND(AVG(decision_priority_score), 3) AS avg_priority,
       ROUND(AVG(decision_confidence_score), 3) AS avg_confidence
FROM ma.v_isa_decision_priority_engine
GROUP BY decision_priority_class, decision_support_status
ORDER BY AVG(decision_priority_score) DESC;

\echo ''
\echo '=== 5. Decision matrix par pilier ==='
SELECT pillar_code, decision_priority_class, COUNT(*) AS nb,
       ROUND(AVG(decision_priority_score), 3) AS avg_priority,
       ROUND(AVG(decision_confidence_score), 3) AS avg_confidence
FROM ma.v_isa_intervention_decision_matrix
GROUP BY pillar_code, decision_priority_class
ORDER BY pillar_code, AVG(decision_priority_score) DESC;

\echo ''
\echo '=== 6. Country decision classes ==='
SELECT country_decision_class, country_decision_status, COUNT(*) AS nb,
       ROUND(AVG(country_decision_priority_score), 3) AS avg_priority,
       ROUND(AVG(country_decision_confidence_score), 3) AS avg_confidence
FROM ma.v_isa_decision_country_year
GROUP BY country_decision_class, country_decision_status
ORDER BY AVG(country_decision_priority_score) DESC;

\echo ''
\echo '=== 7. Readiness P7J ==='
SELECT *
FROM ma.v_isa_decision_readiness
ORDER BY avg_decision_priority_score DESC, pillar_code
LIMIT 80;

\echo ''
\echo '=== 8. Top decision priorities ==='
SELECT country_iso3, year, pillar_code, intervention_family_code, decision_priority_class,
       decision_priority_score, decision_confidence_score, sovereign_alert_level,
       decision_timing_code, governance_track, decision_matrix_action
FROM ma.v_isa_intervention_decision_matrix
ORDER BY decision_priority_score DESC, decision_confidence_score DESC
LIMIT 60;

\echo ''
\echo '=== RAPPORT P7J TERMINÉ ==='
