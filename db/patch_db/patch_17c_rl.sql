-- =============================================================================
-- OSA OBSERVATORY -- PATCH 17C -- RATE LIMITING
-- Sprint 17 -- 27 mai 2026
--
-- Principe : separation des responsabilites
--   mg.api_usage_registry  -> audit (inchange)
--   mg.rate_limit_counters -> compteurs rate limit (nouvelle table, < 2ms)
--
-- Architecture des compteurs :
--   Une ligne par (identifier, window_type, window_start).
--   Upsert sur la fenetre courante uniquement.
--   La table reste petite (N affilies actifs + M IPs actives).
--   Migration vers Redis : meme interface, backend different.
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. mg.rate_limit_counters
--    Compteurs de rate limiting. Une ligne par identifiant actif.
--    identifier : affiliation_id (JWT) ou adresse IP (PUBLIC)
--    window_type : HOURLY | DAILY
--    window_start : debut de la fenetre courante (tronque a l'heure ou au jour)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mg.rate_limit_counters (
    id           BIGSERIAL    PRIMARY KEY,
    identifier   TEXT         NOT NULL,
    window_type  TEXT         NOT NULL CHECK (window_type IN ('HOURLY', 'DAILY')),
    window_start TIMESTAMPTZ  NOT NULL,
    counter      INTEGER      NOT NULL DEFAULT 1,
    access_class TEXT         NOT NULL DEFAULT 'PUBLIC',
    updated_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (identifier, window_type, window_start)
);

COMMENT ON TABLE mg.rate_limit_counters IS
    'Compteurs de rate limiting Sprint 17. '
    'Une ligne par identifiant actif par fenetre. '
    'Taille stable dans le temps (upsert sur fenetre courante). '
    'Latence cible < 2ms. Migration vers Redis conditionnelle > 10 000 req/jour.';

COMMENT ON COLUMN mg.rate_limit_counters.identifier IS
    'affiliation_id (JWT STANDARD/PREMIUM) ou adresse IP (PUBLIC/OTP). '
    'Format : "aff:1" pour affiliation_id=1, "ip:127.0.0.1" pour IP.';

COMMENT ON COLUMN mg.rate_limit_counters.window_type IS
    'HOURLY : fenetre glissante 1h (PUBLIC, OTP). '
    'DAILY  : fenetre fixe journaliere minuit UTC (STANDARD, PREMIUM).';

COMMENT ON COLUMN mg.rate_limit_counters.window_start IS
    'HOURLY : DATE_TRUNC(''hour'', NOW()). '
    'DAILY  : DATE_TRUNC(''day'', NOW() AT TIME ZONE ''UTC'').';

-- Index principal : lookup par identifiant + fenetre
CREATE UNIQUE INDEX IF NOT EXISTS idx_rl_counters_lookup
    ON mg.rate_limit_counters (identifier, window_type, window_start);

-- Index nettoyage : supprimer les fenetres expirées
CREATE INDEX IF NOT EXISTS idx_rl_counters_window_start
    ON mg.rate_limit_counters (window_start);

-- ---------------------------------------------------------------------------
-- 2. Index supplementaires sur mg.api_usage_registry
--    Pour les requetes d'audit (pas de rate limiting)
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_api_usage_ip_timestamp
    ON mg.api_usage_registry (requester_ip, request_timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_api_usage_identity_timestamp
    ON mg.api_usage_registry (requester_identity, request_timestamp DESC);

-- ---------------------------------------------------------------------------
-- 3. Fonction nettoyage des compteurs expires
--    Appel recommande : quotidien via run_full_pipeline.ps1 option [8]
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mg.cleanup_rate_limit_counters()
RETURNS BIGINT AS $$
DECLARE
    v_deleted BIGINT;
BEGIN
    -- Supprimer les fenetres HOURLY de plus de 2 heures
    DELETE FROM mg.rate_limit_counters
    WHERE window_type = 'HOURLY'
      AND window_start < NOW() - INTERVAL '2 hours';
    GET DIAGNOSTICS v_deleted = ROW_COUNT;

    -- Supprimer les fenetres DAILY de plus de 2 jours
    DELETE FROM mg.rate_limit_counters
    WHERE window_type = 'DAILY'
      AND window_start < NOW() - INTERVAL '2 days';

    RETURN v_deleted;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION mg.cleanup_rate_limit_counters() IS
    'Nettoie les compteurs de fenetres expirees. '
    'Maintient la table petite et les performances stables. '
    'Appel recommande : toutes les heures ou via pipeline option [8].';

COMMIT;

-- Verification post-patch
SELECT 'mg.rate_limit_counters creee' AS statut, COUNT(*) AS lignes
FROM mg.rate_limit_counters;

-- =============================================================================
-- ROLLBACK
-- =============================================================================
-- BEGIN;
-- DROP TABLE IF EXISTS mg.rate_limit_counters CASCADE;
-- DROP FUNCTION IF EXISTS mg.cleanup_rate_limit_counters();
-- DROP INDEX IF EXISTS mg.idx_api_usage_ip_timestamp;
-- DROP INDEX IF EXISTS mg.idx_api_usage_identity_timestamp;
-- COMMIT;
