-- =============================================================================
-- OSA / ISA — PATCH MG API REGISTRIES
-- mg.api_usage_registry  : journal des appels API
-- mg.api_key_registry    : clés API expert (hash SHA-256)
-- =============================================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS mg;

-- -----------------------------------------------------------------------------
-- mg.api_usage_registry
-- Alimenté par api/middleware/telemetry.py après chaque appel
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mg.api_usage_registry (
    usage_id            BIGSERIAL       PRIMARY KEY,
    request_timestamp   TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    endpoint_code       TEXT,
    api_path            TEXT,
    http_method         TEXT,
    access_class        TEXT,
    requester_ip        TEXT,
    requester_identity  TEXT,
    response_status     INTEGER,
    response_time_ms    NUMERIC(10,2),
    rows_returned       INTEGER,
    release_code        TEXT,
    semantic_version    TEXT,
    audit_status        TEXT            DEFAULT 'OK'
);

CREATE INDEX IF NOT EXISTS idx_api_usage_timestamp
    ON mg.api_usage_registry (request_timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_api_usage_endpoint
    ON mg.api_usage_registry (endpoint_code);
CREATE INDEX IF NOT EXISTS idx_api_usage_access_class
    ON mg.api_usage_registry (access_class);

-- -----------------------------------------------------------------------------
-- mg.api_key_registry
-- Stocke le hash SHA-256 de la clé — jamais la clé en clair
-- Pour insérer une clé :
--   INSERT INTO mg.api_key_registry (api_key_hash, owner_label, access_class)
--   VALUES (encode(sha256('votre-clé'::bytea), 'hex'), 'Label', 'EXPERT');
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mg.api_key_registry (
    api_key_id      BIGSERIAL       PRIMARY KEY,
    api_key_hash    TEXT            NOT NULL UNIQUE,
    owner_label     TEXT,
    access_class    TEXT            NOT NULL DEFAULT 'EXPERT',
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    expires_at      TIMESTAMPTZ,
    last_used_at    TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_api_key_active
    ON mg.api_key_registry (is_active)
    WHERE is_active = TRUE;

-- -----------------------------------------------------------------------------
-- Validation
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    RAISE NOTICE 'MG API registries : api_usage_registry=OK, api_key_registry=OK';
    RAISE NOTICE 'Pour insérer une clé expert :';
    RAISE NOTICE '  INSERT INTO mg.api_key_registry (api_key_hash, owner_label, access_class)';
    RAISE NOTICE '  VALUES (encode(sha256(:key::bytea), hex), :label, EXPERT);';
END $$;

COMMIT;
