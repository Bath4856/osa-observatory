-- ============================================================
-- ADR-OSA-OIM-001 (version finale) / finding #42 OIM_ENGINE_CREATION
-- Phase 1 -- socle de donnees du moteur OIM
-- 17 juillet 2026
-- ============================================================
-- Chaine : Objectif strategique -> Transformation Requirement ->
--          Patron(s) d'Intervention -> Famille(s) de projets compatibles
-- Depend de : ADR-004 Phase 1 (mg.strategic_objectives), deja construite
-- et testee sur DEV le 17 juillet 2026 -- finding #44 desormais
-- non bloquant pour cette migration.
-- Cardinalites actees le 17 juillet 2026 :
--   - Objectif strategique -> Transformation Requirement : 1:N
--   - Transformation Requirement -> Patron d'Intervention : N:N ponderee
--   - Patron d'Intervention -> Famille de projets compatibles : N:N
--     ponderee (decide le 17 juillet, coherence avec le reste de la
--     chaine -- consequence : 2 tables, pas 1, pour ce dernier maillon)
-- A executer sur DEV en premier (doctrine du projet).
-- ============================================================
-- EXECUTION :
--   docker exec -i osa-db psql -U postgres -d osa_dev \
--     < oim_phase1_schema.sql
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1) mg.transformation_requirements -- premiere table d'OIM. Un meme
--    objectif strategique peut se decomposer en plusieurs besoins de
--    transformation distincts (ADR-OSA-OIM-001, section 3).
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mg.transformation_requirements (
    id              serial PRIMARY KEY,
    objective_id    integer NOT NULL REFERENCES mg.strategic_objectives(id),
    label_fr        text NOT NULL,
    label_en        text NOT NULL,
    description_fr  text,
    description_en  text,
    status          varchar(20) NOT NULL DEFAULT 'ACTIVE'
                    CHECK (status IN ('ACTIVE', 'ARCHIVED')),
    created_by      integer REFERENCES mg.affiliates(id),
    created_at      timestamp NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_transformation_req_objective
    ON mg.transformation_requirements (objective_id);

COMMENT ON TABLE mg.transformation_requirements IS
    'Besoin de transformation -- decompose un objectif strategique '
    '(1:N). Point de depart du moteur OIM, distinct de la chaine '
    'scientifique ADR-004 (ADR-OSA-OIM-001, section 2).';

-- ------------------------------------------------------------
-- 2) mg.intervention_patterns -- catalogue des Patrons d'Intervention.
--    Meme nature que mg.strategic_levers : axe d'ingenierie, pas objet
--    doctrinal.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mg.intervention_patterns (
    pattern_code    text PRIMARY KEY,
    label_fr        text NOT NULL,
    label_en        text NOT NULL,
    description_fr  text,
    description_en  text,
    is_active       boolean NOT NULL DEFAULT true,
    created_at      timestamp NOT NULL DEFAULT now()
);

COMMENT ON TABLE mg.intervention_patterns IS
    'Catalogue des Patrons d''Intervention -- hors hierarchie '
    'doctrinale OSA, registre Conseil technique (ADR-OSA-OIM-001).';

-- ------------------------------------------------------------
-- 3) mg.requirement_pattern_matches -- N:N ponderee, meme forme que
--    mg.root_cause_levers / mg.lever_objectives (ADR-004).
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mg.requirement_pattern_matches (
    requirement_id    integer NOT NULL REFERENCES mg.transformation_requirements(id),
    pattern_code      text NOT NULL REFERENCES mg.intervention_patterns(pattern_code),
    relevance_weight  numeric(4,2) NOT NULL CHECK (relevance_weight BETWEEN 0 AND 1),
    created_at        timestamp NOT NULL DEFAULT now(),
    PRIMARY KEY (requirement_id, pattern_code)
);

-- ------------------------------------------------------------
-- 4) mg.project_families -- catalogue des familles de projets
--    compatibles (ex-"Projet recommande", renomme -- ADR-OSA-OIM-001
--    section 5). OSA caracterise un ensemble de reponses possibles,
--    ne designe jamais une reponse unique.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mg.project_families (
    id              serial PRIMARY KEY,
    label_fr        text NOT NULL,
    label_en        text NOT NULL,
    description_fr  text,
    description_en  text,
    status          varchar(20) NOT NULL DEFAULT 'ACTIVE'
                    CHECK (status IN ('ACTIVE', 'ARCHIVED')),
    created_at      timestamp NOT NULL DEFAULT now()
);

COMMENT ON TABLE mg.project_families IS
    'Famille de projets compatibles (ex-"Projet recommande"). '
    'Candidat naturel a gtm.deliverables (famille DECISION) -- aucun '
    'lien technique construit a ce stade (ADR-OSA-OIM-001, section 7).';

-- ------------------------------------------------------------
-- 5) mg.pattern_project_families -- N:N ponderee, dernier maillon de
--    la chaine. Cardinalite actee le 17 juillet 2026, pour coherence
--    avec le reste de la chaine (deliberation anterieure de Theo D.
--    Bakang).
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mg.pattern_project_families (
    pattern_code      text NOT NULL REFERENCES mg.intervention_patterns(pattern_code),
    family_id         integer NOT NULL REFERENCES mg.project_families(id),
    relevance_weight  numeric(4,2) NOT NULL CHECK (relevance_weight BETWEEN 0 AND 1),
    created_at        timestamp NOT NULL DEFAULT now(),
    PRIMARY KEY (pattern_code, family_id)
);

COMMIT;

-- Verification post-execution
SELECT table_name FROM information_schema.tables
    WHERE table_schema = 'mg' AND table_name IN (
        'transformation_requirements', 'intervention_patterns',
        'requirement_pattern_matches', 'project_families',
        'pattern_project_families'
    )
    ORDER BY table_name;
