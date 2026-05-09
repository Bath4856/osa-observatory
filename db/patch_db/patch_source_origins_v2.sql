-- ============================================================
-- OSA / ISA OBSERVATORY
-- patch_source_origins_v2.sql
-- ============================================================
-- Insère les sources manquantes dans mm.source_origins :
-- UNCTAD, EITI, COMTRADE, UNPK, ACLED, USGS
-- ============================================================

BEGIN;

INSERT INTO mm.source_origins (code, name) VALUES
  ('UNCTAD',   'UNCTADstat'),
  ('EITI',     'EITI International Secretariat'),
  ('COMTRADE', 'UN Comtrade'),
  ('UNPK',     'IPI Peacekeeping Database'),
  ('ACLED',    'Armed Conflict Location & Event Data'),
  ('USGS',     'USGS Mineral Resources')
ON CONFLICT (code) DO NOTHING;

DO $$
DECLARE v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count FROM mm.source_origins;
    RAISE NOTICE 'Total source_origins : %', v_count;
END;
$$;

COMMIT;
