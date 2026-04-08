-- ============================================================
-- OSA / ISA OBSERVATORY
-- patch_providers_endpoints_v2.sql
-- ============================================================
-- Insère les data_providers et provider_endpoints manquants :
-- UNCTAD, COMTRADE, UNPK, EITI, USGS, ACLED
-- ============================================================

BEGIN;

INSERT INTO collect.data_providers (code, name) VALUES
  ('UNCTAD',   'UNCTADstat'),
  ('COMTRADE', 'UN Comtrade'),
  ('UNPK',     'IPI Peacekeeping Database'),
  ('EITI',     'EITI International'),
  ('USGS',     'USGS Mineral Resources'),
  ('ACLED',    'ACLED')
ON CONFLICT (code) DO NOTHING;

INSERT INTO collect.provider_endpoints
  (endpoint_code, provider_id, name, endpoint_url, output_format)
SELECT 'UNCTAD_FDI', id, 'UNCTADstat FDI',
       'https://unctadstat.unctad.org/datacentre/', 'csv'
FROM collect.data_providers WHERE code = 'UNCTAD'
ON CONFLICT (endpoint_code) DO NOTHING;

INSERT INTO collect.provider_endpoints
  (endpoint_code, provider_id, name, endpoint_url, output_format)
SELECT 'COMTRADE_TRADE', id, 'UN Comtrade API',
       'https://comtradeapi.un.org/public/v1', 'json'
FROM collect.data_providers WHERE code = 'COMTRADE'
ON CONFLICT (endpoint_code) DO NOTHING;

INSERT INTO collect.provider_endpoints
  (endpoint_code, provider_id, name, endpoint_url, output_format)
SELECT 'UNPK_IPI', id, 'IPI Peacekeeping CSV',
       'https://data.humdata.org/dataset/ipi-peacekeeping-database', 'csv'
FROM collect.data_providers WHERE code = 'UNPK'
ON CONFLICT (endpoint_code) DO NOTHING;

INSERT INTO collect.provider_endpoints
  (endpoint_code, provider_id, name, endpoint_url, output_format)
SELECT 'EITI_CSV', id, 'EITI Data CSV',
       'https://eiti.org/data', 'csv'
FROM collect.data_providers WHERE code = 'EITI'
ON CONFLICT (endpoint_code) DO NOTHING;

INSERT INTO collect.provider_endpoints
  (endpoint_code, provider_id, name, endpoint_url, output_format)
SELECT 'USGS_CSV', id, 'USGS Mineral Resources CSV',
       'https://mrdata.usgs.gov/', 'csv'
FROM collect.data_providers WHERE code = 'USGS'
ON CONFLICT (endpoint_code) DO NOTHING;

INSERT INTO collect.provider_endpoints
  (endpoint_code, provider_id, name, endpoint_url, output_format)
SELECT 'ACLED_API', id, 'ACLED REST API',
       'https://api.acleddata.com', 'json'
FROM collect.data_providers WHERE code = 'ACLED'
ON CONFLICT (endpoint_code) DO NOTHING;

DO $$
DECLARE v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count FROM collect.provider_endpoints;
    RAISE NOTICE 'Total endpoints : %', v_count;
END;
$$;

COMMIT;
