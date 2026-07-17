-- ============================================================
-- ADR-004 / finding #41 PILLAR_STRATEGIC_CHAIN_ARCHITECTURE
-- Phase 1 -- socle de donnees du diagnostic par pilier
-- 17 juillet 2026 -- resout le blocage identifie au finding #44
-- ============================================================
-- Chaine : Pilier -> 5 Pourquoi -> Cause racine -> Levier(s) ->
--          Objectif strategique
-- Portee : pays + pilier, OU pilier seul panafricain (country_iso3
--          nullable -- NULL = portee panafricaine). Decide le
--          17 juillet 2026.
-- A executer sur DEV en premier (doctrine du projet : valider en DEV
-- avant PREPROD/PROD). Ne PAS executer sur preprod/prod avant
-- validation explicite.
-- ============================================================
-- EXECUTION :
--   docker exec -i osa-db psql -U postgres -d osa_dev \
--     < adr004_phase1_pillar_chain_schema.sql
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1) Referentiel -- categorisation 5M (Ishikawa) des causes racines.
--    Confirmee manquante le 17 juillet malgre la mention du finding
--    #41 ("deja en usage") -- jamais construite en realite.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rf.cause_category_5m (
    code            text PRIMARY KEY,
    label_fr        text NOT NULL,
    label_en        text NOT NULL,
    description_fr  text,
    description_en  text,
    display_order   integer NOT NULL
);

INSERT INTO rf.cause_category_5m (code, label_fr, label_en, description_fr, description_en, display_order) VALUES
    ('MAIN_OEUVRE', 'Main-d''œuvre', 'Manpower',
     'Compétences, effectifs, formation, organisation humaine.',
     'Skills, staffing, training, human organisation.', 1),
    ('METHODE', 'Méthode', 'Method',
     'Procédures, processus, gouvernance opérationnelle.',
     'Procedures, processes, operational governance.', 2),
    ('MATERIEL', 'Matériel', 'Machinery',
     'Infrastructure, équipement, outillage technique.',
     'Infrastructure, equipment, technical tooling.', 3),
    ('MATIERE', 'Matière', 'Materials',
     'Données, ressources, intrants premiers.',
     'Data, resources, raw inputs.', 4),
    ('MILIEU', 'Milieu', 'Environment',
     'Contexte institutionnel, politique, géographique, culturel.',
     'Institutional, political, geographic, cultural context.', 5)
ON CONFLICT (code) DO NOTHING;

-- ------------------------------------------------------------
-- 2) mg.pillar_5whys_analysis -- processus analytique versionnable et
--    rejouable (finding #41, principe 1). Le raisonnement, pas la
--    decision -- peut etre rejoue sans jamais toucher au modele en aval.
--    country_iso3 nullable : NULL = portee panafricaine, sinon portee
--    pays+pilier (decide le 17 juillet 2026, "les deux possibles").
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mg.pillar_5whys_analysis (
    id              serial PRIMARY KEY,
    pillar_code     varchar(10) NOT NULL REFERENCES mg.working_groups(pillar_code),
    country_iso3    varchar(3),
    version         integer NOT NULL DEFAULT 1,
    content         jsonb NOT NULL,
    status          varchar(20) NOT NULL DEFAULT 'DRAFT'
                    CHECK (status IN ('DRAFT', 'VALIDATED', 'ARCHIVED')),
    created_by      integer REFERENCES mg.affiliates(id),
    created_at      timestamp NOT NULL DEFAULT now(),
    updated_at      timestamp NOT NULL DEFAULT now()
);

-- Unicite version par (pilier, pays-ou-panafricain) -- COALESCE
-- necessaire : NULL <> NULL en SQL standard, un index unique brut
-- laisserait passer des doublons de version en portee panafricaine.
CREATE UNIQUE INDEX IF NOT EXISTS uq_5whys_pillar_country_version
    ON mg.pillar_5whys_analysis (pillar_code, COALESCE(country_iso3, 'PANAFRICAIN'), version);

CREATE INDEX IF NOT EXISTS idx_5whys_pillar ON mg.pillar_5whys_analysis (pillar_code);
CREATE INDEX IF NOT EXISTS idx_5whys_status ON mg.pillar_5whys_analysis (status);

COMMENT ON TABLE mg.pillar_5whys_analysis IS
    'Raisonnement analytique (5 Pourquoi), versionnable et rejouable. '
    'Ne pas confondre avec mg.pillar_root_causes (la conclusion validee) '
    '-- separation actee au finding #41, principe 1.';

-- ------------------------------------------------------------
-- 3) mg.pillar_root_causes -- la conclusion validee (finding #41,
--    principe 1). Seule cette table alimente la suite de la chaine,
--    jamais l'analyse brute directement.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mg.pillar_root_causes (
    id                      serial PRIMARY KEY,
    analysis_id             integer NOT NULL REFERENCES mg.pillar_5whys_analysis(id),
    pillar_code             varchar(10) NOT NULL REFERENCES mg.working_groups(pillar_code),
    country_iso3            varchar(3),
    cause_category_5m_code  text NOT NULL REFERENCES rf.cause_category_5m(code),
    description_fr          text NOT NULL,
    description_en          text,
    status                  varchar(20) NOT NULL DEFAULT 'ACTIVE'
                            CHECK (status IN ('ACTIVE', 'SUPERSEDED', 'ARCHIVED')),
    created_by              integer REFERENCES mg.affiliates(id),
    created_at              timestamp NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_root_causes_analysis ON mg.pillar_root_causes (analysis_id);
