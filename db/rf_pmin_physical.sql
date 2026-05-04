INSERT INTO rf.units (code, name, symbol, unit_type, description)
VALUES ('MTONNE', 'Millions de tonnes', 'Mt', 'quantity', 'Unite geologique standard')
ON CONFLICT (code) DO NOTHING;

INSERT INTO rf.indicators (code, name_fr, name_en, pillar_code, direction, unit_code, imputation_regime, description)
VALUES
('MIN_GEO', 'Reserves prouvees minerales index norme', 'Proven mineral reserves normalized index', 'PMIN', '+', 'SCORE_0_1', 'STANDARD', 'Reserves minerales prouvees normalisees - source USGS. Cobalt lithium manganese platine uranium bauxite phosphates chrome coltan terres rares'),
('MIN_CRI', 'Indice criticite minerale strategique', 'Strategic mineral criticality index', 'PMIN', '+', 'SCORE_0_1', 'STANDARD', 'Criticite reserves nationales selon listes CE Critical Raw Materials et USGS Critical Minerals'),
('MIN_POT', 'Potentiel geologique non exploite', 'Unexploited geological potential', 'PMIN', '+', 'SCORE_0_1', 'STANDARD', 'Potentiel geologique non exploite commercialement - source BGS World Mineral Statistics et USGS'),
('MIN_RAR', 'Concentration terres rares et mineraux strategiques', 'Rare earth and strategic minerals concentration', 'PMIN', '+', 'SCORE_0_1', 'STANDARD', 'Concentration en terres rares REE et mineraux critiques - lithium cobalt coltan graphite platine uranium. Source USGS REE Database');

SELECT code, name_fr, pillar_code, direction, unit_code FROM rf.indicators WHERE code IN ('MIN_GEO','MIN_CRI','MIN_POT','MIN_RAR') ORDER BY code;