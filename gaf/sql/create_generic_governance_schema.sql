-- ============================================================
-- ADR-003 -- Phase 1/6 : Création du schéma générique
-- Moteur de gouvernance événementielle multi-domaines
-- 14 juillet 2026
-- ============================================================
-- Cf. finding GAF ADR003_GENERIC_GOVERNANCE_ENGINE (#38) pour la
-- doctrine complète. Ce script est additif uniquement -- il ne
-- touche pas à mg.identity_events ni rf.identity_event_types,
-- conformément à la décision de migration progressive (ADR-003 §
-- "Plan de migration").
--
-- Portée : osa_preprod UNIQUEMENT à ce stade (décision du 14 juillet
-- 2026 : "on développe tout sur PREPROD et on synchronise"). Ne pas
-- exécuter sur osa_db ni osa_dev avant validation complète.
-- ============================================================
-- EXECUTION :
--   docker exec -i osa-db psql -U postgres -d osa_preprod \
--     < create_generic_governance_schema.sql
-- ============================================================

BEGIN;

-- ---------------------------------------------------------------
-- 1) Référentiel générique des types d'événements, par domaine.
--    Clé composite (domain_code, code) -- deux domaines peuvent
--    réutiliser le même code sans collision (ex. STATUS_CHANGED
--    pourrait exister pour IDENTITY et pour un futur domaine PROJECT
--    sans ambiguïté).
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rf.event_types (
    domain_code    varchar(30) NOT NULL,
    code           varchar(40) NOT NULL,
    label_fr       text NOT NULL,
    label_en       text NOT NULL,
    description    text,
    is_active      boolean NOT NULL DEFAULT true,
    PRIMARY KEY (domain_code, code)
);

COMMENT ON TABLE rf.event_types IS
    'Référentiel générique des types d''événements de gouvernance, '
    'ADR-003 -- remplace à terme rf.identity_event_types (conservée '
    'intacte pendant la période de transition). Un type est propre à '
    'un domaine (domain_code, code).';

-- Migration des 5 types déjà actés pour le domaine IDENTITY
-- (reprise à l'identique depuis rf.identity_event_types, ADR-001).
INSERT INTO rf.event_types (domain_code, code, label_fr, label_en, description) VALUES
    ('IDENTITY', 'AFFILIATE_CONFIRMED', 'Affilié confirmé', 'Affiliate confirmed',
     'Email confirmé et mot de passe défini -- identité et authentification validées.'),
    ('IDENTITY', 'COMMITTEE_MEMBERSHIP_GRANTED', 'Adhésion à un comité accordée', 'Committee membership granted',
     'Cooptation approuvée, appartenance à un comité activée.'),
    ('IDENTITY', 'WORKING_GROUP_ACTIVATED', 'Groupe de travail activé', 'Working group activated',
     'Invitation à un groupe de travail par pilier acceptée (statut INVITED -> ACTIVE).'),
    ('IDENTITY', 'PROFILE_UPDATED', 'Profil mis à jour', 'Profile updated',
     'Fonction, organisation ou pays modifiés après KYC initial.'),
    ('IDENTITY', 'STATUS_CHANGED', 'Statut modifié', 'Status changed',
     'Changement de statut hors des cas ci-dessus (suspension, retrait...).')
ON CONFLICT (domain_code, code) DO NOTHING;

-- ---------------------------------------------------------------
-- 2) Journal générique des événements de gouvernance.
--    object_type + object_uuid remplacent affiliate_uuid --
--    généralise la cible de l'événement à n'importe quel objet
--    métier, pas seulement un affilié. Aucune contrainte FK vers une
--    table métier spécifique : l'intégrité référentielle de
--    object_uuid est portée par le code applicatif de chaque domaine,
--    pas par la base (un objet peut résider dans des tables
--    différentes selon le domaine).
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mg.governance_events (
    event_uuid          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    domain_code         varchar(30) NOT NULL,
    event_type          varchar(40) NOT NULL,
    object_type         varchar(40) NOT NULL,
    object_uuid         uuid NOT NULL,
    source_environment  varchar(10) NOT NULL CHECK (source_environment IN ('DEV', 'PREPROD', 'PROD')),
    target_environment  varchar(10) NOT NULL CHECK (target_environment IN ('DEV', 'PREPROD', 'PROD')),
    payload             jsonb NOT NULL,
    payload_hash        text NOT NULL,
    created_at          timestamp NOT NULL DEFAULT now(),
    validated_at        timestamp,
    propagated_at       timestamp,
    propagated_by       varchar(60),
    status              varchar(20) NOT NULL DEFAULT 'PENDING'
                         CHECK (status IN ('PENDING', 'PROPAGATED', 'FAILED')),
    error_detail        text,
    CHECK (source_environment <> target_environment),
    FOREIGN KEY (domain_code, event_type) REFERENCES rf.event_types(domain_code, code)
);

COMMENT ON TABLE mg.governance_events IS
    'Journal générique des événements de gouvernance multi-domaines, '
    'ADR-003 -- remplace à terme mg.identity_events (conservée intacte '
    'pendant la période de transition). object_type/object_uuid '
    'généralisent affiliate_uuid : pas de FK vers une table métier '
    'précise, intégrité portée par l''application selon le domaine.';

COMMENT ON COLUMN mg.governance_events.object_uuid IS
    'Identifiant générique de l''objet concerné. Pour domain_code=IDENTITY, '
    'reprend exactement la valeur de mg.affiliates.identity_uuid.';

CREATE INDEX IF NOT EXISTS idx_governance_events_object ON mg.governance_events (object_uuid);
CREATE INDEX IF NOT EXISTS idx_governance_events_status ON mg.governance_events (status) WHERE status = 'PENDING';
CREATE INDEX IF NOT EXISTS idx_governance_events_target ON mg.governance_events (target_environment, status);
CREATE INDEX IF NOT EXISTS idx_governance_events_domain ON mg.governance_events (domain_code);

COMMIT;

-- Vérification post-exécution
SELECT domain_code, code, label_fr FROM rf.event_types ORDER BY domain_code, code;
\d mg.governance_events
