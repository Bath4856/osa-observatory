-- ============================================================
-- mg.strategic_lever_proposals
-- 5 aout 2026
-- ============================================================
-- Correctif suite a l'echec reel : mg.strategic_levers est le
-- CATALOGUE PARTAGE existant (lever_code, Sprint "OIM Lot 1/2",
-- ADR004_strategic_chain_draft.md du 14 juillet) -- l'IA ne doit
-- JAMAIS y ecrire directement (vocabulaire partage, doit rester sous
-- controle humain). Cette nouvelle table stocke les PROPOSITIONS de
-- levier par vision (AI_DRAFTED -> HUMAN_VALIDATED -> PROMOTED) --
-- a la promotion, cree le lever_code dans le catalogue s'il n'existe
-- pas encore, puis lie l'analyse 5_POURQUOI promue via
-- mg.root_cause_levers.
--
-- A executer DEV -> PREPROD -> PROD.
-- ============================================================

BEGIN;

CREATE TABLE mg.strategic_lever_proposals (
    id                      integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    vision_id               integer NOT NULL REFERENCES mg.pillar_strategic_vision(id),
    source_analysis_id      integer NOT NULL REFERENCES osoa.strategic_analyses(id),
    proposed_lever_code     text,
    reuses_existing_code    boolean NOT NULL DEFAULT false,
    label_fr                text NOT NULL,
    label_en                text,
    description_fr          text NOT NULL,
    description_en          text,
    relevance_weight        numeric(4,2) NOT NULL DEFAULT 1.0,
    status                  character varying(20) NOT NULL DEFAULT 'AI_DRAFTED',
    created_by              integer REFERENCES mg.affiliates(id),
    created_at              timestamp without time zone NOT NULL DEFAULT now(),
    updated_at              timestamp without time zone NOT NULL DEFAULT now()
);

ALTER TABLE mg.strategic_lever_proposals
    ADD CONSTRAINT chk_lever_proposals_status CHECK (
        status IN ('AI_DRAFTED', 'HUMAN_VALIDATED', 'PROMOTED')
    );

ALTER TABLE mg.strategic_lever_proposals
    ADD CONSTRAINT chk_lever_proposals_weight CHECK (
        relevance_weight >= 0 AND relevance_weight <= 1
    );

CREATE INDEX idx_lever_proposals_vision ON mg.strategic_lever_proposals (vision_id);

COMMIT;

-- Verification post-execution
\d mg.strategic_lever_proposals
