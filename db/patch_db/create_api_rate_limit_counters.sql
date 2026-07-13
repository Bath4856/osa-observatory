-- =============================================================================
-- OSA OBSERVATORY -- Correction collision de nom -- mg.api_rate_limit_counters
-- 13 juillet 2026
--
-- Contexte : mg.rate_limit_counters a ete creee une premiere fois par le
-- Sprint 17 (patch_17c_rl.sql, 27 mai 2026) pour le middleware global
-- (api/middleware/rate_limiter.py -- paliers PUBLIC/STANDARD/PREMIUM/EXPERT,
-- cf. Livre blanc Go-to-Market, section 3 "Niveau 2 -- Donnees enrichies").
-- Schema d'origine : identifier / window_type / counter / access_class.
--
-- Plus tard (Sprint 30, gestion des affilies), une table portant le MEME NOM
-- mg.rate_limit_counters a ete creee avec un schema different : key_type /
-- key_value / endpoint / count (utilisee par check_rate_limit() dans
-- api/routers/affiliation.py, restreinte a 2 endpoints : /auth/login et
-- /affiliation/request, cf. mg.rate_limit_policies).
--
-- Consequence : depuis que la seconde a remplace la premiere, le middleware
-- global echoue silencieusement sur CHAQUE requete (fail-open, cf. log
-- "Rate limit check failed (fail open)"). Aucune limite PUBLIC/STANDARD/
-- PREMIUM/EXPERT n'est donc plus appliquee en pratique sur l'ensemble de
-- l'API depuis un moment indetermine.
--
-- Correction : le middleware global recoit sa propre table, sous un nom qui
-- ne collisionne plus. mg.rate_limit_counters (schema affiliation.py) n'est
-- pas touchee. Verifie exhaustif au 13/07/2026 : seuls 3 fichiers
-- referencent "rate_limit_counters" dans tout le depot (rate_limiter.py,
-- affiliation.py, patch_17c_rl.sql) -- aucune autre dependance.
--
-- EXECUTION -- sur les trois environnements (osa_db, osa_preprod, osa_dev),
-- le middleware global n'etant pas exclu de DEV contrairement au mecanisme
-- de synchronisation d'identite (ADR-001) :
--   docker exec -i osa-db psql -U postgres -d <base> \
--     < create_api_rate_limit_counters.sql
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. mg.api_rate_limit_counters -- reprise exacte du schema Sprint 17,
--    sous un nom dedie au middleware global.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mg.api_rate_limit_counters (
    id           BIGSERIAL    PRIMARY KEY,
    identifier   TEXT         NOT NULL,
    window_type  TEXT         NOT NULL CHECK (window_type IN ('HOURLY', 'DAILY')),
    window_start TIMESTAMPTZ  NOT NULL,
    counter      INTEGER      NOT NULL DEFAULT 1,
    access_class TEXT         NOT NULL DEFAULT 'PUBLIC',
    updated_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (identifier, window_type, window_start)
);

COMMENT ON TABLE mg.api_rate_limit_counters IS
    'Compteurs de rate limiting du middleware global (api/middleware/rate_limiter.py). '
    'Renommee le 13/07/2026 -- anciennement mg.rate_limit_counters, en collision '
    'avec la table homonyme de check_rate_limit() (api/routers/affiliation.py, '
    'schema different : key_type/key_value/endpoint/count). '
    'Une ligne par identifiant actif par fenetre. Latence cible < 2ms.';

COMMENT ON COLUMN mg.api_rate_limit_counters.identifier IS
    'affiliation_id (JWT STANDARD/PREMIUM) ou adresse IP (PUBLIC/OTP). '
    'Format : "aff:1" pour affiliation_id=1, "ip:127.0.0.1" pour IP.';

COMMENT ON COLUMN mg.api_rate_limit_counters.window_type IS
    'HOURLY : fenetre glissante 1h (PUBLIC, OTP). '
    'DAILY  : fenetre fixe journaliere minuit UTC (STANDARD, PREMIUM).';

COMMENT ON COLUMN mg.api_rate_limit_counters.window_start IS
    'HOURLY : DATE_TRUNC(''hour'', NOW()). '
    'DAILY  : DATE_TRUNC(''day'', NOW() AT TIME ZONE ''UTC'').';

-- Index principal : lookup par identifiant + fenetre
CREATE UNIQUE INDEX IF NOT EXISTS idx_api_rl_counters_lookup
    ON mg.api_rate_limit_counters (identifier, window_type, window_start);

-- Index nettoyage : supprimer les fenetres expirees
CREATE INDEX IF NOT EXISTS idx_api_rl_counters_window_start
    ON mg.api_rate_limit_counters (window_start);

-- ---------------------------------------------------------------------------
-- 2. Fonction de nettoyage -- renommee pour correspondre a la nouvelle table.
--    Appel recommande : quotidien via run_full_pipeline.ps1 option [8].
--    L'ancienne fonction mg.cleanup_rate_limit_counters() (Sprint 17) est
--    laissee en place si elle existe -- elle referencait deja la table sous
--    son ancien nom et n'a probablement jamais fonctionne non plus depuis la
--    collision ; suppression differee, hors perimetre de cette correction.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mg.cleanup_api_rate_limit_counters()
RETURNS BIGINT AS $$
DECLARE
    v_deleted BIGINT;
BEGIN
    DELETE FROM mg.api_rate_limit_counters
    WHERE window_type = 'HOURLY'
      AND window_start < NOW() - INTERVAL '2 hours';
    GET DIAGNOSTICS v_deleted = ROW_COUNT;

    DELETE FROM mg.api_rate_limit_counters
    WHERE window_type = 'DAILY'
      AND window_start < NOW() - INTERVAL '2 days';

    RETURN v_deleted;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION mg.cleanup_api_rate_limit_counters() IS
    'Nettoie les compteurs de fenetres expirees du middleware global. '
    'Remplace mg.cleanup_rate_limit_counters() (Sprint 17, table renommee '
    'le 13/07/2026). Appel recommande : toutes les heures ou via pipeline option [8].';

COMMIT;

-- Verification post-execution
SELECT 'mg.api_rate_limit_counters creee' AS statut, COUNT(*) AS lignes
FROM mg.api_rate_limit_counters;

-- =============================================================================
-- ROLLBACK
-- =============================================================================
-- BEGIN;
-- DROP TABLE IF EXISTS mg.api_rate_limit_counters CASCADE;
-- DROP FUNCTION IF EXISTS mg.cleanup_api_rate_limit_counters();
-- COMMIT;
