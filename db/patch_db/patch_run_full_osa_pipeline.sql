-- ============================================================
-- OSA / ISA OBSERVATORY
-- Patch: run_full_osa_pipeline() - mode production L1 -> L6
-- ============================================================
BEGIN;
CREATE SCHEMA IF NOT EXISTS collect;
CREATE SCHEMA IF NOT EXISTS rf;
-- ============================================================
-- 1) Journalisation pipeline et audit
-- ============================================================
CREATE TABLE IF NOT EXISTS collect.pipeline_runs (
    id BIGSERIAL PRIMARY KEY,
    year SMALLINT NOT NULL,
    include_pilot BOOLEAN NOT NULL DEFAULT FALSE,
    requested_by VARCHAR(120) NOT NULL DEFAULT 'SYSTEM',
    method_version_id INT NOT NULL DEFAULT 1,
    require_validation BOOLEAN NOT NULL DEFAULT TRUE,
    validation_id BIGINT,
    quality_score NUMERIC(6, 4),
    status VARCHAR(30) NOT NULL DEFAULT 'RUNNING' CHECK (
        status IN (
            'RUNNING',
            'WAITING_VALIDATION',
            'FAILED_QUALITY',
            'FAILED',
            'SUCCESS'
        )
    ),
    message TEXT,
    started_at TIMESTAMP NOT NULL DEFAULT now(),
    completed_at TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_pipeline_runs_year_status ON collect.pipeline_runs(year, status, started_at DESC);
CREATE TABLE IF NOT EXISTS collect.pipeline_step_logs (
    id BIGSERIAL PRIMARY KEY,
    run_id BIGINT NOT NULL REFERENCES collect.pipeline_runs(id) ON DELETE CASCADE,
    step_code VARCHAR(40) NOT NULL,
    status VARCHAR(20) NOT NULL CHECK (
        status IN ('RUNNING', 'SUCCESS', 'SKIPPED', 'FAILED')
    ),
    message TEXT,
    details JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_pipeline_step_logs_run ON collect.pipeline_step_logs(run_id, created_at);
CREATE TABLE IF NOT EXISTS rf.audit_log (
    id BIGSERIAL PRIMARY KEY,
    domain VARCHAR(40) NOT NULL,
    event_type VARCHAR(80) NOT NULL,
    actor VARCHAR(120),
    ref_id VARCHAR(120),
    payload JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_audit_log_domain_event ON rf.audit_log(domain, event_type, created_at DESC);
CREATE TABLE IF NOT EXISTS rf.security_proof_log (
    id BIGSERIAL PRIMARY KEY,
    proof_type VARCHAR(40) NOT NULL,
    ref_id VARCHAR(120) NOT NULL,
    signer_1 VARCHAR(120),
    signer_2 VARCHAR(120),
    signature_hash_1 TEXT,
    signature_hash_2 TEXT,
    payload_hash TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_security_proof_ref ON rf.security_proof_log(ref_id, created_at DESC);
-- ============================================================
-- 2) Donnee canonique L1 et validation souveraine
-- ============================================================
CREATE TABLE IF NOT EXISTS collect.source_data (
    id BIGSERIAL PRIMARY KEY,
    country_code CHAR(3) NOT NULL,
    indicator_code VARCHAR(30) NOT NULL,
    year SMALLINT NOT NULL,
    value NUMERIC(24, 8),
    source_id VARCHAR(30) NOT NULL,
    quality_flag VARCHAR(20) DEFAULT 'OK',
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    updated_at TIMESTAMP NOT NULL DEFAULT now(),
    UNIQUE (country_code, indicator_code, year, source_id)
);
CREATE INDEX IF NOT EXISTS idx_source_data_lookup ON collect.source_data(year, indicator_code, country_code, source_id);
CREATE TABLE IF NOT EXISTS collect.dataset_validation (
    id BIGSERIAL PRIMARY KEY,
    dataset_code VARCHAR(50) NOT NULL,
    year SMALLINT NOT NULL,
    requested_by VARCHAR(120) NOT NULL,
    approver_1 VARCHAR(120),
    approver_2 VARCHAR(120),
    signature_hash_1 TEXT,
    signature_hash_2 TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED')),
    notes TEXT,
    requested_at TIMESTAMP NOT NULL DEFAULT now(),
    approved_at TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_dataset_validation_status ON collect.dataset_validation(year, status, requested_at DESC);
CREATE TABLE IF NOT EXISTS collect.quality_gate_results (
    id BIGSERIAL PRIMARY KEY,
    run_id BIGINT REFERENCES collect.pipeline_runs(id) ON DELETE CASCADE,
    year SMALLINT NOT NULL,
    completeness_score NUMERIC(6, 4) NOT NULL,
    freshness_score NUMERIC(6, 4) NOT NULL,
    consistency_score NUMERIC(6, 4) NOT NULL,
    quality_score NUMERIC(6, 4) NOT NULL,
    details JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_quality_gate_results_year ON collect.quality_gate_results(year, created_at DESC);
-- ============================================================
-- 3) Utilitaires pipeline
-- ============================================================
CREATE OR REPLACE FUNCTION collect.log_pipeline_step(
        p_run_id BIGINT,
        p_step_code VARCHAR,
        p_status VARCHAR,
        p_message TEXT DEFAULT NULL,
        p_details JSONB DEFAULT NULL
    ) RETURNS VOID LANGUAGE plpgsql AS $$ BEGIN
INSERT INTO collect.pipeline_step_logs(run_id, step_code, status, message, details)
VALUES (
        p_run_id,
        p_step_code,
        p_status,
        p_message,
        p_details
    );
END;
$$;
CREATE OR REPLACE FUNCTION collect.sync_source_data_from_l1(p_year SMALLINT) RETURNS INT LANGUAGE plpgsql AS $$
DECLARE v_upserted INT := 0;
BEGIN
INSERT INTO collect.source_data(
        country_code,
        indicator_code,
        year,
        value,
        source_id,
        quality_flag,
        updated_at
    )
SELECT iv.country_iso3,
    iv.indicator_code,
    iv.year,
    iv.raw_value,
    so.code,
    COALESCE(iv.quality_flag, 'OK'),
    now()
FROM ma.indicator_values iv
    JOIN mm.source_origins so ON so.id = iv.source_id
WHERE iv.layer_id = 1
    AND iv.year = p_year
    AND iv.raw_value IS NOT NULL ON CONFLICT (country_code, indicator_code, year, source_id) DO
UPDATE
SET value = EXCLUDED.value,
    quality_flag = EXCLUDED.quality_flag,
    updated_at = now();
GET DIAGNOSTICS v_upserted = ROW_COUNT;
RETURN v_upserted;
END;
$$;
CREATE OR REPLACE FUNCTION collect.request_dataset_validation(
        p_year SMALLINT,
        p_requested_by VARCHAR DEFAULT 'SYSTEM',
        p_dataset_code VARCHAR DEFAULT 'OSA_MAIN'
    ) RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE v_id BIGINT;
BEGIN
INSERT INTO collect.dataset_validation(dataset_code, year, requested_by, status)
VALUES (
        p_dataset_code,
        p_year,
        COALESCE(p_requested_by, 'SYSTEM'),
        'PENDING'
    )
RETURNING id INTO v_id;
INSERT INTO rf.audit_log(domain, event_type, actor, ref_id, payload)
VALUES (
        'VALIDATION',
        'VALIDATION_REQUESTED',
        COALESCE(p_requested_by, 'SYSTEM'),
        v_id::text,
        jsonb_build_object('year', p_year, 'dataset_code', p_dataset_code)
    );
RETURN v_id;
END;
$$;
CREATE OR REPLACE FUNCTION rf.validate_dataset(
        p_validation_id BIGINT,
        p_user_1 VARCHAR,
        p_user_2 VARCHAR,
        p_signature_hash_1 TEXT DEFAULT NULL,
        p_signature_hash_2 TEXT DEFAULT NULL
    ) RETURNS BOOLEAN LANGUAGE plpgsql AS $$
DECLARE v_year SMALLINT;
BEGIN IF p_user_1 IS NULL
OR p_user_2 IS NULL
OR p_user_1 = p_user_2 THEN RAISE EXCEPTION 'Validation 4-eyes invalide: deux validateurs distincts requis';
END IF;
UPDATE collect.dataset_validation
SET approver_1 = p_user_1,
    approver_2 = p_user_2,
    signature_hash_1 = p_signature_hash_1,
    signature_hash_2 = p_signature_hash_2,
    status = 'APPROVED',
    approved_at = now()
WHERE id = p_validation_id
    AND status = 'PENDING'
RETURNING year INTO v_year;
IF v_year IS NULL THEN RETURN FALSE;
END IF;
INSERT INTO rf.security_proof_log(
        proof_type,
        ref_id,
        signer_1,
        signer_2,
        signature_hash_1,
        signature_hash_2,
        payload_hash
    )
VALUES (
        'DOUBLE_VALIDATION',
        p_validation_id::text,
        p_user_1,
        p_user_2,
        p_signature_hash_1,
        p_signature_hash_2,
        md5(
            coalesce(p_validation_id::text, '') || '|' || coalesce(v_year::text, '')
        )
    );
INSERT INTO rf.audit_log(domain, event_type, actor, ref_id, payload)
VALUES (
        'VALIDATION',
        'VALIDATION_APPROVED',
        p_user_1 || '+' || p_user_2,
        p_validation_id::text,
        jsonb_build_object('year', v_year)
    );
RETURN TRUE;
END;
$$;
CREATE OR REPLACE FUNCTION collect.run_quality_gate(
        p_run_id BIGINT,
        p_year SMALLINT,
        p_include_pilot BOOLEAN DEFAULT FALSE
    ) RETURNS NUMERIC LANGUAGE plpgsql AS $$
DECLARE v_expected BIGINT := 0;
v_observed BIGINT := 0;
v_completeness NUMERIC := 0;
v_freshness NUMERIC := 0;
v_consistency NUMERIC := 0;
v_quality NUMERIC := 0;
v_max_year SMALLINT;
BEGIN
SELECT COUNT(DISTINCT c.iso3) * COUNT(DISTINCT sri.osa_code) INTO v_expected
FROM rf.countries c
    CROSS JOIN collect.source_registry_indicators sri
    JOIN collect.source_registry sr ON sr.source_id = sri.source_id
WHERE sr.is_active = TRUE
    AND sri.is_active = TRUE
    AND (
        sr.status = 'GO'
        OR (
            sr.status = 'PILOT'
            AND p_include_pilot
        )
    )
    AND (
        sri.decision = 'GO'
        OR (
            sri.decision = 'PILOT'
            AND p_include_pilot
        )
    );
SELECT COUNT(*) INTO v_observed
FROM collect.source_data sd
WHERE sd.year = p_year
    AND sd.value IS NOT NULL;
IF v_expected > 0 THEN v_completeness := LEAST(1, v_observed::numeric / v_expected::numeric);
END IF;
SELECT MAX(year) INTO v_max_year
FROM collect.source_data;
IF v_max_year IS NULL THEN v_freshness := 0;
ELSE v_freshness := GREATEST(
    0,
    1 - (GREATEST(0, p_year - v_max_year)::numeric / 5)
);
END IF;
WITH per_point AS (
    SELECT indicator_code,
        country_code,
        year,
        COUNT(*) AS n,
        AVG(value) AS avg_v,
        STDDEV_POP(value) AS std_v
    FROM collect.source_data
    WHERE year = p_year
        AND value IS NOT NULL
    GROUP BY indicator_code,
        country_code,
        year
)
SELECT COALESCE(
        AVG(
            CASE
                WHEN n <= 1 THEN 1
                WHEN avg_v = 0 THEN 1
                WHEN abs(std_v / NULLIF(avg_v, 0)) <= 1 THEN 1
                ELSE 0
            END
        ),
        0
    ) INTO v_consistency
FROM per_point;
v_quality := ROUND(
    (v_completeness + v_freshness + v_consistency) / 3.0,
    4
);
INSERT INTO collect.quality_gate_results(
        run_id,
        year,
        completeness_score,
        freshness_score,
        consistency_score,
        quality_score,
        details
    )
VALUES (
        p_run_id,
        p_year,
        ROUND(v_completeness, 4),
        ROUND(v_freshness, 4),
        ROUND(v_consistency, 4),
        v_quality,
        jsonb_build_object(
            'expected_points',
            v_expected,
            'observed_points',
            v_observed,
            'include_pilot',
            p_include_pilot
        )
    );
INSERT INTO rf.audit_log(domain, event_type, actor, ref_id, payload)
VALUES (
        'QUALITY',
        'QUALITY_GATE_EXECUTED',
        'SYSTEM',
        p_run_id::text,
        jsonb_build_object(
            'year',
            p_year,
            'quality_score',
            v_quality,
            'completeness',
            ROUND(v_completeness, 4),
            'freshness',
            ROUND(v_freshness, 4),
            'consistency',
            ROUND(v_consistency, 4)
        )
    );
RETURN v_quality;
END;
$$;
CREATE OR REPLACE FUNCTION collect.run_publication_cycle(
        p_year SMALLINT,
        p_method_version_id INT DEFAULT 1
    ) RETURNS INT LANGUAGE plpgsql AS $$
DECLARE v_published INT := 0;
BEGIN
UPDATE ma.isa_index
SET is_published = TRUE,
    published_at = now()
WHERE year = p_year
    AND method_version_id = p_method_version_id;
GET DIAGNOSTICS v_published = ROW_COUNT;
INSERT INTO rf.audit_log(domain, event_type, actor, ref_id, payload)
VALUES (
        'PUBLICATION',
        'ISA_PUBLISHED',
        'SYSTEM',
        p_year::text,
        jsonb_build_object(
            'published_rows',
            v_published,
            'method_version_id',
            p_method_version_id
        )
    );
RETURN v_published;
END;
$$;
CREATE OR REPLACE FUNCTION collect.run_full_osa_pipeline(
        p_year SMALLINT,
        p_include_pilot BOOLEAN DEFAULT FALSE,
        p_requested_by VARCHAR DEFAULT 'SYSTEM',
        p_method_version_id INT DEFAULT 1,
        p_require_validation BOOLEAN DEFAULT TRUE,
        p_validation_id BIGINT DEFAULT NULL,
        p_quality_threshold NUMERIC DEFAULT 0.70
    ) RETURNS TABLE (
        run_id BIGINT,
        status VARCHAR,
        quality_score NUMERIC,
        validation_id BIGINT,
        message TEXT
    ) LANGUAGE plpgsql AS $$
DECLARE v_run_id BIGINT;
v_quality NUMERIC := 0;
v_validation_id BIGINT := p_validation_id;
v_validation_ok BOOLEAN := FALSE;
v_sync_count INT := 0;
v_published INT := 0;
v_exec_count INT := 0;
BEGIN
INSERT INTO collect.pipeline_runs(
        year,
        include_pilot,
        requested_by,
        method_version_id,
        require_validation,
        validation_id,
        status
    )
VALUES (
        p_year,
        p_include_pilot,
        COALESCE(p_requested_by, 'SYSTEM'),
        p_method_version_id,
        p_require_validation,
        v_validation_id,
        'RUNNING'
    )
RETURNING id INTO v_run_id;
PERFORM collect.log_pipeline_step(
    v_run_id,
    'INGESTION_PLAN',
    'RUNNING',
    'Generation du plan matrice',
    NULL
);
SELECT COUNT(*) INTO v_exec_count
FROM collect.run_ingestion_from_matrix(p_year, p_year, p_include_pilot, p_requested_by)
WHERE decision = 'EXECUTE';
PERFORM collect.log_pipeline_step(
    v_run_id,
    'INGESTION_PLAN',
    'SUCCESS',
    'Plan matrice genere',
    jsonb_build_object('sources_execute', v_exec_count)
);
PERFORM collect.log_pipeline_step(
    v_run_id,
    'SYNC_L1',
    'RUNNING',
    'Synchronisation L1 vers source_data',
    NULL
);
v_sync_count := collect.sync_source_data_from_l1(p_year);
PERFORM collect.log_pipeline_step(
    v_run_id,
    'SYNC_L1',
    'SUCCESS',
    'Synchronisation terminee',
    jsonb_build_object('upserted_points', v_sync_count)
);
PERFORM collect.log_pipeline_step(
    v_run_id,
    'QUALITY_GATE',
    'RUNNING',
    'Controle qualite',
    NULL
);
v_quality := collect.run_quality_gate(v_run_id, p_year, p_include_pilot);
UPDATE collect.pipeline_runs
SET quality_score = v_quality
WHERE id = v_run_id;
IF v_quality < p_quality_threshold THEN
UPDATE collect.pipeline_runs
SET status = 'FAILED_QUALITY',
    message = 'Quality gate insuffisant',
    completed_at = now()
WHERE id = v_run_id;
PERFORM collect.log_pipeline_step(
    v_run_id,
    'QUALITY_GATE',
    'FAILED',
    'Seuil qualite non atteint',
    jsonb_build_object(
        'quality_score',
        v_quality,
        'threshold',
        p_quality_threshold
    )
);
RETURN QUERY
SELECT v_run_id,
    'FAILED_QUALITY'::VARCHAR,
    v_quality,
    v_validation_id,
    'Quality gate insuffisant'::TEXT;
RETURN;
END IF;
PERFORM collect.log_pipeline_step(
    v_run_id,
    'QUALITY_GATE',
    'SUCCESS',
    'Quality gate valide',
    jsonb_build_object('quality_score', v_quality)
);
IF p_require_validation THEN PERFORM collect.log_pipeline_step(
    v_run_id,
    'VALIDATION',
    'RUNNING',
    'Verification validation souveraine',
    NULL
);
IF v_validation_id IS NULL THEN v_validation_id := collect.request_dataset_validation(p_year, p_requested_by, 'OSA_MAIN');
UPDATE collect.pipeline_runs
SET validation_id = v_validation_id,
    status = 'WAITING_VALIDATION',
    message = 'Validation humaine requise',
    completed_at = now()
WHERE id = v_run_id;
PERFORM collect.log_pipeline_step(
    v_run_id,
    'VALIDATION',
    'SKIPPED',
    'Validation demandee, en attente approbation',
    jsonb_build_object('validation_id', v_validation_id)
);
RETURN QUERY
SELECT v_run_id,
    'WAITING_VALIDATION'::VARCHAR,
    v_quality,
    v_validation_id,
    'Validation humaine requise'::TEXT;
RETURN;
END IF;
SELECT (status = 'APPROVED') INTO v_validation_ok
FROM collect.dataset_validation
WHERE id = v_validation_id;
IF COALESCE(v_validation_ok, FALSE) IS FALSE THEN
UPDATE collect.pipeline_runs
SET validation_id = v_validation_id,
    status = 'WAITING_VALIDATION',
    message = 'Validation non approuvee',
    completed_at = now()
WHERE id = v_run_id;
PERFORM collect.log_pipeline_step(
    v_run_id,
    'VALIDATION',
    'SKIPPED',
    'Validation non approuvee',
    jsonb_build_object('validation_id', v_validation_id)
);
RETURN QUERY
SELECT v_run_id,
    'WAITING_VALIDATION'::VARCHAR,
    v_quality,
    v_validation_id,
    'Validation non approuvee'::TEXT;
RETURN;
END IF;
PERFORM collect.log_pipeline_step(
    v_run_id,
    'VALIDATION',
    'SUCCESS',
    'Validation approuvee',
    jsonb_build_object('validation_id', v_validation_id)
);
ELSE PERFORM collect.log_pipeline_step(
    v_run_id,
    'VALIDATION',
    'SKIPPED',
    'Validation desactivee par parametrage',
    NULL
);
END IF;
PERFORM collect.log_pipeline_step(
    v_run_id,
    'ANALYTICS',
    'RUNNING',
    'Calcul analytique ISA',
    NULL
);
CALL ma.run_pipeline_year(p_year, p_method_version_id);
PERFORM collect.log_pipeline_step(
    v_run_id,
    'ANALYTICS',
    'SUCCESS',
    'Calcul analytique termine',
    NULL
);
PERFORM collect.log_pipeline_step(
    v_run_id,
    'PUBLICATION',
    'RUNNING',
    'Publication ISA',
    NULL
);
v_published := collect.run_publication_cycle(p_year, p_method_version_id);
PERFORM collect.log_pipeline_step(
    v_run_id,
    'PUBLICATION',
    'SUCCESS',
    'Publication terminee',
    jsonb_build_object('published_rows', v_published)
);
UPDATE collect.pipeline_runs
SET status = 'SUCCESS',
    validation_id = v_validation_id,
    message = 'Pipeline termine avec succes',
    completed_at = now()
WHERE id = v_run_id;
INSERT INTO rf.audit_log(domain, event_type, actor, ref_id, payload)
VALUES (
        'PIPELINE',
        'FULL_PIPELINE_SUCCESS',
        COALESCE(p_requested_by, 'SYSTEM'),
        v_run_id::text,
        jsonb_build_object(
            'year',
            p_year,
            'include_pilot',
            p_include_pilot,
            'quality_score',
            v_quality,
            'validation_id',
            v_validation_id,
            'published_rows',
            v_published
        )
    );
RETURN QUERY
SELECT v_run_id,
    'SUCCESS'::VARCHAR,
    v_quality,
    v_validation_id,
    'Pipeline termine avec succes'::TEXT;
END;
$$;
COMMIT;