\echo '============================================================'
\echo ' OSA / ISA — P7I-AMAR-GENECO PRODUCTION REPORT'
\echo '============================================================'

\echo ''
\echo '=== Dependency check ==='
SELECT
    to_regclass('ma.v_isa_early_warning_engine')        AS p7i_core_engine,
    to_regclass('ma.v_p7i_amar_dashboard')              AS amar_dashboard_optional,
    to_regclass('ma.v_p7i_amar_geneco_engine')          AS geneco_engine,
    to_regclass('ma.v_p7i_amar_geneco_dashboard')       AS geneco_dashboard,
    to_regclass('ma.v_p7i_amar_composite_dashboard')    AS amar_composite_dashboard,
    to_regclass('mg.v_public_p7i_amar_geneco_alerts')   AS public_geneco_alerts;

\echo ''
\echo '=== Package registry ==='
SELECT package_code, package_name, status, parent_package_code
FROM mg.package_registry
WHERE package_code ILIKE 'P7I-AMAR%'
ORDER BY package_code;

\echo ''
\echo '=== GENECO distribution by year/band ==='
SELECT
    year,
    risk_band,
    COUNT(*)                        AS nb_countries,
    ROUND(AVG(risk_score), 3)       AS avg_score,
    ROUND(AVG(confidence_score), 3) AS avg_confidence
FROM ma.v_p7i_amar_geneco_dashboard
GROUP BY year, risk_band
ORDER BY year DESC, risk_band;

\echo ''
\echo '=== Top GENECO exposure rows ==='
SELECT
    country_iso3,
    year,
    risk_band,
    risk_score,
    confidence_score,
    resource_capture_risk,
    logistics_enabling_risk,
    institutional_capture_risk,
    civilian_exploitation_risk,
    narrative_weaponization_risk,
    recommended_action
FROM ma.v_p7i_amar_geneco_dashboard
ORDER BY year DESC, risk_score DESC
LIMIT 30;

\echo ''
\echo '=== Optional composite distribution ==='
SELECT
    year,
    amar_composite_band,
    COUNT(*)                               AS nb_countries,
    ROUND(AVG(amar_composite_score), 3)    AS avg_composite_score,
    ROUND(AVG(amar_composite_confidence), 3) AS avg_composite_confidence
FROM ma.v_p7i_amar_composite_dashboard
GROUP BY year, amar_composite_band
ORDER BY year DESC, amar_composite_band;

\echo ''
\echo '=== Stored GENECO alerts, if persisted ==='
SELECT
    source_engine,
    risk_code,
    risk_band,
    COUNT(*) AS nb_alerts
FROM mg.early_warning_alerts
WHERE source_engine = 'P7I-AMAR-GENECO'
GROUP BY source_engine, risk_code, risk_band
ORDER BY risk_code, risk_band;

-- ============================================================
-- SECTION AJOUTÉE — Sprint 5 — Mai 2026
-- Surveillance des sous-classements potentiels :
-- pays avec resource_capture_risk élevé mais score composite bas.
-- Ces cas indiquent un découplage entre l'exposition extractive
-- documentée et le score GENECO final — à investiguer manuellement
-- ou à réexaminer après intégration EITI / UCDP (Sprint 6).
-- ============================================================

\echo ''
\echo '=== Underclassification watch — resource_capture >= 0.700 but geneco_score < 0.650 ==='
SELECT
    year,
    country_iso3,
    ROUND(geneco_exposure_score, 3)             AS geneco_score,
    ROUND(geneco_confidence_score, 3)           AS confidence,
    geneco_exposure_class,
    ROUND(resource_capture_risk, 3)             AS resource_capture,
    ROUND(logistics_enabling_risk, 3)           AS logistics,
    ROUND(institutional_capture_risk, 3)        AS institutional,
    ROUND(resource_capture_risk
          - geneco_exposure_score, 3)           AS capture_vs_composite_gap
FROM ma.v_p7i_amar_geneco_engine
WHERE resource_capture_risk >= 0.700
  AND geneco_exposure_score  <  0.650
ORDER BY year DESC,
         (resource_capture_risk - geneco_exposure_score) DESC
LIMIT 40;

\echo ''
\echo '=== Former BLACK countries trajectory (last known BLACK year through 2024) ==='
-- Pays ayant été BLACK (>= 0.800) avant 2022, suivis jusqu'en 2024.
-- Permet de distinguer amélioration réelle vs artefact de couverture.
SELECT
    e.country_iso3,
    e.year,
    ROUND(e.geneco_exposure_score, 3)    AS geneco_score,
    ROUND(e.geneco_confidence_score, 3)  AS confidence,
    e.geneco_exposure_class,
    ROUND(e.resource_capture_risk, 3)    AS resource_capture,
    ROUND(e.logistics_enabling_risk, 3)  AS logistics
FROM ma.v_p7i_amar_geneco_engine e
WHERE e.country_iso3 IN (
    SELECT DISTINCT country_iso3
    FROM ma.v_p7i_amar_geneco_engine
    WHERE geneco_exposure_score >= 0.800
      AND year < 2022
)
  AND e.year >= 2019
ORDER BY e.country_iso3, e.year;

\echo ''
\echo '=== Confidence degradation watch — countries with confidence drop > 0.100 between 2021 and 2024 ==='
-- Détecte les pays dont la confiance chute significativement après 2021,
-- signal potentiel de dégradation de la couverture de données récentes.
SELECT
    a.country_iso3,
    ROUND(a.geneco_confidence_score, 3) AS confidence_2021,
    ROUND(b.geneco_confidence_score, 3) AS confidence_2024,
    ROUND(a.geneco_confidence_score
          - b.geneco_confidence_score, 3) AS confidence_drop,
    ROUND(a.geneco_exposure_score, 3)   AS score_2021,
    ROUND(b.geneco_exposure_score, 3)   AS score_2024
FROM ma.v_p7i_amar_geneco_engine a
JOIN ma.v_p7i_amar_geneco_engine b
  ON b.country_iso3 = a.country_iso3
 AND b.year = 2024
WHERE a.year = 2021
  AND (a.geneco_confidence_score - b.geneco_confidence_score) > 0.100
ORDER BY confidence_drop DESC;

\echo ''
\echo '=== P7I-AMAR-GENECO REPORT DONE ==='
