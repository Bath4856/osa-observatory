\echo '============================================================'
\echo ' OSA / ISA — P7I-AMAR PRODUCTION REPORT'
\echo '============================================================'

\echo ''
\echo '=== 1. Package registry ==='
SELECT package_code, package_name, status, parent_package_code, description
FROM mg.package_registry
WHERE package_code IN ('P7I', 'P7I-AMAR')
ORDER BY package_code;

\echo ''
\echo '=== 2. Required source views ==='
SELECT
    to_regclass('ma.v_p7i_risk_source') AS v_p7i_risk_source,
    to_regclass('ma.v_isa_early_warning_engine') AS v_isa_early_warning_engine,
    to_regclass('ma.v_isa_risk_escalation_engine') AS v_isa_risk_escalation_engine,
    to_regclass('ma.v_isa_early_warning_country_year') AS v_isa_early_warning_country_year,
    to_regclass('ma.v_p7i_amar_atrocity_precursor_engine') AS v_p7i_amar_engine,
    to_regclass('ma.v_p7i_amar_dashboard') AS v_p7i_amar_dashboard,
    to_regclass('mg.v_public_p7i_amar_alerts') AS v_public_p7i_amar_alerts;

\echo ''
\echo '=== 3. Risk taxonomy ==='
SELECT risk_code, risk_name, severity_order, public_visible
FROM mg.risk_taxonomy
WHERE risk_code IN ('ATROCITY_PRECURSOR', 'CIVILIAN_PROTECTION')
ORDER BY severity_order;

\echo ''
\echo '=== 4. AMAR score sanity check ==='
SELECT
    MIN(risk_score) AS min_risk_score,
    MAX(risk_score) AS max_risk_score,
    ROUND(AVG(risk_score), 3) AS avg_risk_score,
    MIN(confidence_score) AS min_confidence,
    MAX(confidence_score) AS max_confidence,
    ROUND(AVG(confidence_score), 3) AS avg_confidence,
    COUNT(*) AS nb_rows
FROM ma.v_p7i_amar_dashboard;

\echo ''
\echo '=== 5. AMAR alert distribution ==='
SELECT
    year,
    risk_band,
    COUNT(*) AS nb_countries,
    ROUND(AVG(risk_score), 3) AS avg_risk_score,
    ROUND(AVG(confidence_score), 3) AS avg_confidence
FROM ma.v_p7i_amar_dashboard
GROUP BY year, risk_band
ORDER BY year DESC,
    CASE risk_band
        WHEN 'BLACK' THEN 5
        WHEN 'RED' THEN 4
        WHEN 'ORANGE' THEN 3
        WHEN 'YELLOW' THEN 2
        WHEN 'GREEN' THEN 1
        ELSE 0
    END DESC;

\echo ''
\echo '=== 6. Top AMAR risks ==='
SELECT
    country_iso3,
    year,
    risk_band,
    risk_score,
    confidence_score,
    recommended_action,
    risk_interpretation
FROM ma.v_p7i_amar_dashboard
ORDER BY year DESC, risk_score DESC, confidence_score DESC
LIMIT 30;

\echo ''
\echo '=== 7. Stored AMAR alerts ==='
SELECT
    source_engine,
    risk_code,
    risk_band,
    COUNT(*) AS nb_alerts,
    ROUND(AVG(risk_score), 3) AS avg_score
FROM mg.early_warning_alerts
WHERE source_engine = 'P7I-AMAR'
GROUP BY source_engine, risk_code, risk_band
ORDER BY source_engine, risk_code, risk_band;

\echo ''
\echo '=== 8. Public view sample ==='
SELECT *
FROM mg.v_public_p7i_amar_alerts
ORDER BY year DESC, risk_score DESC
LIMIT 20;

\echo ''
\echo '=== RAPPORT P7I-AMAR TERMINÉ ==='
