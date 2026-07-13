-- ============================================================
-- Table mg.password_reset_tokens
-- Session du 11 juillet 2026 -- gestion de profil et de mot de passe
-- ============================================================
-- Table dediee (plutot que reutiliser mg.email_confirmation_tokens) :
-- semantique distincte -- "confirmation d'identite initiale" et
-- "reinitialisation d'un mot de passe existant" ne doivent pas se
-- melanger dans un audit. Meme structure, expiration plus courte (2h,
-- geree cote application).
-- ============================================================
-- EXECUTION (sur chaque environnement -- osa_dev, osa_preprod, osa_db) :
--   docker exec -i osa-db psql -U postgres -d <base> \
--     < create_password_reset_tokens.sql
-- ============================================================

BEGIN;

CREATE TABLE IF NOT EXISTS mg.password_reset_tokens (
    id            integer PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    affiliate_id  integer NOT NULL REFERENCES mg.affiliates(id) ON DELETE CASCADE,
    token         uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    expires_at    timestamp NOT NULL,
    used_at       timestamp,
    created_at    timestamp NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_password_reset_affiliate ON mg.password_reset_tokens (affiliate_id);
CREATE INDEX IF NOT EXISTS idx_password_reset_token ON mg.password_reset_tokens (token);

COMMIT;

\d mg.password_reset_tokens
