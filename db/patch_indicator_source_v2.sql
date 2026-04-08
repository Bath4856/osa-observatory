-- ============================================================
-- OSA / ISA OBSERVATORY
-- patch_indicator_source_v2.sql
-- ============================================================
-- Insère les entrées manquantes dans collect.indicator_source
-- pour UNCTAD, EITI, COMTRADE, UNPK
-- ============================================================

BEGIN;

INSERT INTO collect.indicator_source
  (indicator_code, endpoint_id, source_indicator_code, is_active)
VALUES
  ('ECO_FDI', (SELECT id FROM collect.provider_endpoints WHERE endpoint_code='UNCTAD_FDI'),    'FDI_inflows', TRUE),
  ('MIN_GOV', (SELECT id FROM collect.provider_endpoints WHERE endpoint_code='EITI_CSV'),       'EITI_score', TRUE),
  ('MIN_TAX', (SELECT id FROM collect.provider_endpoints WHERE endpoint_code='EITI_CSV'),       'EITI_revenue', TRUE),
  ('ECO_EXP', (SELECT id FROM collect.provider_endpoints WHERE endpoint_code='COMTRADE_TRADE'), 'TradeValue_HS_manuf', TRUE),
  ('ECO_IMP', (SELECT id FROM collect.provider_endpoints WHERE endpoint_code='COMTRADE_TRADE'), 'TradeValue_TOTAL_import', TRUE),
  ('MIN_EXP', (SELECT id FROM collect.provider_endpoints WHERE endpoint_code='COMTRADE_TRADE'), 'TradeValue_HS26_export', TRUE),
  ('MIL_MIS', (SELECT id FROM collect.provider_endpoints WHERE endpoint_code='UNPK_IPI'),       'total_troops', TRUE),
  ('GEO_PEA', (SELECT id FROM collect.provider_endpoints WHERE endpoint_code='UNPK_IPI'),       'total_personnel', TRUE)
ON CONFLICT (indicator_code, endpoint_id) DO NOTHING;

DO $$
DECLARE v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM collect.indicator_source src
    JOIN collect.provider_endpoints pe ON pe.id = src.endpoint_id
    WHERE pe.endpoint_code IN ('UNCTAD_FDI','EITI_CSV','COMTRADE_TRADE','UNPK_IPI');
    RAISE NOTICE 'indicator_source UNCTAD+EITI+COMTRADE+UNPK : % (attendu 8)', v_count;
END;
$$;

COMMIT;
