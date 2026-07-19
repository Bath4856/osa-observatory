-- ============================================================
-- OSOA -- Volume 0, Phase 1 du modele de donnees
-- 17 juillet 2026
-- ============================================================
-- Perimetre volontairement limite : suivi de dossier, analyses
-- strategiques (Phase 3), scenarios (Phase 4), recommandation
-- (Phase 5), validation (Phase 6). Laisse de cote : gestion
-- documentaire detaillee (Phase 2), retour d'experience (Phase 8),
-- et tout rattachement a un organe de gouvernance doctrinal --
-- explicitement non tranche par le Volume 0 lui-meme (Encadre 8.1).
--
-- Deux sources d'entree (Volume 0 chapitre 4.4 / OIM chapitre 5.2) :
-- INTERNAL (une Famille de projets compatibles issue d'OIM) ou
-- EXTERNAL (AMI/DP/AO). Meme patron origin_type que celui deja
-- applique a mg.transformation_requirements.
--
-- A executer sur DEV en premier.
-- ============================================================
-- EXECUTION :
--   docker exec -i osa-db psql -U postgres -d osa_dev \
--     < osoa_phase1_schema.sql
-- ============================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS osoa;

-- ------------------------------------------------------------
-- 1) Referentiels
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS rf.osoa_scenario_types (
    code            text PRIMARY KEY,
    label_fr        text NOT NULL,
    label_en        text NOT NULL,
    display_order   integer NOT NULL
);

INSERT INTO rf.osoa_scenario_types (code, label_fr, label_en, display_order) VALUES
    ('ACCEPTER', 'Accepter', 'Accept', 1),
    ('ACCEPTER_CONDITIONS', 'Accepter sous conditions', 'Accept with conditions', 2),
    ('DIFFERER', 'Différer', 'Defer', 3),
    ('DEMANDE_INFO', 'Demander des informations complémentaires', 'Request further information', 4),
    ('CONSORTIUM', 'Constituer un consortium', 'Form a consortium', 5),
    ('MODIFIER_PERIMETRE', 'Modifier le périmètre', 'Modify scope', 6),
    ('REJETER', 'Rejeter', 'Reject', 7)
ON CONFLICT (code) DO NOTHING;

CREATE TABLE IF NOT EXISTS rf.osoa_execution_modes (
    code            text PRIMARY KEY,
    label_fr        text NOT NULL,
    label_en        text NOT NULL,
    display_order   integer NOT NULL
);

INSERT INTO rf.osoa_execution_modes (code, label_fr, label_en, display_order) VALUES
    ('PROPRE', 'Intervention propre', 'Direct intervention', 1),
    ('PARTENARIAT', 'Partenariat', 'Partnership', 2),
    ('CONSORTIUM', 'Consortium', 'Consortium', 3),
    ('SOUS_TRAITANCE', 'Sous-traitance', 'Subcontracting', 4)
ON CONFLICT (code) DO NOTHING;

COMMENT ON TABLE rf.osoa_execution_modes IS
    'Classification des modes d''execution, production systematique de la Phase 5 (Recommandation) -- Volume 0 OSOA, note de cadrage OSOA-INTEGRATION §5. Pilotee par table, jamais codee en dur.';

-- ------------------------------------------------------------
-- 2) osoa.opportunities -- entite centrale, une ligne par dossier.
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS osoa.opportunities (
    id                          serial PRIMARY KEY,
    code                        text UNIQUE NOT NULL,
    title_fr                    text NOT NULL,
    title_en                    text,
    origin_type                 varchar(20) NOT NULL CHECK (origin_type IN ('INTERNAL', 'EXTERNAL')),
    origin_project_family_id    integer REFERENCES mg.project_families(id),
    current_phase               smallint NOT NULL DEFAULT 1 CHECK (current_phase BETWEEN 1 AND 8),
    status                      varchar(20) NOT NULL DEFAULT 'ACTIVE'
                                CHECK (status IN ('ACTIVE', 'CLOSED', 'ABANDONED')),
    created_by                  integer REFERENCES mg.affiliates(id),
    created_at                  timestamp NOT NULL DEFAULT now(),
    updated_at                  timestamp NOT NULL DEFAULT now(),
    CHECK (
        (origin_type = 'INTERNAL' AND origin_project_family_id IS NOT NULL)
        OR (origin_type = 'EXTERNAL' AND origin_project_family_id IS NULL)
    )
);

