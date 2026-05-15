\echo ''
\echo '========================================================'
\echo ' OSA / ISA — P7I EARLY WARNING & RISK INTELLIGENCE REPORT'
\echo '========================================================'
\echo ''

\echo '=== 0. Colonnes sources P7I ==='
\i audit/list_p7i_source_columns.sql

\echo ''
\echo '=== 1. Package lifecycle ==='
SELECT package_code, package_status, replacement_package, notes
FROM mg.package_lifecycle
WHERE package_code = 'P7I';

\echo ''
\echo '=== 2. Politiques early warning ==='
SELECT alert_level, alert_rank, min_risk_score, max_risk_score, public_visibility
FROM rf.isa_early_warning_policy
ORDER BY alert_rank;

\echo ''
\echo '=== 3. Source P7I volumétrie ==='
SELECT
    COUNT(*) AS source_rows,
    COUNT(DISTINCT country_iso3) AS nb_countries,
    COUNT(DISTINCT year) AS nb_years,
    COUNT(DISTINCT pillar_code) AS nb_pillars
FROM ma.v_p7i_risk_source;

\echo ''
\echo '=== 4. Alertes souveraines par niveau ==='
SELECT sovereign_alert_level, early_warning_class, COUNT(*) AS nb,
       ROUND(AVG(early_warning_score), 3) AS avg_score,
       ROUND(AVG(early_warning_confidence), 3) AS avg_confidence
FROM ma.v_isa_early_warning_engine
GROUP BY sovereign_alert_level, early_warning_class
ORDER BY MIN(alert_rank), early_warning_class;

\echo ''
\echo '=== 5. Alertes par pilier ==='
SELECT pillar_code, sovereign_alert_level, COUNT(*) AS nb,
       ROUND(AVG(early_warning_score), 3) AS avg_warning_score,
       ROUND(AVG(early_warning_confidence), 3) AS avg_confidence
FROM ma.v_isa_early_warning_engine
GROUP BY pillar_code, sovereign_alert_level
ORDER BY pillar_code, sovereign_alert_level;

\echo ''
\echo '=== 6. Escalade du risque ==='
SELECT risk_escalation_class, escalation_reason, COUNT(*) AS nb,
       ROUND(AVG(risk_delta), 3) AS avg_risk_delta
FROM ma.v_isa_risk_escalation_engine
GROUP BY risk_escalation_class, escalation_reason
ORDER BY risk_escalation_class, escalation_reason;

\echo ''
\echo '=== 7. Fragility warnings ==='
SELECT fragility_warning_class, fragility_recommended_action, COUNT(*) AS nb,
       ROUND(AVG(fragility_warning_score), 3) AS avg_fragility_score
FROM ma.v_isa_fragility_warning_engine
GROUP BY fragility_warning_class, fragility_recommended_action
ORDER BY fragility_warning_class, fragility_recommended_action;

\echo ''
\echo '=== 8. Priorités intervention ==='
SELECT intervention_priority_class, priority_intervention_alert_status, COUNT(*) AS nb,
       ROUND(AVG(intervention_alert_priority_score), 3) AS avg_priority
FROM ma.v_isa_priority_intervention_alerts
GROUP BY intervention_priority_class, priority_intervention_alert_status
ORDER BY intervention_priority_class, priority_intervention_alert_status;

\echo ''
\echo '=== 9. Country early warning ==='
SELECT country_sovereign_alert_level, country_early_warning_status, COUNT(*) AS nb,
       ROUND(AVG(country_early_warning_score), 3) AS avg_country_score,
       ROUND(AVG(country_early_warning_confidence), 3) AS avg_confidence
FROM ma.v_isa_early_warning_country_year
GROUP BY country_sovereign_alert_level, country_early_warning_status
ORDER BY country_sovereign_alert_level, country_early_warning_status;

\echo ''
\echo '=== 10. Top RED/ORANGE alerts ==='
SELECT country_iso3, year, pillar_code, sovereign_alert_level,
       early_warning_score, early_warning_confidence,
       forecast_blocking_reason, strategic_diagnostic_role,
       recommended_governance_action
FROM ma.v_isa_early_warning_engine
WHERE sovereign_alert_level IN ('RED','ORANGE')
ORDER BY alert_rank DESC, early_warning_score DESC, early_warning_confidence DESC
LIMIT 60;

\echo ''
\echo '=== RAPPORT P7I TERMINÉ ==='
