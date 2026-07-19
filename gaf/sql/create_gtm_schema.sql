-- ============================================================
-- OSA / ISA OBSERVATORY
-- BLOC : SCHEMA GTM — CATALOGUE DES LIVRABLES (GO-TO-MARKET)
-- Version    : 1.0.0 -- corrige le 17 juillet 2026
-- Correctif : COMMENT ON TABLE/VIEW exige une chaine litterale unique
--   en PostgreSQL, jamais une expression de concatenation (||) --
--   syntaxe rejetee a l'execution, transaction entiere annulee sans
--   consequence (BEGIN/COMMIT englobant, verifie le 17 juillet 2026).
--   Chaines fusionnees en une seule, aucun autre changement.
-- Dépend de  : 01_rf_schema.sql (rf schema doit exister)
-- Source doctrinale : Livre Blanc "Go To Market de l'Observatoire
--   Africain de la Souveraineté (OSA)" — fourni le 14 juillet 2026.
-- Portée     : structure de données pour le catalogue normalisé des
--   livrables (§10 du livre blanc), les quatre familles de produits
--   (§7), les niveaux de diffusion (§3) et les catégories de
--   bénéficiaires (§8). N'implémente PAS l'application des règles
--   d'accès au niveau API — c'est un chantier distinct (05_API).
-- Statut     : ADR-005 -- PROPOSED (registre rf.adr_registry).
-- ============================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS gtm;
SET search_path TO gtm, rf, public;

-- ============================================================
-- 1. RÉFÉRENTIEL — Familles de produits (rf, stable, §7 livre blanc)
-- ============================================================

CREATE TABLE IF NOT EXISTS rf.product_families (
    code            VARCHAR(20)  PRIMARY KEY,
    name_fr         VARCHAR(100) NOT NULL,
    name_en         VARCHAR(100) NOT NULL,
    description_fr  TEXT,
    description_en  TEXT,
    display_order   SMALLINT     NOT NULL,
    created_at      TIMESTAMP    DEFAULT now()
);

INSERT INTO rf.product_families (code, name_fr, name_en, description_fr, description_en, display_order) VALUES
('DATA',           'Produits de données',        'Data Products',
 'Jeux de données, API, métadonnées, référentiels, documentation.',
 'Datasets, APIs, metadata, reference frameworks, documentation.', 1),
('KNOWLEDGE',      'Produits de connaissance',    'Knowledge Products',
 'Diagnostics, analyses, études, dossiers thématiques, AMAR, GENECO.',
 'Diagnostics, analyses, studies, thematic dossiers, AMAR, GENECO.', 2),
('DECISION',       'Produits d''aide à la décision', 'Decision Products',
 'Études de faisabilité, feuilles de route, POC, business cases, dossiers de financement, cahiers des charges.',
 'Feasibility studies, roadmaps, POCs, business cases, funding dossiers, terms of reference.', 3),
('IMPLEMENTATION', 'Services d''accompagnement',  'Implementation Products',
 'Audits, formations, assistance, suivi, gouvernance.',
 'Audits, training, assistance, monitoring, governance support.', 4)
ON CONFLICT (code) DO NOTHING;

-- ============================================================
-- 2. RÉFÉRENTIEL — Niveaux de diffusion (rf, stable, §3 livre blanc)
-- ============================================================

CREATE TABLE IF NOT EXISTS rf.diffusion_levels (
    code            VARCHAR(20)  PRIMARY KEY,
    name_fr         VARCHAR(100) NOT NULL,
    name_en         VARCHAR(100) NOT NULL,
    description_fr  TEXT,
    description_en  TEXT,
    requires_auth   BOOLEAN      NOT NULL DEFAULT FALSE,
    display_order   SMALLINT     NOT NULL,
    created_at      TIMESTAMP    DEFAULT now()
);

INSERT INTO rf.diffusion_levels (code, name_fr, name_en, description_fr, description_en, requires_auth, display_order) VALUES
('OUVERT',   'Niveau 1 — Données ouvertes',   'Level 1 — Open data',
 'Documentation méthodologique, définitions, dictionnaires de données, métadonnées, données publiques sélectionnées, API publique limitée, visualisations publiques.',
 'Methodological documentation, definitions, data dictionaries, metadata, selected public data, limited public API, public visualisations.',
 FALSE, 1),
