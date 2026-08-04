-- ============================================================
-- mg.pillar_analysis_drafts -- brouillons IA des analyses de vision
-- 4 aout 2026
-- ============================================================
-- Chantier prioritaire identifie par Theo : automatiser la generation
-- des 9 analyses primaires (5W1H, SWOT, ZACHMAN, RISQUE, ECONOMIQUE,
-- GOUVERNANCE, MULTICRITERE, FAISABILITE, 5_POURQUOI) par pays+pilier,
-- a partir des vraies donnees ISA/POA -- condition prealable a tout
-- lancement en masse (540 visions/an).
--
-- INTERDEPENDANCE (10eme methode) traitee DIFFEREMMENT sur demande de
-- Theo : jamais generee comme les 9 primaires (donnees brutes), mais
-- comme une SYNTHESE deduite du contenu des 9 autres une fois promues --
-- evite d'inventer une relation inter-pilier a partir de chiffres seuls.
--
-- Meme patron que mg.plan_action_projects : AI_DRAFTED -> HUMAN_VALIDATED
-- -> PROMOTED (devient une vraie ligne osoa.strategic_analyses).
--
-- A executer DEV -> PREPROD -> PROD.
-- ============================================================

BEGIN;

CREATE TABLE mg.pillar_analysis_drafts (
    id                      integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    vision_id               integer NOT NULL REFERENCES mg.pillar_strategic_vision(id),
    method                  character varying(30) NOT NULL,
    content                 jsonb NOT NULL,
    status                  character varying(20) NOT NULL DEFAULT 'AI_DRAFTED',
    promoted_analysis_id    integer REFERENCES osoa.strategic_analyses(id),
    created_by              integer REFERENCES mg.affiliates(id),
    created_at              timestamp without time zone NOT NULL DEFAULT now(),
    updated_at              timestamp without time zone NOT NULL DEFAULT now()
);

ALTER TABLE mg.pillar_analysis_drafts
    ADD CONSTRAINT chk_pillar_analysis_drafts_method CHECK (
        method IN ('5W1H', 'SWOT', '5_POURQUOI', 'RISQUE', 'FAISABILITE',
                   'MULTICRITERE', 'ECONOMIQUE', 'GOUVERNANCE', 'ZACHMAN',
                   'INTERDEPENDANCE')
    );

ALTER TABLE mg.pillar_analysis_drafts
    ADD CONSTRAINT chk_pillar_analysis_drafts_status CHECK (
        status IN ('AI_DRAFTED', 'HUMAN_VALIDATED', 'PROMOTED')
    );

CREATE INDEX idx_pillar_analysis_drafts_vision ON mg.pillar_analysis_drafts (vision_id);
CREATE INDEX idx_pillar_analysis_drafts_status ON mg.pillar_analysis_drafts (status);

COMMIT;

-- Verification post-execution
\d mg.pillar_analysis_drafts
