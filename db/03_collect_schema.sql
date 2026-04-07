-- ============================================================
-- OSA / ISA OBSERVATORY
-- BLOC 03 : SCHEMA COLLECT — INGESTION DES DONNÉES
-- Version   : 1.0.0
-- Dépend de  : 01_rf_schema.sql, 02_mm_schema.sql
-- Doctrine  : Python appelle les API, PL/pgSQL ne le fait JAMAIS
--             raw_data partitionné par année (2010 → N)
-- ============================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS collect;
SET search_path TO collect, rf, mm, public;

-- ============================================================
-- 1. DATA_PROVIDERS (fournisseurs techniques)
-- ============================================================

CREATE TABLE IF NOT EXISTS collect.data_providers (
    id                SERIAL       PRIMARY KEY,
    code              VARCHAR(20)  UNIQUE NOT NULL,
    name              VARCHAR(150) NOT NULL,
    base_url          TEXT,
    reliability_score NUMERIC(3,2) CHECK (reliability_score BETWEEN 0 AND 1),
    description       TEXT,
    is_active         BOOLEAN      DEFAULT TRUE,
    created_at        TIMESTAMP    DEFAULT now()
);

INSERT INTO collect.data_providers
    (code, name, base_url, reliability_score, description)
VALUES
('WB',     'World Bank Open Data',      'https://api.worldbank.org/v2',                      0.95, 'API REST JSON — WDI, WGI, IDA'),
('IMF',    'IMF DataMapper',            'https://www.imf.org/external/datamapper/api/v1',    0.94, 'API REST JSON — WEO, IFS, BOP'),
('UNDP',   'UNDP HDR Data',             'https://hdrdata.org/api',                           0.90, 'API REST JSON — IDH et composantes'),
('ITU',    'ITU Datahub',               'https://datahub.itu.int/api',                       0.88, 'API REST JSON — ICT Development Index'),
('FAO',    'FAOSTAT API',               'https://fenixservices.fao.org/faostat/api/v1',      0.88, 'API REST JSON — production agricole, forêts, eau'),
('WHO',    'WHO GHO API',               'https://ghoapi.azureedge.net/api',                  0.92, 'API REST OData — indicateurs santé'),
('SIPRI',  'SIPRI (CSV manuel)',         NULL,                                                0.87, 'Fichiers CSV annuels — dépenses militaires, armes'),
('UNEP',   'UNEP ENV Stats (CSV)',       NULL,                                                0.85, 'Fichiers CSV — indicateurs environnementaux'),
('SNCTM',  'SNCTM Base nationale',      NULL,                                                0.99, 'Source souveraine — accès restreint, import manuel')
ON CONFLICT (code) DO NOTHING;

-- ============================================================
-- 2. PROVIDER_ENDPOINTS (catalogue des endpoints par fournisseur)
--    URL templates : {iso3} = code pays ISO-3, {year} = année
-- ============================================================

CREATE TABLE IF NOT EXISTS collect.provider_endpoints (
    id              SERIAL       PRIMARY KEY,
    provider_id     INT          NOT NULL REFERENCES collect.data_providers(id),
    endpoint_code   VARCHAR(50)  UNIQUE NOT NULL,
    name            VARCHAR(150) NOT NULL,
    endpoint_url    TEXT         NOT NULL,
    output_format   VARCHAR(20)  DEFAULT 'json'
        CHECK (output_format IN ('json','csv','xml','xlsx')),
    description     TEXT,
    is_active       BOOLEAN      DEFAULT TRUE,
    created_at      TIMESTAMP    DEFAULT now()
);

-- World Bank endpoints
WITH wb AS (SELECT id FROM collect.data_providers WHERE code = 'WB')
INSERT INTO collect.provider_endpoints
    (provider_id, endpoint_code, name, endpoint_url, output_format, description)
SELECT wb.id, v.endpoint_code, v.name, v.endpoint_url, v.output_format, v.description
FROM wb, (VALUES
    ('WB_COUNTRY_INDICATOR',
     'WB — indicateur par pays',
     'https://api.worldbank.org/v2/country/{iso3}/indicator/{wb_code}?format=json&per_page=100&mrv=20',
     'json',
     'Requête principale WB : 1 indicateur, 1 pays, 20 dernières années'),
    ('WB_ALL_COUNTRIES',
     'WB — tous pays africains en une requête',
     'https://api.worldbank.org/v2/country/{iso3_list}/indicator/{wb_code}?format=json&per_page=5000&date=2010:2024',
     'json',
     'Requête batch : liste pays séparés par ;')
) AS v(endpoint_code, name, endpoint_url, output_format, description)
ON CONFLICT (endpoint_code) DO NOTHING;

