-- ============================================================
-- Sous-chantier B -- Propagation contrôlée entre environnements
-- ADR-001 : clé stable + journal d'événements d'identité
-- 12 juillet 2026
-- ============================================================
-- Cf. finding GAF ADR001_EVENT_DRIVEN_IDENTITY_SYNC pour la doctrine
-- complète. Livre le socle de données uniquement -- le service de
-- synchronisation ("OSA Identity Synchronizer") reste à construire
-- séparément, une fois le mécanisme push/scrutation tranché.
-- ============================================================
-- EXECUTION -- sur chaque environnement concerné (osa_db en premier,
-- puis osa_preprod ; osa_dev exclu du mécanisme par decision ADR-001) :
--   docker exec -i osa-db psql -U postgres -d <base> \
--     < sub_b_identity_uuid_and_events.sql
-- ============================================================

BEGIN;

-- 1) Cle stable inter-environnements -- complement de la contrainte
--    unique existante sur l'email (qui peut changer), jamais l'email
--    seul comme cle de correspondance a terme.
ALTER TABLE mg.affiliates
    ADD COLUMN IF NOT EXISTS identity_uuid uuid NOT NULL DEFAULT gen_random_uuid();

ALTER TABLE mg.affiliates
    ADD CONSTRAINT affiliates_identity_uuid_key UNIQUE (identity_uuid);

-- 2) Referentiel des types d'evenement -- extensible sans modifier de
--    contrainte CHECK a chaque nouveau type (doctrine "tout en base").
CREATE TABLE IF NOT EXISTS rf.identity_event_types (
    code           varchar(40) PRIMARY KEY,
    label_fr       text NOT NULL,
    label_en       text NOT NULL,
    description    text,
    is_active      boolean NOT NULL DEFAULT true
);

INSERT INTO rf.identity_event_types (code, label_fr, label_en, description) VALUES
    ('AFFILIATE_CONFIRMED', 'Affilié confirmé', 'Affiliate confirmed',
     'Email confirmé et mot de passe défini -- identité et authentification validées.'),
    ('COMMITTEE_MEMBERSHIP_GRANTED', 'Adhésion à un comité accordée', 'Committee membership granted',
     'Cooptation approuvée, appartenance à un comité activée.'),
    ('WORKING_GROUP_ACTIVATED', 'Groupe de travail activé', 'Working group activated',
     'Invitation à un groupe de travail par pilier acceptée (statut INVITED -> ACTIVE).'),
    ('PROFILE_UPDATED', 'Profil mis à jour', 'Profile updated',
     'Fonction, organisation ou pays modifiés après KYC initial.'),
    ('STATUS_CHANGED', 'Statut modifié', 'Status changed',
     'Changement de statut hors des cas ci-dessus (suspension, retrait...).')
ON CONFLICT (code) DO NOTHING;

-- 3) Journal d'evenements -- registre de reference des synchronisations.
--    payload/hash ajoutes a la specification ADR-001 d'origine : un
--    evenement doit rester fidele a l'etat au moment de sa validation,
--    independamment de l'etat courant de la source au moment du
--    traitement par le synchroniseur.
CREATE TABLE IF NOT EXISTS mg.identity_events (
    event_uuid          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type          varchar(40) NOT NULL REFERENCES rf.identity_event_types(code),
    affiliate_uuid       uuid NOT NULL REFERENCES mg.affiliates(identity_uuid),
    source_environment  varchar(10) NOT NULL CHECK (source_environment IN ('DEV', 'PREPROD', 'PROD')),
    target_environment  varchar(10) NOT NULL CHECK (target_environment IN ('DEV', 'PREPROD', 'PROD')),
    payload             jsonb NOT NULL,
    payload_hash        text NOT NULL,
    created_at           timestamp NOT NULL DEFAULT now(),
    validated_at         timestamp,
    propagated_at        timestamp,
    propagated_by        varchar(60),
    status               varchar(20) NOT NULL DEFAULT 'PENDING'
                          CHECK (status IN ('PENDING', 'PROPAGATED', 'FAILED')),
    error_detail         text,
    CHECK (source_environment <> target_environment)
);

CREATE INDEX IF NOT EXISTS idx_identity_events_affiliate ON mg.identity_events (affiliate_uuid);
CREATE INDEX IF NOT EXISTS idx_identity_events_status ON mg.identity_events (status) WHERE status = 'PENDING';
CREATE INDEX IF NOT EXISTS idx_identity_events_target ON mg.identity_events (target_environment, status);

COMMIT;

-- Verification post-execution
SELECT column_name, data_type, is_nullable FROM information_schema.columns
    WHERE table_schema = 'mg' AND table_name = 'affiliates' AND column_name = 'identity_uuid';
SELECT code, label_fr FROM rf.identity_event_types ORDER BY code;
\d mg.identity_events
