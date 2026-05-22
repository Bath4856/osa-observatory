CREATE TABLE rf.indicator_versions (
    id              SERIAL PRIMARY KEY,
    indicator_code  VARCHAR NOT NULL,
    action          VARCHAR NOT NULL CHECK (action IN ('DEPRECATED', 'REPLACED_BY', 'CREATED', 'PATCHED')),
    replaced_by     VARCHAR REFERENCES rf.indicators(code),
    reason          TEXT NOT NULL,
    sprint          VARCHAR NOT NULL,
    effective_date  DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

UPDATE rf.indicators SET is_active = FALSE WHERE code IN ('GEO_RSK', 'PMIL_STABILITY_WGI', 'PNUM_GOV_EFFECTIVENESS');

INSERT INTO rf.indicator_versions (indicator_code, action, replaced_by, reason, sprint) VALUES
('GEO_RSK', 'DEPRECATED', NULL, 'Indicateur WGI Political Stability deguise - valeurs negatives centrees sur zero, source_id NULL, quality_flag incoherent. Redondant avec PGEO_EVT/PGEO_FAT/PGEO_CIV alimentes depuis ACLED. Violation Doctrine ISA v1 §1.1 : mesure de perception, non comportementale.', 'Sprint10'),
('PMIL_STABILITY_WGI', 'DEPRECATED', NULL, 'WGI Political Stability - indice de perception construit a majorite par evaluateurs OCDE. Violation Doctrine ISA v1 §1.1. Remplace fonctionnellement par MIL_TER + PGEO_EVT/PGEO_FAT (ACLED comportemental).', 'Sprint10'),
('PNUM_GOV_EFFECTIVENESS', 'DEPRECATED', NULL, 'WGI Government Effectiveness - indice de perception. Violation Doctrine ISA v1 §1.1. PNUM_EGDI_EGOV (54 pays, 2010-2024) constitue le proxy comportemental conforme : services en ligne deployes, infrastructure numerique, capital humain observables.', 'Sprint10');

SELECT code, name_fr, is_active FROM rf.indicators WHERE code IN ('GEO_RSK', 'PMIL_STABILITY_WGI', 'PNUM_GOV_EFFECTIVENESS');

SELECT indicator_code, action, sprint, effective_date FROM rf.indicator_versions ORDER BY id;
