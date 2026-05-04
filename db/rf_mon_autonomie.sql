-- ================================================================
-- M4 : Nouveaux indicateurs AUTONOMIE PMON
-- MON_CTRL, MON_CHG, MON_IND
-- OSA Observatory — Mai 2026
-- ================================================================

-- 3 indicateurs composante AUTONOMIE
INSERT INTO rf.indicators
    (code, name_fr, name_en, pillar_code, direction,
     unit_code, imputation_regime, description)
VALUES
    ('MON_CTRL',
     'Controle des taux directeurs',
     'Policy rate control',
     'PMON', '+', 'SCORE_0_1', 'STANDARD',
     'Capacite de la banque centrale a fixer souverainement ses taux — 1=souverain, 0=contraint par union monetaire'),

    ('MON_CHG',
     'Flexibilite du regime de change',
     'Exchange rate flexibility',
     'PMON', '+', 'SCORE_0_1', 'STANDARD',
     'Indice de flexibilite du regime de change — 0=fixe arrimage total, 1=flottant libre souverain'),

    ('MON_IND',
     'Independance de la banque centrale',
     'Central bank independence',
     'PMON', '+', 'SCORE_0_1', 'STANDARD',
     'Score dindependance legale et effective de la banque centrale — source BRI CBI index');

-- Sources dans collect.indicator_source
-- MON_CTRL — proxy via MON_SOV_FACTOR (règle métier OSA)
INSERT INTO collect.indicator_source
    (indicator_code, endpoint_id, source_indicator_code, source_notes, is_active)
SELECT 'MON_CTRL', pe.id,
    'policy_rate_sovereignty',
    'Proxy : MON_SOV_FACTOR binaire — 1 si INDEPENDENT/ZAR_RAND, 0.4 si CFA, 0.5 si DOLLARIZED/PEGGED',
    true
FROM collect.provider_endpoints pe
WHERE pe.endpoint_code = 'FAO_FOREST_CSV'
LIMIT 0;  -- placeholder — source a definir (BRI/FMI)

-- MON_CHG — FMI AREAER Classification
INSERT INTO collect.provider_endpoints
    (provider_id, endpoint_code, name, endpoint_url, output_format, description, is_active)
SELECT
    dp.id,
    'IMF_AREAER',
    'FMI — Annual Report on Exchange Arrangements and Exchange Restrictions',
    'https://www.imf.org/en/Publications/AREAER',
    'xlsx',
    'Classification des regimes de change par pays — mise a jour annuelle',
    true
FROM collect.data_providers dp
WHERE dp.code = 'IMF'
ON CONFLICT (endpoint_code) DO NOTHING;

-- MON_IND — BRI CBI (Central Bank Independence Index)
INSERT INTO collect.provider_endpoints
    (provider_id, endpoint_code, name, endpoint_url, output_format, description, is_active)
SELECT
    dp.id,
    'BRI_CBI',
    'BRI — Central Bank Independence Index',
    'https://www.bis.org/cbspeeches/index.htm',
    'xlsx',
    'Indice independance banque centrale par pays — Dincer & Eichengreen',
    true
FROM collect.data_providers dp
WHERE dp.code = 'IMF'  -- utilise IMF comme provider par defaut si BRI absent
ON CONFLICT (endpoint_code) DO NOTHING;

-- Verification
SELECT code, name_fr, pillar_code, direction, unit_code, description
FROM rf.indicators
WHERE code IN ('MON_CTRL','MON_CHG','MON_IND')
ORDER BY code;