-- ============================================================
-- OSA / ISA OBSERVATORY
-- patch_missing_core_providers.sql
-- ============================================================
-- Insère les providers manquants dans collect.source_registry :
-- WB, IMF, WHO, FAO, ACLED, COMTRADE, UNCTAD, OECD
-- ============================================================

BEGIN;

INSERT INTO collect.source_registry (
    source_id, name, organization, api_type, base_url,
    status, priority,
    coverage, stability, limits, reason,
    freshness_score, completeness_score, reliability_score,
    is_active
)
VALUES

('WB',
 'World Bank',
 'World Bank Group',
 'REST',
 'https://api.worldbank.org/v2',
 'GO', 1,
 '54 pays africains — couverture globale',
 'HIGH', NULL, NULL,
 0.95, 0.90, 0.95, TRUE),

('IMF',
 'IMF IFS/WEO',
 'International Monetary Fund',
 'SDMX',
 'https://dataservices.imf.org/REST/SDMX_JSON.svc',
 'GO', 1,
 '54 pays africains — indicateurs monétaires',
 'HIGH', 'Latence variable', NULL,
 0.90, 0.85, 0.92, TRUE),

('WHO',
 'WHO Global Health Observatory',
 'World Health Organization',
 'REST',
 'https://ghoapi.azureedge.net/api',
 'GO', 1,
 '54 pays africains — indicateurs santé',
 'HIGH', NULL, NULL,
 0.88, 0.82, 0.90, TRUE),

('FAO',
 'FAOSTAT',
 'Food and Agriculture Organization',
 'CSV_BULK',
 'https://www.fao.org/faostat/en/#data',
 'GO', 1,
 '54 pays africains — alimentation et environnement',
 'HIGH', NULL, NULL,
 0.88, 0.83, 0.90, TRUE),

('ACLED',
 'ACLED',
 'Armed Conflict Location & Event Data',
 'REST',
 'https://api.acleddata.com',
 'PILOT', 4,
 'Pays africains — conflits et sécurité',
 'MEDIUM', NULL, NULL,
 0.80, 0.75, 0.82, TRUE),

('COMTRADE',
 'UN Comtrade',
 'United Nations',
 'REST_PUBLIC',
 'https://comtradeapi.un.org/public/v1',
 'PILOT', 2,
 '54 pays africains — commerce international',
 'MEDIUM',
 '100 req/h sans clé',
 NULL,
 0.82, 0.75, 0.85, TRUE),

('UNCTAD',
 'UNCTADstat',
 'UN Trade and Development',
 'CSV_BULK',
 'https://unctadstat.unctad.org/datacentre/',
 'GO', 2,
 '54 pays africains — IDE et commerce',
 'HIGH', NULL, NULL,
 0.85, 0.80, 0.88, TRUE),

('OECD',
 'OECD SDMX',
 'Organisation for Economic Co-operation and Development',
 'SDMX',
 'https://stats.oecd.org/restsdmx/sdmx.ashx',
 'NO_GO', 3,
 NULL, NULL, NULL,
 'Fetcher non implémenté — GOV_EDU sans couverture alternative',
 NULL, NULL, NULL, TRUE)

ON CONFLICT (source_id) DO NOTHING;

-- Vérification
DO $$
DECLARE v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count FROM collect.source_registry;
    RAISE NOTICE 'Total providers dans source_registry : %', v_count;
END;
$$;

COMMIT;
