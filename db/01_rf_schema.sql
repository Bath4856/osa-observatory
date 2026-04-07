-- ============================================================
-- OSA / ISA OBSERVATORY
-- BLOC 01 : SCHEMA RF — RÉFÉRENTIEL CANONIQUE
-- Version   : 1.0.0
-- Doctrine  : immuable après déploiement initial
--             toute modification = nouvelle version versionnée
-- SGBD      : PostgreSQL 13+
-- ============================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS rf;
SET search_path TO rf, public;

-- ============================================================
-- 1. REGIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS rf.regions (
    code        VARCHAR(10)  PRIMARY KEY,
    name_fr     TEXT         NOT NULL,
    name_en     TEXT         NOT NULL,
    created_at  TIMESTAMP    DEFAULT now()
);

INSERT INTO rf.regions (code, name_fr, name_en) VALUES
('AFN',  'Afrique du Nord',      'North Africa'),
('AFW',  'Afrique de l''Ouest',  'West Africa'),
('AFE',  'Afrique de l''Est',    'East Africa'),
('AFC',  'Afrique Centrale',     'Central Africa'),
('AFS',  'Afrique Australe',     'Southern Africa')
ON CONFLICT DO NOTHING;

-- ============================================================
-- 2. COUNTRIES (54 pays africains)
-- ============================================================

CREATE TABLE IF NOT EXISTS rf.countries (
    iso2        CHAR(2)      PRIMARY KEY,
    iso3        CHAR(3)      UNIQUE NOT NULL,
    iso_numeric SMALLINT     UNIQUE NOT NULL,
    name_fr     TEXT,
    name_en     TEXT,
    region_code VARCHAR(10)  REFERENCES rf.regions(code),
    created_at  TIMESTAMP    DEFAULT now()
);

INSERT INTO rf.countries (iso2, iso3, iso_numeric, name_fr, name_en, region_code) VALUES
-- Afrique du Nord
('DZ','DZA',12, 'Algérie',             'Algeria',              'AFN'),
('EG','EGY',818,'Égypte',              'Egypt',                'AFN'),
('LY','LBY',434,'Libye',               'Libya',                'AFN'),
('MA','MAR',504,'Maroc',               'Morocco',              'AFN'),
('MR','MRT',478,'Mauritanie',          'Mauritania',           'AFN'),
('SD','SDN',729,'Soudan',              'Sudan',                'AFN'),
('TN','TUN',788,'Tunisie',             'Tunisia',              'AFN'),
-- Afrique de l'Ouest
('BJ','BEN',204,'Bénin',               'Benin',                'AFW'),
('BF','BFA',854,'Burkina Faso',        'Burkina Faso',         'AFW'),
('CI','CIV',384,'Côte d''Ivoire',      'Côte d''Ivoire',       'AFW'),
('CV','CPV',132,'Cabo Verde',          'Cabo Verde',           'AFW'),
('GM','GMB',270,'Gambie',              'Gambia',               'AFW'),
('GH','GHA',288,'Ghana',               'Ghana',                'AFW'),
('GN','GIN',324,'Guinée',              'Guinea',               'AFW'),
('GW','GNB',624,'Guinée-Bissau',       'Guinea-Bissau',        'AFW'),
('LR','LBR',430,'Libéria',             'Liberia',              'AFW'),
('ML','MLI',466,'Mali',                'Mali',                 'AFW'),
('NE','NER',562,'Niger',               'Niger',                'AFW'),
('NG','NGA',566,'Nigéria',             'Nigeria',              'AFW'),
('SL','SLE',694,'Sierra Leone',        'Sierra Leone',         'AFW'),
('SN','SEN',686,'Sénégal',             'Senegal',              'AFW'),
('TG','TGO',768,'Togo',                'Togo',                 'AFW'),
-- Afrique de l'Est
('BI','BDI',108,'Burundi',             'Burundi',              'AFE'),
('KM','COM',174,'Comores',             'Comoros',              'AFE'),
('DJ','DJI',262,'Djibouti',            'Djibouti',             'AFE'),
('ER','ERI',232,'Érythrée',            'Eritrea',              'AFE'),
('ET','ETH',231,'Éthiopie',            'Ethiopia',             'AFE'),
('KE','KEN',404,'Kenya',               'Kenya',                'AFE'),
('MG','MDG',450,'Madagascar',          'Madagascar',           'AFE'),
('MW','MWI',454,'Malawi',              'Malawi',               'AFE'),
('MU','MUS',480,'Maurice',             'Mauritius',            'AFE'),
('MZ','MOZ',508,'Mozambique',          'Mozambique',           'AFE'),
('RW','RWA',646,'Rwanda',              'Rwanda',               'AFE'),
('SC','SYC',690,'Seychelles',          'Seychelles',           'AFE'),
('SO','SOM',706,'Somalie',             'Somalia',              'AFE'),
('SS','SSD',728,'Soudan du Sud',       'South Sudan',          'AFE'),
('TZ','TZA',834,'Tanzanie',            'Tanzania',             'AFE'),
('UG','UGA',800,'Ouganda',             'Uganda',               'AFE'),
('ZM','ZMB',894,'Zambie',              'Zambia',               'AFE'),
('ZW','ZWE',716,'Zimbabwe',            'Zimbabwe',             'AFE'),
-- Afrique Centrale
('AO','AGO',24, 'Angola',              'Angola',               'AFC'),
('CM','CMR',120,'Cameroun',            'Cameroon',             'AFC'),
('CF','CAF',140,'Rép. centrafricaine', 'Central African Rep.', 'AFC'),
('TD','TCD',148,'Tchad',               'Chad',                 'AFC'),
('CG','COG',178,'Congo',               'Congo',                'AFC'),
('CD','COD',180,'Rép. dém. du Congo',  'DR Congo',             'AFC'),
('GQ','GNQ',226,'Guinée équatoriale',  'Equatorial Guinea',    'AFC'),
('GA','GAB',266,'Gabon',               'Gabon',                'AFC'),
('ST','STP',678,'São Tomé-et-Príncipe','São Tomé and Príncipe','AFC'),
-- Afrique Australe
('BW','BWA',72, 'Botswana',            'Botswana',             'AFS'),
('SZ','SWZ',748,'Eswatini',            'Eswatini',             'AFS'),
('LS','LSO',426,'Lesotho',             'Lesotho',              'AFS'),
('NA','NAM',516,'Namibie',             'Namibia',              'AFS'),
('ZA','ZAF',710,'Afrique du Sud',      'South Africa',         'AFS')
ON CONFLICT DO NOTHING;

