
BEGIN;

-- ============================================================
-- OSA Observatory -- D2.3 Registre des tickets pilote
-- Table mg.pilot_tickets
-- Sprint 19 post-runbook -- 3 juin 2026
-- ============================================================

CREATE TABLE mg.pilot_tickets (

    -- Identifiant
    ticket_id        BIGSERIAL PRIMARY KEY,
    ticket_ref       TEXT NOT NULL UNIQUE,  -- OSA-YYYY-NNNN

    -- Classification
    ticket_type      VARCHAR(40) NOT NULL
                     CHECK (ticket_type IN (
                         'QUESTION',
                         'CONTESTATION',
                         'DEMANDE_ACCES',
                         'DEMANDE_CORRECTION',
                         'SUGGESTION'
                     )),

    -- Priorité et statut
    priority         VARCHAR(20) NOT NULL DEFAULT 'NORMAL'
                     CHECK (priority IN ('URGENT','NORMAL','LOW')),
    status           VARCHAR(30) NOT NULL DEFAULT 'OUVERT'
                     CHECK (status IN (
                         'OUVERT',
                         'EN_TRAITEMENT',
                         'EN_ATTENTE_INFO',
                         'RESOLU',
                         'FERME',
                         'ESCALADE'
                     )),

    -- Soumettant
    affiliation_id   BIGINT REFERENCES rf.affiliations(affiliation_id) ON DELETE SET NULL,
    submitter_email  TEXT,
    submitter_name   TEXT,

    -- Périmètre ISA concerné
    country_iso3     VARCHAR(3),
    year_concerned   INTEGER,
    pillar_code      VARCHAR(10),
    indicator_code   VARCHAR(30),

    -- Contenu
    subject          TEXT NOT NULL,
    description      TEXT NOT NULL,
    evidence_url     TEXT,

    -- Lien POL-OSA-001 (pour CONTESTATION et DEMANDE_CORRECTION)
    pol_level        VARCHAR(5)   -- N1/N2/N3/N4
                     CHECK (pol_level IN ('N1','N2','N3','N4') OR pol_level IS NULL),
    pol_ref          TEXT,        -- Référence décision POL-OSA-001

    -- Lien publication concernée
    dataset_code     TEXT REFERENCES mg.publication_registry(dataset_code) ON DELETE SET NULL,

    -- Traitement
    assigned_to      TEXT,
    resolution_note  TEXT,
    resolved_at      TIMESTAMP,

    -- Timestamps
    created_at       TIMESTAMP NOT NULL DEFAULT now(),
    updated_at       TIMESTAMP NOT NULL DEFAULT now()
);

-- Index principaux
CREATE INDEX idx_pilot_tickets_type   ON mg.pilot_tickets (ticket_type, status);
CREATE INDEX idx_pilot_tickets_affil  ON mg.pilot_tickets (affiliation_id);
CREATE INDEX idx_pilot_tickets_scope  ON mg.pilot_tickets (country_iso3, pillar_code, year_concerned);
CREATE INDEX idx_pilot_tickets_date   ON mg.pilot_tickets (created_at DESC);

-- Trigger updated_at
CREATE OR REPLACE FUNCTION mg.set_ticket_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_pilot_tickets_updated_at
    BEFORE UPDATE ON mg.pilot_tickets
    FOR EACH ROW EXECUTE FUNCTION mg.set_ticket_updated_at();

-- Séquence ticket_ref : OSA-2026-0001
CREATE SEQUENCE IF NOT EXISTS mg.pilot_ticket_seq START 1;

-- Fonction génération ticket_ref
CREATE OR REPLACE FUNCTION mg.generate_ticket_ref()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.ticket_ref IS NULL OR NEW.ticket_ref = '' THEN
        NEW.ticket_ref := 'OSA-' || to_char(now(), 'YYYY') || '-'
                       || lpad(nextval('mg.pilot_ticket_seq')::text, 4, '0');
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_pilot_tickets_ref
    BEFORE INSERT ON mg.pilot_tickets
    FOR EACH ROW EXECUTE FUNCTION mg.generate_ticket_ref();

COMMENT ON TABLE mg.pilot_tickets IS
    'Registre des tickets pilote OSA Observatory. '
    '5 types : QUESTION / CONTESTATION / DEMANDE_ACCES / DEMANDE_CORRECTION / SUGGESTION. '
    'Les CONTESTATION et DEMANDE_CORRECTION declenchent POL-OSA-001. '
    'Référence D2.3 -- Sprint 19 post-runbook -- 3 juin 2026.';

COMMIT;
