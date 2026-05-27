-- =============================================================================
-- OSA OBSERVATORY -- PATCH 17B -- OTP (ONE-TIME PASSWORD)
-- Sprint 17 -- 27 mai 2026
--
-- Dépend de : patch_17_jwt.sql (mg.api_key_registry.legacy_expires_at)
-- =============================================================================

BEGIN;

-- Drop de l'ancienne version (signature différente)
DROP FUNCTION IF EXISTS mg.cleanup_expired_tokens();

-- ---------------------------------------------------------------------------
-- mg.otp_codes
--    Un seul code actif par api_key_hash à tout moment.
--    L'insertion d'un nouveau code invalide le précédent (used_at = NOW()).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mg.otp_codes (
    id             BIGSERIAL    PRIMARY KEY,
    api_key_hash   TEXT         NOT NULL REFERENCES mg.api_key_registry(api_key_hash) ON DELETE CASCADE,
    code_hash      TEXT         NOT NULL,
    expires_at     TIMESTAMPTZ  NOT NULL,
    used_at        TIMESTAMPTZ,
    attempt_count  INTEGER      NOT NULL DEFAULT 0,
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE mg.otp_codes IS
    'Codes OTP à usage unique pour la double authentification JWT. '
    'Un seul code actif par clé API. Durée : 10 min. Max 3 tentatives. '
    'Jamais stocké en clair -- SHA-256 uniquement.';

COMMENT ON COLUMN mg.otp_codes.code_hash IS
    'SHA-256 du code à 6 chiffres. Le code brut n''est jamais stocké.';

COMMENT ON COLUMN mg.otp_codes.attempt_count IS
    'Nombre de tentatives échouées. Invalidation automatique à OSA_OTP_MAX_ATTEMPTS (défaut 3).';

CREATE INDEX IF NOT EXISTS idx_otp_codes_api_key_hash
    ON mg.otp_codes (api_key_hash);

CREATE INDEX IF NOT EXISTS idx_otp_codes_expires_at
    ON mg.otp_codes (expires_at);

-- ---------------------------------------------------------------------------
-- Fonction nettoyage -- à intégrer dans mg.cleanup_expired_tokens()
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mg.cleanup_expired_tokens()
RETURNS TABLE(deleted_revoked BIGINT, deleted_refresh BIGINT, deleted_otp BIGINT) AS $$
DECLARE
    v_revoked BIGINT;
    v_refresh BIGINT;
    v_otp     BIGINT;
BEGIN
    DELETE FROM mg.revoked_tokens WHERE expires_at < NOW();
    GET DIAGNOSTICS v_revoked = ROW_COUNT;

    DELETE FROM mg.refresh_tokens
    WHERE is_revoked = TRUE
      AND revoked_at < NOW() - INTERVAL '7 days';
    GET DIAGNOSTICS v_refresh = ROW_COUNT;

    -- OTP expirés ou utilisés depuis plus d'1 heure
    DELETE FROM mg.otp_codes
    WHERE expires_at < NOW()
       OR used_at < NOW() - INTERVAL '1 hour';
    GET DIAGNOSTICS v_otp = ROW_COUNT;

    RETURN QUERY SELECT v_revoked, v_refresh, v_otp;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION mg.cleanup_expired_tokens() IS
    'Nettoyage des tokens expirés/révoqués et des OTP expirés. '
    'Appel recommandé : quotidien via run_full_pipeline.ps1 option [8].';

COMMIT;

-- Vérification post-patch
SELECT 'mg.otp_codes créée' AS statut, COUNT(*) AS lignes FROM mg.otp_codes;

-- =============================================================================
-- ROLLBACK
-- =============================================================================
-- BEGIN;
-- DROP TABLE IF EXISTS mg.otp_codes CASCADE;
-- COMMIT;
-- (recréer mg.cleanup_expired_tokens sans le bloc OTP si nécessaire)
