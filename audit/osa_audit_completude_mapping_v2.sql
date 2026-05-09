-- ======================================================
-- OSA — AUDIT COMPLETUDE MAPPING INDICATEURS ↔ SOURCES
-- VERSION CORRIGÉE (COMPATIBLE SCHÉMA RÉEL)
-- ======================================================

\echo '======================================================'
\echo ' OSA — AUDIT COMPLETUDE MAPPAGE INDICATEURS ↔ SOURCES'
\echo '======================================================'

-- ======================================================
-- BLOC A : VUE GLOBALE MAPPING
-- ======================================================

\echo ''
\echo '=== BLOC A : VUE COMPLÈTE INDICATEURS × MAPPING ==='

SELECT
    i.pillar_code,
    i.code AS indicator_code,
    i.name_fr,

    dp.code AS provider,
    dp.base_url,

    pe.id AS endpoint_id,
    cs.source_indicator_code,
    cs.coverage_pct,
    cs.is_active

FROM rf.indicators i

LEFT JOIN collect.indicator_source cs
    ON cs.indicator_code = i.code

LEFT JOIN collect.provider_endpoints pe
    ON pe.id = cs.endpoint_id

LEFT JOIN collect.data_providers dp
    ON dp.id = pe.provider_id

ORDER BY i.pillar_code, i.code;

-- ======================================================
-- BLOC B : INDICATEURS MAPPÉS
-- ======================================================

\echo ''
\echo '=== BLOC B : INDICATEURS MAPPÉS — DÉTAIL ==='

SELECT
    i.pillar_code,
    i.code,
    i.name_fr,

    dp.code AS provider,
    dp.base_url,
    pe.id AS endpoint_id,

    cs.source_indicator_code,
    cs.coverage_pct

FROM rf.indicators i

JOIN collect.indicator_source cs
    ON cs.indicator_code = i.code

JOIN collect.provider_endpoints pe
    ON pe.id = cs.endpoint_id

JOIN collect.data_providers dp
    ON dp.id = pe.provider_id

WHERE cs.is_active = true

ORDER BY i.pillar_code, i.code;

-- ======================================================
-- BLOC C : INDICATEURS NON MAPPÉS
-- ======================================================

\echo ''
\echo '=== BLOC C : INDICATEURS NON MAPPÉS ==='

SELECT
    i.pillar_code,
    i.code,
    i.name_fr

FROM rf.indicators i

LEFT JOIN collect.indicator_source cs
    ON cs.indicator_code = i.code

WHERE cs.id IS NULL

ORDER BY i.pillar_code, i.code;

-- ======================================================
-- BLOC D : REGISTRY (QUALIFICATION)
-- ======================================================

\echo ''
\echo '=== BLOC D : INDICATEURS EN REGISTRY ==='

SELECT
    i.code,
    i.name_fr,

    sri.source_id,
    sri.source_code,
    sri.decision,
    sri.endpoint

FROM rf.indicators i

LEFT JOIN collect.source_registry_indicators sri
    ON sri.osa_code = i.code

ORDER BY i.code;

-- ======================================================
-- BLOC E : PROVIDERS & CODES DISPONIBLES
-- ======================================================

\echo ''
\echo '=== BLOC E : CODES SOURCE PAR PROVIDER ==='

SELECT
    dp.code AS provider,
    sri.source_code,
    sri.osa_code,
    sri.decision

FROM collect.source_registry_indicators sri

JOIN collect.source_registry sr
    ON sr.source_id = sri.source_id

LEFT JOIN collect.data_providers dp
    ON dp.code = sr.source_id

ORDER BY dp.code;

-- ======================================================
-- BLOC F : TAUX DE MAPPING PAR PILIER
-- ======================================================

\echo ''
\echo '=== BLOC F : TAUX DE COMPLÉTUDE PAR PILIER ==='

SELECT
    i.pillar_code,

    COUNT(*) AS total_indicators,
    COUNT(cs.id) AS mapped_indicators,

    ROUND(100.0 * COUNT(cs.id) / COUNT(*), 2) AS mapping_pct

FROM rf.indicators i

LEFT JOIN collect.indicator_source cs
    ON cs.indicator_code = i.code

GROUP BY i.pillar_code
ORDER BY i.pillar_code;

-- ======================================================
-- BLOC G : COHÉRENCE REGISTRY vs MAPPING
-- ======================================================

\echo ''
\echo '=== BLOC G : REGISTRY vs MAPPING ==='

SELECT
    i.code,
    i.name_fr,

    CASE
        WHEN cs.id IS NOT NULL THEN 'MAPPÉ'
        ELSE 'NON MAPPÉ'
    END AS mapping_status,

    sri.decision AS registry_status

FROM rf.indicators i

LEFT JOIN collect.indicator_source cs
    ON cs.indicator_code = i.code

LEFT JOIN collect.source_registry_indicators sri
    ON sri.osa_code = i.code

ORDER BY i.code;

-- ======================================================
-- BLOC H : DONNÉES SANS SOURCE
-- ======================================================

\echo ''
\echo '=== BLOC H : DONNÉES SANS SOURCE TRACÉE ==='

SELECT
    i.pillar_code,
    v.indicator_code,
    i.name_fr,

    COUNT(*) AS observations,
    COUNT(DISTINCT v.country_iso3) AS countries,

    ROUND(AVG(v.confidence_score), 3) AS avg_confidence,

    MIN(v.year) AS start_year,
    MAX(v.year) AS end_year,

    '⚠ Données présentes sans mapping source' AS alerte

FROM ma.indicator_values v

JOIN rf.indicators i
    ON i.code = v.indicator_code

LEFT JOIN collect.indicator_source cs
    ON cs.indicator_code = v.indicator_code

WHERE cs.id IS NULL

GROUP BY i.pillar_code, v.indicator_code, i.name_fr

ORDER BY observations DESC;

-- ======================================================
-- RÉSUMÉ GLOBAL
-- ======================================================

\echo ''
\echo '=== RÉSUMÉ GLOBAL ==='

SELECT
    COUNT(*) AS total_indicators,
    COUNT(cs.id) AS mapped,
    COUNT(*) - COUNT(cs.id) AS unmapped,

    ROUND(100.0 * COUNT(cs.id) / COUNT(*), 2) AS mapping_pct

FROM rf.indicators i

LEFT JOIN collect.indicator_source cs
    ON cs.indicator_code = i.code;

-- ======================================================
-- FIN
-- ======================================================

\echo ''
\echo '=== AUDIT TERMINÉ ==='