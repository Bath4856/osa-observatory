-- ============================================================
-- OSA / ISA OBSERVATORY
-- Patch: source matrix registry + GO/PILOT/NO_GO orchestration
-- ============================================================
BEGIN;
CREATE SCHEMA IF NOT EXISTS collect;
CREATE TABLE IF NOT EXISTS collect.source_registry (
    id BIGSERIAL PRIMARY KEY,
    source_id VARCHAR(30) UNIQUE NOT NULL,
    name VARCHAR(150) NOT NULL,
    organization VARCHAR(200),
    api_type VARCHAR(30),
    base_url TEXT,
    status VARCHAR(10) NOT NULL CHECK (status IN ('GO', 'PILOT', 'NO_GO')),
    priority INT NOT NULL DEFAULT 999,
    coverage TEXT,
    stability TEXT,
    limits TEXT,
    reason TEXT,
    freshness_score NUMERIC(4, 2),
    completeness_score NUMERIC(4, 2),
    reliability_score NUMERIC(4, 2),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    updated_at TIMESTAMP NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_source_registry_status_priority ON collect.source_registry(status, priority, source_id);
CREATE TABLE IF NOT EXISTS collect.source_registry_indicators (
    id BIGSERIAL PRIMARY KEY,
    source_id VARCHAR(30) NOT NULL REFERENCES collect.source_registry(source_id) ON DELETE CASCADE,
    osa_code VARCHAR(30),
    source_code VARCHAR(120) NOT NULL,
    endpoint TEXT,
    fallback TEXT,
    unit VARCHAR(40),
    frequency VARCHAR(20),
    decision VARCHAR(10) NOT NULL DEFAULT 'PILOT' CHECK (decision IN ('GO', 'PILOT', 'NO_GO')),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    updated_at TIMESTAMP NOT NULL DEFAULT now(),
    UNIQUE (source_id, source_code)
);
CREATE INDEX IF NOT EXISTS idx_source_registry_indicators_decision ON collect.source_registry_indicators(source_id, decision, osa_code);
CREATE TABLE IF NOT EXISTS collect.ingestion_matrix_runs (
    id BIGSERIAL PRIMARY KEY,
    run_at TIMESTAMP NOT NULL DEFAULT now(),
    include_pilot BOOLEAN NOT NULL DEFAULT FALSE,
    year_from INT,
    year_to INT,
    requested_by VARCHAR(120) NOT NULL DEFAULT 'SYSTEM',
    notes TEXT
);
CREATE TABLE IF NOT EXISTS collect.ingestion_matrix_run_items (
    id BIGSERIAL PRIMARY KEY,
    run_id BIGINT NOT NULL REFERENCES collect.ingestion_matrix_runs(id) ON DELETE CASCADE,
    source_id VARCHAR(30) NOT NULL,
    status VARCHAR(10) NOT NULL,
    priority INT NOT NULL,
    supported BOOLEAN NOT NULL DEFAULT FALSE,
    decision VARCHAR(20) NOT NULL CHECK (decision IN ('EXECUTE', 'SKIP', 'UNSUPPORTED')),
    reason TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_ingestion_matrix_run_items_run ON collect.ingestion_matrix_run_items(run_id, decision, priority);
-- ============================================================
-- Dashboard GO / PILOT / NO_GO (temps reel)
-- ============================================================
CREATE OR REPLACE VIEW collect.v_source_status_summary AS
SELECT s.status,
    COUNT(*) AS sources_count,
    MIN(s.priority) AS min_priority,
    MAX(s.priority) AS max_priority,
    ROUND(
        AVG(COALESCE(s.reliability_score, 0))::numeric,
        3
    ) AS avg_reliability
FROM collect.source_registry s
WHERE s.is_active = TRUE
GROUP BY s.status
ORDER BY CASE
        s.status
        WHEN 'GO' THEN 1
        WHEN 'PILOT' THEN 2
        ELSE 3
    END;
CREATE OR REPLACE VIEW collect.v_source_dashboard_live AS WITH latest_run AS (
        SELECT COALESCE(MAX(id), 0) AS run_id
        FROM collect.ingestion_matrix_runs
    )
SELECT s.source_id,
    s.name,
    s.status,
    s.priority,
    s.api_type,
    s.base_url,
    s.reliability_score,
    s.freshness_score,
    s.completeness_score,
    s.is_active,
    ri.run_id AS latest_run_id,
    ri.decision AS latest_decision,
    ri.supported AS latest_supported,
    ri.reason AS latest_reason,
    ri.created_at AS latest_decision_at
FROM collect.source_registry s
    LEFT JOIN latest_run lr ON TRUE
    LEFT JOIN collect.ingestion_matrix_run_items ri ON ri.run_id = lr.run_id
    AND ri.source_id = s.source_id
ORDER BY s.priority,
    s.source_id;
CREATE OR REPLACE VIEW collect.v_source_quality_scores AS
SELECT s.source_id,
    s.name,
    s.status,
    s.priority,
    COALESCE(s.freshness_score, 0) AS freshness_score,
    COALESCE(s.completeness_score, 0) AS completeness_score,
    COALESCE(s.reliability_score, 0) AS reliability_score,
    ROUND(
        (
            COALESCE(s.freshness_score, 0) * 0.30 + COALESCE(s.completeness_score, 0) * 0.30 + COALESCE(s.reliability_score, 0) * 0.40
        )::numeric,
        3
    ) AS quality_index
FROM collect.source_registry s
WHERE s.is_active = TRUE
ORDER BY s.priority,
    s.source_id;
CREATE OR REPLACE VIEW collect.v_fallback_coverage_by_source AS WITH candidates AS (
        SELECT iv.indicator_code,
            iv.country_iso3,
            iv.year,
            sri.source_id,
            sr.status,
            sr.priority,
            ROW_NUMBER() OVER (
                PARTITION BY iv.indicator_code,
                iv.country_iso3,
                iv.year
                ORDER BY sr.priority,
                    sri.source_id
            ) AS rn,
            COUNT(*) OVER (
                PARTITION BY iv.indicator_code,
                iv.country_iso3,
                iv.year
            ) AS candidate_sources
        FROM ma.indicator_values iv
            JOIN mm.source_origins so ON so.id = iv.source_id
            JOIN collect.source_registry_indicators sri ON sri.osa_code = iv.indicator_code
            AND sri.source_id = so.code
            AND sri.is_active = TRUE
            JOIN collect.source_registry sr ON sr.source_id = sri.source_id
            AND sr.is_active = TRUE
        WHERE iv.layer_id = 1
            AND iv.raw_value IS NOT NULL
            AND sr.status IN ('GO', 'PILOT')
    ),
    selected AS (
        SELECT indicator_code,
            country_iso3,
            year,
            source_id,
            status,
            priority,
            candidate_sources
        FROM candidates
        WHERE rn = 1
    )
SELECT year,
    indicator_code,
    source_id AS selected_source_id,
    status AS selected_source_status,
    priority AS selected_source_priority,
    COUNT(*) AS resolved_points,
    SUM(
        CASE
            WHEN candidate_sources > 1 THEN 1
            ELSE 0
        END
    ) AS fallback_points,
    ROUND(
        SUM(
            CASE
                WHEN candidate_sources > 1 THEN 1
                ELSE 0
            END
        )::numeric * 100 / NULLIF(COUNT(*), 0),
        2
    ) AS fallback_rate_pct,
    ROUND(AVG(candidate_sources)::numeric, 3) AS avg_candidate_sources
FROM selected
GROUP BY year,
    indicator_code,
    source_id,
    status,
    priority
ORDER BY year,
    indicator_code,
    selected_source_priority,
    selected_source_id;
CREATE OR REPLACE FUNCTION collect.run_ingestion_from_matrix(
        p_year_from INT DEFAULT NULL,
        p_year_to INT DEFAULT NULL,
        p_include_pilot BOOLEAN DEFAULT FALSE,
        p_requested_by VARCHAR DEFAULT 'SYSTEM'
    ) RETURNS TABLE (
        run_id BIGINT,
        source_id VARCHAR,
        status VARCHAR,
        priority INT,
        supported BOOLEAN,
        decision VARCHAR,
        reason TEXT
    ) LANGUAGE plpgsql AS $$
DECLARE v_run_id BIGINT;
BEGIN
INSERT INTO collect.ingestion_matrix_runs(
        include_pilot,
        year_from,
        year_to,
        requested_by
    )
VALUES (
        p_include_pilot,
        p_year_from,
        p_year_to,
        COALESCE(p_requested_by, 'SYSTEM')
    )
RETURNING id INTO v_run_id;
INSERT INTO collect.ingestion_matrix_run_items(
        run_id,
        source_id,
        status,
        priority,
        supported,
        decision,
        reason
    )
SELECT v_run_id AS run_id,
    s.source_id,
    s.status,
    s.priority,
    (
        s.source_id IN (
            'WB',
            'IMF',
            'WHO',
            'ITU',
            'FAO',
            'UNDP',
            'UNESCO',
            'OECD'
        )
    ) AS supported,
    CASE
        WHEN s.is_active IS FALSE THEN 'SKIP'
        WHEN s.source_id NOT IN (
            'WB',
            'IMF',
            'WHO',
            'ITU',
            'FAO',
            'UNDP',
            'UNESCO',
            'OECD'
        ) THEN 'UNSUPPORTED'
        WHEN s.status = 'GO' THEN 'EXECUTE'
        WHEN s.status = 'PILOT'
        AND p_include_pilot THEN 'EXECUTE'
        WHEN s.status = 'PILOT'
        AND NOT p_include_pilot THEN 'SKIP'
        ELSE 'SKIP'
    END AS decision,
    CASE
        WHEN s.is_active IS FALSE THEN 'Source inactive'
        WHEN s.source_id NOT IN (
            'WB',
            'IMF',
            'WHO',
            'ITU',
            'FAO',
            'UNDP',
            'UNESCO',
            'OECD'
        ) THEN 'Provider non implemente dans les fetchers courants'
        WHEN s.status = 'GO' THEN 'GO autorise'
        WHEN s.status = 'PILOT'
        AND p_include_pilot THEN 'PILOT autorise par include_pilot'
        WHEN s.status = 'PILOT'
        AND NOT p_include_pilot THEN 'PILOT desactive'
        WHEN s.status = 'NO_GO' THEN COALESCE(s.reason, 'NO_GO')
        ELSE 'Hors scope'
    END AS reason
FROM collect.source_registry s
ORDER BY s.priority,
    s.source_id;
RETURN QUERY
SELECT i.run_id,
    i.source_id,
    i.status,
    i.priority,
    i.supported,
    i.decision,
    i.reason
FROM collect.ingestion_matrix_run_items i
WHERE i.run_id = v_run_id
ORDER BY i.priority,
    i.source_id;
END;
$$;
-- ============================================================
-- Fallback multi-source (arbitrage automatique)
-- ============================================================
CREATE OR REPLACE FUNCTION collect.resolve_fallback_value(
        p_indicator_code VARCHAR,
        p_country_iso3 CHAR(3),
        p_year SMALLINT,
        p_include_pilot BOOLEAN DEFAULT FALSE,
        p_layer_id SMALLINT DEFAULT 1
    ) RETURNS TABLE (
        indicator_code VARCHAR,
        country_iso3 CHAR(3),
        year SMALLINT,
        layer_id SMALLINT,
        selected_source_code VARCHAR,
        selected_priority INT,
        resolved_value NUMERIC,
        candidate_sources INT,
        fallback_chain TEXT
    ) LANGUAGE sql AS $$ WITH candidates AS (
        SELECT sri.osa_code AS indicator_code,
            iv.country_iso3,
            iv.year,
            iv.layer_id,
            so.code AS source_code,
            sr.priority,
            iv.raw_value
        FROM collect.source_registry_indicators sri
            JOIN collect.source_registry sr ON sr.source_id = sri.source_id
            JOIN mm.source_origins so ON so.code = sri.source_id
            JOIN ma.indicator_values iv ON iv.indicator_code = sri.osa_code
            AND iv.source_id = so.id
            AND iv.country_iso3 = p_country_iso3
            AND iv.year = p_year
            AND iv.layer_id = p_layer_id
            AND iv.raw_value IS NOT NULL
        WHERE sri.osa_code = p_indicator_code
            AND sri.is_active = TRUE
            AND sr.is_active = TRUE
            AND (
                sr.status = 'GO'
                OR (
                    sr.status = 'PILOT'
                    AND p_include_pilot = TRUE
                )
            )
            AND (
                sri.decision = 'GO'
                OR (
                    sri.decision = 'PILOT'
                    AND p_include_pilot = TRUE
                )
            )
    ),
    ranked AS (
        SELECT c.*,
            ROW_NUMBER() OVER (
                ORDER BY CASE
                        WHEN c.priority IS NULL THEN 999
                        ELSE c.priority
                    END,
                    c.source_code
            ) AS rn,
            COUNT(*) OVER () AS candidate_sources,
            STRING_AGG(
                c.source_code || ':' || COALESCE(c.raw_value::text, 'NULL'),
                ' -> '
            ) OVER (
                ORDER BY CASE
                        WHEN c.priority IS NULL THEN 999
                        ELSE c.priority
                    END,
                    c.source_code ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
            ) AS fallback_chain
        FROM candidates c
    )
SELECT r.indicator_code,
    r.country_iso3,
    r.year,
    r.layer_id,
    r.source_code AS selected_source_code,
    r.priority AS selected_priority,
    r.raw_value AS resolved_value,
    r.candidate_sources,
    r.fallback_chain
FROM ranked r
WHERE r.rn = 1;
$$;
CREATE OR REPLACE FUNCTION collect.resolve_indicator_fallback_set(
        p_indicator_code VARCHAR,
        p_year SMALLINT,
        p_include_pilot BOOLEAN DEFAULT FALSE,
        p_layer_id SMALLINT DEFAULT 1
    ) RETURNS TABLE (
        indicator_code VARCHAR,
        country_iso3 CHAR(3),
        year SMALLINT,
        layer_id SMALLINT,
        selected_source_code VARCHAR,
        selected_priority INT,
        resolved_value NUMERIC,
        used_fallback BOOLEAN,
        candidate_sources INT,
        fallback_chain TEXT
    ) LANGUAGE sql AS $$ WITH countries AS (
        SELECT c.iso3::CHAR(3) AS country_iso3
        FROM rf.countries c
    ),
    resolved AS (
        SELECT c.country_iso3,
            r.indicator_code,
            r.year,
            r.layer_id,
            r.selected_source_code,
            r.selected_priority,
            r.resolved_value,
            r.candidate_sources,
            r.fallback_chain
        FROM countries c
            LEFT JOIN LATERAL collect.resolve_fallback_value(
                p_indicator_code,
                c.country_iso3,
                p_year,
                p_include_pilot,
                p_layer_id
            ) r ON TRUE
    )
SELECT p_indicator_code AS indicator_code,
    country_iso3,
    p_year AS year,
    p_layer_id AS layer_id,
    selected_source_code,
    selected_priority,
    resolved_value,
    (candidate_sources > 1) AS used_fallback,
    COALESCE(candidate_sources, 0) AS candidate_sources,
    fallback_chain
FROM resolved
ORDER BY country_iso3;
$$;
COMMIT;