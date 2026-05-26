-- ============================================================
-- OSA Observatory -- Sprint 14
-- Chaine de paiement -- Infrastructure affiliations
--
-- 1. rf.affiliations          -- abonnements S1/S2
-- 2. mg.api_key_registry      -- extension access_class + affiliation_id
-- 3. rf.v_active_affiliations -- vue operationnelle
-- 4. mg.v_api_key_status      -- vue controle acces
-- ============================================================

BEGIN;

-- ── 1. Table affiliations ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS rf.affiliations (
    affiliation_id      BIGSERIAL PRIMARY KEY,
    institution_name    TEXT        NOT NULL,
    country_iso3        CHAR(3),
    institution_type    TEXT        NOT NULL,  -- MINISTRY / CENTRAL_BANK / REGIONAL / UNIVERSITY / OTHER
    access_level        TEXT        NOT NULL,  -- STANDARD / PREMIUM
    contact_email       TEXT,
    status              TEXT        NOT NULL DEFAULT 'ACTIVE',  -- ACTIVE / SUSPENDED / EXPIRED
    subscription_start  DATE        NOT NULL,
    subscription_end    DATE,
    auto_renew          BOOLEAN     NOT NULL DEFAULT FALSE,
    notes               TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT affiliation_level_check
        CHECK (access_level IN ('STANDARD', 'PREMIUM')),
    CONSTRAINT affiliation_type_check
        CHECK (institution_type IN ('MINISTRY', 'CENTRAL_BANK', 'REGIONAL', 'UNIVERSITY', 'OTHER')),
    CONSTRAINT affiliation_status_check
        CHECK (status IN ('ACTIVE', 'SUSPENDED', 'EXPIRED'))
);

COMMENT ON TABLE rf.affiliations IS
'Sprint 14 -- Abonnements institutionnels OSA.
STANDARD = Couche 1 (scores + pentes + actions souveraines).
PREMIUM  = Couche 2 (simulations + IC P5-P95 + AMAR complet).
Source de revenus S1 et S2 du modele economique OSA.';

-- Index
CREATE INDEX IF NOT EXISTS idx_affiliations_country
    ON rf.affiliations (country_iso3);
CREATE INDEX IF NOT EXISTS idx_affiliations_status
    ON rf.affiliations (status);
CREATE INDEX IF NOT EXISTS idx_affiliations_level
    ON rf.affiliations (access_level);

-- ── 2. Extension mg.api_key_registry ─────────────────────────
-- Ajouter affiliation_id et rate_limit si absents
ALTER TABLE mg.api_key_registry
    ADD COLUMN IF NOT EXISTS affiliation_id BIGINT
        REFERENCES rf.affiliations(affiliation_id) ON DELETE SET NULL;

ALTER TABLE mg.api_key_registry
    ADD COLUMN IF NOT EXISTS rate_limit_per_hour INT NOT NULL DEFAULT 1000;

ALTER TABLE mg.api_key_registry
    ADD COLUMN IF NOT EXISTS requests_today INT NOT NULL DEFAULT 0;

ALTER TABLE mg.api_key_registry
    ADD COLUMN IF NOT EXISTS last_reset_date DATE DEFAULT CURRENT_DATE;

COMMENT ON TABLE mg.api_key_registry IS
'Sprint 14 -- Registre des cles API OSA.
access_class : STANDARD (Couche 1) | PREMIUM (Couche 2) | EXPERT (Couche 2+).
Validation SHA-256 -- jamais la cle en clair.
Rate limiting par heure selon access_class.';