('ENRICHI',  'Niveau 2 — Données enrichies',  'Level 2 — Enriched data',
 'Jeux de données consolidés, séries historiques, API avancées, tableaux de bord, exports spécialisés — accès professionnel.',
 'Consolidated datasets, historical series, advanced APIs, dashboards, specialised exports — professional access.',
 TRUE, 2)
ON CONFLICT (code) DO NOTHING;

-- ============================================================
-- 3. RÉFÉRENTIEL — Catégories de bénéficiaires (rf, stable, §8 livre blanc)
-- ============================================================

CREATE TABLE IF NOT EXISTS rf.beneficiary_types (
    code            VARCHAR(30)  PRIMARY KEY,
    name_fr         VARCHAR(100) NOT NULL,
    name_en         VARCHAR(100) NOT NULL,
    display_order   SMALLINT     NOT NULL,
    created_at      TIMESTAMP    DEFAULT now()
);

INSERT INTO rf.beneficiary_types (code, name_fr, name_en, display_order) VALUES
('ETAT',          'États',                                   'States',                              1),
('MINISTERE',     'Ministères',                               'Ministries',                          2),
('COLLECTIVITE',  'Collectivités territoriales',               'Local authorities',                  3),
('ORG_REGIONALE', 'Organisations régionales africaines',      'African regional organisations',      4),
('IFI',           'Institutions financières',                 'Financial institutions',              5),
('PTF',           'Partenaires techniques et financiers',     'Technical and financial partners',    6),
('UNIVERSITE',    'Universités',                               'Universities',                        7),
('CENTRE_RECH',   'Centres de recherche',                     'Research centres',                    8),
('ORG_INTL',      'Organisations internationales',            'International organisations',         9),
('ENTREPRISE',    'Entreprises',                               'Businesses',                          10),
('INVESTISSEUR',  'Investisseurs',                             'Investors',                           11),
('SOCIETE_CIVILE','Organisations de la société civile',       'Civil society organisations',         12)
ON CONFLICT (code) DO NOTHING;

-- ============================================================
-- 4. CATALOGUE DES LIVRABLES (gtm, évolutif, §10 livre blanc)
--    Chaque livrable : objectif, données d'entrée, méthode, usages,
--    bénéficiaires (table de liaison), conditions de diffusion.
--    Versionné (valid_from/valid_to/is_active) — cohérent avec le
--    Principe 4 (les méthodes constituent un patrimoine scientifique)
--    et le Principe 5 (chaque donnée a une origine, une histoire).
-- ============================================================

CREATE TABLE IF NOT EXISTS gtm.deliverables (
    id                    SERIAL       PRIMARY KEY,
    code                  VARCHAR(60)  NOT NULL,
    version               INTEGER      NOT NULL DEFAULT 1,
    name_fr               VARCHAR(200) NOT NULL,
    name_en               VARCHAR(200) NOT NULL,
    product_family_code   VARCHAR(20)  NOT NULL
        REFERENCES rf.product_families(code),
    diffusion_level_code  VARCHAR(20)  NOT NULL
        REFERENCES rf.diffusion_levels(code),

    -- Fiche normalisée (§10 du livre blanc)
    objective_fr          TEXT         NOT NULL,
    objective_en          TEXT,
    input_data_fr         TEXT,
    input_data_en         TEXT,
    method_description_fr TEXT,
    method_description_en TEXT,
    outputs_fr             TEXT,
    outputs_en             TEXT,
    usages_fr              TEXT,
    usages_en              TEXT,
    diffusion_conditions_fr TEXT,
    diffusion_conditions_en TEXT,

    -- Gouvernance / traçabilité (cohérent avec les autres schémas OSA)
    status                VARCHAR(20)  NOT NULL DEFAULT 'DRAFT'
        CHECK (status IN ('DRAFT','ACTIVE','DEPRECATED','RETIRED')),
    valid_from             DATE         NOT NULL DEFAULT CURRENT_DATE,
    valid_to               DATE,
    is_active              BOOLEAN      NOT NULL DEFAULT TRUE,
    gaf_finding_code        VARCHAR(80),   -- à renseigner une fois le GAF ouvert
    created_at              TIMESTAMP    DEFAULT now(),
    updated_at              TIMESTAMP    DEFAULT now(),

    UNIQUE (code, version)
);

