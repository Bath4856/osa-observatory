-- =========================================================
-- osa-observatory – schéma osa
-- Pilier PMIN : tables de données brutes + indices calculés
-- Version consolidée (remplace patch_pmin.sql et patch_pmin_ia.sql)
--
-- Convention : schéma unique osa.
-- Prérequis   : osa.country(id) doit exister avant ce script.
-- =========================================================

-- ── Référentiels ──────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS osa.mineral_resource (
    id          SERIAL PRIMARY KEY,
    code        VARCHAR(50)  UNIQUE NOT NULL,  -- ex: 'Gold', 'Copper'
    label       VARCHAR(100) NOT NULL,
    category    VARCHAR(50)  NOT NULL,         -- Metal | Hydrocarbon | Precious | Non-metal
    description TEXT
);

-- Mapping code HS (4 chiffres) ↔ ressource minière
CREATE TABLE IF NOT EXISTS osa.mineral_mapping (
    id            SERIAL PRIMARY KEY,
    hs_code       VARCHAR(10) UNIQUE NOT NULL,  -- ex: '2603'
    resource_id   INTEGER NOT NULL
                    REFERENCES osa.mineral_resource(id) ON DELETE CASCADE,
    wiki_keywords TEXT,   -- mots-clés séparés par virgule pour detect_min_pmin
    producers     TEXT    -- pays producteurs (informatif)
);

-- ── PGEO — sites miniers géolocalisés ─────────────────────────────────────

CREATE TABLE IF NOT EXISTS osa.pgeo_site (
    id          SERIAL PRIMARY KEY,
    site_code   VARCHAR(50)  UNIQUE NOT NULL,   -- ex: 'CMR_MINE_001'
    name        VARCHAR(200) NOT NULL,
    country_id  INTEGER NOT NULL REFERENCES osa.country(id),
    resource_id INTEGER REFERENCES osa.mineral_resource(id),
    latitude    DOUBLE PRECISION,
    longitude   DOUBLE PRECISION,
    source      VARCHAR(100),                   -- 'USGS' | 'Wikipedia' | 'Admin'
    metadata    JSONB
);

-- ── PMIN – données brutes par indicateur ──────────────────────────────────

-- PMIN_SEC : événements de sécurité autour des sites (ACLED + UCDP)
CREATE TABLE IF NOT EXISTS osa.pmin_security_event (
    id          SERIAL PRIMARY KEY,
    site_id     INTEGER NOT NULL
                  REFERENCES osa.pgeo_site(id) ON DELETE CASCADE,
    source      VARCHAR(10) NOT NULL CHECK (source IN ('ACLED','UCDP')),
    event_date  DATE    NOT NULL,
    event_type  VARCHAR(100),
    fatalities  INTEGER DEFAULT 0,
    raw_payload JSONB
);

-- PMIN_GOV : gouvernance EITI agrégée au niveau pays × année
CREATE TABLE IF NOT EXISTS osa.pmin_governance (
    id          SERIAL PRIMARY KEY,
    country_id  INTEGER NOT NULL REFERENCES osa.country(id) ON DELETE CASCADE,
    year        INTEGER NOT NULL,
    gov_amount  NUMERIC,   -- revenus gouvernementaux (EITI revenues)
    tax_amount  NUMERIC,   -- paiements entreprises   (EITI company-payments)
    eiti_total  NUMERIC GENERATED ALWAYS AS (COALESCE(gov_amount,0) + COALESCE(tax_amount,0)) STORED,
    UNIQUE (country_id, year)
);

-- PMIN_COM : flux commerciaux Comtrade agrégés pays × ressource × année
CREATE TABLE IF NOT EXISTS osa.pmin_trade (
    id          SERIAL PRIMARY KEY,
    reporter_id INTEGER NOT NULL REFERENCES osa.country(id) ON DELETE CASCADE,
    resource_id INTEGER NOT NULL REFERENCES osa.mineral_resource(id),
    year        INTEGER NOT NULL,
    flow        VARCHAR(10) NOT NULL CHECK (flow IN ('import','export')),
    trade_value NUMERIC,
    UNIQUE (reporter_id, resource_id, year, flow)
);