-- ============================================================
-- 3. BLOCS RÉGIONAUX
-- ============================================================

CREATE TABLE IF NOT EXISTS rf.regional_blocs (
    code        VARCHAR(15)  PRIMARY KEY,
    name_fr     TEXT,
    name_en     TEXT,
    description TEXT,
    created_at  TIMESTAMP    DEFAULT now()
);

CREATE TABLE IF NOT EXISTS rf.country_blocs (
    country_iso2       CHAR(2)     REFERENCES rf.countries(iso2),
    bloc_code          VARCHAR(15) REFERENCES rf.regional_blocs(code),
    membership_status  TEXT        DEFAULT 'member',
    join_date          DATE,
    PRIMARY KEY (country_iso2, bloc_code)
);

INSERT INTO rf.regional_blocs (code, name_fr, name_en) VALUES
('UA',    'Union Africaine',                          'African Union'),
('CEDEAO','Communauté éco. des États Afrique Ouest',  'ECOWAS'),
('CEMAC', 'Communauté éco. et monétaire Afrique Cent.','CEMAC'),
('SADC',  'Communauté de développement Afrique australe','SADC'),
('EAC',   'Communauté est-africaine',                 'East African Community'),
('CEN-SAD','Communauté des États sahélo-sahariens',   'CEN-SAD'),
('IGAD',  'Autorité intergouvernementale développement','IGAD'),
('UMA',   'Union du Maghreb arabe',                   'Arab Maghreb Union'),
('COMESA','Marché commun Afrique orientale et australe','COMESA')
ON CONFLICT DO NOTHING;

-- ============================================================
-- 4. UNITS (table unique canonique)
-- ============================================================

CREATE TABLE IF NOT EXISTS rf.units (
    code        VARCHAR(20)  PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    symbol      VARCHAR(20),
    unit_type   VARCHAR(30)  NOT NULL
        CHECK (unit_type IN ('ratio','currency','quantity','index','score','count','years')),
    description TEXT,
    is_active   BOOLEAN      DEFAULT TRUE,
    created_at  TIMESTAMP    DEFAULT now()
);

