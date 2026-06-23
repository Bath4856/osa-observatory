
-- =====================================================
-- OSA ISA
-- P8_AUDIT_AUTOMATION_V2.1
-- Audit Ledger
-- =====================================================

CREATE SCHEMA IF NOT EXISTS ops;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- =====================================================
-- AUDIT RUNS
-- =====================================================

CREATE TABLE IF NOT EXISTS ops.audit_runs (

audit_id UUID PRIMARY KEY
    DEFAULT gen_random_uuid(),

audit_timestamp TIMESTAMP NOT NULL
    DEFAULT CURRENT_TIMESTAMP,

audit_duration_seconds NUMERIC(10,2),

iprs NUMERIC(5,2),

publication_status TEXT NOT NULL,

git_commit TEXT,

report_hash TEXT,

signature_hash TEXT,

created_at TIMESTAMP
    DEFAULT CURRENT_TIMESTAMP

);

CREATE INDEX IF NOT EXISTS idx_audit_runs_timestamp
ON ops.audit_runs(audit_timestamp DESC);

-- =====================================================
-- AUDIT RESULTS
-- =====================================================

CREATE TABLE IF NOT EXISTS ops.audit_results (

result_id BIGSERIAL PRIMARY KEY,

audit_id UUID NOT NULL,

module_name TEXT NOT NULL,

status TEXT NOT NULL,

details JSONB,

created_at TIMESTAMP
    DEFAULT CURRENT_TIMESTAMP,

CONSTRAINT fk_audit_result
    FOREIGN KEY(audit_id)
    REFERENCES ops.audit_runs(audit_id)

);

CREATE INDEX IF NOT EXISTS idx_audit_results_audit
ON ops.audit_results(audit_id);

-- =====================================================
-- PUBLICATION GATE
-- =====================================================

CREATE TABLE IF NOT EXISTS ops.audit_publication_gate (

gate_id BIGSERIAL PRIMARY KEY,

audit_id UUID NOT NULL,

publication_status TEXT,

warning_modules JSONB,

fail_modules JSONB,

created_at TIMESTAMP
    DEFAULT CURRENT_TIMESTAMP,

CONSTRAINT fk_gate_audit
    FOREIGN KEY(audit_id)
    REFERENCES ops.audit_runs(audit_id)

);

-- =====================================================
-- VUE DERNIER AUDIT
-- =====================================================

CREATE OR REPLACE VIEW ops.v_audit_latest AS

SELECT *
FROM ops.audit_runs
ORDER BY audit_timestamp DESC
LIMIT 1;

--- 