-- ── PMIN – indices calculés ───────────────────────────────────────────────

-- Indices PMIN agrégés au niveau site × année (résultat final du fetcher)
CREATE TABLE IF NOT EXISTS osa.pmin_index_site (
    id          SERIAL PRIMARY KEY,
    site_id     INTEGER NOT NULL
                  REFERENCES osa.pgeo_site(id) ON DELETE CASCADE,
    year        INTEGER NOT NULL,
    pmin_sec    NUMERIC CHECK (pmin_sec    BETWEEN 0 AND 1),
    pmin_gov    NUMERIC CHECK (pmin_gov    BETWEEN 0 AND 1),
    pmin_com    NUMERIC CHECK (pmin_com    BETWEEN 0 AND 1),
    pmin_final  NUMERIC CHECK (pmin_final  BETWEEN 0 AND 1),
    -- pondérations utilisées (traçabilité)
    w_sec       NUMERIC DEFAULT 0.40,
    w_gov       NUMERIC DEFAULT 0.35,
    w_com       NUMERIC DEFAULT 0.25,
    computed_at TIMESTAMP DEFAULT now(),
    UNIQUE (site_id, year)
);

-- ── Logs d'import ─────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS osa.import_log (
    id           SERIAL PRIMARY KEY,
    source       VARCHAR(50) NOT NULL,  -- 'ACLED'|'UCDP'|'EITI'|'COMTRADE'|'SIPRI'
    imported_at  TIMESTAMP   NOT NULL DEFAULT now(),
    period_start INTEGER,
    period_end   INTEGER,
    row_count    INTEGER,
    details      TEXT
);

-- =========================================================
-- DONNÉES DE RÉFÉRENCE – ressources et mapping HS
-- (INSERT OR IGNORE via ON CONFLICT DO NOTHING)
-- =========================================================

INSERT INTO osa.mineral_resource (code, label, category) VALUES
-- HS 25 – minéraux non-métalliques
('Salt',              'Salt',               'Non-metal'),
('Graphite',          'Graphite',           'Non-metal'),
('Sand',              'Sand',               'Non-metal'),
('Clays',             'Clays',              'Non-metal'),
('Phosphate',         'Phosphate',          'Non-metal'),
('Pumice',            'Pumice',             'Non-metal'),
('Slate',             'Slate',              'Non-metal'),
('Granite',           'Granite',            'Non-metal'),
('Gravel',            'Gravel',             'Non-metal'),
('Dolomite',          'Dolomite',           'Non-metal'),
('Gypsum',            'Gypsum',             'Non-metal'),
('Limestone',         'Limestone',          'Non-metal'),
('Talc',              'Talc',               'Non-metal'),
-- HS 26 – minerais métalliques
('Iron',              'Iron',               'Metal'),
('Manganese',         'Manganese',          'Metal'),
('Copper',            'Copper',             'Metal'),
('Nickel',            'Nickel',             'Metal'),
('Cobalt',            'Cobalt',             'Metal'),
('Bauxite',           'Bauxite',            'Metal'),
('Lead',              'Lead',               'Metal'),
('Zinc',              'Zinc',               'Metal'),
('Tin',               'Tin',               'Metal'),
('Chromium',          'Chromium',           'Metal'),
('Tungsten',          'Tungsten',           'Metal'),
('Uranium',           'Uranium',            'Metal'),
('Molybdenum',        'Molybdenum',         'Metal'),
('Titanium',          'Titanium',           'Metal'),
('NiobiumTantalum',   'Niobium-Tantalum',   'Metal'),
('PreciousMetalOres', 'Precious Metal Ores','Metal'),
-- HS 27 – hydrocarbures
('Coal',              'Coal',               'Hydrocarbon'),
('CrudeOil',          'Crude Oil',          'Hydrocarbon'),
('NaturalGas',        'Natural Gas',        'Hydrocarbon'),
('Bitumen',           'Bitumen',            'Hydrocarbon'),
('OilShale',          'Oil Shale',          'Hydrocarbon'),
-- HS 71 – métaux précieux
('Diamonds',          'Diamonds',           'Precious'),
('PreciousStones',    'Precious Stones',    'Precious'),
('Silver',            'Silver',             'Precious'),
('Gold',              'Gold',               'Precious'),
('Platinum',          'Platinum',           'Precious')
ON CONFLICT (code) DO NOTHING;

