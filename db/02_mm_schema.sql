-- ============================================================
-- OSA / ISA OBSERVATORY
-- BLOC 02 : SCHEMA MM — MODÈLE MÉTIER
-- Version   : 1.0.0
-- Dépend de  : 01_rf_schema.sql (rf.pillars, rf.units, rf.indicators)
-- Corrections: FK vers tables inexistantes supprimées
--              méthodes créées avant indicateurs
--              PKI absente (activée en Phase 4)
-- ============================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS mm;
SET search_path TO mm, rf, public;

-- ============================================================
-- 1. DIMENSIONS analytiques (10 axes d'analyse transversaux)
-- ============================================================

CREATE TABLE IF NOT EXISTS mm.dimensions (
    code           VARCHAR(20)  PRIMARY KEY,
    name           VARCHAR(150) NOT NULL,
    description    TEXT,
    dimension_type VARCHAR(30)  NOT NULL
        CHECK (dimension_type IN ('governance','capacity','risk','impact')),
    is_core        BOOLEAN      DEFAULT TRUE,
    created_at     TIMESTAMP    DEFAULT now()
);

INSERT INTO mm.dimensions (code, name, description, dimension_type) VALUES
('GOV',  'Gouvernance',    'Qualité institutionnelle, transparence, règles',         'governance'),
('CAP',  'Capacité',       'Capacité opérationnelle réelle',                         'capacity'),
('DEP',  'Dépendance',     'Dépendance externe ou critique',                         'risk'),
('RES',  'Résilience',     'Capacité à absorber les chocs',                          'capacity'),
('RISK', 'Risque',         'Niveau de menace ou vulnérabilité',                      'risk'),
('VAL',  'Valeur',         'Création et captation de valeur',                        'impact'),
('AUT',  'Autonomie',      'Maîtrise souveraine',                                    'governance'),
('TRAC', 'Traçabilité',    'Traçabilité et auditabilité',                            'governance'),
('SUST', 'Soutenabilité',  'Durabilité économique et environnementale',              'impact'),
('IMP',  'Impact',         'Effet réel sur la population et le territoire',           'impact')
ON CONFLICT DO NOTHING;

-- ============================================================
-- 2. INDICATOR_METHODS (méthodes de normalisation versionnées)
--    Créé AVANT les indicateurs (FK indicator_code → ici)
-- ============================================================

CREATE TABLE IF NOT EXISTS mm.indicator_methods (
    id               SERIAL       PRIMARY KEY,
    code             VARCHAR(50)  UNIQUE NOT NULL,
    method_type      VARCHAR(20)  NOT NULL
        CHECK (method_type IN ('simple','composite','derived')),
    normalize_method VARCHAR(20)  NOT NULL
        CHECK (normalize_method IN ('minmax','zscore','log','invert','none')),
    direction        VARCHAR(10)  NOT NULL
        CHECK (direction IN ('up','down','neutral')),
    description      TEXT,
    is_active        BOOLEAN      DEFAULT TRUE,
    created_at       TIMESTAMP    DEFAULT now()
);

CREATE TABLE IF NOT EXISTS mm.indicator_method_versions (
    id               SERIAL       PRIMARY KEY,
    method_id        INT          NOT NULL
        REFERENCES mm.indicator_methods(id) ON DELETE CASCADE,
    version          INTEGER      NOT NULL DEFAULT 1,
    normalization    VARCHAR(20),
    aggregation      VARCHAR(30),
    direction        VARCHAR(10),
    valid_from       DATE         NOT NULL DEFAULT CURRENT_DATE,
    valid_to         DATE,
    is_active        BOOLEAN      DEFAULT TRUE,
    description      TEXT,
    UNIQUE (method_id, version)
);

INSERT INTO mm.indicator_methods (code, method_type, normalize_method, direction, description) VALUES
('SIMPLE_MINMAX_UP',   'simple',    'minmax',  'up',      'Min-max, indicateur positif (+ haut = + souverain)'),
('SIMPLE_MINMAX_DOWN', 'simple',    'minmax',  'down',    'Min-max inversé, indicateur négatif'),
('SIMPLE_LOG_UP',      'simple',    'log',     'up',      'Log-normalisation, indicateur positif (valeurs à forte dispersion)'),
('SIMPLE_ZSCORE_UP',   'simple',    'zscore',  'up',      'Z-score, indicateur positif (distribution normale)'),
('COMPOSITE_SUM',      'composite', 'none',    'up',      'Agrégation pondérée de sous-indicateurs'),
('SOUVERAIN_TRAC',     'derived',   'minmax',  'up',      'Indicateur souverain OSA (SNCTM, données nationales)')
ON CONFLICT DO NOTHING;

-- ============================================================
-- 3. SUPER_CATEGORIES (26 — répartition par pilier)
-- ============================================================

CREATE TABLE IF NOT EXISTS mm.super_categories (
    code          VARCHAR(50)  PRIMARY KEY,
    name          VARCHAR(200) NOT NULL,
    description   TEXT,
    pillar_code   VARCHAR(10)  NOT NULL
        REFERENCES rf.pillars(code) ON DELETE RESTRICT,
    display_order INT          DEFAULT 0,
    created_at    TIMESTAMP    DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_mm_supercat_pillar ON mm.super_categories(pillar_code);

INSERT INTO mm.super_categories (code, name, description, pillar_code, display_order) VALUES
-- PMIN (5)
('PMIN_GOV',  'Gouvernance minière',        'Régulation, transparence, conformité',     'PMIN', 1),
('PMIN_PROD', 'Production minière',         'Volumes, exploitation, diversification',   'PMIN', 2),
('PMIN_VAL',  'Valeur ajoutée minière',     'Transformation locale, fiscalité',         'PMIN', 3),
('PMIN_SEC',  'Sécurité & traçabilité',     'Protection sites, certification SNCTM',    'PMIN', 4),
('PMIN_ENV',  'Impact environnemental',     'Pollution, réhabilitation des sites',      'PMIN', 5),
-- PMON (3)
('PMON_STAB', 'Stabilité monétaire',        'Inflation, volatilité, réserves',          'PMON', 1),
('PMON_RES',  'Réserves & financement',     'Liquidité, dette, capacité financement',   'PMON', 2),
('PMON_DEP',  'Dépendance monétaire',       'Zones monétaires, CBDC, AfCFTA',           'PMON', 3),
-- PECO (3)
('PECO_STR',  'Structure économique',       'Diversification, industrialisation',       'PECO', 1),
('PECO_CV',   'Chaînes de valeur',          'Transformation, commerce, AfCFTA',         'PECO', 2),
('PECO_FIN',  'Solidité financière',        'Dette, déficit, IDE, PME',                 'PECO', 3),
-- PGEO (2)
('PGEO_SEC',  'Sécurité & stabilité',       'Conflits, risques, résilience',            'PGEO', 1),
('PGEO_DIP',  'Diplomatie & alliances',     'Coopération, organisations, soft power',   'PGEO', 2),
-- PMIL (4)
('PMIL_CAP',  'Capacités militaires',       'Effectifs, équipements, logistique',       'PMIL', 1),
('PMIL_EXP',  'Effort militaire',           'Budget, industrie, importations armes',    'PMIL', 2),
('PMIL_SEC',  'Sécurité territoriale',      'Contrôle territoire, menaces internes',    'PMIL', 3),
('PMIL_INT',  'Coopération militaire',      'Alliances, missions ONU, interopérabilité','PMIL', 4),
-- PHUM (3)
('PHUM_HEA',  'Santé',                      'Accès soins, mortalité, services hosp.',   'PHUM', 1),
('PHUM_EDU',  'Éducation & compétences',    'Formation, alphabétisation, numérique',    'PHUM', 2),
('PHUM_SOC',  'Conditions sociales',        'Pauvreté, inégalités, cohésion',           'PHUM', 3),
-- PENV (3)
('PENV_CLM',  'Climat & résilience',        'Vulnérabilité, adaptation climatique',     'PENV', 1),
('PENV_BIO',  'Biodiversité & forêts',      'Aires protégées, déforestation',           'PENV', 2),
('PENV_POL',  'Pollution & énergie',        'Émissions, déchets, renouvelables',        'PENV', 3),
-- PNUM (3)
('PNUM_INFRA','Infrastructures numériques', 'Fibre, data centers, connectivité',        'PNUM', 1),
('PNUM_GOV',  'Gouvernance numérique',      'Stratégie, régulation, cybersécurité',     'PNUM', 2),
('PNUM_ECO',  'Économie numérique',         'Fintech, startups, IA, CBDC',              'PNUM', 3)
ON CONFLICT DO NOTHING;

-- ============================================================
-- 4. CATEGORIES (64 — détail par super-catégorie)
-- ============================================================

CREATE TABLE IF NOT EXISTS mm.categories (
    code                VARCHAR(50)  PRIMARY KEY,
    name                VARCHAR(200) NOT NULL,
    description         TEXT,
    super_category_code VARCHAR(50)  NOT NULL
        REFERENCES mm.super_categories(code) ON DELETE RESTRICT,
    pillar_code         VARCHAR(10)  NOT NULL
        REFERENCES rf.pillars(code) ON DELETE RESTRICT,
    display_order       INT          DEFAULT 0,
    created_at          TIMESTAMP    DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_mm_categories_pillar    ON mm.categories(pillar_code);
CREATE INDEX IF NOT EXISTS idx_mm_categories_supercat  ON mm.categories(super_category_code);

INSERT INTO mm.categories
    (code, name, description, super_category_code, pillar_code, display_order)
VALUES
-- P1 PMIN
('PMIN_GOV_CAT',  'Gouvernance minière',       'Cadre légal, transparence, régulation',          'PMIN_GOV',  'PMIN', 1),
('PMIN_CONT_CAT', 'Contrats miniers',          'Qualité et transparence des contrats',           'PMIN_GOV',  'PMIN', 2),
('PMIN_CERT_CAT', 'Certification minière',     'EITI, SNCTM, lutte minerais conflit',            'PMIN_GOV',  'PMIN', 3),
('PMIN_PROD_CAT', 'Production minière',        'Volumes extraits, diversification minerais',     'PMIN_PROD', 'PMIN', 4),
('PMIN_VAL_CAT',  'Valeur ajoutée locale',     'Valeur ajoutée, fiscalité, royalties',           'PMIN_VAL',  'PMIN', 5),
('PMIN_TRANS_CAT','Transformation locale',     'Capacité à transformer les minerais',            'PMIN_VAL',  'PMIN', 6),
('PMIN_SEC_CAT',  'Sécurité minière',          'Sécurité des sites et des flux',                 'PMIN_SEC',  'PMIN', 7),
('PMIN_ENV_CAT',  'Impact environnemental',    'Pollution, réhabilitation des sites',            'PMIN_ENV',  'PMIN', 8),
-- P2 PMON
('PMON_PIB_CAT',  'Agrégats macro',            'PIB, masse monétaire, productivité',             'PMON_STAB', 'PMON', 1),
('PMON_PRIX_CAT', 'Inflation & prix',          'Stabilité des prix, inflation',                  'PMON_STAB', 'PMON', 2),
('PMON_CHA_CAT',  'Réserves de change',        'Couverture importations, liquidités',            'PMON_RES',  'PMON', 3),
('PMON_FIS_CAT',  'Dette & fiscalité',         'Soutenabilité dette, pression fiscale',          'PMON_RES',  'PMON', 4),
('PMON_FIN_CAT',  'Financement interne',       'Capacité de financement local',                  'PMON_RES',  'PMON', 5),
('PMON_INT_CAT',  'Intégration monétaire',     'Zones monétaires africaines',                    'PMON_DEP',  'PMON', 6),
('PMON_MNUM_CAT', 'Monnaies numériques',       'CBDC, paiements souverains',                     'PMON_DEP',  'PMON', 7),
('PMON_COMP_CAT', 'Compensation régionale',    'PAPSS, AfCFTA, compensations',                   'PMON_DEP',  'PMON', 8),
-- P3 PECO
('PECO_PROD_CAT', 'Capacité productive',       'Production nationale, industrie',                'PECO_STR',  'PECO', 1),
('PECO_AGR_CAT',  'Agriculture',               'Sécurité alimentaire, production agricole',      'PECO_STR',  'PECO', 2),
('PECO_INFRA_CAT','Infrastructure',            'Transport, énergie, logistique',                 'PECO_CV',   'PECO', 3),
('PECO_COM_CAT',  'Commerce & AfCFTA',         'Intégration commerciale continentale',           'PECO_CV',   'PECO', 4),
('PECO_INOV_CAT', 'Innovation & R&D',          'Propriété intellectuelle, recherche',            'PECO_CV',   'PECO', 5),
('PECO_PME_CAT',  'PME & entrepreneuriat',     'Accès financement, écosystème PME',              'PECO_FIN',  'PECO', 6),
('PECO_IDE_CAT',  'Attractivité IDE',          'Flux IDE, climat des affaires',                  'PECO_FIN',  'PECO', 7),
('PECO_FIS_CAT',  'Solidité fiscale',          'Recettes fiscales, dépenses publiques',          'PECO_FIN',  'PECO', 8),
-- P4 PGEO
('PGEO_STAB_CAT', 'Stabilité politique',       'Institutions, élections, gouvernance',           'PGEO_SEC',  'PGEO', 1),
('PGEO_SEC_CAT',  'Sécurité nationale',        'Armée, police, sécurité intérieure',             'PGEO_SEC',  'PGEO', 2),
('PGEO_RES_CAT',  'Résilience stratégique',    'Capacité à absorber les chocs externes',         'PGEO_SEC',  'PGEO', 3),
('PGEO_DIP_CAT',  'Diplomatie',                'Influence et présence internationale',           'PGEO_DIP',  'PGEO', 4),
('PGEO_COOP_CAT', 'Coopération régionale',     'UA, CEMAC, CEDEAO, EAC',                        'PGEO_DIP',  'PGEO', 5),
('PGEO_POS_CAT',  'Positionnement intl',       'Présence ONU, organisations',                   'PGEO_DIP',  'PGEO', 6),
-- P5 PMIL
('PMIL_CAP_CAT',  'Capacités militaires',      'Effectifs, équipements, logistique',             'PMIL_CAP',  'PMIL', 1),
('PMIL_AUTO_CAT', 'Autonomie militaire',       'Industrie défense, souveraineté',                'PMIL_EXP',  'PMIL', 2),
('PMIL_BUD_CAT',  'Budget défense',            'Dépenses militaires, effort budgétaire',         'PMIL_EXP',  'PMIL', 3),
('PMIL_SEC_CAT',  'Sécurité territoriale',     'Contrôle du territoire, frontières',             'PMIL_SEC',  'PMIL', 4),
('PMIL_COOP_CAT', 'Coopération militaire',     'Alliances, missions ONU, interopérabilité',     'PMIL_INT',  'PMIL', 5),
-- P6 PHUM
('PHUM_SANTE_CAT','Santé',                     'Accès soins, espérance vie',                     'PHUM_HEA',  'PHUM', 1),
('PHUM_HOP_CAT',  'Services hospitaliers',     'Capacité hospitalière',                          'PHUM_HEA',  'PHUM', 2),
('PHUM_EDU_CAT',  'Éducation',                 'Compétences et qualité enseignement',            'PHUM_EDU',  'PHUM', 3),
('PHUM_FPROF_CAT','Formation professionnelle', 'Compétences techniques',                         'PHUM_EDU',  'PHUM', 4),
('PHUM_DIG_CAT',  'Compétences numériques',    'Accès formation numérique, STEM',                'PHUM_EDU',  'PHUM', 5),
('PHUM_SOC_CAT',  'Conditions sociales',       'Pauvreté, vulnérabilité',                        'PHUM_SOC',  'PHUM', 6),
('PHUM_ECART_CAT','Inégalités',                'Écarts régionaux, genre, revenus',               'PHUM_SOC',  'PHUM', 7),
('PHUM_COSOC_CAT','Cohésion sociale',          'Stabilité communautaire, confiance',             'PHUM_SOC',  'PHUM', 8),
-- P7 PENV
('PENV_CLIM_CAT', 'Vulnérabilité climatique',  'Exposition aux risques climatiques',             'PENV_CLM',  'PENV', 1),
('PENV_ADA_CAT',  'Résilience climatique',     'Adaptation, politiques climatiques',             'PENV_CLM',  'PENV', 2),
('PENV_BIOD_CAT', 'Biodiversité',              'Zones protégées, espèces menacées',              'PENV_BIO',  'PENV', 3),
('PENV_FOR_CAT',  'Foresterie',                'Couverture, déforestation',                      'PENV_BIO',  'PENV', 4),
('PENV_POL_CAT',  'Pollution',                 'CO2, qualité air, eau, sols',                   'PENV_POL',  'PENV', 5),
('PENV_ENR_CAT',  'Énergies propres',          'Solaire, hydraulique, renouvelables',            'PENV_POL',  'PENV', 6),
('PENV_DEC_CAT',  'Gestion déchets',           'Collecte, tri, traitement',                      'PENV_POL',  'PENV', 7),
-- P8 PNUM
('PNUM_INFRA_CAT','Infrastructure numérique',  'Datacenters, backbone fibre',                    'PNUM_INFRA','PNUM', 1),
('PNUM_CON_CAT',  'Connectivité',              'Accès internet, mobile, inclusion',              'PNUM_INFRA','PNUM', 2),
('PNUM_SEC_CAT',  'Cybersécurité',             'CERT national, SOC, cybermenaces',               'PNUM_GOV',  'PNUM', 3),
('PNUM_SOV_CAT',  'Données souveraines',       'Cloud souverain, hébergement local',             'PNUM_GOV',  'PNUM', 4),
('PNUM_REG_CAT',  'Régulation numérique',      'Cadre légal, protection données',                'PNUM_GOV',  'PNUM', 5),
('PNUM_IA_CAT',   'Intelligence artificielle', 'Compétences IA, HPC, R&D',                       'PNUM_ECO',  'PNUM', 6),
('PNUM_ENUM_CAT', 'Économie numérique',        'Startups, fintech, e-commerce',                  'PNUM_ECO',  'PNUM', 7),
('PNUM_LOG_CAT',  'Logiciels souverains',      'Solutions open source, stack national',          'PNUM_ECO',  'PNUM', 8)
ON CONFLICT DO NOTHING;

-- ============================================================
-- 5. INDICATOR_GROUPS (1 groupe par pilier)
-- ============================================================

CREATE TABLE IF NOT EXISTS mm.indicator_groups (
    code          VARCHAR(50)  PRIMARY KEY,
    name          VARCHAR(200) NOT NULL,
    description   TEXT,
    pillar_code   VARCHAR(10)  NOT NULL
        REFERENCES rf.pillars(code) ON DELETE RESTRICT,
    display_order INT          DEFAULT 0,
    is_active     BOOLEAN      DEFAULT TRUE,
    created_at    TIMESTAMP    DEFAULT now()
);

INSERT INTO mm.indicator_groups (code, name, pillar_code, display_order) VALUES
('GPMIN','Groupe indicateurs miniers',          'PMIN', 1),
('GPMON','Groupe indicateurs monétaires',       'PMON', 2),
('GPECO','Groupe indicateurs économiques',      'PECO', 3),
('GPGEO','Groupe indicateurs géopolitiques',    'PGEO', 4),
('GPMIL','Groupe indicateurs militaires',       'PMIL', 5),
('GPHUM','Groupe indicateurs humains',          'PHUM', 6),
('GPENV','Groupe indicateurs environnementaux', 'PENV', 7),
('GPNUM','Groupe indicateurs numériques',       'PNUM', 8)
ON CONFLICT DO NOTHING;

-- ============================================================
-- 6. INDICATOR_GROUP_LINKS (liaison automatique groupe ↔ indicateur)
-- ============================================================

CREATE TABLE IF NOT EXISTS mm.indicator_group_links (
    group_code     VARCHAR(50) REFERENCES mm.indicator_groups(code),
    indicator_code VARCHAR(30) REFERENCES rf.indicators(code),
    PRIMARY KEY (group_code, indicator_code)
);

INSERT INTO mm.indicator_group_links (group_code, indicator_code)
SELECT
    'G' || i.pillar_code,
    i.code
FROM rf.indicators i
ON CONFLICT DO NOTHING;

-- ============================================================
-- 7. SOURCE_ORIGINS (catalogue des sources institutionnelles)
-- ============================================================

CREATE TABLE IF NOT EXISTS mm.source_origins (
    id                SERIAL       PRIMARY KEY,
    code              VARCHAR(50)  NOT NULL UNIQUE,
    name              VARCHAR(200) NOT NULL,
    source_type       VARCHAR(50)  DEFAULT 'international'
        CHECK (source_type IN ('international','regional','national','private','sovereign')),
    license_type      VARCHAR(50)  DEFAULT 'open'
        CHECK (license_type IN ('open','restricted','commercial')),
    api_url           TEXT,
    website           TEXT,
    reliability_score NUMERIC(4,3) DEFAULT 0.800
        CHECK (reliability_score BETWEEN 0 AND 1),
    update_frequency  VARCHAR(50)  DEFAULT 'yearly'
        CHECK (update_frequency IN ('daily','monthly','quarterly','yearly','irregular')),
    description       TEXT,
    created_at        TIMESTAMP    DEFAULT now()
);

INSERT INTO mm.source_origins
    (code, name, source_type, license_type, api_url, website, reliability_score, update_frequency, description)
VALUES
('WB',      'Banque mondiale',                        'international','open',       'https://api.worldbank.org/v2',                         'https://data.worldbank.org',   0.950, 'yearly',    'Indicateurs du développement mondial (WDI)'),
('IMF',     'Fonds monétaire international',          'international','open',       'https://www.imf.org/external/datamapper/api/v1',       'https://www.imf.org',          0.940, 'yearly',    'World Economic Outlook, IFS, BOP'),
('UNDP',    'Programme des Nations Unies pour le dév.','international','open',      'https://hdrdata.org/api',                              'https://hdr.undp.org',         0.900, 'yearly',    'Indice de développement humain (IDH)'),
('ITU',     'Union internationale des télécommunications','international','open',   'https://datahub.itu.int/api',                          'https://www.itu.int',          0.880, 'yearly',    'Indicateurs TIC et cybersécurité'),
('FAO',     'Organisation pour l''alimentation et l''agriculture','international','open','https://fenixservices.fao.org/faostat/api/v1',    'https://fao.org',              0.880, 'yearly',    'Données agricoles, alimentaires, forestières'),
('SIPRI',   'Institut international de recherche sur la paix','international','open',NULL,                                                  'https://www.sipri.org',        0.870, 'yearly',    'Dépenses militaires, transferts d''armes'),
('WHO',     'Organisation mondiale de la santé',      'international','open',       'https://ghoapi.azureedge.net/api',                     'https://www.who.int',          0.920, 'yearly',    'Données sanitaires mondiales'),
('UNEP',    'Programme des Nations Unies pour l''env.','international','open',      NULL,                                                   'https://www.unep.org',         0.850, 'yearly',    'Indicateurs environnementaux'),
('SNCTM',   'Service national de certification et traçabilité minière','sovereign','restricted',NULL,                                       NULL,                           0.990, 'quarterly', 'Source souveraine nationale — données minières certifiées'),
('AFRISTAT','Observatoire économique et statistique d''Afrique subsaharienne','regional','restricted',NULL,                                 'https://www.afristat.org',     0.850, 'yearly',    'Statistiques économiques africaines')
ON CONFLICT DO NOTHING;

COMMIT;

-- Vérification
-- SELECT pillar_code, COUNT(*) FROM mm.super_categories GROUP BY pillar_code ORDER BY pillar_code;
-- SELECT pillar_code, COUNT(*) FROM mm.categories GROUP BY pillar_code ORDER BY pillar_code;
-- SELECT COUNT(*) FROM mm.indicator_group_links;  -- attendu : 120