INSERT INTO rf.units (code, name, symbol, unit_type, description) VALUES
('PERCENT',    'Pourcentage',          '%',       'ratio',    'Valeur relative en pourcentage'),
('USD',        'Dollar US courant',    'USD',     'currency', 'Valeur monétaire nominale'),
('USD_CONST',  'Dollar US constant',   'USD_c',   'currency', 'Valeur ajustée à l''inflation (base 2015)'),
('USD_PC',     'USD par habitant',     'USD/hab', 'currency', 'Valeur monétaire par habitant'),
('TONNES',     'Tonnes métriques',     't',       'quantity', 'Poids ou volume physique'),
('KG',         'Kilogrammes',          'kg',      'quantity', 'Unité de masse'),
('MWH',        'Mégawatt-heure',       'MWh',     'quantity', 'Unité d''énergie'),
('PERSONS',    'Personnes',            'pers',    'quantity', 'Effectif humain ou population'),
('NB',         'Nombre',               'nb',      'count',    'Quantité entière sans unité'),
('INDEX',      'Indice standard',      'idx',     'index',    'Indice comparatif base 100'),
('SCORE',      'Score non borné',      'pts',     'score',    'Score d''évaluation composite'),
('SCORE_0_100','Score 0–100',          '/100',    'score',    'Score normalisé borné 0–100'),
('SCORE_0_10', 'Score 0–10',           '/10',     'score',    'Score normalisé borné 0–10'),
('SCORE_0_1',  'Score 0–1',            '/1',      'score',    'Score normalisé borné 0–1'),
('YEARS',      'Années',               'ans',     'years',    'Durée en années'),
('RATIO',      'Ratio',                'ratio',   'ratio',    'Rapport entre deux grandeurs')
ON CONFLICT DO NOTHING;

-- ============================================================
-- 5. PILLARS (8 piliers de souveraineté)
-- ============================================================

CREATE TABLE IF NOT EXISTS rf.pillars (
    code          VARCHAR(10)  PRIMARY KEY,
    name_fr       TEXT         NOT NULL,
    name_en       TEXT         NOT NULL,
    description   TEXT,
    display_order INT          DEFAULT 0,
    created_at    TIMESTAMP    DEFAULT now()
);

INSERT INTO rf.pillars (code, name_fr, name_en, description, display_order) VALUES
('PMIN','Souveraineté minière',          'Mining Sovereignty',          'Contrôle des ressources minières et extractives',     1),
('PMON','Souveraineté monétaire',        'Monetary Sovereignty',        'Autonomie monétaire, financière et fiscale',          2),
('PECO','Souveraineté économique',       'Economic Sovereignty',        'Structure productive, industrialisation, commerce',   3),
('PGEO','Souveraineté géopolitique',     'Geopolitical Sovereignty',    'Influence diplomatique et positionnement international',4),
('PMIL','Souveraineté militaire',        'Military Sovereignty',        'Capacités défensives et sécurité territoriale',       5),
('PHUM','Souveraineté humaine',          'Human Sovereignty',           'Capital humain, santé, éducation, cohésion sociale',  6),
('PENV','Souveraineté environnementale', 'Environmental Sovereignty',   'Résilience climatique et gestion des ressources naturelles',7),
('PNUM','Souveraineté numérique',        'Digital Sovereignty',         'Infrastructure numérique, cybersécurité, économie digitale',8)
ON CONFLICT DO NOTHING;

-- ============================================================
-- 6. META_INDICATORS (1 meta par pilier = agrégat pilier)
-- ============================================================

CREATE TABLE IF NOT EXISTS rf.meta_indicators (
    meta_code   VARCHAR(20)  PRIMARY KEY,
    name_fr     TEXT         NOT NULL,
    name_en     TEXT         NOT NULL,
    pillar_code VARCHAR(10)  NOT NULL REFERENCES rf.pillars(code),
    description TEXT,
    created_at  TIMESTAMP    DEFAULT now()
);

INSERT INTO rf.meta_indicators (meta_code, name_fr, name_en, pillar_code) VALUES
('SOV_PMIN','Indice souveraineté minière',          'Mining Sovereignty Index',          'PMIN'),
('SOV_PMON','Indice souveraineté monétaire',        'Monetary Sovereignty Index',        'PMON'),
('SOV_PECO','Indice souveraineté économique',       'Economic Sovereignty Index',        'PECO'),
('SOV_PGEO','Indice souveraineté géopolitique',     'Geopolitical Sovereignty Index',    'PGEO'),
('SOV_PMIL','Indice souveraineté militaire',        'Military Sovereignty Index',        'PMIL'),
('SOV_PHUM','Indice souveraineté humaine',          'Human Sovereignty Index',           'PHUM'),
('SOV_PENV','Indice souveraineté environnementale', 'Environmental Sovereignty Index',   'PENV'),
('SOV_PNUM','Indice souveraineté numérique',        'Digital Sovereignty Index',         'PNUM')
ON CONFLICT DO NOTHING;

-- ============================================================
-- 7. INDICATORS (120 indicateurs — 15 par pilier)
-- ============================================================

