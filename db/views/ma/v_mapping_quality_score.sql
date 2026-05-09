-- ======================================================
-- VIEW : ma.v_mapping_quality_score
-- ======================================================

CREATE OR REPLACE VIEW ma.v_mapping_quality_score AS

WITH mapping AS (
    SELECT
        i.code AS indicator_code,
        i.pillar_code,

        CASE WHEN cs.id IS NOT NULL THEN 1 ELSE 0 END AS mapping_exists,

        CASE 
            WHEN cs.is_active = true THEN 1
            WHEN cs.is_active = false THEN 0.3
            ELSE 0
        END AS mapping_active,

        COALESCE(cs.coverage_pct / 100.0, 0) AS coverage_score,

        COALESCE(dp.reliability_score, 0.5) AS provider_score

    FROM rf.indicators i

    LEFT JOIN collect.indicator_source cs
        ON cs.indicator_code = i.code

    LEFT JOIN collect.provider_endpoints pe
        ON pe.id = cs.endpoint_id

    LEFT JOIN collect.data_providers dp
        ON dp.id = pe.provider_id
),

data_quality AS (
    SELECT
        indicator_code,
        AVG(confidence_score) AS avg_confidence
    FROM ma.indicator_values
    GROUP BY indicator_code
),

registry AS (
    SELECT
        osa_code AS indicator_code,
        MAX(
            CASE 
                WHEN decision = 'GO' THEN 1
                WHEN decision = 'PILOT' THEN 0.5
                WHEN decision = 'NO_GO' THEN 0
                ELSE 0
            END
        ) AS registry_score
    FROM collect.source_registry_indicators
    GROUP BY osa_code
)

SELECT
    m.indicator_code,
    m.pillar_code,

    m.mapping_exists,
    m.mapping_active,
    m.coverage_score,
    m.provider_score,
    COALESCE(d.avg_confidence, 0) AS data_confidence,
    COALESCE(r.registry_score, 0) AS registry_score,

    ROUND(
        0.30 * m.mapping_exists +
        0.15 * m.mapping_active +
        0.20 * m.coverage_score +
        0.20 * m.provider_score +
        0.15 * COALESCE(d.avg_confidence, 0)
    , 3) AS mapping_quality_score,

    CASE
        WHEN (
            0.30 * m.mapping_exists +
            0.15 * m.mapping_active +
            0.20 * m.coverage_score +
            0.20 * m.provider_score +
            0.15 * COALESCE(d.avg_confidence, 0)
        ) >= 0.80 THEN 'A — FIABLE'
        WHEN (
            0.30 * m.mapping_exists +
            0.15 * m.mapping_active +
            0.20 * m.coverage_score +
            0.20 * m.provider_score +
            0.15 * COALESCE(d.avg_confidence, 0)
        ) >= 0.60 THEN 'B — ACCEPTABLE'
        WHEN (
            0.30 * m.mapping_exists +
            0.15 * m.mapping_active +
            0.20 * m.coverage_score +
            0.20 * m.provider_score +
            0.15 * COALESCE(d.avg_confidence, 0)
        ) >= 0.40 THEN 'C — FRAGILE'
        ELSE 'D — CRITIQUE'
    END AS quality_class,

    CASE
        WHEN (
            0.30 * m.mapping_exists +
            0.15 * m.mapping_active +
            0.20 * m.coverage_score +
            0.20 * m.provider_score +
            0.15 * COALESCE(d.avg_confidence, 0)
        ) < 0.50 THEN 'EXCLU ISA'
        ELSE 'OK'
    END AS isa_status,

    CASE
        WHEN m.mapping_exists = 0 AND COALESCE(d.avg_confidence, 0) > 0 THEN 'ORPHELIN'
        ELSE NULL
    END AS orphan_flag

FROM mapping m
LEFT JOIN data_quality d ON d.indicator_code = m.indicator_code
LEFT JOIN registry r ON r.indicator_code = m.indicator_code;