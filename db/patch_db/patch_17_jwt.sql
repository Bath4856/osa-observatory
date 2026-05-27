-- =============================================================================
-- OSA OBSERVATORY -- PATCH 17 -- AUTHENTIFICATION JWT
-- Sprint 17 -- 27 mai 2026
--
-- Structure réelle confirmée par diagnostic :
--   rf.affiliations      PK : affiliation_id (BIGINT)
--   mg.api_key_registry  PK : api_key_id (BIGINT), UNIQUE : api_key_hash
--                        affiliation_id nullable (clés EXPERT sans affiliation)
--   mg.v_api_key_status  effective_access_class = COALESCE(k.access_class, 'STANDARD')
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. mg.revoked_tokens — liste noire jti access tokens révoqués
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mg.revoked_tokens (
    id             BIGSERIAL    PRIMARY KEY,
    jti            UUID         NOT NULL UNIQUE,
    affiliation_id BIGINT       REFERENCES rf.affiliations(affiliation_id) ON DELETE CASCADE,
    token_type     TEXT         NOT NULL CHECK (token_type IN ('access', 'refresh')),
    revoked_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    expires_at     TIMESTAMPTZ  NOT NULL,
    revoked_by     TEXT         NOT NULL DEFAULT 'user',
    reason         TEXT
);

COMMENT ON TABLE mg.revoked_tokens IS
    'Liste noire JWT Sprint 17. Nettoyage : DELETE WHERE expires_at < NOW().';

CREATE INDEX IF NOT EXISTS idx_revoked_tokens_jti
    ON mg.revoked_tokens (jti);
CREATE INDEX IF NOT EXISTS idx_revoked_tokens_expires
    ON mg.revoked_tokens (expires_at);

-- ---------------------------------------------------------------------------
-- 2. mg.refresh_tokens — registre refresh tokens actifs
--    affiliation_id nullable : clés EXPERT internes sans affiliation
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mg.refresh_tokens (
    id             BIGSERIAL    PRIMARY KEY,
    jti            UUID         NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    affiliation_id BIGINT       REFERENCES rf.affiliations(affiliation_id) ON DELETE CASCADE,
    api_key_hash   TEXT         REFERENCES mg.api_key_registry(api_key_hash) ON DELETE SET NULL,
    token_hash     TEXT         NOT NULL UNIQUE,
    token_family   UUID         NOT NULL DEFAULT gen_random_uuid(),
    issued_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    expires_at     TIMESTAMPTZ  NOT NULL,
    last_used_at   TIMESTAMPTZ,
    is_revoked     BOOLEAN      NOT NULL DEFAULT FALSE,
    revoked_at     TIMESTAMPTZ,
    user_agent     TEXT,
    ip_address     TEXT
);

COMMENT ON TABLE mg.refresh_tokens IS
    'Registre des refresh tokens JWT Sprint 17. '
    'affiliation_id nullable : clés EXPERT internes sans affiliation. '
    'token_family : réutilisation d''un token révoqué → révocation de toute la famille.';

CREATE INDEX IF NOT EXISTS idx_refresh_tokens_jti
    ON mg.refresh_tokens (jti);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_hash
    ON mg.refresh_tokens (token_hash);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_affiliation
    ON mg.refresh_tokens (affiliation_id, is_revoked);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_family
    ON mg.refresh_tokens (token_family);

-- ---------------------------------------------------------------------------
-- 3. Colonne legacy_expires_at sur mg.api_key_registry
--    Période de grâce 90 jours pour les clés Sprint 14 (X-Api-Key)
-- ---------------------------------------------------------------------------
ALTER TABLE mg.api_key_registry
    ADD COLUMN IF NOT EXISTS legacy_expires_at TIMESTAMPTZ
        DEFAULT (NOW() + INTERVAL '90 days');

COMMENT ON COLUMN mg.api_key_registry.legacy_expires_at IS
    'Expiration de la compatibilité descendante Sprint 14 (X-Api-Key). '
    'Après cette date, seul le JWT Bearer est accepté par /auth/token.';

UPDATE mg.api_key_registry
SET legacy_expires_at = NOW() + INTERVAL '90 days'
WHERE legacy_expires_at IS NULL;

-- ---------------------------------------------------------------------------
-- 4. Vue utilitaire — refresh tokens actifs par affiliation
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW mg.v_active_refresh_tokens AS
SELECT
    rt.id,
    rt.jti,
    rt.affiliation_id,
    a.institution_name,
    a.country_iso3,
    rt.issued_at,
    rt.expires_at,
    rt.last_used_at,
    rt.ip_address,
    ROUND(EXTRACT(EPOCH FROM (rt.expires_at - NOW())) / 86400, 1) AS days_remaining
FROM mg.refresh_tokens rt
LEFT JOIN rf.affiliations a ON a.affiliation_id = rt.affiliation_id
WHERE rt.is_revoked = FALSE
  AND rt.expires_at > NOW();

COMMENT ON VIEW mg.v_active_refresh_tokens IS
    'Refresh tokens actifs et non expirés -- usage admin OSA uniquement.';

-- ---------------------------------------------------------------------------
-- 5. Fonction nettoyage périodique
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mg.cleanup_expired_tokens()
RETURNS TABLE(deleted_revoked BIGINT, deleted_refresh BIGINT) AS $$
DECLARE
    v_revoked BIGINT;
    v_refresh BIGINT;
BEGIN
    DELETE FROM mg.revoked_tokens WHERE expires_at < NOW();
    GET DIAGNOSTICS v_revoked = ROW_COUNT;

    DELETE FROM mg.refresh_tokens
    WHERE is_revoked = TRUE
      AND revoked_at < NOW() - INTERVAL '7 days';
    GET DIAGNOSTICS v_refresh = ROW_COUNT;

    RETURN QUERY SELECT v_revoked, v_refresh;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION mg.cleanup_expired_tokens() IS
    'Nettoyage des tokens expirés/révoqués. '
    'Appel recommandé : quotidien, intégrer à run_full_pipeline.ps1 option [8].';

COMMIT;

-- Vérification post-patch
SELECT 'mg.revoked_tokens'  AS table_name, COUNT(*) AS lignes FROM mg.revoked_tokens
UNION ALL
SELECT 'mg.refresh_tokens'  AS table_name, COUNT(*) FROM mg.refresh_tokens
UNION ALL
SELECT 'api_key_registry -- legacy_expires_at initialisé', COUNT(*)
    FROM mg.api_key_registry WHERE legacy_expires_at IS NOT NULL;

-- =============================================================================
-- ROLLBACK
-- =============================================================================
-- BEGIN;
-- DROP TABLE IF EXISTS mg.revoked_tokens CASCADE;
-- DROP TABLE IF EXISTS mg.refresh_tokens CASCADE;
-- DROP VIEW  IF EXISTS mg.v_active_refresh_tokens;
-- DROP FUNCTION IF EXISTS mg.cleanup_expired_tokens();
-- ALTER TABLE mg.api_key_registry DROP COLUMN IF EXISTS legacy_expires_at;
-- COMMIT;
