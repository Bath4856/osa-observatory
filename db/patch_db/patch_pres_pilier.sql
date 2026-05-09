-- PATCH PRES
BEGIN;
INSERT INTO rf.units (code, name, symbol, unit_type) VALUES
    ('KTOE',   'Kilotonne equivalent petrole', 'ktoe',    'quantity'),
    ('GWH',    'Gigawatt-heure',               'GWh',     'quantity'),
    ('KWH_PC', 'Kilowatt-heure par habitant',  'kWh/hab', 'quantity'),
    ('MW',     'Megawatt',                     'MW',      'quantity'),
    ('M3',     'Metre cube',                   'm3',      'quantity'),
    ('M3_PC',  'Metre cube par habitant',      'm3/hab',  'quantity')
ON CONFLICT (code) DO NOTHING;
INSERT INTO rf.pillars (code, name_fr, name_en, description, display_order) VALUES (
'PRES','Souverainete ressources strategiques','Strategic Resources Sovereignty','Energie et eau',9)
ON CONFLICT (code) DO NOTHING;
INSERT INTO rf.indicators (code, name_fr, name_en, pillar_code, unit_code, direction, description, display_order) VALUES
('PRES_EN_PROD_TOT',    'Production energie totale',          'Total energy production',           'PRES','KTOE',     '+','Production nationale brute',               1),
('PRES_EN_ELEC_PROD',   'Production electricite',             'Electricity production',            'PRES','GWH',      '+','Production electrique nationale',          2),
('PRES_EN_CAP_PC',      'Production electricite par hab',     'Electricity per capita',            'PRES','KWH_PC',   '+','Production electrique par habitant',       3),
('PRES_EN_CAPACITY',    'Capacite installee electrique',      'Installed electrical capacity',     'PRES','MW',       '+','Puissance totale installee',               4),
('PRES_EN_RENEW_SHARE', 'Part des energies renouvelables',    'Renewable energy share',            'PRES','PERCENT',  '+','Part renouvelables production totale',     5),
('PRES_EN_FOSSIL',      'Production fossile',                 'Fossil fuel production',            'PRES','KTOE',     '+','Production hydrocarbures et charbon',      6),
('PRES_EN_RESERVE',     'Reserves energetiques',              'Energy reserves',                   'PRES','KTOE',     '+','Reserves prouvees energie',                7),
('PRES_EN_STABILITY',   'Stabilite production energetique',   'Energy production stability',       'PRES','SCORE_0_1','+','CV inverse 5 ans calcul OSA',              8),
('PRES_WA_RES_TOTAL',   'Ressources eau renouvelables',       'Renewable water resources',         'PRES','M3',       '+','Volume total eau renouvelable interne',    9),
('PRES_WA_RES_PC',      'Eau par habitant',                   'Water per capita',                  'PRES','M3_PC',    '+','Eau renouvelable par habitant',            10),
('PRES_WA_STORAGE',     'Capacite stockage eau',              'Water storage capacity',            'PRES','M3',       '+','Capacite totale stockage eau',             11),
('PRES_WA_SURFACE',     'Ressources eau de surface',          'Surface water resources',           'PRES','PERCENT',  '+','Part eaux de surface dans ressources',     12),
('PRES_WA_GROUND',      'Ressources eau souterraine',         'Groundwater resources',             'PRES','PERCENT',  '+','Part eaux souterraines dans ressources',   13),
('PRES_WA_VARIABILITY', 'Variabilite hydrique',               'Hydrological variability',          'PRES','SCORE_0_1','-','CV brut 5 ans calcul OSA',                 14),
('PRES_WA_INTERNAL',    'Independence hydrique interne',      'Internal water independence',       'PRES','PERCENT',  '+','Part ressources hydriques internes',       15)
ON CONFLICT (code) DO NOTHING;
DO $$ DECLARE v_p INTEGER; v_i INTEGER; v_u INTEGER;
BEGIN
SELECT COUNT(*) INTO v_p FROM rf.pillars    WHERE code='PRES';
SELECT COUNT(*) INTO v_i FROM rf.indicators WHERE pillar_code='PRES';
SELECT COUNT(*) INTO v_u FROM rf.units      WHERE code IN ('KTOE','GWH','KWH_PC','MW','M3','M3_PC');
RAISE NOTICE 'PATCH PRES — pilier:% indicateurs:% unites:%', v_p, v_i, v_u;
IF v_p<>1 OR v_i<>15 OR v_u<>6 THEN
RAISE EXCEPTION 'PATCH PRES echoue';
END IF; END $$;
COMMIT;
