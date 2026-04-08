-- ============================================================
-- QUALITÉ DES DONNÉES — OSA
-- Corrigé pour le schéma réel : country_iso3, value_raw
-- ============================================================

-- 1. Complétude par indicateur
CREATE OR REPLACE VIEW collect.v_quality_completeness AS
SELECT
    indicator_code,
    year,
    COUNT(DISTINCT country_iso3) AS nb_countries
FROM collect.raw_data
WHERE value_raw IS NOT NULL
GROUP BY indicator_code, year;

-- 2. Score qualité global
CREATE OR REPLACE FUNCTION collect.compute_quality_score(p_year INT)
RETURNS TABLE(
    indicator_code TEXT,
    coverage_pct NUMERIC,
    status TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        i.code,
        ROUND(
            COUNT(DISTINCT rd.country_iso3) * 100.0 /
            NULLIF((SELECT COUNT(*) FROM rf.countries), 0),
        0),
        CASE
            WHEN COUNT(DISTINCT rd.country_iso3) >= 40 THEN 'GO'
            WHEN COUNT(DISTINCT rd.country_iso3) >= 20 THEN 'PARTIAL'
            ELSE 'NO_GO'
        END
    FROM rf.indicators i
    LEFT JOIN collect.raw_data rd
        ON rd.indicator_code = i.code
        AND rd.year = p_year
    GROUP BY i.code;
END;
$$ LANGUAGE plpgsql;

-- 3. Détection anomalies
CREATE OR REPLACE VIEW collect.v_quality_anomalies AS
SELECT *
FROM collect.raw_data
WHERE value_raw IS NULL
   OR value_raw < 0;
