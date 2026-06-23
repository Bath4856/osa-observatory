-- ============================================================
-- OSA ISA – Sprint 24 GAF v3
-- Migration complète : Lots A + A bis + D
--
-- Nouveautés v3 :
-- [A bis] finding_hash, recurrence_count, first_seen_at, publication_impact
-- [B bis] publication_impact + iprs_weight dans gaf_orientation_rules
-- [D]     ops.gaf_iprs_calibration (table comité)
--         ops.v_gaf_iprs_impact (KPIs MTTC, closure rate)
-- ============================================================

BEGIN;

-- ============================================================
-- 1. ops.audit_findings
-- ============================================================

CREATE TABLE IF NOT EXISTS ops.audit_findings (

    finding_id          BIGSERIAL       PRIMARY KEY,
    audit_id            BIGINT          NOT NULL
                        REFERENCES ops.audit_runs(audit_id) ON DELETE CASCADE,
    module              TEXT            NOT NULL,
    finding_code        TEXT            NOT NULL,

    -- [A bis] Récurrence
    finding_hash        TEXT            NOT NULL,
    recurrence_count    INTEGER         NOT NULL DEFAULT 1,
    first_seen_at       TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    -- Sévérité
    severity            TEXT            NOT NULL
                        CHECK (severity IN ('CRITICAL','HIGH','MEDIUM','LOW','INFO')),

    -- [B bis] Impact publication
    publication_impact  TEXT            NOT NULL DEFAULT 'NONE'
                        CHECK (publication_impact IN ('BLOCKING','CONDITIONAL','NONE')),

    -- [D] Poids IPRS
    iprs_weight         NUMERIC(4,2)    NOT NULL DEFAULT 0.00,

    object_type         TEXT,
    object_code         TEXT,
    description         TEXT            NOT NULL,
    raw_finding         JSONB,
    status              TEXT            NOT NULL DEFAULT 'OPEN'
                        CHECK (status IN ('OPEN','ORIENTED','IN_PROGRESS',
                                          'RESOLVED','DEFERRED','CLOSED')),
    detected_at         TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    closed_at           TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_findings_audit_id    ON ops.audit_findings (audit_id);
CREATE INDEX IF NOT EXISTS idx_findings_module      ON ops.audit_findings (module);
CREATE INDEX IF NOT EXISTS idx_findings_severity    ON ops.audit_findings (severity);
CREATE INDEX IF NOT EXISTS idx_findings_status      ON ops.audit_findings (status);
CREATE INDEX IF NOT EXISTS idx_findings_object_code ON ops.audit_findings (object_code);
CREATE INDEX IF NOT EXISTS idx_findings_detected_at ON ops.audit_findings (detected_at DESC);
CREATE INDEX IF NOT EXISTS idx_findings_hash        ON ops.audit_findings (finding_hash);
CREATE INDEX IF NOT EXISTS idx_findings_pub_impact  ON ops.audit_findings (publication_impact);

COMMENT ON COLUMN ops.audit_findings.finding_hash IS
    'SHA-256(module:finding_code:object_code). Identifie un type de finding.';
COMMENT ON COLUMN ops.audit_findings.recurrence_count IS
    'Nombre total de détections de ce finding_hash tous runs confondus.';
COMMENT ON COLUMN ops.audit_findings.first_seen_at IS
    'Date de première détection de ce finding_hash.';
COMMENT ON COLUMN ops.audit_findings.publication_impact IS
    'BLOCKING: bloque publication. CONDITIONAL: CONDITIONAL_PUBLICATION. NONE: informatif.';
COMMENT ON COLUMN ops.audit_findings.iprs_weight IS
    'Points IPRS retirés. Calibré par le Comité Scientifique.';

-- ============================================================
-- 2. ops.audit_recommendations
-- ============================================================

CREATE TABLE IF NOT EXISTS ops.audit_recommendations (
    recommendation_id   BIGSERIAL       PRIMARY KEY,
    finding_id          BIGINT          NOT NULL
                        REFERENCES ops.audit_findings(finding_id) ON DELETE CASCADE,
    recommended_action  TEXT            NOT NULL,
    priority            TEXT            NOT NULL DEFAULT 'MEDIUM'
                        CHECK (priority IN ('CRITICAL','HIGH','MEDIUM','LOW')),
    owner               TEXT,
    sprint_target       TEXT,
    rationale           TEXT,
    rule_code           TEXT,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rec_finding_id ON ops.audit_recommendations (finding_id);
CREATE INDEX IF NOT EXISTS idx_rec_priority   ON ops.audit_recommendations (priority);
CREATE INDEX IF NOT EXISTS idx_rec_owner      ON ops.audit_recommendations (owner);

-- ============================================================
-- 3. ops.audit_decisions
-- ============================================================

CREATE TABLE IF NOT EXISTS ops.audit_decisions (
    decision_id         BIGSERIAL       PRIMARY KEY,
    finding_id          BIGINT          NOT NULL
                        REFERENCES ops.audit_findings(finding_id) ON DELETE CASCADE,
    decision            TEXT            NOT NULL
                        CHECK (decision IN ('ACCEPT','DEFER','REJECT','ESCALATE')),
    decided_by          TEXT            NOT NULL,
    decision_date       TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    sprint_assigned     TEXT,
    due_date            DATE,
    comment             TEXT,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_dec_finding_id   ON ops.audit_decisions (finding_id);
CREATE INDEX IF NOT EXISTS idx_dec_decision_date ON ops.audit_decisions (decision_date DESC);

-- ============================================================
-- 4. ops.audit_corrections
-- ============================================================

CREATE TABLE IF NOT EXISTS ops.audit_corrections (
    correction_id       BIGSERIAL       PRIMARY KEY,
    finding_id          BIGINT          NOT NULL
                        REFERENCES ops.audit_findings(finding_id) ON DELETE CASCADE,
    decision_id         BIGINT
                        REFERENCES ops.audit_decisions(decision_id) ON DELETE SET NULL,
    corrected_by        TEXT            NOT NULL,
    correction_date     TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    description         TEXT            NOT NULL,
    verified            BOOLEAN         NOT NULL DEFAULT FALSE,
    verified_by         TEXT,
    verified_at         TIMESTAMPTZ,
    git_commit          TEXT,
    finding_resolved    BOOLEAN         NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cor_finding_id     ON ops.audit_corrections (finding_id);
CREATE INDEX IF NOT EXISTS idx_cor_correction_date ON ops.audit_corrections (correction_date DESC);

-- ============================================================
-- 5. [D] ops.gaf_iprs_calibration — Table comité
-- ============================================================

CREATE TABLE IF NOT EXISTS ops.gaf_iprs_calibration (
    finding_code        TEXT            PRIMARY KEY,
    iprs_weight         NUMERIC(4,2)    NOT NULL DEFAULT 0.00,
    publication_impact  TEXT            NOT NULL DEFAULT 'NONE'
                        CHECK (publication_impact IN ('BLOCKING','CONDITIONAL','NONE')),
    rationale           TEXT,
    validated_by        TEXT            DEFAULT 'DEFAULT',
    validated_at        TIMESTAMPTZ     DEFAULT NOW(),
    is_validated        BOOLEAN         NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE ops.gaf_iprs_calibration IS
    'Calibration Comité Scientifique OSA. '
    'Ne pas modifier via code. Mise à jour par le comité uniquement.';

-- ============================================================
-- 6. Triggers
-- ============================================================

CREATE OR REPLACE FUNCTION ops.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END; $$;

DROP TRIGGER IF EXISTS trg_findings_updated_at     ON ops.audit_findings;
DROP TRIGGER IF EXISTS trg_calibration_updated_at  ON ops.gaf_iprs_calibration;
DROP TRIGGER IF EXISTS trg_close_finding           ON ops.audit_corrections;

CREATE TRIGGER trg_findings_updated_at
    BEFORE UPDATE ON ops.audit_findings
    FOR EACH ROW EXECUTE FUNCTION ops.set_updated_at();

CREATE TRIGGER trg_calibration_updated_at
    BEFORE UPDATE ON ops.gaf_iprs_calibration
    FOR EACH ROW EXECUTE FUNCTION ops.set_updated_at();

CREATE OR REPLACE FUNCTION ops.close_finding_on_verified_correction()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.verified = TRUE AND NEW.finding_resolved = TRUE THEN
        UPDATE ops.audit_findings
        SET status = 'CLOSED', closed_at = NOW()
        WHERE finding_id = NEW.finding_id AND status != 'CLOSED';
    END IF;
    RETURN NEW;
END; $$;

CREATE TRIGGER trg_close_finding
    AFTER INSERT OR UPDATE ON ops.audit_corrections
    FOR EACH ROW EXECUTE FUNCTION ops.close_finding_on_verified_correction();

-- ============================================================
-- 7. Vues
-- ============================================================

CREATE OR REPLACE VIEW ops.v_findings_open AS
SELECT
    f.finding_id, f.audit_id, f.module, f.finding_code,
    f.finding_hash, f.recurrence_count, f.first_seen_at,
    f.severity, f.publication_impact, f.iprs_weight,
    f.object_type, f.object_code, f.description, f.status,
    f.detected_at,
    EXTRACT(DAY FROM NOW() - f.first_seen_at)::INTEGER AS age_days,
    r.recommended_action, r.priority, r.owner, r.sprint_target,
    d.decision, d.decided_by, d.sprint_assigned
FROM ops.audit_findings f
LEFT JOIN ops.audit_recommendations r ON r.finding_id = f.finding_id
LEFT JOIN ops.audit_decisions d       ON d.finding_id = f.finding_id
WHERE f.status NOT IN ('CLOSED','RESOLVED')
ORDER BY
    CASE f.publication_impact WHEN 'BLOCKING' THEN 1 WHEN 'CONDITIONAL' THEN 2 ELSE 3 END,
    CASE f.severity WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2
                    WHEN 'MEDIUM' THEN 3 WHEN 'LOW' THEN 4 ELSE 5 END,
    f.recurrence_count DESC, f.first_seen_at ASC;

CREATE OR REPLACE VIEW ops.v_findings_dashboard AS
SELECT
    DATE_TRUNC('day', f.detected_at) AS day,
    f.module, f.severity, f.publication_impact, f.status,
    COUNT(*)                          AS finding_count,
    SUM(f.iprs_weight)                AS iprs_weight_total,
    AVG(f.recurrence_count)::NUMERIC(6,2) AS avg_recurrence,
    MAX(f.recurrence_count)           AS max_recurrence,
    COUNT(*) FILTER (WHERE f.status = 'CLOSED') AS closed_count,
    COUNT(*) FILTER (WHERE f.status = 'OPEN')   AS open_count,
    ROUND(100.0 * COUNT(*) FILTER (WHERE f.status = 'CLOSED')
          / GREATEST(COUNT(*),1), 2) AS resolution_rate_pct
FROM ops.audit_findings f
GROUP BY DATE_TRUNC('day', f.detected_at), f.module,
         f.severity, f.publication_impact, f.status
ORDER BY day DESC, f.severity;

-- [D] KPI IPRS GAF
CREATE OR REPLACE VIEW ops.v_gaf_iprs_impact AS
SELECT
    COALESCE(SUM(f.iprs_weight) FILTER (
        WHERE f.status NOT IN ('CLOSED','RESOLVED')), 0)    AS iprs_deduction_active,
    COALESCE(SUM(f.iprs_weight) FILTER (
        WHERE f.publication_impact = 'BLOCKING'
          AND f.status NOT IN ('CLOSED','RESOLVED')), 0)    AS iprs_deduction_blocking,
    COUNT(*) FILTER (
        WHERE f.publication_impact = 'BLOCKING'
          AND f.status NOT IN ('CLOSED','RESOLVED'))        AS blocking_findings_open,
    COUNT(*) FILTER (
        WHERE f.publication_impact = 'CONDITIONAL'
          AND f.status NOT IN ('CLOSED','RESOLVED'))        AS conditional_findings_open,
    ROUND(AVG(
        EXTRACT(DAY FROM c.correction_date - f.first_seen_at)
    )::NUMERIC, 2)                                          AS mttc_days,
    ROUND(100.0 * COUNT(c.correction_id) FILTER (
        WHERE c.finding_resolved = TRUE)
        / GREATEST(COUNT(DISTINCT f.finding_id), 1), 2)    AS recommendation_closure_rate_pct
FROM ops.audit_findings f
LEFT JOIN ops.audit_corrections c ON c.finding_id = f.finding_id;

COMMENT ON VIEW ops.v_gaf_iprs_impact IS
    'KPIs GAF : déduction IPRS, MTTC, Recommendation Closure Rate.';

COMMIT;

-- Vérification
SELECT tablename,
       pg_size_pretty(pg_total_relation_size('ops.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'ops'
  AND tablename IN ('audit_findings','audit_recommendations','audit_decisions',
                    'audit_corrections','gaf_iprs_calibration')
ORDER BY tablename;
