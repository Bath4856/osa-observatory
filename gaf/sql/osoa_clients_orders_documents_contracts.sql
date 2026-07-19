-- ============================================================
-- OSOA -- Identite client externe, commande (livrable GTM choisi),
-- depot documentaire, contrat
-- 17 juillet 2026
-- ============================================================
-- Decisions actees dans la conversation du 17 juillet 2026 :
-- - Le demandeur de service est un tiers payant, jamais un affilie --
--   identite et KYC propres, distincts de mg.affiliates (pas de
--   comite, pas de groupe de travail).
-- - Pas un paiement ponctuel type e-commerce : une negociation
--   contractuelle. KYC prealable a tout ; depot documentaire non
--   bloque par un paiement (il n'y en a pas) mais par l'identite
--   verifiee ; le contrat formalise l'accord des deux parties ; la
--   livraison est le produit intellectuel du travail d'analyse OSOA
--   lui-meme (etude, POC... deja catalogue dans gtm.deliverables).
-- - assigned_to (Comite Technique ou coordinateur) reference
--   directement mg.affiliates -- COORDINATOR existe deja dans
--   mg.group_roles, aucun nouveau role invente. Regle metier
--   documentee, non verrouillee par contrainte technique (a l'image
--   d'autres regles similaires deja actees ce soir).
-- A executer sur DEV en premier.
-- ============================================================
-- EXECUTION :
--   docker exec -i osa-db psql -U postgres -d osa_dev \
--     < osoa_clients_orders_documents_contracts.sql
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1) osoa.clients -- identite du demandeur de service, KYC propre,
--    jamais un affilie.
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS osoa.clients (
    id                  serial PRIMARY KEY,
    organization_name   text NOT NULL,
    contact_name        text NOT NULL,
    contact_email       text NOT NULL UNIQUE,
    country_iso3        varchar(3),
    kyc_status          varchar(20) NOT NULL DEFAULT 'PENDING'
                        CHECK (kyc_status IN ('PENDING', 'VERIFIED', 'REJECTED')),
    kyc_verified_by     integer REFERENCES mg.affiliates(id),
    kyc_verified_at     timestamp,
    created_at          timestamp NOT NULL DEFAULT now()
);

COMMENT ON TABLE osoa.clients IS
    'Identite du demandeur de service (tiers payant, negociation contractuelle) -- KYC propre, distinct de mg.affiliates. Jamais de comite, jamais de groupe de travail pour cette identite.';

-- ------------------------------------------------------------
-- 2) osoa.opportunities -- extension pour le chemin externe complet :
--    client, livrable GTM choisi, responsable assigne.
-- ------------------------------------------------------------

ALTER TABLE osoa.opportunities
    ADD COLUMN IF NOT EXISTS client_id integer REFERENCES osoa.clients(id),
    ADD COLUMN IF NOT EXISTS deliverable_id integer REFERENCES gtm.deliverables(id),
    ADD COLUMN IF NOT EXISTS assigned_to integer REFERENCES mg.affiliates(id);

ALTER TABLE osoa.opportunities
    DROP CONSTRAINT opportunities_check;

ALTER TABLE osoa.opportunities
    ADD CONSTRAINT chk_osoa_opportunities_origin
    CHECK (
        (origin_type = 'INTERNAL' AND origin_project_family_id IS NOT NULL AND client_id IS NULL AND deliverable_id IS NULL)
        OR (origin_type = 'EXTERNAL' AND origin_project_family_id IS NULL AND client_id IS NOT NULL AND deliverable_id IS NOT NULL)
    );

COMMENT ON COLUMN osoa.opportunities.assigned_to IS
    'Responsable de la conduite du dossier -- attendu : membre du Comite Technique (mg.committee_memberships, committee=COMITE_TECH) ou coordinateur (mg.working_group_members, role_in_group=COORDINATOR). Non verrouille par contrainte technique.';

-- ------------------------------------------------------------
-- 3) osoa.document_deposits -- Phase 2, depot documentaire avec
--    controle d'acces (client proprietaire, ou personnel OSA).
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS osoa.document_deposits (
    id                          serial PRIMARY KEY,
    opportunity_id              integer NOT NULL REFERENCES osoa.opportunities(id),
    deposited_by_client_id      integer REFERENCES osoa.clients(id),
    deposited_by_affiliate_id   integer REFERENCES mg.affiliates(id),
    document_type               varchar(30) NOT NULL
                                CHECK (document_type IN ('REFERENCE', 'INSTITUTIONNEL', 'FINANCIER', 'TECHNIQUE', 'JURIDIQUE', 'SCIENTIFIQUE')),
    title                       text NOT NULL,
    file_reference               text NOT NULL,
    deposited_at                 timestamp NOT NULL DEFAULT now(),
    CHECK (
        (deposited_by_client_id IS NOT NULL AND deposited_by_affiliate_id IS NULL)
        OR (deposited_by_client_id IS NULL AND deposited_by_affiliate_id IS NOT NULL)
    )
);

CREATE INDEX IF NOT EXISTS idx_osoa_documents_opportunity ON osoa.document_deposits (opportunity_id);

COMMENT ON TABLE osoa.document_deposits IS
    'Depot documentaire Phase 2 -- file_reference pointe vers un stockage externe (jamais de blob en base). Deposant = client externe OU personnel OSA, jamais les deux, jamais aucun.';

-- ------------------------------------------------------------
-- 4) osoa.contracts -- formalise l'accord des deux parties -- pas un
--    paiement, un contrat sur le perimetre et les conditions.
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS osoa.contracts (
    id                  serial PRIMARY KEY,
    opportunity_id      integer NOT NULL REFERENCES osoa.opportunities(id),
    recommendation_id   integer REFERENCES osoa.recommendations(id),
    scope_fr            text NOT NULL,
    conditions_fr        text,
    status               varchar(20) NOT NULL DEFAULT 'DRAFT'
                         CHECK (status IN ('DRAFT', 'UNDER_NEGOTIATION', 'AGREED', 'DELIVERED', 'CANCELLED')),
    agreed_at            timestamp,
    delivered_at         timestamp,
    created_at           timestamp NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_osoa_contracts_opportunity ON osoa.contracts (opportunity_id);

COMMIT;

-- Verification post-execution
SELECT table_name FROM information_schema.tables
    WHERE table_schema = 'osoa' AND table_name IN ('clients', 'document_deposits', 'contracts')
    ORDER BY table_name;
SELECT column_name FROM information_schema.columns
    WHERE table_schema = 'osoa' AND table_name = 'opportunities' AND column_name IN ('client_id', 'deliverable_id', 'assigned_to');