-- Mapping HS → ressource (avec mots-clés Wikipedia et pays producteurs)
INSERT INTO osa.mineral_mapping (hs_code, resource_id, wiki_keywords, producers)
SELECT m.hs, r.id, m.kw, m.prod
FROM (VALUES
    ('2501','Salt',             'salt',                         'Senegal,Tunisia,Egypt'),
    ('2504','Graphite',         'graphite',                     'Madagascar,Mozambique'),
    ('2505','Sand',             'sand',                         'AllAfrica'),
    ('2508','Clays',            'clay',                         'Morocco,SouthAfrica'),
    ('2510','Phosphate',        'phosphate',                    'Morocco,Tunisia'),
    ('2513','Pumice',           'pumice',                       'Ethiopia'),
    ('2514','Slate',            'slate',                        'SouthAfrica'),
    ('2516','Granite',          'granite',                      'Zimbabwe,SouthAfrica'),
    ('2517','Gravel',           'gravel',                       'AllAfrica'),
    ('2519','Dolomite',         'dolomite',                     'SouthAfrica'),
    ('2520','Gypsum',           'gypsum',                       'Egypt'),
    ('2521','Limestone',        'limestone',                    'AllAfrica'),
    ('2526','Talc',             'talc',                         'Egypt,Morocco'),
    ('2601','Iron',             'iron,iron ore',                'Mauritania,Liberia,Algeria,SouthAfrica'),
    ('2602','Manganese',        'manganese',                    'Gabon,SouthAfrica,Ghana'),
    ('2603','Copper',           'copper',                       'DRC,Zambia'),
    ('2604','Nickel',           'nickel',                       'Madagascar,SouthAfrica'),
    ('2605','Cobalt',           'cobalt',                       'DRC'),
    ('2606','Bauxite',          'bauxite',                      'Guinea,Ghana'),
    ('2607','Lead',             'lead',                         'Morocco,Tunisia,Namibia'),
    ('2608','Zinc',             'zinc',                         'Namibia,SouthAfrica'),
    ('2609','Tin',              'tin',                          'DRC,Rwanda'),
    ('2610','Chromium',         'chromium,chrome',              'SouthAfrica'),
    ('2611','Tungsten',         'tungsten',                     'Rwanda'),
    ('2612','Uranium',          'uranium',                      'Niger,Namibia'),
    ('2613','Molybdenum',       'molybdenum',                   'Morocco'),
    ('2614','Titanium',         'titanium',                     'Mozambique,Madagascar'),
    ('2615','NiobiumTantalum',  'niobium,tantalum,coltan',      'Rwanda,DRC'),
    ('2616','PreciousMetalOres','precious metal',               'SouthAfrica,Ghana,DRC'),
    ('2701','Coal',             'coal',                         'SouthAfrica,Mozambique'),
    ('2709','CrudeOil',         'oil,crude oil',                'Nigeria,Angola,Algeria'),
    ('2711','NaturalGas',       'gas,natural gas',              'Algeria,Egypt,Mozambique'),
    ('2713','Bitumen',          'bitumen',                      'Nigeria'),
    ('2714','OilShale',         'oil shale',                    'Madagascar'),
    ('7102','Diamonds',         'diamond,kimberlite',           'Botswana,DRC,Angola'),
    ('7103','PreciousStones',   'gemstone,precious stone',      'Tanzania,Ethiopia'),
    ('7106','Silver',           'silver',                       'Morocco,SouthAfrica'),
    ('7108','Gold',             'gold,gold mine',               'Ghana,Mali,BurkinaFaso'),
    ('7110','Platinum',         'platinum,palladium',           'SouthAfrica')
) AS m(hs, res, kw, prod)
JOIN osa.mineral_resource r ON r.code = m.res
ON CONFLICT (hs_code) DO UPDATE
    SET wiki_keywords = EXCLUDED.wiki_keywords,
        producers     = EXCLUDED.producers;
