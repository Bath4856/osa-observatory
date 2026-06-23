-- ============================================================
-- Sprint 25 -- Lot B : Backfill AMAR Triggers 2020-2024
-- + Investigation anomalie SDN/COD WKN NULL
-- 23 juin 2026 -- v2 (colonnes corrigees)
-- ============================================================

BEGIN;

-- ────────────────────────────────────────────────────────────
-- 1. BACKFILL 2020-2024
-- ────────────────────────────────────────────────────────────

INSERT INTO pub.amar_triggers (
    country_iso3,
    year,
    pillar_code,
    trigger_class,
    thr_score,
    wkn_score,
    wkn_confidence,
    wkn_missing,
    source_view,
    computed_at
)
SELECT
    src.country_iso3,
    src.year::SMALLINT,
    src.pillar_code,
    pub.trigger_classify(
        src.threat_score,
        src.weakness_score,
        src.observation_confidence
    )                                   AS trigger_class,
    src.threat_score                    AS thr_score,
    src.weakness_score                  AS wkn_score,
    src.observation_confidence          AS wkn_confidence,
    (src.weakness_score IS NULL)        AS wkn_missing,
    'ma.v_p7i_risk_source'              AS source_view,
    now()                               AS computed_at
FROM ma.v_p7i_risk_source src
JOIN rf.publication_policy pp
    ON pp.year = src.year
   AND pp.status = 'OFFICIAL'
WHERE pub.trigger_classify(
        src.threat_score,
        src.weakness_score,
        src.observation_confidence
      ) IS NOT NULL
ON CONFLICT (country_iso3, year, pillar_code) DO NOTHING;

-- ────────────────────────────────────────────────────────────
-- 2. VERIFICATION POST-BACKFILL
-- ────────────────────────────────────────────────────────────

-- 2a. Distribution par classe
SELECT
    trigger_class,
    COUNT(*)                                            AS n,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM pub.amar_triggers
GROUP BY trigger_class
ORDER BY
    CASE trigger_class
        WHEN 'TRIGGER_EXCEPTIONAL'           THEN 1
        WHEN 'TRIGGER_CRITICAL'              THEN 2
        WHEN 'TRIGGER_ACTIVE'                THEN 3
        WHEN 'TRIGGER_DIAGNOSTIC_INCOMPLETE' THEN 4
    END;

-- 2b. Distribution par annee
SELECT
    year,
    COUNT(DISTINCT country_iso3)    AS n_countries,
    COUNT(*)                        AS n_triggers,
    STRING_AGG(
        country_iso3 || '/' || pillar_code,
        ', ' ORDER BY country_iso3
    )                               AS detail
FROM pub.amar_triggers
GROUP BY year
ORDER BY year;

-- 2c. Distribution par pilier
SELECT
    pillar_code,
    COUNT(*)                                            AS n_triggers,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM pub.amar_triggers
GROUP BY pillar_code
ORDER BY n_triggers DESC;

-- 2d. Validation total attendu
SELECT
    COUNT(*)    AS total_triggers,
    CASE WHEN COUNT(*) = 18
        THEN 'OK -- 18 triggers attendus'
        ELSE 'ANOMALIE -- ' || COUNT(*)::TEXT || ' triggers (attendu : 18)'
    END         AS validation
FROM pub.amar_triggers;

COMMIT;

-- ────────────────────────────────────────────────────────────
-- 3. DIAGNOSTIC ANOMALIE WKN NULL (hors transaction)
-- ────────────────────────────────────────────────────────────

-- 3a. Etat dans pub.amar_triggers apres backfill
SELECT
    country_iso3,
    year,
    pillar_code,
    trigger_class,
    thr_score,
    wkn_score,
    wkn_confidence,
    wkn_missing
FROM pub.amar_triggers
WHERE country_iso3 IN ('SDN', 'COD')
  AND pillar_code = 'PENV'
ORDER BY country_iso3, year;

-- 3b. Valeurs brutes dans ma.computed_values pour SDN et COD 2024
SELECT
    cv.country_iso3,
    cv.year,
    cv.indicator_code,
    cv.value,
    cv.confidence,
    cv.nb_indicators,
    cv.imputation_method
FROM ma.computed_values cv
WHERE cv.country_iso3 IN ('SDN', 'COD')
  AND cv.year = 2024
  AND cv.indicator_code ILIKE '%PENV%'
ORDER BY cv.country_iso3, cv.indicator_code;

-- 3c. Valeurs dans ma.v_p7i_risk_source pour SDN et COD 2024
SELECT
    country_iso3,
    year,
    pillar_code,
    threat_score,
    weakness_score,
    observation_confidence,
    strategic_risk_score,
    swot_data_status
FROM ma.v_p7i_risk_source
WHERE country_iso3 IN ('SDN', 'COD')
  AND year = 2024
  AND pillar_code = 'PENV';
