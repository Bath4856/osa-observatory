-- ============================================================
-- OSA / ISA — PATCH P2 ORPHANS WB FAST
-- Mapping rapide des orphelins à forte confiance
-- ============================================================

BEGIN;

WITH src AS (
    SELECT *
    FROM (VALUES
        -- PNUM / ITU via World Bank WDI
        ('PNUM_INTERNET_USERS',       'WB_COUNTRY_INDICATOR', 'IT.NET.USER.ZS',    'WB WDI / ITU — Individuals using the Internet (% population)', 95.00),
        ('PNUM_BROADBAND_FIXED',      'WB_COUNTRY_INDICATOR', 'IT.NET.BBND.P2',    'WB WDI / ITU — Fixed broadband subscriptions per 100 people', 95.00),
        ('PNUM_MOBILE_SUBSCRIPTIONS', 'WB_COUNTRY_INDICATOR', 'IT.CEL.SETS.P2',    'WB WDI / ITU — Mobile cellular subscriptions per 100 people', 95.00),
        ('PNUM_SECURE_SERVERS',       'WB_COUNTRY_INDICATOR', 'IT.NET.SECR.P6',    'WB WDI — Secure Internet servers per 1 million people', 95.00),

        -- PMIL / military, WB WDI proxy
        ('PMIL_DEF_BUDGET_GDP',       'WB_COUNTRY_INDICATOR', 'MS.MIL.XPND.GD.ZS', 'WB WDI / SIPRI — Military expenditure (% GDP)', 90.00),
        ('PMIL_DEF_BUDGET_GOV',       'WB_COUNTRY_INDICATOR', 'MS.MIL.XPND.ZS',    'WB WDI / SIPRI — Military expenditure (% central government expenditure)', 90.00),
        ('PMIL_ARMED_FORCES',         'WB_COUNTRY_INDICATOR', 'MS.MIL.TOTL.P1',    'WB WDI / IISS — Armed forces personnel, total', 85.00),

        -- PTRA / air transport, WB WDI
        ('PTRA_AIR_PASSENGERS',       'WB_COUNTRY_INDICATOR', 'IS.AIR.PSGR',       'WB WDI / ICAO — Air transport, passengers carried', 90.00),
        ('PTRA_AIR_CARGO',            'WB_COUNTRY_INDICATOR', 'IS.AIR.GOOD.MT.K1', 'WB WDI / ICAO — Air transport, freight million ton-km', 90.00),
        ('PTRA_AIR_AIRPORTS',         'WB_COUNTRY_INDICATOR', 'IS.AIR.DPRT',       'WB WDI / ICAO — Air transport, registered carrier departures worldwide', 90.00)
    ) AS t(indicator_code, endpoint_code, source_indicator_code, source_notes, coverage_pct)
),
resolved AS (
    SELECT
        s.indicator_code,
        pe.id AS endpoint_id,
        s.source_indicator_code,
        s.source_notes,
        s.coverage_pct
    FROM src s
    JOIN rf.indicators i
        ON i.code = s.indicator_code
    JOIN collect.provider_endpoints pe
        ON pe.endpoint_code = s.endpoint_code
)
INSERT INTO collect.indicator_source
    (indicator_code, endpoint_id, source_indicator_code, source_notes, coverage_pct, last_verified, is_active)
SELECT
    indicator_code,
    endpoint_id,
    source_indicator_code,
    source_notes,
    coverage_pct,
    CURRENT_DATE,
    TRUE
FROM resolved
ON CONFLICT (indicator_code, endpoint_id)
DO UPDATE SET
    source_indicator_code = EXCLUDED.source_indicator_code,
    source_notes          = EXCLUDED.source_notes,
    coverage_pct          = EXCLUDED.coverage_pct,
    last_verified         = CURRENT_DATE,
    is_active             = TRUE;

INSERT INTO collect.source_registry_indicators
    (source_id, osa_code, source_code, endpoint, fallback, unit, frequency, decision, is_active)
VALUES
('WB', 'PNUM_INTERNET_USERS',       'IT.NET.USER.ZS',    'WB_COUNTRY_INDICATOR', 'ITU primary if direct access available', 'percent', 'annual', 'GO', TRUE),
('WB', 'PNUM_BROADBAND_FIXED',      'IT.NET.BBND.P2',    'WB_COUNTRY_INDICATOR', 'ITU primary if direct access available', 'per_100_people', 'annual', 'GO', TRUE),
('WB', 'PNUM_MOBILE_SUBSCRIPTIONS', 'IT.CEL.SETS.P2',    'WB_COUNTRY_INDICATOR', 'ITU primary if direct access available', 'per_100_people', 'annual', 'GO', TRUE),
('WB', 'PNUM_SECURE_SERVERS',       'IT.NET.SECR.P6',    'WB_COUNTRY_INDICATOR', NULL, 'per_1m_people', 'annual', 'GO', TRUE),

('WB', 'PMIL_DEF_BUDGET_GDP',       'MS.MIL.XPND.GD.ZS', 'WB_COUNTRY_INDICATOR', 'SIPRI primary', 'percent_gdp', 'annual', 'GO', TRUE),
('WB', 'PMIL_DEF_BUDGET_GOV',       'MS.MIL.XPND.ZS',    'WB_COUNTRY_INDICATOR', 'SIPRI primary', 'percent_gov_exp', 'annual', 'GO', TRUE),
('WB', 'PMIL_ARMED_FORCES',         'MS.MIL.TOTL.P1',    'WB_COUNTRY_INDICATOR', 'IISS/SIPRI primary', 'count', 'annual', 'GO', TRUE),

('WB', 'PTRA_AIR_PASSENGERS',       'IS.AIR.PSGR',       'WB_COUNTRY_INDICATOR', 'ICAO primary', 'passengers', 'annual', 'GO', TRUE),
('WB', 'PTRA_AIR_CARGO',            'IS.AIR.GOOD.MT.K1', 'WB_COUNTRY_INDICATOR', 'ICAO primary', 'million_ton_km', 'annual', 'GO', TRUE),
('WB', 'PTRA_AIR_AIRPORTS',         'IS.AIR.DPRT',       'WB_COUNTRY_INDICATOR', 'ICAO primary', 'departures', 'annual', 'GO', TRUE)
ON CONFLICT (source_id, source_code)
DO UPDATE SET
    osa_code   = EXCLUDED.osa_code,
    endpoint   = EXCLUDED.endpoint,
    fallback   = EXCLUDED.fallback,
    unit       = EXCLUDED.unit,
    frequency  = EXCLUDED.frequency,
    decision   = EXCLUDED.decision,
    is_active  = TRUE,
    updated_at = now();

DO $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM collect.indicator_source
    WHERE indicator_code IN (
        'PNUM_INTERNET_USERS',
        'PNUM_BROADBAND_FIXED',
        'PNUM_MOBILE_SUBSCRIPTIONS',
        'PNUM_SECURE_SERVERS',
        'PMIL_DEF_BUDGET_GDP',
        'PMIL_DEF_BUDGET_GOV',
        'PMIL_ARMED_FORCES',
        'PTRA_AIR_PASSENGERS',
        'PTRA_AIR_CARGO',
        'PTRA_AIR_AIRPORTS'
    )
    AND is_active = TRUE;

    RAISE NOTICE 'Mappings P2 actifs corrigés : % / 10', v_count;
END $$;

COMMIT;