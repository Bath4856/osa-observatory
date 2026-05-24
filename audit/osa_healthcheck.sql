-- ============================================================
-- OSA Observatory -- osa_healthcheck.sql
-- Diagnostic automatise pipeline + AMAR + conformite doctrinale
-- Produit des lignes JSON parsables par osa_healthcheck.py
-- Usage : psql -h 127.0.0.1 -U postgres -d osa_db -f osa_healthcheck.sql
-- ============================================================

\t on
\pset format unaligned
\pset fieldsep '|'

-- ── 1. VUES CRITIQUES ────────────────────────────────────────
SELECT 'CHECK_VIEWS|'
    || CASE WHEN to_regclass('ma.v_p7i_risk_source') IS NOT NULL THEN 'OK' ELSE 'MISSING' END || '|'
    || CASE WHEN to_regclass('ma.v_isa_early_warning_engine') IS NOT NULL THEN 'OK' ELSE 'MISSING' END || '|'
    || CASE WHEN to_regclass('ma.v_isa_risk_escalation_engine') IS NOT NULL THEN 'OK' ELSE 'MISSING' END || '|'
    || CASE WHEN to_regclass('ma.v_p7i_amar_dashboard') IS NOT NULL THEN 'OK' ELSE 'MISSING' END || '|'
    || CASE WHEN to_regclass('ma.v_p7i_amar_geneco_dashboard') IS NOT NULL THEN 'OK' ELSE 'MISSING' END || '|'
    || CASE WHEN to_regclass('ma.v_p7i_amar_composite_dashboard') IS NOT NULL THEN 'OK' ELSE 'MISSING' END || '|'
    || CASE WHEN to_regclass('mg.v_public_p7i_amar_alerts') IS NOT NULL THEN 'OK' ELSE 'MISSING' END || '|'
    || CASE WHEN to_regclass('mg.v_public_p7i_amar_geneco_alerts') IS NOT NULL THEN 'OK' ELSE 'MISSING' END
AS result;

-- ── 2. CONFORMITE DOCTRINALE ──────────────────────────────────
SELECT 'CHECK_DOCTRINE|'
    || COUNT(*)::text || '|'
    || STRING_AGG(code, ',') AS result
FROM rf.indicators
WHERE is_active = TRUE
  AND doctrine_compliance_flag = FALSE;

-- ── 3. INDICATEURS ACTIFS SANS L3 ────────────────────────────
SELECT 'CHECK_ACTIVE_NO_L3|'
    || COUNT(*)::text || '|'
    || COALESCE(STRING_AGG(i.code, ','), '') AS result
FROM rf.indicators i
WHERE i.is_active = TRUE
  AND i.is_composite_score = FALSE
  AND EXISTS (
      SELECT 1 FROM ma.indicator_values v
      WHERE v.indicator_code = i.code
        AND v.layer_id = 1
  )
  AND NOT EXISTS (
      SELECT 1 FROM ma.indicator_values v
      WHERE v.indicator_code = i.code
        AND v.layer_id = 3
  );

-- ── 4. DOUBLONS L1 ────────────────────────────────────────────
SELECT 'CHECK_DUPLICATES_L1|'
    || COUNT(*)::text AS result
FROM (
    SELECT indicator_code, country_iso3, year, layer_id, COUNT(*) AS cnt
    FROM ma.indicator_values
    WHERE layer_id = 1
    GROUP BY indicator_code, country_iso3, year, layer_id
    HAVING COUNT(*) > 1
) dupes;

-- ── 5. SOURCE_ID NULL EN L1 ───────────────────────────────────
SELECT 'CHECK_SOURCE_NULL|'
    || COUNT(*)::text AS result
FROM ma.indicator_values
WHERE layer_id = 1
  AND source_id IS NULL;

-- ── 6. SCORES ISA OBSERVES PAR ANNEE ─────────────────────────
SELECT 'ISA_SCORES|'
    || year::text || '|'
    || ROUND(AVG(isa_observed_score)::numeric, 5)::text || '|'
    || COUNT(*)::text AS result
FROM ma.v_isa_observed_scores_by_country_year
WHERE year BETWEEN 2010 AND 2024
GROUP BY year
ORDER BY year;

-- ── 7. DISTRIBUTION AMAR PAR ANNEE ───────────────────────────
SELECT 'AMAR_DIST|'
    || year::text || '|'
    || risk_band || '|'
    || COUNT(*)::text || '|'
    || ROUND(AVG(risk_score)::numeric, 4)::text AS result
FROM ma.v_p7i_amar_dashboard
WHERE year BETWEEN 2010 AND 2024
GROUP BY year, risk_band
ORDER BY year, risk_band;

-- ── 8. DISTRIBUTION GENECO PAR ANNEE ─────────────────────────
SELECT 'GENECO_DIST|'
    || year::text || '|'
    || risk_band || '|'
    || COUNT(*)::text || '|'
    || ROUND(AVG(risk_score)::numeric, 4)::text AS result
FROM ma.v_p7i_amar_geneco_dashboard
WHERE year BETWEEN 2010 AND 2024
GROUP BY year, risk_band
ORDER BY year, risk_band;

-- ── 9. RUPTURES AMAR (SAUT > 20% ENTRE ANNEES CONSECUTIVES) ──
SELECT 'AMAR_BREAK|'
    || year::text || '|'
    || risk_band || '|'
    || nb_pays::text || '|'
    || prev_nb::text || '|'
    || ABS(nb_pays - prev_nb)::text AS result
FROM (
    SELECT
        year,
        risk_band,
        COUNT(*) AS nb_pays,
        LAG(COUNT(*)) OVER (PARTITION BY risk_band ORDER BY year) AS prev_nb
    FROM ma.v_p7i_amar_dashboard
    WHERE year BETWEEN 2010 AND 2024
    GROUP BY year, risk_band
) t
WHERE prev_nb IS NOT NULL
  AND ABS(nb_pays - prev_nb) > GREATEST(prev_nb * 0.20, 3)
ORDER BY year, risk_band;

-- ── 10. INDICATEURS ACTIFS PAR PILIER ────────────────────────
SELECT 'PILIER_COUNT|'
    || pillar_code || '|'
    || COUNT(*)::text AS result
FROM rf.indicators
WHERE is_active = TRUE
GROUP BY pillar_code
ORDER BY pillar_code;

-- ── 11. LIGNES L1/L2/L3 PAR LAYER ────────────────────────────
SELECT 'LAYER_COUNT|'
    || layer_id::text || '|'
    || COUNT(*)::text || '|'
    || COUNT(DISTINCT indicator_code)::text || '|'
    || COUNT(DISTINCT country_iso3)::text AS result
FROM ma.indicator_values
WHERE layer_id IN (1, 2, 3)
GROUP BY layer_id
ORDER BY layer_id;

-- ── 12. RF.INDICATOR_VERSIONS (traçabilité doctrinale) ────────
SELECT 'VERSIONS_COUNT|'
    || sprint || '|'
    || action || '|'
    || COUNT(*)::text AS result
FROM rf.indicator_versions
GROUP BY sprint, action
ORDER BY sprint, action;

\t off
\pset format aligned