CREATE INDEX IF NOT EXISTS idx_osoa_opportunities_status ON osoa.opportunities (status);

COMMENT ON TABLE osoa.opportunities IS
    'Dossier d''opportunite OSOA -- deux sources d''entree symetriques (Volume 0 OSOA ch.4.4, Volume 0 OIM ch.5.2). Aucun rattachement a un organe de gouvernance doctrinal : explicitement non tranche par le Volume 0 (Encadre 8.1), a ajouter lors d''une future revision.';

-- ------------------------------------------------------------
-- 3) osoa.strategic_analyses -- Phase 3, methodes appliquees.
--    Meme patron method/content que mg.indicator_comments.
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS osoa.strategic_analyses (
    id              serial PRIMARY KEY,
    opportunity_id  integer NOT NULL REFERENCES osoa.opportunities(id),
    method          varchar(30) NOT NULL
                    CHECK (method IN ('5W1H', 'SWOT', '5_POURQUOI', 'RISQUE', 'FAISABILITE', 'MULTICRITERE', 'ECONOMIQUE', 'GOUVERNANCE')),
    content         jsonb NOT NULL,
    created_by      integer REFERENCES mg.affiliates(id),
    created_at      timestamp NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_osoa_analyses_opportunity ON osoa.strategic_analyses (opportunity_id);

-- ------------------------------------------------------------
-- 4) osoa.scenarios -- Phase 4.
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS osoa.scenarios (
    id                  serial PRIMARY KEY,
    opportunity_id      integer NOT NULL REFERENCES osoa.opportunities(id),
    scenario_type_code  text NOT NULL REFERENCES rf.osoa_scenario_types(code),
    description_fr      text,
    justification_fr    text,
    assessed_by         integer REFERENCES mg.affiliates(id),
    created_at          timestamp NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_osoa_scenarios_opportunity ON osoa.scenarios (opportunity_id);

-- ------------------------------------------------------------
-- 5) osoa.recommendations -- Phase 5.
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS osoa.recommendations (
    id                     serial PRIMARY KEY,
    opportunity_id         integer NOT NULL REFERENCES osoa.opportunities(id),
    scenario_id            integer NOT NULL REFERENCES osoa.scenarios(id),
    execution_mode_code    text REFERENCES rf.osoa_execution_modes(code),
    expected_benefits_fr   text,
    identified_risks_fr    text,
    conditions_fr          text,
    poc_reference          text,
    recommended_by         integer REFERENCES mg.affiliates(id),
    recommended_at         timestamp NOT NULL DEFAULT now()
);

COMMENT ON COLUMN osoa.recommendations.poc_reference IS
    'POC cite comme livrable possible, en coherence avec le Livre Blanc Go-To-Market -- note de cadrage OSOA-INTEGRATION §4.';

-- ------------------------------------------------------------
-- 6) osoa.validations -- Phase 6, decision de l'organe de gouvernance.
--    Organe lui-meme non nomme -- cf. commentaire sur osoa.opportunities.
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS osoa.validations (
    id                  serial PRIMARY KEY,
    recommendation_id   integer NOT NULL REFERENCES osoa.recommendations(id),
    decision            varchar(30) NOT NULL
                        CHECK (decision IN ('APPROUVE', 'AMENDE', 'ANALYSE_COMPLEMENTAIRE', 'REJETE')),
    justification_fr    text,
    validated_by        integer REFERENCES mg.affiliates(id),
    validated_at        timestamp NOT NULL DEFAULT now()
);

COMMIT;

-- Verification post-execution
SELECT table_name FROM information_schema.tables
    WHERE table_schema = 'osoa'
    ORDER BY table_name;
SELECT code FROM rf.osoa_scenario_types ORDER BY display_order;
SELECT code FROM rf.osoa_execution_modes ORDER BY display_order;
