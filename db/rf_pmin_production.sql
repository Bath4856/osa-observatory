-- PMIN : 9 indicateurs de production mineraux critiques
INSERT INTO rf.indicators
    (code, name_fr, name_en, pillar_code, direction, unit_code, imputation_regime)
VALUES
    ('MIN_PRD_BAU','Production bauxite','Bauxite production','PMIN','+','KTOE','STANDARD'),
    ('MIN_PRD_ALU','Production aluminium','Aluminum production','PMIN','+','KTOE','STANDARD'),
    ('MIN_PRD_CHR','Production chromite','Chromite production','PMIN','+','KTOE','STANDARD'),
    ('MIN_PRD_COB','Production cobalt','Cobalt production','PMIN','+','TONNES','STANDARD'),
    ('MIN_PRD_COP','Production cuivre','Copper production','PMIN','+','KTOE','STANDARD'),
    ('MIN_PRD_GOL','Production or','Gold production','PMIN','+','KG','STANDARD'),
    ('MIN_PRD_IRN','Production minerai fer','Iron ore production','PMIN','+','KTOE','STANDARD'),
    ('MIN_PRD_STL','Production acier','Steel production','PMIN','+','KTOE','STANDARD'),
    ('MIN_PRD_MAN','Production manganese','Manganese production','PMIN','+','KTOE','STANDARD')
ON CONFLICT (code) DO NOTHING;

SELECT code, name_fr, unit_code
FROM rf.indicators
WHERE code LIKE 'MIN_PRD_%'
ORDER BY code;