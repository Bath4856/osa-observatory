-- ============================================================
-- mg.plan_action_projects -- actions proposees d'un PLAN_ACTION
-- 28 juillet 2026 (nouvelle session, suite directe du week-end)
-- ============================================================
-- "L'explosion" d'un PLAN_ACTION en vrais projets nommes -- exemple
-- de Theo : PMIN fuite de minerais (POA) -> plan d'actions -> actions
-- concretes : "Systeme numerique de tracabilite", "Systeme de
-- certification", "Fonds souverain tokenise". Chaque action DEVIENT
-- un projet reel dans rf.sovereign_project_catalog, jamais construit
-- a la main comme les 18 legacy (doctrinal_status='LEGACY_MANUAL',
-- session precedente).
--
-- Meme patron que le resume executif Vision (nuit precedente) : IA
-- propose une liste d'actions nommees a partir du contenu JSON du
-- PLAN_ACTION, un humain valide/corrige AVANT toute promotion en
-- catalogue reel -- jamais de promotion automatique sans validation.
--
-- 3 etats : AI_DRAFTED (proposition brute) -> HUMAN_VALIDATED (relu,
-- eventuellement corrige) -> PROMOTED (devenu une vraie ligne
-- rf.sovereign_project_catalog, promoted_project_code renseigne).
--
-- A executer DEV -> PREPROD -> PROD.
-- ============================================================

BEGIN;

CREATE TABLE mg.plan_action_projects (
    id                      integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    deliverable_id          integer NOT NULL REFERENCES osoa.strategic_deliverables(id),
    action_name_fr          text NOT NULL,
    action_name_en          text,
    action_description_fr   text NOT NULL,
    action_description_en   text,
    status                  character varying(20) NOT NULL DEFAULT 'AI_DRAFTED',
    promoted_project_code   character varying(60) REFERENCES rf.sovereign_project_catalog(project_code),
    created_by              integer REFERENCES mg.affiliates(id),
    created_at              timestamp without time zone NOT NULL DEFAULT now(),
    updated_at              timestamp without time zone NOT NULL DEFAULT now()
);

ALTER TABLE mg.plan_action_projects
    ADD CONSTRAINT chk_plan_action_projects_status CHECK (
        status IN ('AI_DRAFTED', 'HUMAN_VALIDATED', 'PROMOTED')
    );

CREATE INDEX idx_plan_action_projects_deliverable ON mg.plan_action_projects (deliverable_id);

COMMIT;

-- Verification post-execution
\d mg.plan_action_projects