-- IMF endpoints
WITH imf AS (SELECT id FROM collect.data_providers WHERE code = 'IMF')
INSERT INTO collect.provider_endpoints
    (provider_id, endpoint_code, name, endpoint_url, output_format, description)
SELECT imf.id, v.endpoint_code, v.name, v.endpoint_url, v.output_format, v.description
FROM imf, (VALUES
    ('IMF_WEO_INDICATOR',
     'IMF WEO — indicateur macro',
     'https://www.imf.org/external/datamapper/api/v1/{imf_code}/{iso2_list}',
     'json',
     'World Economic Outlook : inflation, dette, PIB, balance paiements'),
    ('IMF_IFS_INDICATOR',
     'IMF IFS — statistiques financières',
     'https://dataservices.imf.org/REST/SDMX_JSON.svc/CompactData/IFS/Q.{iso2}.{ifs_code}',
     'json',
     'International Financial Statistics : réserves, taux de change')
) AS v(endpoint_code, name, endpoint_url, output_format, description)
ON CONFLICT (endpoint_code) DO NOTHING;

-- UNDP endpoints
WITH undp AS (SELECT id FROM collect.data_providers WHERE code = 'UNDP')
INSERT INTO collect.provider_endpoints
    (provider_id, endpoint_code, name, endpoint_url, output_format, description)
SELECT undp.id, v.endpoint_code, v.name, v.endpoint_url, v.output_format, v.description
FROM undp, (VALUES
    ('UNDP_HDI',
     'UNDP — IDH et composantes',
     'https://hdrdata.org/api/composite/country/all/{undp_code}',
     'json',
     'IDH, espérance de vie, éducation, revenu national brut')
) AS v(endpoint_code, name, endpoint_url, output_format, description)
ON CONFLICT (endpoint_code) DO NOTHING;

-- ITU endpoints
WITH itu AS (SELECT id FROM collect.data_providers WHERE code = 'ITU')
INSERT INTO collect.provider_endpoints
    (provider_id, endpoint_code, name, endpoint_url, output_format, description)
SELECT itu.id, v.endpoint_code, v.name, v.endpoint_url, v.output_format, v.description
FROM itu, (VALUES
    ('ITU_INDICATOR',
     'ITU — indicateurs TIC',
     'https://datahub.itu.int/api/data/?indicator={itu_code}&e={iso3}&timePeriod=2010-2024',
     'json',
     'Accès internet, abonnements mobiles, cybersécurité')
) AS v(endpoint_code, name, endpoint_url, output_format, description)
ON CONFLICT (endpoint_code) DO NOTHING;

-- FAO endpoints
WITH fao AS (SELECT id FROM collect.data_providers WHERE code = 'FAO')
INSERT INTO collect.provider_endpoints
    (provider_id, endpoint_code, name, endpoint_url, output_format, description)
SELECT fao.id, v.endpoint_code, v.name, v.endpoint_url, v.output_format, v.description
FROM fao, (VALUES
    ('FAO_INDICATOR',
     'FAO — données agricoles et forêts',
     'https://fenixservices.fao.org/faostat/api/v1/en/data/{fao_dataset}?area={fao_area}&element={fao_element}&year=2010:2024&output_type=json',
     'json',
     'Production agricole, sécurité alimentaire, couverture forestière')
) AS v(endpoint_code, name, endpoint_url, output_format, description)
ON CONFLICT (endpoint_code) DO NOTHING;

-- WHO endpoints
WITH who AS (SELECT id FROM collect.data_providers WHERE code = 'WHO')
INSERT INTO collect.provider_endpoints
    (provider_id, endpoint_code, name, endpoint_url, output_format, description)
SELECT who.id, v.endpoint_code, v.name, v.endpoint_url, v.output_format, v.description
FROM who, (VALUES
    ('WHO_GHO_INDICATOR',
     'WHO GHO — indicateurs santé',
     'https://ghoapi.azureedge.net/api/{gho_code}?$filter=SpatialDim eq ''{iso3}''',
     'json',
     'Espérance de vie, mortalité infantile, accès aux soins')
) AS v(endpoint_code, name, endpoint_url, output_format, description)
ON CONFLICT (endpoint_code) DO NOTHING;

-- ============================================================
-- 3. INDICATOR_SOURCE (mapping indicateur OSA ↔ code source)
--    Permet au fetcher Python de savoir quelle variable appeler
-- ============================================================

