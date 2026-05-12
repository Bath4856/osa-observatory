-- ============================================================
-- OSA / ISA — P7F
-- View: ma.v_p7f_computed_swot_source
-- Purpose: stable computed SWOT source based on confirmed columns.
-- Depends: ma.computed_values(indicator_code,country_iso3,year,value,confidence)
-- ============================================================

CREATE OR REPLACE VIEW ma.v_p7f_computed_swot_source AS
WITH src AS (
    SELECT
        indicator_code::TEXT AS swot_code,
        CASE
            WHEN indicator_code LIKE 'WKN_%' THEN 'WKN'
            WHEN indicator_code LIKE 'THR_%' THEN 'THR'
            WHEN indicator_code LIKE 'STR_%' THEN 'STR'
            WHEN indicator_code LIKE 'OPP_%' THEN 'OPP'
            ELSE 'OTHER'
        END AS swot_type,
        country_iso3::TEXT AS country_iso3,
        year::INTEGER AS year,
        UPPER(COALESCE(
            NULLIF(substring(indicator_code::TEXT FROM '^(?:WKN|THR|STR|OPP)_([A-Z0-9]+)'), ''),
            'UNKNOWN'
        )) AS pillar_code,
        GREATEST(0::NUMERIC, LEAST(1::NUMERIC, COALESCE(value, 0)::NUMERIC)) AS swot_value,
        GREATEST(0::NUMERIC, LEAST(1::NUMERIC, COALESCE(confidence, 0.70)::NUMERIC)) AS swot_confidence
    FROM ma.computed_values
    WHERE indicator_code LIKE 'WKN_%'
       OR indicator_code LIKE 'THR_%'
       OR indicator_code LIKE 'STR_%'
       OR indicator_code LIKE 'OPP_%'
)
SELECT
    swot_code,
    swot_type,
    country_iso3,
    year,
    pillar_code,
    swot_value,
    swot_confidence,
    CASE
        WHEN swot_type IN ('WKN','THR','STR','OPP') AND pillar_code <> 'UNKNOWN'
            THEN 'P7F_COMPAT_OK'
        ELSE 'P7F_COMPAT_REVIEW'
    END AS compatibility_status
FROM src;
