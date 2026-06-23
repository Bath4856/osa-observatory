-- ────────────────────────────────────────────────────────────
-- Diagnostic 3b corrige : ma.computed_values SDN/COD 2024 PENV
-- ────────────────────────────────────────────────────────────

SELECT
    cv.country_iso3,
    cv.year,
    cv.indicator_code,
    cv.value,
    cv.confidence,
    cv.nb_indicators
FROM ma.computed_values cv
WHERE cv.country_iso3 IN ('SDN', 'COD')
  AND cv.year = 2024
  AND cv.indicator_code ILIKE '%PENV%'
ORDER BY cv.country_iso3, cv.indicator_code;

-- 3c. Valeurs dans ma.v_p7i_risk_source pour SDN et COD 2024 PENV
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
