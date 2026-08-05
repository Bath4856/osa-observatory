-- ============================================================
-- mg.strategic_levers + mg.project_interdependence_drafts
-- 5 aout 2026 -- refonte de l'interdependance en 2 niveaux
-- ============================================================
-- Suite au diagnostic de Theo (le matin apres la session precedente) :
-- l'interdependance n'est PAS une relation scientifique entre deux
-- piliers (corr(PMIN, PECO) -- ca releve de la recherche, pas d'OIM).
-- OIM repond a une question operationnelle : "si on agit sur ce levier
-- / ce projet, quels autres piliers en beneficient ?"
--
-- DEUX NIVEAUX, chronologie naturelle de la chaine OIM :
-- POA -> GAP -> 5 Pourquoi -> Cause racine -> LEVIER STRATEGIQUE
--   -> Interdependance des leviers (niveau VISION, avant tout projet)
--   -> PROJET (mg.plan_action_projects -> rf.sovereign_project_catalog)
--   -> Interdependance des interventions (niveau PLAN D'ACTION)
--
-- mg.strategic_levers : le levier n'est PAS un projet nomme -- un domaine
-- d'intervention identifie a partir des 9 analyses (surtout 5_POURQUOI/
-- RISQUE), avant qu'aucun projet concret n'existe.
--
-- mg.project_interdependence_drafts : une fois un PROJET REEL promu
-- (rf.sovereign_project_catalog), analyse ses effets attendus sur
-- d'autres piliers -- ancre sur project_code (cle primaire reelle),
-- jamais sur un entier arbitraire.
--
-- A executer DEV -> PREPROD -> PROD.
-- ============================================================

BEGIN;

CREATE TABLE mg.strategic_levers (
    id                      integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    vision_id               integer NOT NULL REFERENCES mg.pillar_strategic_vision(id),
    label_fr                text NOT NULL,
    description_fr          text NOT NULL,
    source_analysis_ids     integer[] NOT NULL,
    status                  character varying(20) NOT NULL DEFAULT 'AI_DRAFTED',
    created_by              integer REFERENCES mg.affiliates(id),
    created_at              timestamp without time zone NOT NULL DEFAULT now(),
    updated_at              timestamp without time zone NOT NULL DEFAULT now()
);

ALTER TABLE mg.strategic_levers
    ADD CONSTRAINT chk_strategic_levers_status CHECK (
        status IN ('AI_DRAFTED', 'HUMAN_VALIDATED')
    );

CREATE INDEX idx_strategic_levers_vision ON mg.strategic_levers (vision_id);

CREATE TABLE mg.project_interdependence_drafts (
    id                      integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    project_code            character varying(60) NOT NULL REFERENCES rf.sovereign_project_catalog(project_code),
    content                 jsonb NOT NULL,
    status                  character varying(20) NOT NULL DEFAULT 'AI_DRAFTED',
    created_by              integer REFERENCES mg.affiliates(id),
    created_at              timestamp without time zone NOT NULL DEFAULT now(),
    updated_at              timestamp without time zone NOT NULL DEFAULT now()
);

ALTER TABLE mg.project_interdependence_drafts
    ADD CONSTRAINT chk_project_interdep_drafts_status CHECK (
        status IN ('AI_DRAFTED', 'HUMAN_VALIDATED')
    );

CREATE INDEX idx_project_interdep_drafts_project ON mg.project_interdependence_drafts (project_code);

COMMIT;

-- Verification post-execution
\d mg.strategic_levers
\d mg.project_interdependence_drafts
