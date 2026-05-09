BEGIN;

-- UNCTAD : mettre à jour base_url dans data_providers
UPDATE collect.data_providers
SET base_url = 'https://unctadstat.unctad.org/datacentre/'
WHERE code = 'UNCTAD';

-- COMTRADE : mettre à jour base_url dans data_providers
UPDATE collect.data_providers
SET base_url = 'https://comtradeapi.un.org/public/v1'
WHERE code = 'COMTRADE';

-- Indicateurs UNCTAD + COMTRADE dans indicator_source
INSERT INTO collect.indicator_source
    (indicator_code, endpoint_id, source_indicator_code, is_active)
VALUES
    ('ECO_FDI', (SELECT id FROM collect.provider_endpoints WHERE endpoint_code='UNCTAD_FDI'),    'FDI_inflows',            TRUE),
    ('ECO_EXP', (SELECT id FROM collect.provider_endpoints WHERE endpoint_code='COMTRADE_TRADE'), 'TradeValue_HS_manuf',    TRUE),
    ('ECO_IMP', (SELECT id FROM collect.provider_endpoints WHERE endpoint_code='COMTRADE_TRADE'), 'TradeValue_TOTAL_import',TRUE),
    ('MIN_EXP', (SELECT id FROM collect.provider_endpoints WHERE endpoint_code='COMTRADE_TRADE'), 'TradeValue_HS26_export', TRUE)
ON CONFLICT (indicator_code, endpoint_id) DO UPDATE SET
    source_indicator_code = EXCLUDED.source_indicator_code,
    is_active = TRUE;

DO $$
DECLARE v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM collect.indicator_source src
    JOIN collect.provider_endpoints pe ON pe.id = src.endpoint_id
    WHERE pe.endpoint_code IN ('UNCTAD_FDI','COMTRADE_TRADE');
    RAISE NOTICE 'Indicateurs UNCTAD+COMTRADE : % (attendu 4)', v_count;
END;
$$;
COMMIT;
