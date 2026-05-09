BEGIN;

-- =========================================================
-- P3 — PRES + PTRA QUICK WINS
-- =========================================================

INSERT INTO mapping.indicator_provider_mapping (
    indicator_code,
    provider_code,
    provider_indicator_code,
    is_active,
    created_at
)
VALUES

-- =========================================================
-- PRES
-- =========================================================

('PRES_OIL_RENTS',
 'WB',
 'NY.GDP.PETR.RT.ZS',
 TRUE,
 NOW()),

('PRES_GAS_RENTS',
 'WB',
 'NY.GDP.NGAS.RT.ZS',
 TRUE,
 NOW()),

('PRES_ENRG_USE_CAP',
 'WB',
 'EG.USE.PCAP.KG.OE',
 TRUE,
 NOW()),

('PRES_FOSSIL_RENTS_EIA',
 'WB',
 'NY.GDP.TOTL.RT.ZS',
 TRUE,
 NOW()),

('PRES_RENEW_SHARE_FEC',
 'WB',
 'EG.FEC.RNEW.ZS',
 TRUE,
 NOW()),

('PRES_WATER_AGRI',
 'WB',
 'ER.H2O.FWAG.ZS',
 TRUE,
 NOW()),

-- =========================================================
-- PTRA
-- =========================================================

('PTRA_RD_PAVED',
 'WB',
 'IS.ROD.PAVE.ZS',
 TRUE,
 NOW()),

('PTRA_RD_DENSITY',
 'WB',
 'IS.ROD.DNST.K2',
 TRUE,
 NOW()),

('PTRA_LOG_LPI',
 'WB',
 'LP.LPI.OVRL.XQ',
 TRUE,
 NOW()),

('PTRA_RD_QUALITY',
 'WEF',
 'GCI_ROAD_QUALITY',
 TRUE,
 NOW())

ON CONFLICT DO NOTHING;

COMMIT;