CREATE TABLE IF NOT EXISTS collect.indicator_source (
    id                   SERIAL       PRIMARY KEY,
    indicator_code       VARCHAR(30)  NOT NULL REFERENCES rf.indicators(code),
    endpoint_id          INT          NOT NULL REFERENCES collect.provider_endpoints(id),
    source_indicator_code TEXT        NOT NULL,
    source_notes         TEXT,
    coverage_pct         NUMERIC(5,2) DEFAULT 0,
    last_verified        DATE,
    is_active            BOOLEAN      DEFAULT TRUE,
    created_at           TIMESTAMP    DEFAULT now(),
    UNIQUE (indicator_code, endpoint_id)
);

-- Mapping World Bank (codes WDI)
WITH wb_ep AS (SELECT id FROM collect.provider_endpoints WHERE endpoint_code = 'WB_COUNTRY_INDICATOR')
INSERT INTO collect.indicator_source
    (indicator_code, endpoint_id, source_indicator_code, source_notes)
SELECT i.indicator_code, wb_ep.id, i.wb_code, i.notes
FROM wb_ep,
(VALUES
    ('ECO_GDP',  'NY.GDP.PCAP.KD',      'PIB par habitant USD constants 2015'),
    ('ECO_GRW',  'NY.GDP.MKTP.KD.ZG',   'Croissance PIB annuelle %'),
    ('ECO_INV',  'NE.GDI.TOTL.ZS',      'Formation brute capital fixe % PIB'),
    ('ECO_EMP',  'SL.EMP.TOTL.SP.ZS',   'Emploi % population active'),
    ('ECO_FDI',  'BX.KLT.DINV.CD.WD',   'IDE entrants nets USD'),
    ('ECO_LOG',  'LP.LPI.OVRL.XQ',      'Indice de performance logistique'),
    ('ECO_TAX',  'GC.TAX.TOTL.GD.ZS',   'Recettes fiscales % PIB'),
    ('ECO_IND',  'NV.IND.TOTL.ZS',      'Valeur ajoutée industrie % PIB'),
    ('MON_INF',  'FP.CPI.TOTL.ZG',      'Inflation prix à la consommation %'),
    ('MON_RES',  'FI.RES.TOTL.CD',      'Réserves totales en USD'),
    ('MON_EXT',  'DT.DOD.DECT.GD.ZS',   'Dette extérieure totale % PIB'),
    ('MON_FIN',  'FS.AST.PRVT.GD.ZS',   'Crédit secteur privé % PIB'),
    ('MON_M2',   'FM.LBL.BMNY.GD.ZS',   'Masse monétaire large M2 % PIB'),
    ('MON_INT',  'FR.INR.RINR',          'Taux d intérêt réel %'),
    ('MON_DET',  'GC.XPN.INTP.RV.ZS',   'Service de la dette % recettes'),
    ('HUM_LIT',  'SE.ADT.LITR.ZS',      'Taux alphabétisation adultes %'),
    ('HUM_POV',  'SI.POV.DDAY',          'Pauvreté < 2.15 USD/jour %'),
    ('HUM_WAT',  'SH.H2O.BASW.ZS',      'Accès eau potable de base %'),
    ('HUM_SAN',  'SH.STA.BASS.ZS',      'Accès assainissement de base %'),
    ('HUM_GEN',  'SG.GEN.PARL.ZS',      'Femmes au parlement %'),
    ('ENV_CO2',  'EN.ATM.CO2E.PC',       'Émissions CO2 tonnes par habitant'),
    ('ENV_FOR',  'AG.LND.FRST.ZS',      'Couverture forestière % superficie'),
    ('ENV_ENR',  'EG.ELC.RNEW.ZS',      'Électricité renouvelable % total'),
    ('ENV_ENE',  'EG.EGY.PRIM.PP.KD',   'Intensité énergétique MJ/USD 2017'),
    ('NUM_INT',  'IT.NET.USER.ZS',       'Utilisateurs internet % population'),
    ('NUM_MOB',  'IT.CEL.SETS',          'Abonnements mobiles total'),
    ('NUM_GOV',  'GE.EST',               'Efficacité gouvernementale (WGI)'),
    ('GEO_STAB', 'PV.EST',               'Stabilité politique WGI'),
    ('GEO_RSK',  'RL.EST',               'État de droit WGI (inversé)'),
    ('MIN_VAL',  'NV.MNF.OTHR.ZS.UN',   'Valeur ajoutée industrie extractive % PIB')
) AS i(indicator_code, wb_code, notes)
ON CONFLICT (indicator_code, endpoint_id) DO NOTHING;

-- Mapping IMF WEO
WITH imf_ep AS (SELECT id FROM collect.provider_endpoints WHERE endpoint_code = 'IMF_WEO_INDICATOR')
INSERT INTO collect.indicator_source
    (indicator_code, endpoint_id, source_indicator_code, source_notes)
