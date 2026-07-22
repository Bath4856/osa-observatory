-- ============================================================
-- osoa.strategic_deliverables -- livrables synthetiques
-- 22 juillet 2026
-- ============================================================
-- Un livrable synthetise plusieurs osoa.strategic_analyses d'une
-- meme opportunite en un document coherent, monnayable (ce que
-- Theo appelle "etude d'opportunite et/ou de faisabilite").
-- Snapshot fige au moment de la generation -- ne se recalcule
-- jamais automatiquement si une analyse source est modifiee apres
-- coup (source_analysis_ids trace la provenance pour audit, mais
-- content est la version figee servie au client).
--
-- Seuls ETUDE_OPPORTUNITE et ETUDE_FAISABILITE construits ce soir
-- (les deux mentionnes comme "monnayables" par Theo) -- SCHEMA_
-- DIRECTEUR et PLAN_ACTION notes pour une session future, pas
-- inclus dans la contrainte CHECK pour ne pas promettre une
-- fonctionnalite non implementee.
--
-- A executer DEV -> PREPROD -> PROD.
-- ============================================================

BEGIN;

CREATE TABLE osoa.strategic_deliverables (
    id                   integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    opportunity_id       integer NOT NULL REFERENCES osoa.opportunities(id),
    deliverable_type     character varying(30) NOT NULL
                             CHECK (deliverable_type IN ('ETUDE_OPPORTUNITE', 'ETUDE_FAISABILITE')),
    content              jsonb NOT NULL,
    source_analysis_ids  integer[] NOT NULL,
    generated_by         integer REFERENCES mg.affiliates(id),
    generated_at         timestamp without time zone NOT NULL DEFAULT now()
);

CREATE INDEX idx_osoa_deliverables_opportunity ON osoa.strategic_deliverables (opportunity_id);
CREATE INDEX idx_osoa_deliverables_type ON osoa.strategic_deliverables (deliverable_type);

-- Lien depuis le devis -- coexiste avec strategic_analysis_id (deja
-- present depuis hier soir), ne le remplace pas. Un devis peut
-- justifier son prix soit par une analyse isolee, soit par un
-- livrable synthetique complet.
ALTER TABLE osoa.quotes
    ADD COLUMN strategic_deliverable_id integer REFERENCES osoa.strategic_deliverables(id);

COMMIT;

-- Verification post-execution
\d osoa.strategic_deliverables
\d osoa.quotes
