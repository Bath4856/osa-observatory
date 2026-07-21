-- ============================================================
-- osoa.quotes -- devis (proposition chiffree)
-- 21 juillet 2026
-- ============================================================
-- Positionnement dans le tunnel OSOA :
--   depot (document_deposits) -> etude (strategic_analyses,
--   method=FAISABILITE) -> DEVIS (osoa.quotes, cette table) ->
--   negociation -> accord -> contrat (osoa.contracts)
--
-- Le devis est une piece commerciale engageante (montant, statut)
-- -- table dediee plutot qu'un JSONB dans strategic_analyses.content,
-- pour beneficier de contraintes CHECK, d'un type numeric fiable pour
-- le montant, et de requetes directes par statut (cf. 5W1H du 21
-- juillet 2026 -- decision actee : Option B).
--
-- Rattache directement a opportunity_id (comme document_deposits et
-- strategic_analyses) -- pas via scenario/recommendation, le devis
-- intervient plus tot dans le tunnel, avant la decision strategique
-- formelle (osoa.scenarios).
--
-- N'affecte PAS osoa.clients.kyc_status -- ce passage PENDING->VERIFIED
-- reste reserve a la signature du contrat (decision du 20 juillet 2026,
-- ADR-010 / commit 0b7c772), pas a l'acceptation d'un devis.
--
-- A executer DEV -> PREPROD -> PROD, dans cet ordre.
-- ============================================================

BEGIN;

CREATE TABLE osoa.quotes (
    id                     integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    opportunity_id         integer NOT NULL REFERENCES osoa.opportunities(id),
    strategic_analysis_id  integer REFERENCES osoa.strategic_analyses(id),
    amount                 numeric(14,2) NOT NULL CHECK (amount >= 0),
    currency               character varying(3) NOT NULL CHECK (currency ~ '^[A-Z]{3}$'),
    status                 character varying(20) NOT NULL DEFAULT 'PROPOSED'
                               CHECK (status IN ('PROPOSED', 'ACCEPTED', 'REJECTED', 'EXPIRED', 'REVISED')),
    description_fr         text,
    valid_until            date,
    proposed_by            integer REFERENCES mg.affiliates(id),
    proposed_at            timestamp without time zone NOT NULL DEFAULT now(),
    responded_by           integer REFERENCES mg.affiliates(id),
    responded_at           timestamp without time zone
);

CREATE INDEX idx_osoa_quotes_opportunity ON osoa.quotes (opportunity_id);
CREATE INDEX idx_osoa_quotes_status ON osoa.quotes (status);

COMMIT;

-- Verification post-execution
\d osoa.quotes
