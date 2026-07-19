-- ============================================================
-- ADR-003 / ADR-004 -- Bus de gouvernance evenementielle generique
-- Phase 1 -- schema generique, sans toucher a l'existant
-- 17 juillet 2026
-- ============================================================
-- Correctif au passage : le document source (ADR-004, Phase 2 du plan
-- de migration) affirme "les deux enregistrements de
-- rf.identity_event_types" -- verifie le 17 juillet 2026, il y en a
-- reellement CINQ (AFFILIATE_CONFIRMED, COMMITTEE_MEMBERSHIP_GRANTED,
-- PROFILE_UPDATED, STATUS_CHANGED, WORKING_GROUP_ACTIVATED). Les cinq
-- sont migres ici, pas seulement deux -- meme si Phase 1 (ce script)
-- ne fait que CREER le schema generique, la Phase 2 (migration des
-- donnees) est anticipee ici par souci de coherence, toujours sans
-- toucher a mg.identity_events ni au code applicatif (Phase 3).
--
-- mg.identity_events et identity_synchronizer.py restent seuls
-- operationnels apres ce script -- coexistence, rien de decommissionne.
-- ============================================================
-- EXECUTION :
--   docker exec -i osa-db psql -U postgres -d osa_dev \
--     < bus_generique_phase1_schema.sql
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1) rf.event_types -- referentiel generique, cle composite
--    (domain_code, code) au lieu d'une table par domaine.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rf.event_types (
    domain_code   text NOT NULL,
    code          text NOT NULL,
    label_fr      text NOT NULL,
    label_en      text NOT NULL,
    description   text,
    is_active     boolean NOT NULL DEFAULT true,
    PRIMARY KEY (domain_code, code)
);

COMMENT ON TABLE rf.event_types IS
    'Referentiel generique des types d''evenements de gouvernance -- ADR-003/004. Un domaine s''ajoute par simple enregistrement, jamais par modification de schema.';

-- Migration anticipee des 5 enregistrements reels IDENTITY (le
-- document source en mentionnait 2 par erreur -- corrige ici).
INSERT INTO rf.event_types (domain_code, code, label_fr, label_en, description, is_active) VALUES
    ('IDENTITY', 'AFFILIATE_CONFIRMED', 'Affilié confirmé', 'Affiliate confirmed', 'Email confirmé et mot de passe défini -- identité et authentification validées.', true),
    ('IDENTITY', 'COMMITTEE_MEMBERSHIP_GRANTED', 'Adhésion à un comité accordée', 'Committee membership granted', 'Cooptation approuvée, appartenance à un comité activée.', true),
    ('IDENTITY', 'PROFILE_UPDATED', 'Profil mis à jour', 'Profile updated', 'Fonction, organisation ou pays modifiés après KYC initial.', true),
    ('IDENTITY', 'STATUS_CHANGED', 'Statut modifié', 'Status changed', 'Changement de statut hors des cas ci-dessus (suspension, retrait...).', true),
    ('IDENTITY', 'WORKING_GROUP_ACTIVATED', 'Groupe de travail activé', 'Working group activated', 'Invitation à un groupe de travail par pilier acceptée (statut INVITED -> ACTIVE).', true)
ON CONFLICT (domain_code, code) DO NOTHING;

-- ------------------------------------------------------------
-- 2) mg.governance_events -- journal generique, structure stable
--    (domain_code / event_type / object_type / object_uuid / payload),
--    concue pour accueillir tout domaine futur sans modification de
--    schema ni d'API (ADR-004 principe 3).
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mg.governance_events (
    event_uuid          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    domain_code         text NOT NULL,
    event_type          text NOT NULL,
    object_type         text NOT NULL,
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
    FOREIGN KEY (domain_code, event_type) REFERENCES rf.event_types(domain_code, code),
    CHECK (source_environment <> target_environment)
);

CREATE INDEX IF NOT EXISTS idx_governance_events_object ON mg.governance_events (object_uuid);
CREATE INDEX IF NOT EXISTS idx_governance_events_status ON mg.governance_events (status) WHERE status = 'PENDING';
CREATE INDEX IF NOT EXISTS idx_governance_events_target ON mg.governance_events (target_environment, status);
CREATE INDEX IF NOT EXISTS idx_governance_events_domain ON mg.governance_events (domain_code);

COMMENT ON TABLE mg.governance_events IS
    'Journal generique de propagation entre environnements, pour tout domaine actuel ou futur -- ADR-003/004. IDENTITY est le premier domaine branche, pas la definition du mecanisme. mg.identity_events reste seul operationnel tant que la Phase 3 (adaptation du code applicatif) n''est pas executee.';

COMMIT;

-- Verification post-execution
SELECT domain_code, code FROM rf.event_types ORDER BY domain_code, code;
SELECT table_name FROM information_schema.tables WHERE table_schema = 'mg' AND table_name = 'governance_events';
