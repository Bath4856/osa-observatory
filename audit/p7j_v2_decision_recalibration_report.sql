\echo ''
\echo '========================================================'
\echo ' OSA / ISA — P7J v2 DECISION RECALIBRATION REPORT'
\echo '========================================================'
\echo ''
\echo '=== 1. Alert cap violations ==='
SELECT
 SUM(CASE WHEN sovereign_alert_level='YELLOW' AND decision_priority_class='DECISION_CRITICAL' THEN 1 ELSE 0 END) AS yellow_to_critical,
 SUM(CASE WHEN sovereign_alert_level='GREEN' AND decision_priority_class IN ('DECISION_HIGH','DECISION_CRITICAL') THEN 1 ELSE 0 END) AS green_to_high_or_critical
FROM ma.v_isa_decision_priority_engine;
\echo ''
\echo '=== 2. Decision priority distribution ==='
SELECT decision_priority_class, sovereign_alert_level, COUNT(*) AS nb, ROUND(AVG(decision_priority_score),3) AS avg_score, ROUND(AVG(decision_confidence_score),3) AS avg_confidence
FROM ma.v_isa_decision_priority_engine
GROUP BY decision_priority_class, sovereign_alert_level
ORDER BY decision_priority_class, sovereign_alert_level;
\echo ''
\echo '=== 3. Country decision classes ==='
SELECT country_decision_class, country_decision_status, COUNT(*) AS nb, ROUND(AVG(country_decision_priority_score),3) AS avg_priority, ROUND(AVG(country_decision_confidence_score),3) AS avg_confidence
FROM ma.v_isa_decision_country_year
GROUP BY country_decision_class, country_decision_status
ORDER BY country_decision_class, country_decision_status;
\echo ''
\echo '=== 4. Top country critical/high decisions ==='
SELECT country_iso3, year, nb_decision_items, nb_critical_decisions, nb_high_decisions, country_decision_priority_score, country_max_decision_priority_score, country_decision_confidence_score, country_decision_class, country_decision_status
FROM ma.v_isa_decision_country_year
WHERE country_decision_class IN ('COUNTRY_DECISION_CRITICAL','COUNTRY_DECISION_HIGH')
ORDER BY country_decision_priority_score DESC, country_max_decision_priority_score DESC
LIMIT 50;
\echo ''
\echo '=== 5. Readiness ==='
SELECT * FROM ma.v_isa_decision_readiness
ORDER BY CASE decision_priority_class WHEN 'DECISION_CRITICAL' THEN 4 WHEN 'DECISION_HIGH' THEN 3 WHEN 'DECISION_STANDARD' THEN 2 ELSE 1 END DESC, avg_decision_priority_score DESC;
\echo ''
\echo '=== RAPPORT P7J v2 TERMINÉ ==='
