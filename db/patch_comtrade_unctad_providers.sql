-- ============================================================
-- OSA / ISA OBSERVATORY
-- patch_comtrade_unctad_providers.sql
-- ============================================================
-- Enregistre COMTRADE (3 indicateurs) et UNCTAD (1 indicateur)
-- dans source_registry_indicators.
--
-- COMTRADE validé terrain avril 2026 :
--   NGA MIN_EXP 2022 → 107 M USD  (H6)
--   ZAF MIN_EXP 2022 → 16 Md USD  (H6)
--   COD MIN_EXP 2022 → 139 M USD  (H4)
--   NGA ECO_IMP 2022 → 60 Md USD  (cifvalue)
-- ============================================================

BEGIN;

-- ── UNCTAD : passer en GO (CSV fiable, sans clé) ──────────
UPDATE collect.source_registry
SET status     = 'GO',
    api_type   = 'CSV_BULK',
    base_url   = 'https://unctadstat.unctad.org/datacentre/',
    reason     = NULL,
    updated_at = now()
WHERE source_id = 'UNCTAD';

-- ── COMTRADE : PILOT (API limitée sans clé) ───────────────
UPDATE collect.source_registry
SET status     = 'PILOT',
    api_type   = 'REST_PUBLIC',
    base_url   = 'https://comtradeapi.un.org/public/v1',
    limits     = '100 req/h sans clé — prévoir clé gratuite pour production',
    reason     = NULL,
    updated_at = now()
WHERE source_id = 'COMTRADE';

-- ── Indicateur UNCTAD ─────────────────────────────────────
INSERT INTO collect.source_registry_indicators (
    source_id, osa_code, source_code, endpoint,
    fallback, unit, frequency, decision, is_active
)
VALUES (
    'UNCTAD',
    'ECO_FDI',
    'FDI_inflows',
    'https://unctadstat.unctad.org/datacentre/dataviewer/US.FdiFlows',
    'WB FDI (BX.KLT.DINV.CD.WD)',
    'USD',
    'annual',
    'GO',
    TRUE
)
ON CONFLICT (source_id, source_code) DO UPDATE SET
    osa_code   = EXCLUDED.osa_code,
    endpoint   = EXCLUDED.endpoint,
    fallback   = EXCLUDED.fallback,
    decision   = EXCLUDED.decision,
    is_active  = TRUE,
    updated_at = now();

-- ── Indicateurs COMTRADE (3) ──────────────────────────────
INSERT INTO collect.source_registry_indicators (
    source_id, osa_code, source_code, endpoint,
    fallback, unit, frequency, decision, is_active
)
VALUES
(
    'COMTRADE',
    'ECO_EXP',
    'TradeValue_HS_manuf',
    'https://comtradeapi.un.org/public/v1/preview/C/A/HS',
    'WB manufactured exports (TX.VAL.MANF.ZS.UN)',
    'PERCENT',
    'annual',
    'PILOT',
    TRUE
),
(
    'COMTRADE',
    'ECO_IMP',
    'TradeValue_TOTAL_import',
    'https://comtradeapi.un.org/public/v1/preview/C/A/HS',
    'WB imports (NE.IMP.GNFS.CD)',
    'USD',
    'annual',
    'PILOT',
    TRUE
),
(
    'COMTRADE',
    'MIN_EXP',
    'TradeValue_HS26_export',
    'https://comtradeapi.un.org/public/v1/preview/C/A/HS',
    NULL,
    'USD',
    'annual',
    'PILOT',
    TRUE
)
ON CONFLICT (source_id, source_code) DO UPDATE SET
    osa_code   = EXCLUDED.osa_code,
    endpoint   = EXCLUDED.endpoint,
    fallback   = EXCLUDED.fallback,
    decision   = EXCLUDED.decision,
    is_active  = TRUE,
    updated_at = now();

-- ── Vérification ──────────────────────────────────────────
DO $$
DECLARE v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM collect.source_registry_indicators
    WHERE source_id IN ('UNCTAD', 'COMTRADE');
    RAISE NOTICE 'Indicateurs UNCTAD+COMTRADE enregistrés : % (attendu 4)', v_count;
END;
$$;

COMMIT;