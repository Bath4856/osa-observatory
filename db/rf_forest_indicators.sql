-- ================================================================
-- F1 — ENREGISTREMENT INDICATEURS FORESTIERS dans rf.indicators
-- 8 nouveaux codes (ENV_FOR deja existant — non recree)
-- OSA Observatory — Mai 2026
-- ================================================================

-- PRES : ressources forestières productives
INSERT INTO rf.indicators
    (code, name_fr, name_en, pillar_code, direction,
     unit, source_primary, is_active, imputation_regime)
VALUES
    ('PRES_PRB',
     'Production bois rondins (roundwood)',
     'Roundwood production',
     'PRES', '+', 'm3/an', 'FAO', true, 'STANDARD'),

    ('PRES_BEN',
     'Production bois energie (wood fuel)',
     'Wood fuel production',
     'PRES', '+', 'm3/an', 'FAO', true, 'STANDARD'),

    ('PRES_CAR',
     'Stock carbone forestier',
     'Forest carbon stock',
     'PRES', '+', 'Mg_C', 'GFW', true, 'STANDARD');

-- PECO : filiere bois comme activite economique
INSERT INTO rf.indicators
    (code, name_fr, name_en, pillar_code, direction,
     unit, source_primary, is_active, imputation_regime)
VALUES
    ('ECO_EXB',
     'Exportations bois industriel',
     'Industrial roundwood exports',
     'PECO', '+', 'USD', 'FAO', true, 'STANDARD'),

    ('ECO_VAF',
     'Valeur ajoutee filiere foret / PIB',
     'Forestry value added / GDP',
     'PECO', '+', '%', 'FAO', true, 'STANDARD'),

    ('ECO_INB',
     'Indice transformation industrielle bois',
     'Wood industrial transformation index',
     'PECO', '+', 'ratio', 'FAO', true, 'COMPUTED');

-- PENV : dynamique forestiere environnementale
INSERT INTO rf.indicators
    (code, name_fr, name_en, pillar_code, direction,
     unit, source_primary, is_active, imputation_regime)
VALUES
    ('ENV_DEF',
     'Deforestation annuelle',
     'Annual deforestation',
     'PENV', '-', 'ha/an', 'GFW', true, 'STANDARD'),

    ('ENV_REF',
     'Taux reforestation',
     'Reforestation rate',
     'PENV', '+', '%', 'FAO', true, 'STANDARD');

-- Verification
SELECT code, name_fr, pillar_code, direction, source_primary
FROM rf.indicators
WHERE code IN (
    'PRES_PRB','PRES_BEN','PRES_CAR',
    'ECO_EXB','ECO_VAF','ECO_INB',
    'ENV_DEF','ENV_REF'
)
ORDER BY pillar_code, code;