CREATE TABLE IF NOT EXISTS rf.indicators (
    code          VARCHAR(30)  PRIMARY KEY,
    name_fr       TEXT         NOT NULL,
    name_en       TEXT         NOT NULL,
    pillar_code   VARCHAR(10)  NOT NULL  REFERENCES rf.pillars(code),
    unit_code     VARCHAR(20)  NOT NULL  REFERENCES rf.units(code),
    direction     CHAR(1)      NOT NULL  CHECK (direction IN ('+','-')),
    description   TEXT,
    display_order INT          DEFAULT 0,
    is_active     BOOLEAN      DEFAULT TRUE,
    created_at    TIMESTAMP    DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rf_indicators_pillar ON rf.indicators(pillar_code);

INSERT INTO rf.indicators
    (code, name_fr, name_en, pillar_code, unit_code, direction, description, display_order)
VALUES

-- ── PILIER MINIER (PMIN) ──────────────────────────────────
('MIN_RES', 'Valeur des réserves minières',   'Mineral reserves value',      'PMIN','USD',       '+','Valeur estimée des réserves exploitables',          1),
('MIN_EXP', 'Exportations minières',          'Mining exports',              'PMIN','USD',       '+','Valeur totale des exportations minières',            2),
('MIN_VAL', 'Valeur ajoutée minière / PIB',   'Mining value added / GDP',    'PMIN','PERCENT',   '+','Contribution du secteur minier au PIB',             3),
('MIN_LOC', 'Transformation locale minerais', 'Local mineral processing',    'PMIN','PERCENT',   '+','Part des minerais transformés localement',           4),
('MIN_DEP', 'Dépendance exportations minières','Mining export dependency',   'PMIN','PERCENT',   '-','Part du minerai dans les exportations totales',      5),
('MIN_EMP', 'Emplois secteur minier',         'Mining employment',           'PMIN','PERSONS',   '+','Nombre d''emplois directs dans les mines',           6),
('MIN_INV', 'Investissements miniers',        'Mining investment',           'PMIN','USD',       '+','IDE et investissements nationaux dans le secteur',   7),
('MIN_TAX', 'Recettes fiscales minières',     'Mining fiscal revenue',       'PMIN','PERCENT',   '+','Part des recettes minières dans recettes totales',   8),
('MIN_GOV', 'Qualité gouvernance minière',    'Mining governance quality',   'PMIN','SCORE_0_100','+','Indice de gouvernance minière (ITIE, EITI)',         9),
('MIN_TRAC','Traçabilité chaîne minière',     'Mining chain traceability',   'PMIN','SCORE_0_100','+','Niveau de traçabilité et certification',            10),
('MIN_CERT','Conformité certifications',      'Mining certification compliance','PMIN','SCORE_0_100','+','Conformité EITI, standards internationaux',        11),
('MIN_ENV', 'Impact environnemental minier',  'Mining environmental impact', 'PMIN','SCORE_0_100','-','Pollution et dégradation liées à l''extraction',    12),
('MIN_SEC', 'Sécurité sites miniers',         'Mining site security',        'PMIN','SCORE_0_100','+','Contrôle et sécurisation des sites',                13),
('MIN_TECH','Niveau technologique minier',    'Mining technology level',     'PMIN','SCORE_0_100','+','Degré de modernisation technologique',              14),
('MIN_DIV', 'Diversification minière',        'Mining diversification',      'PMIN','INDEX',     '+','Diversité des minerais exploités',                  15),

-- ── PILIER MONÉTAIRE (PMON) ───────────────────────────────
('MON_INF', 'Taux d''inflation',              'Inflation rate',              'PMON','PERCENT',   '-','Taux d''inflation annuel moyen',                    1),
('MON_RES', 'Réserves de change',             'Foreign reserves',            'PMON','USD',       '+','Réserves en devises de la banque centrale',         2),
('MON_EXT', 'Dette extérieure / PIB',         'External debt / GDP',         'PMON','PERCENT',   '-','Ratio dette extérieure sur PIB',                    3),
('MON_CUR', 'Stabilité monétaire',            'Currency stability',          'PMON','INDEX',     '+','Indice de stabilité de la monnaie nationale',       4),
('MON_PAY', 'Balance des paiements',          'Balance of payments',         'PMON','USD',       '+','Solde de la balance courante',                      5),
('MON_M2',  'Masse monétaire M2 / PIB',       'Money supply M2 / GDP',       'PMON','PERCENT',   '+','Profondeur financière de l''économie',               6),
('MON_AUT', 'Autonomie banque centrale',      'Central bank independence',   'PMON','SCORE_0_100','+','Degré d''indépendance de la banque centrale',       7),
('MON_DIG', 'Adoption monnaie numérique',     'Digital currency adoption',   'PMON','SCORE_0_100','+','Taux d''adoption CBDC et paiements numériques',    8),
('MON_CAP', 'Contrôle des capitaux',          'Capital control capacity',    'PMON','SCORE_0_100','+','Capacité à réguler les flux de capitaux',           9),
('MON_FIN', 'Profondeur financière',          'Financial depth',             'PMON','INDEX',     '+','Accès aux services financiers formels',             10),
('MON_STB', 'Stabilité bancaire',             'Banking stability',           'PMON','SCORE_0_100','+','Solidité du système bancaire (CAR, NPL)',           11),
('MON_INT', 'Taux d''intérêt réel',           'Real interest rate',          'PMON','PERCENT',   '-','Taux réel moyen de l''économie',                   12),
('MON_EXR', 'Volatilité taux de change',      'Exchange rate volatility',    'PMON','INDEX',     '-','Instabilité du taux de change',                    13),
('MON_DET', 'Service de la dette / recettes', 'Debt service ratio',          'PMON','PERCENT',   '-','Part du service de la dette dans les recettes',     14),
('MON_CRY', 'Adoption cryptomonnaies',        'Crypto adoption',             'PMON','PERCENT',   '+','Part des transactions crypto dans le total',        15),

-- ── PILIER ÉCONOMIQUE (PECO) ──────────────────────────────
('ECO_GDP', 'PIB par habitant',               'GDP per capita',              'PECO','USD_CONST', '+','PIB par habitant en dollars constants 2015',         1),
('ECO_GRW', 'Croissance économique',          'GDP growth',                  'PECO','PERCENT',   '+','Taux de croissance annuel du PIB',                   2),
('ECO_DIV', 'Diversification économique',     'Economic diversification',    'PECO','INDEX',     '+','Indice Herfindahl inversé des exportations',         3),
('ECO_IND', 'Part industrie dans PIB',        'Industrialization share',     'PECO','PERCENT',   '+','Part du secteur industriel dans le PIB',             4),
('ECO_EXP', 'Exportations manufacturières',   'Manufactured exports',        'PECO','PERCENT',   '+','Part des produits manufacturés dans les exports',    5),
('ECO_IMP', 'Dépendance aux importations',    'Import dependency',           'PECO','PERCENT',   '-','Part des importations dans la consommation totale',  6),
('ECO_INV', 'Taux d''investissement brut',    'Gross investment rate',       'PECO','PERCENT',   '+','Formation brute de capital fixe / PIB',              7),
('ECO_EMP', 'Emploi formel',                  'Formal employment',           'PECO','PERCENT',   '+','Part de l''emploi formel dans l''emploi total',      8),
('ECO_PRO', 'Productivité du travail',        'Labour productivity',         'PECO','INDEX',     '+','PIB par travailleur, base 100',                      9),
('ECO_FDI', 'Flux d''IDE nets',               'Net FDI flows',               'PECO','USD',       '+','Investissements directs étrangers nets',            10),
('ECO_SME', 'Contribution des PME',           'SME contribution',            'PECO','PERCENT',   '+','Part des PME dans le PIB',                          11),
('ECO_LOG', 'Performance logistique',         'Logistics performance',       'PECO','SCORE_0_100','+','Indice LPI Banque mondiale',                       12),
('ECO_TAX', 'Pression fiscale',               'Tax revenue / GDP',           'PECO','PERCENT',   '+','Recettes fiscales en % du PIB',                    13),
('ECO_AGR', 'Sécurité alimentaire',           'Food security index',         'PECO','SCORE_0_100','+','Indice mondial de sécurité alimentaire',           14),
('ECO_INF', 'Inflation économique',           'Economic inflation',          'PECO','PERCENT',   '-','Inflation des prix à la consommation',              15),

-- ── PILIER GÉOPOLITIQUE (PGEO) ────────────────────────────
('GEO_DIP', 'Présence diplomatique',          'Diplomatic presence',         'PGEO','PERSONS',   '+','Nombre de représentations diplomatiques à l''étranger',1),
('GEO_TRD', 'Accords commerciaux actifs',     'Trade agreements',            'PGEO','NB',        '+','Nombre d''accords de libre-échange en vigueur',     2),
('GEO_SAN', 'Exposition aux sanctions',       'Sanctions exposure',          'PGEO','SCORE_0_100','-','Niveau d''exposition aux sanctions internationales',3),
('GEO_ORG', 'Participation organisations intl','International org. membership','PGEO','NB',      '+','Nombre d''organisations internationales membres',   4),
('GEO_ALL', 'Alliances stratégiques',         'Strategic alliances',         'PGEO','NB',        '+','Nombre de partenariats stratégiques actifs',         5),
('GEO_POW', 'Influence régionale',            'Regional influence',          'PGEO','SCORE_0_100','+','Indice d''influence dans la sous-région',           6),
('GEO_CON', 'Conflits frontaliers actifs',    'Active border conflicts',     'PGEO','NB',        '-','Nombre de conflits frontaliers en cours',            7),
('GEO_PEA', 'Participation opérations de paix','Peacekeeping participation', 'PGEO','PERSONS',   '+','Personnel déployé en opérations de maintien de paix',8),
('GEO_SOF', 'Soft power',                     'Soft power index',            'PGEO','SCORE_0_100','+','Indice d''influence culturelle et normative',       9),
('GEO_MIG', 'Pression migratoire',            'Migration pressure',          'PGEO','INDEX',     '-','Flux nets d''émigration rapportés à la population', 10),
('GEO_NET', 'Diplomatie numérique',           'Digital diplomacy',           'PGEO','SCORE_0_100','+','Capacité de diplomatie via les canaux numériques',  11),
('GEO_RES', 'Résilience géopolitique',        'Geopolitical resilience',     'PGEO','SCORE_0_100','+','Capacité à absorber les chocs géopolitiques',       12),
('GEO_RSK', 'Risque géopolitique',            'Geopolitical risk',           'PGEO','SCORE_0_100','-','Indice de risque politique et sécuritaire',         13),
('GEO_CUL', 'Influence culturelle',           'Cultural influence',          'PGEO','SCORE_0_100','+','Rayonnement culturel international',                14),
('GEO_STAB','Stabilité politique',            'Political stability',         'PGEO','SCORE_0_100','+','Indice de stabilité politique (WGI)',               15),

-- ── PILIER MILITAIRE (PMIL) ───────────────────────────────
('MIL_EXP', 'Dépenses militaires / PIB',      'Military expenditure / GDP',  'PMIL','PERCENT',   '+','Part des dépenses militaires dans le PIB',           1),
('MIL_PER', 'Personnel militaire actif',      'Active military personnel',   'PMIL','PERSONS',   '+','Effectif des forces armées actives',                 2),
('MIL_EQU', 'Équipement militaire',           'Military equipment index',    'PMIL','INDEX',     '+','Indice de modernisation de l''équipement',           3),
('MIL_IND', 'Industrie de défense',           'Defence industry capacity',   'PMIL','SCORE_0_100','+','Capacité de production d''équipements défense',     4),
('MIL_DEP', 'Dépendance en armements',        'Arms import dependency',      'PMIL','PERCENT',   '-','Part des importations d''armes dans le total',       5),
('MIL_SEC', 'Sécurité intérieure',            'Internal security',           'PMIL','SCORE_0_100','+','Indice de sécurité et ordre public',                6),
('MIL_TER', 'Risque terroriste',              'Terrorism risk index',        'PMIL','SCORE_0_100','-','Indice global du terrorisme (inversé)',              7),
('MIL_BRD', 'Contrôle des frontières',        'Border control',              'PMIL','SCORE_0_100','+','Capacité de surveillance et contrôle frontalier',   8),
('MIL_MIS', 'Missions internationales',       'International missions',      'PMIL','NB',        '+','Nombre de missions de paix en cours',                9),
('MIL_RES', 'Forces de réserve',              'Military reserves',           'PMIL','PERSONS',   '+','Effectif des forces de réserve mobilisables',       10),
('MIL_CYB', 'Cyberdéfense',                   'Cyber defence',               'PMIL','SCORE_0_100','+','Capacité de cyberdéfense nationale',               11),
('MIL_LOG', 'Logistique militaire',           'Military logistics',          'PMIL','SCORE_0_100','+','Indice de capacité logistique des forces',          12),
('MIL_INT', 'Interopérabilité forces',        'Forces interoperability',     'PMIL','SCORE_0_100','+','Capacité d''interopérabilité avec alliés',           13),
('MIL_STR', 'Capacité de projection',         'Strategic projection',        'PMIL','SCORE_0_100','+','Capacité de projection de force hors frontières',   14),
('MIL_STB', 'Stabilité des forces armées',    'Military stability',          'PMIL','SCORE_0_100','+','Cohésion et loyauté institutionnelle des forces',   15),

-- ── PILIER HUMAIN (PHUM) ──────────────────────────────────
('HUM_POP', 'Population active',              'Active population',           'PHUM','PERSONS',   '+','Taille de la population en âge de travailler',       1),
('HUM_EDU', 'Indice d''éducation',            'Education index',             'PHUM','INDEX',     '+','Indice d''éducation (IDH composante éducation)',     2),
('HUM_LIT', 'Taux d''alphabétisation',        'Literacy rate',               'PHUM','PERCENT',   '+','Taux d''alphabétisation des adultes (15+)',          3),
('HUM_HEA', 'Espérance de vie',               'Life expectancy',             'PHUM','YEARS',     '+','Espérance de vie à la naissance',                    4),
('HUM_INF', 'Mortalité infantile',            'Infant mortality rate',       'PHUM','PERCENT',   '-','Taux de mortalité des moins de 5 ans (pour 1000)',   5),
('HUM_FOO', 'Sécurité alimentaire',           'Food security score',         'PHUM','SCORE_0_100','+','Indice de sécurité alimentaire',                   6),
('HUM_POV', 'Taux de pauvreté',               'Poverty rate',                'PHUM','PERCENT',   '-','Part de la population sous le seuil de pauvreté',   7),
('HUM_GEN', 'Égalité de genre',               'Gender equality index',       'PHUM','SCORE_0_100','+','Indice mondial d''écart de genre (WEF)',            8),
('HUM_MIG', 'Fuite des cerveaux',             'Brain drain index',           'PHUM','PERCENT',   '-','Émigration des diplômés du supérieur',               9),
('HUM_WAT', 'Accès à l''eau potable',         'Clean water access',          'PHUM','PERCENT',   '+','Part de la population avec accès eau potable',      10),
('HUM_SAN', 'Accès à l''assainissement',      'Sanitation access',           'PHUM','PERCENT',   '+','Part de la population avec accès assainissement',   11),
('HUM_DIG', 'Compétences numériques',         'Digital skills',              'PHUM','SCORE_0_100','+','Niveau de compétences numériques de la population',12),
('HUM_HEA2','Accès aux soins de santé',       'Healthcare access',           'PHUM','SCORE_0_100','+','Indice d''accès et qualité des soins (HAQ)',        13),
('HUM_SOC', 'Cohésion sociale',               'Social cohesion',             'PHUM','SCORE_0_100','+','Indice de cohésion et capital social',              14),
('HUM_RES', 'Résilience sociale',             'Social resilience',           'PHUM','SCORE_0_100','+','Capacité de la société à absorber les chocs',       15),

-- ── PILIER ENVIRONNEMENTAL (PENV) ─────────────────────────
('ENV_CO2', 'Émissions CO2 par habitant',     'CO2 emissions per capita',    'PENV','TONNES',    '-','Émissions de CO2 par habitant',                      1),
('ENV_FOR', 'Couverture forestière',          'Forest coverage',             'PENV','PERCENT',   '+','Part du territoire couvert de forêts',               2),
('ENV_WAT', 'Ressources en eau douce',        'Freshwater resources',        'PENV','INDEX',     '+','Disponibilité en eau douce renouvelable',            3),
('ENV_LAN', 'Dégradation des terres',         'Land degradation',            'PENV','PERCENT',   '-','Part des terres dégradées ou désertifiées',          4),
('ENV_BIO', 'Biodiversité',                   'Biodiversity index',          'PENV','SCORE_0_100','+','Indice de biodiversité (espèces menacées, zones)',  5),
('ENV_ENR', 'Énergies renouvelables',         'Renewable energy share',      'PENV','PERCENT',   '+','Part des renouvelables dans la production d''énergie',6),
('ENV_POL', 'Indice de pollution',            'Pollution index',             'PENV','SCORE_0_100','-','Qualité de l''air, pollution eau et sols',          7),
('ENV_RSK', 'Risque climatique',              'Climate risk index',          'PENV','SCORE_0_100','-','Exposition aux événements climatiques extrêmes',    8),
('ENV_ADA', 'Adaptation climatique',          'Climate adaptation',          'PENV','SCORE_0_100','+','Capacité d''adaptation aux changements climatiques', 9),
('ENV_PRO', 'Aires protégées',                'Protected areas',             'PENV','PERCENT',   '+','Part du territoire en aires protégées',             10),
('ENV_FIS', 'Stocks halieutiques',            'Fish stock health',           'PENV','INDEX',     '+','Santé des stocks de poissons exploités',            11),
('ENV_SOL', 'Fertilité des sols',             'Soil fertility',              'PENV','SCORE_0_100','+','Indice de fertilité et santé des sols',            12),
('ENV_WAS', 'Gestion des déchets',            'Waste management',            'PENV','SCORE_0_100','+','Taux de collecte et traitement des déchets',        13),
('ENV_ENE', 'Intensité énergétique',          'Energy intensity',            'PENV','INDEX',     '-','Consommation d''énergie par unité de PIB',          14),
('ENV_ECO', 'Résilience écologique',          'Ecological resilience',       'PENV','SCORE_0_100','+','Capacité des écosystèmes à se régénérer',          15),

-- ── PILIER NUMÉRIQUE (PNUM) ───────────────────────────────
('NUM_INT', 'Utilisateurs internet',          'Internet users',              'PNUM','PERCENT',   '+','Part de la population utilisant internet',           1),
('NUM_MOB', 'Abonnements mobiles',            'Mobile subscriptions',        'PNUM','PERSONS',   '+','Nombre d''abonnements mobiles actifs',               2),
('NUM_DAT', 'Centres de données nationaux',   'National data centers',       'PNUM','NB',        '+','Nombre de data centers sur le territoire',           3),
('NUM_CLO', 'Adoption du cloud',              'Cloud adoption',              'PNUM','SCORE_0_100','+','Niveau d''adoption des services cloud',            4),
('NUM_CYB', 'Cybersécurité nationale',        'National cybersecurity',      'PNUM','SCORE_0_100','+','Indice global de cybersécurité (UIT)',             5),
('NUM_GOV', 'Gouvernement électronique',      'E-government index',          'PNUM','SCORE_0_100','+','Indice de développement e-gouvernement (EGDI)',    6),
('NUM_DIG', 'Économie numérique / PIB',       'Digital economy share',       'PNUM','PERCENT',   '+','Part de l''économie numérique dans le PIB',         7),
('NUM_STU', 'Formation numérique',            'Digital education',           'PNUM','SCORE_0_100','+','Accès à la formation numérique et aux STEM',       8),
('NUM_AI',  'Recherche et développement IA',  'AI research capacity',        'PNUM','SCORE_0_100','+','Capacité nationale en intelligence artificielle',  9),
('NUM_FIB', 'Couverture fibre optique',       'Fiber coverage',              'PNUM','INDEX',     '+','Étendue du réseau fibre national',                 10),
('NUM_SAT', 'Satellites nationaux',           'National satellites',         'PNUM','NB',        '+','Nombre de satellites nationaux opérationnels',      11),
('NUM_FIN', 'Adoption fintech',               'Fintech adoption',            'PNUM','SCORE_0_100','+','Niveau d''adoption des services fintech',          12),
('NUM_DAT2','Souveraineté des données',       'Data sovereignty',            'PNUM','SCORE_0_100','+','Contrôle national des données (lois, hébergement)',13),
('NUM_REG', 'Régulation numérique',           'Digital regulation',          'PNUM','SCORE_0_100','+','Maturité du cadre légal numérique',                14),
('NUM_RES', 'Résilience numérique',           'Digital resilience',          'PNUM','SCORE_0_100','+','Capacité de résistance aux cybermenaces',          15)

ON CONFLICT DO NOTHING;

-- ============================================================
-- 8. INDICATOR_META_LINK (poids initiaux équipondérés 1/15)
-- ============================================================

CREATE TABLE IF NOT EXISTS rf.indicator_meta_link (
    meta_code      VARCHAR(20)   REFERENCES rf.meta_indicators(meta_code),
    indicator_code VARCHAR(30)   REFERENCES rf.indicators(code),
    weight         NUMERIC(10,8) NOT NULL DEFAULT 0.06666667,
    is_active      BOOLEAN       DEFAULT TRUE,
    created_at     TIMESTAMP     DEFAULT now(),
    PRIMARY KEY (meta_code, indicator_code)
);

INSERT INTO rf.indicator_meta_link (meta_code, indicator_code, weight)
SELECT
    'SOV_' || i.pillar_code,
    i.code,
    ROUND(1.0 / 15, 8)
FROM rf.indicators i
ON CONFLICT DO NOTHING;

-- ============================================================
-- 9. VUE DE CONTRÔLE
-- ============================================================

CREATE OR REPLACE VIEW rf.v_indicator_full AS
SELECT
    i.code,
    i.name_fr,
    i.name_en,
    p.name_fr   AS pillar_fr,
    u.code      AS unit_code,
    u.unit_type,
    i.direction,
    i.is_active
FROM rf.indicators i
JOIN rf.pillars p ON p.code = i.pillar_code
JOIN rf.units   u ON u.code = i.unit_code;

-- ============================================================
-- 10. PROTECTION RÉFÉRENTIEL (triggers anti-mutation)
-- ============================================================

CREATE OR REPLACE FUNCTION rf.protect_referential()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP IN ('UPDATE','DELETE') THEN
        RAISE EXCEPTION
            'RF immuable : mutation interdite (% sur %). Créez une nouvelle version.',
            TG_OP, TG_TABLE_NAME;
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_protect_pillars
BEFORE UPDATE OR DELETE ON rf.pillars
FOR EACH ROW EXECUTE FUNCTION rf.protect_referential();

CREATE OR REPLACE TRIGGER trg_protect_indicators
BEFORE UPDATE OR DELETE ON rf.indicators
FOR EACH ROW EXECUTE FUNCTION rf.protect_referential();

COMMIT;

-- Vérification rapide
-- SELECT pillar_code, COUNT(*) FROM rf.indicators GROUP BY pillar_code ORDER BY pillar_code;
-- SELECT COUNT(*) FROM rf.countries;   -- attendu : 54
-- SELECT COUNT(*) FROM rf.indicators;  -- attendu : 120
