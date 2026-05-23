UPDATE rf.indicators SET is_active = FALSE WHERE code IN ('PGEO_MINE_COUNT', 'PGEO_MINE_COORD', 'MIN_SITE_COUNT');

INSERT INTO rf.indicator_versions (indicator_code, action, replaced_by, reason, sprint) VALUES
('PGEO_MINE_COUNT', 'DEPRECATED', NULL, 'Source Wikipedia/Nominatim non verifiable independamment - violation hierarchie sources Doctrine ISA v1 (N1/N2/N3). Valeurs statiques identiques sur 15 ans (2010-2024) : serie temporelle fictive. Meme dataset que MIN_SITE_COUNT - doublon entre PGEO et PMIN. Remplacement prevu : EITI site data (source N1 auditee, 33 pays africains membres).', 'Sprint11'),
('PGEO_MINE_COORD', 'DEPRECATED', NULL, 'Tautologie Wikipedia : coord_value = 1.0 systematiquement car Wikipedia geolocalise ses entrees par definition. Ne mesure pas la qualite de geolocalisation d un Etat - mesure la completude des articles Wikipedia. processed_value NULL sur 810 lignes L2. Source non verifiable independamment - violation Doctrine ISA v1.', 'Sprint11'),
('MIN_SITE_COUNT', 'DEPRECATED', NULL, 'Source Wikipedia/Nominatim non verifiable independamment - violation hierarchie sources Doctrine ISA v1. Dataset identique a PGEO_MINE_COUNT sur 24 pays - meme scraping duplique entre deux piliers. Serie temporelle fictive : valeur figee 2010-2024. Remplacement prevu : EITI site data (source N1 auditee).', 'Sprint11');

SELECT code, name_fr, pillar_code, is_active FROM rf.indicators WHERE code IN ('PGEO_MINE_COUNT', 'PGEO_MINE_COORD', 'MIN_SITE_COUNT');

SELECT indicator_code, action, sprint, effective_date FROM rf.indicator_versions ORDER BY id;
