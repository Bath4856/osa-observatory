INSERT INTO collect.data_providers
    (code, name, base_url, reliability_score, description, is_active)
VALUES
    ('USGS', 'US Geological Survey',
     'https://www.usgs.gov/centers/national-minerals-information-center',
     0.92,
     'Mineral Resources Data System - production et reserves minerales mondiales',
     true)
ON CONFLICT (code) DO NOTHING;

INSERT INTO collect.provider_endpoints
    (provider_id, endpoint_code, name, endpoint_url, output_format, description, is_active)
SELECT id, 'USGS_MYB_AFRICA',
    'USGS Minerals Yearbook Africa Summary',
    'https://www.usgs.gov/centers/national-minerals-information-center/minerals-yearbook-area-reports-international-africa',
    'xlsx',
    'Production mineraux critiques Afrique - tables annuelles T3',
    true
FROM collect.data_providers WHERE code = 'USGS'
ON CONFLICT (endpoint_code) DO NOTHING;

SELECT dp.code, pe.endpoint_code
FROM collect.provider_endpoints pe
JOIN collect.data_providers dp ON dp.id = pe.provider_id
WHERE pe.endpoint_code = 'USGS_MYB_AFRICA';