CREATE INDEX IF NOT EXISTS idx_root_causes_pillar ON mg.pillar_root_causes (pillar_code);
CREATE INDEX IF NOT EXISTS idx_root_causes_5m ON mg.pillar_root_causes (cause_category_5m_code);

COMMENT ON TABLE mg.pillar_root_causes IS
    'Cause racine retenue -- conclusion validee d''une analyse 5 Pourquoi. '
    'pillar_code/country_iso3 denormalises depuis analysis_id pour '
    'faciliter les jointures directes -- doivent toujours correspondre '
    'a la portee de l''analyse d''origine.';

-- ------------------------------------------------------------
-- 4) mg.strategic_levers -- catalogue des leviers d'intervention.
--    PAS un objet doctrinal (finding #41, principe 2) -- n'entre pas
--    dans la hierarchie OSA->ISA->POA->AMAR->GENECO, ne requiert pas
--    de validation du Conseil scientifique.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mg.strategic_levers (
    lever_code      text PRIMARY KEY,
    label_fr        text NOT NULL,
    label_en        text NOT NULL,
    description_fr  text,
    description_en  text,
    is_active       boolean NOT NULL DEFAULT true,
    created_at      timestamp NOT NULL DEFAULT now()
);

COMMENT ON TABLE mg.strategic_levers IS
    'Catalogue des leviers d''intervention -- axes, pas phenomenes '
    'observes. Hors hierarchie doctrinale OSA (finding #41, principe 2).';

-- ------------------------------------------------------------
-- 5) mg.root_cause_levers -- relation N:N ponderee, cause -> levier.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mg.root_cause_levers (
    root_cause_id     integer NOT NULL REFERENCES mg.pillar_root_causes(id),
    lever_code        text NOT NULL REFERENCES mg.strategic_levers(lever_code),
    relevance_weight  numeric(4,2) NOT NULL CHECK (relevance_weight BETWEEN 0 AND 1),
    created_at        timestamp NOT NULL DEFAULT now(),
    PRIMARY KEY (root_cause_id, lever_code)
);

-- ------------------------------------------------------------
-- 6) mg.strategic_objectives -- noeud central de raccordement, objet
--    propre (finding #41, principe 4) -- point d'arrivee de cette
--    chaine, point d'entree du moteur OIM (ADR-OSA-OIM-001).
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mg.strategic_objectives (
    id              serial PRIMARY KEY,
    pillar_code     varchar(10) NOT NULL REFERENCES mg.working_groups(pillar_code),
    country_iso3    varchar(3),
    label_fr        text NOT NULL,
    label_en        text NOT NULL,
    description_fr  text,
    description_en  text,
    status          varchar(20) NOT NULL DEFAULT 'ACTIVE'
                    CHECK (status IN ('ACTIVE', 'ACHIEVED', 'ARCHIVED')),
    created_by      integer REFERENCES mg.affiliates(id),
    created_at      timestamp NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_objectives_pillar ON mg.strategic_objectives (pillar_code);

COMMENT ON TABLE mg.strategic_objectives IS
    'Objectif strategique -- noeud de sortie de la chaine ADR-004, '
    'noeud d''entree du moteur OIM (mg.transformation_requirements '
    'referencera cette table). Cf. ADR-OSA-OIM-001 (version finale).';

-- ------------------------------------------------------------
-- 7) mg.lever_objectives -- relation N:N ponderee, levier -> objectif.
--    Meme forme que root_cause_levers -- delibere (finding #41,
--    principe 3), chaine entierement referentiel-driven.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mg.lever_objectives (
    lever_code        text NOT NULL REFERENCES mg.strategic_levers(lever_code),
    objective_id      integer NOT NULL REFERENCES mg.strategic_objectives(id),
    relevance_weight  numeric(4,2) NOT NULL CHECK (relevance_weight BETWEEN 0 AND 1),
    created_at        timestamp NOT NULL DEFAULT now(),
    PRIMARY KEY (lever_code, objective_id)
);

COMMIT;

-- Verification post-execution
SELECT code FROM rf.cause_category_5m ORDER BY display_order;
SELECT table_name FROM information_schema.tables
    WHERE table_schema = 'mg' AND table_name IN (
        'pillar_5whys_analysis', 'pillar_root_causes', 'strategic_levers',
        'root_cause_levers', 'strategic_objectives', 'lever_objectives'
    )
    ORDER BY table_name;