SELECT i.indicator_code, imf_ep.id, i.imf_code, i.notes
FROM imf_ep,
(VALUES
    ('MON_PAY',  'BCA_NGDPD',   'Balance courante % PIB — WEO'),
    ('MON_EXT',  'GGXWDG_NGDP', 'Dette brute secteur public % PIB — WEO'),
    ('ECO_GDP',  'NGDPD',       'PIB USD courants — WEO (complément WB)'),
    ('ECO_GRW',  'NGDP_RPCH',   'Croissance PIB réel % — WEO')
) AS i(indicator_code, imf_code, notes)
ON CONFLICT (indicator_code, endpoint_id) DO NOTHING;

-- ============================================================
-- 4. RAW_DATA (table partitionnée par année — L1 du pipeline)
-- ============================================================

CREATE TABLE IF NOT EXISTS collect.raw_data (
    id_raw          BIGSERIAL,
    endpoint_id     INT          NOT NULL,
    indicator_code  VARCHAR(30)  NOT NULL,
    country_iso3    CHAR(3)      NOT NULL,
    year            SMALLINT     NOT NULL CHECK (year >= 2010),
    value_raw       NUMERIC(20,6),
    load_date       TIMESTAMP    DEFAULT now(),
    PRIMARY KEY (id_raw, year)
) PARTITION BY RANGE (year);

CREATE INDEX IF NOT EXISTS idx_raw_indicator ON collect.raw_data(indicator_code);
CREATE INDEX IF NOT EXISTS idx_raw_country   ON collect.raw_data(country_iso3);

-- Partitions 2010 → 2030
DO $$
DECLARE y INT;
BEGIN
    FOR y IN 2010..2030 LOOP
        IF NOT EXISTS (
            SELECT 1 FROM pg_class c
            JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE c.relname = 'raw_data_' || y
              AND n.nspname = 'collect'
        ) THEN
            EXECUTE format(
                'CREATE TABLE collect.raw_data_%s
                 PARTITION OF collect.raw_data
                 FOR VALUES FROM (%s) TO (%s)',
                y, y, y + 1
            );
        END IF;
    END LOOP;
END;
$$;

-- ============================================================
-- 5. INGESTION_REGISTRY (journal d'exécution des collectes)
-- ============================================================

CREATE TABLE IF NOT EXISTS collect.ingestion_registry (
    id               BIGSERIAL    PRIMARY KEY,
    endpoint_id      INT          REFERENCES collect.provider_endpoints(id),
    indicator_code   VARCHAR(30),
    year             SMALLINT,
    execution_date   TIMESTAMP    DEFAULT now(),
    status           VARCHAR(10)  NOT NULL
        CHECK (status IN ('SUCCESS','FAILED','PARTIAL')),
    records_inserted INT          DEFAULT 0,
    records_rejected INT          DEFAULT 0,
    duration_ms      INT,
    message          TEXT
);

CREATE INDEX IF NOT EXISTS idx_ingest_status ON collect.ingestion_registry(status);
CREATE INDEX IF NOT EXISTS idx_ingest_date   ON collect.ingestion_registry(execution_date);

-- ============================================================
-- 6. FONCTION UTILITAIRE : vérification couverture données
-- ============================================================

CREATE OR REPLACE FUNCTION collect.coverage_report(p_year INT DEFAULT NULL)
RETURNS TABLE (
    indicator_code  VARCHAR(30),
    pillar_code     VARCHAR(10),
    total_countries INT,
    countries_with_data INT,
    coverage_pct    NUMERIC(5,1)
)
LANGUAGE sql AS $$
    SELECT
        r.indicator_code,
        i.pillar_code,
        54                                                      AS total_countries,
        COUNT(DISTINCT r.country_iso3)                          AS countries_with_data,
        ROUND(COUNT(DISTINCT r.country_iso3) * 100.0 / 54, 1)  AS coverage_pct
    FROM collect.raw_data r
    JOIN rf.indicators i ON i.code = r.indicator_code
    WHERE (p_year IS NULL OR r.year = p_year)
      AND r.value_raw IS NOT NULL
    GROUP BY r.indicator_code, i.pillar_code
    ORDER BY coverage_pct DESC;
$$;

COMMIT;

-- Vérification
-- SELECT COUNT(*) FROM collect.data_providers;    -- attendu : 9
-- SELECT COUNT(*) FROM collect.provider_endpoints;-- attendu : 8
-- SELECT COUNT(*) FROM collect.indicator_source;  -- attendu : ~35 mappings initiaux
-- SELECT tablename FROM pg_tables WHERE schemaname='collect' AND tablename LIKE 'raw_data_%';