-- ── 3. Vue affiliations actives ───────────────────────────────
CREATE OR REPLACE VIEW rf.v_active_affiliations AS
SELECT
    a.affiliation_id,
    a.institution_name,
    a.country_iso3,
    c.name_fr                                   AS country_name_fr,
    a.institution_type,
    a.access_level,
    a.contact_email,
    a.status,
    a.subscription_start,
    a.subscription_end,
    a.auto_renew,
    -- Jours restants
    CASE
        WHEN a.subscription_end IS NULL THEN NULL
        ELSE (a.subscription_end - CURRENT_DATE)
    END                                         AS days_remaining,
    -- Statut expiration
    CASE
        WHEN a.status != 'ACTIVE' THEN 'INACTIVE'
        WHEN a.subscription_end IS NULL THEN 'ACTIVE_PERPETUAL'
        WHEN a.subscription_end < CURRENT_DATE THEN 'EXPIRED'
        WHEN a.subscription_end < CURRENT_DATE + INTERVAL '30 days' THEN 'EXPIRING_SOON'
        ELSE 'ACTIVE'
    END                                         AS subscription_status,
    -- Nombre de cles actives
    COUNT(k.api_key_id) FILTER (WHERE k.is_active = TRUE) AS nb_active_keys,
    a.created_at,
    a.updated_at
FROM rf.affiliations a
LEFT JOIN rf.v_country_aliases c ON c.iso3 = a.country_iso3
LEFT JOIN mg.api_key_registry k ON k.affiliation_id = a.affiliation_id
GROUP BY a.affiliation_id, a.institution_name, a.country_iso3, c.name_fr,
         a.institution_type, a.access_level, a.contact_email, a.status,
         a.subscription_start, a.subscription_end, a.auto_renew,
         a.created_at, a.updated_at;

COMMENT ON VIEW rf.v_active_affiliations IS
'Sprint 14 -- Vue operationnelle des affiliations OSA.
Statut abonnement + jours restants + nb cles actives.';

-- ── 4. Vue controle acces API ─────────────────────────────────
CREATE OR REPLACE VIEW mg.v_api_key_status AS
SELECT
    k.api_key_id,
    k.api_key_hash,
    k.owner_label,
    k.access_class,
    k.is_active,
    k.expires_at,
    k.last_used_at,
    k.rate_limit_per_hour,
    k.requests_today,
    k.last_reset_date,
    k.affiliation_id,
    a.institution_name,
    a.institution_type,
    a.access_level                              AS affiliation_level,
    a.status                                    AS affiliation_status,
    a.subscription_end,
    -- Acces autorise si cle active + affiliation active + non expiree
    CASE
        WHEN k.is_active = FALSE                 THEN FALSE
        WHEN k.expires_at IS NOT NULL
         AND k.expires_at < NOW()                THEN FALSE
        WHEN a.affiliation_id IS NULL            THEN TRUE  -- cle standalone (legacy)
        WHEN a.status != 'ACTIVE'                THEN FALSE
        WHEN a.subscription_end IS NOT NULL
         AND a.subscription_end < CURRENT_DATE   THEN FALSE
        ELSE TRUE
    END                                         AS access_granted,
    -- Niveau acces effectif
    COALESCE(k.access_class, 'STANDARD')        AS effective_access_class
FROM mg.api_key_registry k
LEFT JOIN rf.affiliations a ON a.affiliation_id = k.affiliation_id;

COMMENT ON VIEW mg.v_api_key_status IS
'Sprint 14 -- Vue de controle acces API.
access_granted = TRUE si cle active + affiliation valide.
Utilisee par api/security.py pour la validation des tokens.';

-- ── 5. Rate limits par niveau ─────────────────────────────────
-- Inserer les valeurs de reference
CREATE TABLE IF NOT EXISTS rf.access_level_policy (
    access_level        TEXT PRIMARY KEY,
    rate_limit_per_hour INT  NOT NULL,
    max_keys_per_affiliation INT NOT NULL,
    description         TEXT
);

INSERT INTO rf.access_level_policy VALUES
    ('STANDARD', 500,  3, 'Affilie standard S1 -- Couche 1 -- scores + pentes + actions'),
    ('PREMIUM',  2000, 5, 'Affilie premium S2 -- Couche 2 -- simulations + IC + AMAR'),
    ('EXPERT',   5000, 10, 'Acces expert interne -- toutes couches -- usage OSA')
ON CONFLICT (access_level) DO NOTHING;

COMMENT ON TABLE rf.access_level_policy IS
'Sprint 14 -- Politique de rate limiting par niveau d acces.
STANDARD : 500 req/h -- PREMIUM : 2000 req/h -- EXPERT : 5000 req/h.';

COMMIT;
