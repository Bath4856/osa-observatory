-- ================================================================
-- F2 — ENREGISTREMENT SOURCES FORESTIERES
-- Provider GFW + 2 endpoints (FAO_FOREST_CSV + GFW_GLOBAL_XLS)
-- OSA Observatory — Mai 2026
-- ================================================================

-- Provider GFW
INSERT INTO collect.data_providers
    (code, name, base_url, reliability_score, description, is_active)
VALUES
    ('GFW', 'Global Forest Watch',
     'https://www.globalforestwatch.org',
     0.85,
     'Plateforme mondiale de surveillance des forets — donnees deforestation et carbone',
     true)
ON CONFLICT (code) DO NOTHING;

-- Endpoint FAO Forestry CSV
INSERT INTO collect.provider_endpoints
    (provider_id, endpoint_code, name, endpoint_url, output_format, description, is_active)
SELECT
    id,
    'FAO_FOREST_CSV',
    'FAO Forestry — donnees Afrique CSV',
    'https://fenixservices.fao.org/faostat/api/v1/en/data/FO',
    'csv',
    'Donnees forestieres FAO — production, exportations, transformation bois',
    true
FROM collect.data_providers
WHERE code = 'FAO'
ON CONFLICT (endpoint_code) DO NOTHING;

-- Endpoint GFW global.xlsx
INSERT INTO collect.provider_endpoints
    (provider_id, endpoint_code, name, endpoint_url, output_format, description, is_active)
SELECT
    id,
    'GFW_GLOBAL_XLS',
    'GFW — Country level data XLSX',
    'https://www.globalforestwatch.org/dashboards/global/',
    'xlsx',
    'Donnees deforestation (tc_loss_ha) et stock carbone par pays 2001-2024',
    true
FROM collect.data_providers
WHERE code = 'GFW'
ON CONFLICT (endpoint_code) DO NOTHING;

-- Mappings indicator_source
INSERT INTO collect.indicator_source
    (indicator_code, endpoint_id, source_indicator_code, source_notes, is_active)
SELECT 'PRES_PRB', pe.id, 'Item1861_Elem5510',
    'FAO Forestry — Roundwood production — m3/an', true
FROM collect.provider_endpoints pe WHERE pe.endpoint_code = 'FAO_FOREST_CSV'
ON CONFLICT (indicator_code, endpoint_id) DO NOTHING;

INSERT INTO collect.indicator_source
    (indicator_code, endpoint_id, source_indicator_code, source_notes, is_active)
SELECT 'PRES_BEN', pe.id, 'Item1864_Elem5510',
    'FAO Forestry — Wood fuel production — m3/an', true
FROM collect.provider_endpoints pe WHERE pe.endpoint_code = 'FAO_FOREST_CSV'
ON CONFLICT (indicator_code, endpoint_id) DO NOTHING;

INSERT INTO collect.indicator_source
    (indicator_code, endpoint_id, source_indicator_code, source_notes, is_active)
SELECT 'PRES_CAR', pe.id, 'gfw_aboveground_carbon_stocks_2000__Mg_C',
    'GFW global.xlsx — sheet Country carbon data — seuil 30pct', true
FROM collect.provider_endpoints pe WHERE pe.endpoint_code = 'GFW_GLOBAL_XLS'
ON CONFLICT (indicator_code, endpoint_id) DO NOTHING;

INSERT INTO collect.indicator_source
    (indicator_code, endpoint_id, source_indicator_code, source_notes, is_active)
SELECT 'ECO_EXB', pe.id, 'Item1865_Elem5922',
    'FAO Forestry — Industrial roundwood export value — USD', true
FROM collect.provider_endpoints pe WHERE pe.endpoint_code = 'FAO_FOREST_CSV'
ON CONFLICT (indicator_code, endpoint_id) DO NOTHING;

INSERT INTO collect.indicator_source
    (indicator_code, endpoint_id, source_indicator_code, source_notes, is_active)
SELECT 'ECO_VAF', pe.id, 'gross_production_value',
    'FAO Forestry — Gross production value forestry', true
FROM collect.provider_endpoints pe WHERE pe.endpoint_code = 'FAO_FOREST_CSV'
ON CONFLICT (indicator_code, endpoint_id) DO NOTHING;

INSERT INTO collect.indicator_source
    (indicator_code, endpoint_id, source_indicator_code, source_notes, is_active)
SELECT 'ECO_INB', pe.id, 'Items1872_1873_1878_1876_ratio_1861',
    'FAO Forestry — Calcule : (SAW+PAN+0.7xPULP+0.5xPAP)/ROUNDWOOD', true
FROM collect.provider_endpoints pe WHERE pe.endpoint_code = 'FAO_FOREST_CSV'
ON CONFLICT (indicator_code, endpoint_id) DO NOTHING;

INSERT INTO collect.indicator_source
    (indicator_code, endpoint_id, source_indicator_code, source_notes, is_active)
SELECT 'ENV_DEF', pe.id, 'tc_loss_ha_XXXX_seuil30pct',
    'GFW global.xlsx — sheet Country tree cover loss — colonnes tc_loss_ha_2010 a 2024', true
FROM collect.provider_endpoints pe WHERE pe.endpoint_code = 'GFW_GLOBAL_XLS'
ON CONFLICT (indicator_code, endpoint_id) DO NOTHING;

INSERT INTO collect.indicator_source
    (indicator_code, endpoint_id, source_indicator_code, source_notes, is_active)
SELECT 'ENV_REF', pe.id, 'afforestation_reforestation',
    'FAO Forestry — Reforestation et afforestation annuelle', true
FROM collect.provider_endpoints pe WHERE pe.endpoint_code = 'FAO_FOREST_CSV'
ON CONFLICT (indicator_code, endpoint_id) DO NOTHING;

-- Verification
SELECT
    cs.indicator_code,
    dp.code AS provider,
    pe.endpoint_code,
    cs.source_indicator_code
FROM collect.indicator_source cs
JOIN collect.provider_endpoints pe ON pe.id = cs.endpoint_id
JOIN collect.data_providers dp ON dp.id = pe.provider_id
WHERE cs.indicator_code IN (
    'PRES_PRB','PRES_BEN','PRES_CAR',
    'ECO_EXB','ECO_VAF','ECO_INB',
    'ENV_DEF','ENV_REF')
ORDER BY cs.indicator_code;