CREATE INDEX IF NOT EXISTS idx_gtm_deliverables_family    ON gtm.deliverables(product_family_code);
CREATE INDEX IF NOT EXISTS idx_gtm_deliverables_diffusion ON gtm.deliverables(diffusion_level_code);
CREATE INDEX IF NOT EXISTS idx_gtm_deliverables_status    ON gtm.deliverables(status) WHERE is_active;

COMMENT ON TABLE gtm.deliverables IS
  'Catalogue normalisé des livrables OSA (Livre Blanc Go-To-Market §10). Une ligne = une version d''un livrable. Ne PAS supprimer une ligne pour en corriger une autre : incrémenter version et clore valid_to (cf. Principe 5, Volume 0).';

-- ============================================================
-- 5. LIAISON — Bénéficiaires par livrable (many-to-many)
-- ============================================================

CREATE TABLE IF NOT EXISTS gtm.deliverable_beneficiaries (
    deliverable_id   INT          NOT NULL REFERENCES gtm.deliverables(id) ON DELETE CASCADE,
    beneficiary_code VARCHAR(30)  NOT NULL REFERENCES rf.beneficiary_types(code),
    PRIMARY KEY (deliverable_id, beneficiary_code)
);

-- ============================================================
-- 6. VUE DE CONSULTATION — catalogue actif, bilingue, prêt pour l'API
-- ============================================================

CREATE OR REPLACE VIEW gtm.v_deliverables_catalog_active AS
SELECT
    d.id,
    d.code,
    d.version,
    d.name_fr, d.name_en,
    pf.code  AS product_family_code,
    pf.name_fr AS product_family_fr, pf.name_en AS product_family_en,
    dl.code  AS diffusion_level_code,
    dl.name_fr AS diffusion_level_fr, dl.name_en AS diffusion_level_en,
    dl.requires_auth,
    d.objective_fr, d.objective_en,
    d.usages_fr, d.usages_en,
    d.diffusion_conditions_fr, d.diffusion_conditions_en,
    ARRAY(
        SELECT bt.code
        FROM gtm.deliverable_beneficiaries db
        JOIN rf.beneficiary_types bt ON bt.code = db.beneficiary_code
        WHERE db.deliverable_id = d.id
        ORDER BY bt.display_order
    ) AS beneficiary_codes,
    d.status, d.valid_from, d.valid_to
FROM gtm.deliverables d
JOIN rf.product_families  pf ON pf.code = d.product_family_code
JOIN rf.diffusion_levels  dl ON dl.code = d.diffusion_level_code
WHERE d.is_active
  AND d.status = 'ACTIVE'
  AND (d.valid_to IS NULL OR d.valid_to >= CURRENT_DATE);

COMMENT ON VIEW gtm.v_deliverables_catalog_active IS
  'Vue de consultation du catalogue des livrables actifs, bilingue FR/EN, destinée à alimenter un futur endpoint API (ex. GET /api/v1/gtm/catalog) et/ou une page portail (§9 AKB, page vitrine des produits).';

COMMIT;

-- ============================================================
-- EXEMPLE D'AMORÇAGE (à adapter, laissé en commentaire volontairement
-- — ne pas insérer de données de démonstration sans validation) :
--
-- INSERT INTO gtm.deliverables
--   (code, name_fr, name_en, product_family_code, diffusion_level_code,
--    objective_fr, status)
-- VALUES
--   ('ISA_SCORE_PAYS', 'Score ISA par pays', 'Country ISA score',
--    'DATA', 'OUVERT',
--    'Mettre à disposition le score de souveraineté par pays et par pilier.',
--    'DRAFT');
-- ============================================================
