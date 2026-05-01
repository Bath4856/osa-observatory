-- ================================================================
-- CREATION DES INDICATEURS CALCULES OSA
-- ma.computed_indicators + ma.computed_values
-- Convention : WKN_ = WEAKNESS / THR_ = THREAT
-- OSA Observatory -- Avril 2026
-- ================================================================

-- ── TABLE DES INDICATEURS CALCULES ──────────────────────────────
CREATE TABLE ma.computed_indicators (
    code            VARCHAR(30)   NOT NULL,
    pillar_code     VARCHAR(10)   NOT NULL
                    REFERENCES rf.pillars(code),
    indicator_type  VARCHAR(20)   NOT NULL
                    CHECK (indicator_type IN ('WEAKNESS','THREAT','CAPACITY')),
    name_fr         TEXT          NOT NULL,
    name_en         TEXT          NOT NULL,
    formula         TEXT,
    is_active       BOOLEAN       DEFAULT true,
    created_at      TIMESTAMP     DEFAULT now(),
    PRIMARY KEY (code)
);

COMMENT ON TABLE ma.computed_indicators IS
'Indicateurs calcules OSA : WEAKNESS (diagnostic interne), THREAT (pression externe), CAPACITY (projets, futur). Convention de nommage : WKN_ pour WEAKNESS, THR_ pour THREAT, CAP_ pour CAPACITY.';

-- ── TABLE DES VALEURS CALCULEES (partitionnee par annee) ─────────
CREATE TABLE ma.computed_values (
    id              BIGSERIAL,
    indicator_code  VARCHAR(30)   NOT NULL
                    REFERENCES ma.computed_indicators(code),
    country_iso3    CHAR(3)       NOT NULL
                    REFERENCES rf.countries(iso3),
    year            SMALLINT      NOT NULL
                    CHECK (year >= 2020),
    value           NUMERIC(10,6)
                    CHECK (value >= 0 AND value <= 1),
    confidence      NUMERIC(4,3)
                    CHECK (confidence >= 0 AND confidence <= 1),
    components      JSONB,
    nb_indicators   SMALLINT,
    computed_at     TIMESTAMP     DEFAULT now(),
    PRIMARY KEY (id, year)
) PARTITION BY RANGE (year);

COMMENT ON TABLE ma.computed_values IS
'Valeurs des indicateurs calcules par pays et par annee (serie ISA 2020+). La colonne components (JSONB) stocke la decomposition du score pour audit et explicabilite.';

COMMENT ON COLUMN ma.computed_values.components IS
'WEAKNESS : {"nb_pos": N, "moy_norm": 0.xx, "indicateurs": [...]}
THREAT    : {"variation": 0.xx, "volatilite": 0.xx, "intensite": 0.xx}';

-- ── PARTITIONS 2020-2030 ──────────────────────────────────────────
CREATE TABLE ma.computed_values_2020 PARTITION OF ma.computed_values
    FOR VALUES FROM (2020) TO (2021);
CREATE TABLE ma.computed_values_2021 PARTITION OF ma.computed_values
    FOR VALUES FROM (2021) TO (2022);
CREATE TABLE ma.computed_values_2022 PARTITION OF ma.computed_values
    FOR VALUES FROM (2022) TO (2023);
CREATE TABLE ma.computed_values_2023 PARTITION OF ma.computed_values
    FOR VALUES FROM (2023) TO (2024);
CREATE TABLE ma.computed_values_2024 PARTITION OF ma.computed_values
    FOR VALUES FROM (2024) TO (2025);
CREATE TABLE ma.computed_values_2025 PARTITION OF ma.computed_values
    FOR VALUES FROM (2025) TO (2026);
CREATE TABLE ma.computed_values_2026 PARTITION OF ma.computed_values
    FOR VALUES FROM (2026) TO (2027);
CREATE TABLE ma.computed_values_2027 PARTITION OF ma.computed_values
    FOR VALUES FROM (2027) TO (2028);
CREATE TABLE ma.computed_values_2028 PARTITION OF ma.computed_values
    FOR VALUES FROM (2028) TO (2029);
CREATE TABLE ma.computed_values_2029 PARTITION OF ma.computed_values
    FOR VALUES FROM (2029) TO (2030);
CREATE TABLE ma.computed_values_2030 PARTITION OF ma.computed_values
    FOR VALUES FROM (2030) TO (2031);

-- ── INDEX ─────────────────────────────────────────────────────────
CREATE INDEX idx_cv_indicator ON ma.computed_values (indicator_code);
CREATE INDEX idx_cv_country   ON ma.computed_values (country_iso3);
CREATE INDEX idx_cv_year      ON ma.computed_values (year);
CREATE INDEX idx_cv_type      ON ma.computed_indicators (indicator_type);
CREATE INDEX idx_cv_pillar    ON ma.computed_indicators (pillar_code);

-- ── INSERTION DES 20 INDICATEURS CALCULES ────────────────────────
INSERT INTO ma.computed_indicators
    (code, pillar_code, indicator_type, name_fr, name_en, formula)
VALUES

-- ── 10 INDICATEURS WEAKNESS ──────────────────────────────────────
(
    'WKN_PECO', 'PECO', 'WEAKNESS',
    'Indice de faiblesse interne — Économique',
    'Internal weakness index — Economic',
    'WKN = 1 - AVG(norm(I+)) sur indicateurs positifs alimentes du pilier PECO'
),
(
    'WKN_PENV', 'PENV', 'WEAKNESS',
    'Indice de faiblesse interne — Environnemental',
    'Internal weakness index — Environmental',
    'WKN = 1 - AVG(norm(I+)) sur indicateurs positifs alimentes du pilier PENV'
),
(
    'WKN_PGEO', 'PGEO', 'WEAKNESS',
    'Indice de faiblesse interne — Géopolitique',
    'Internal weakness index — Geopolitical',
    'WKN = 1 - AVG(norm(I+)) sur indicateurs positifs alimentes du pilier PGEO. Retournement applique sur indicateurs direction=-'
),
(
    'WKN_PHUM', 'PHUM', 'WEAKNESS',
    'Indice de faiblesse interne — Humain',
    'Internal weakness index — Human',
    'WKN = 1 - AVG(norm(I+)) sur indicateurs positifs alimentes du pilier PHUM'
),
(
    'WKN_PMIL', 'PMIL', 'WEAKNESS',
    'Indice de faiblesse interne — Militaire',
    'Internal weakness index — Military',
    'WKN = 1 - AVG(norm(I+)) sur indicateurs positifs alimentes du pilier PMIL. Ponderation reduite pour indicateurs composites (is_composite_score=true)'
),
(
    'WKN_PMIN', 'PMIN', 'WEAKNESS',
    'Indice de faiblesse interne — Minier',
    'Internal weakness index — Mining',
    'WKN = 1 - AVG(norm(I+)) sur indicateurs positifs alimentes du pilier PMIN. MIN_ENV et MIN_DIV exclus (serie < 3 ans)'
),
(
    'WKN_PMON', 'PMON', 'WEAKNESS',
    'Indice de faiblesse interne — Monétaire',
    'Internal weakness index — Monetary',
    'WKN = 1 - AVG(norm(I+)) sur indicateurs positifs alimentes du pilier PMON. Pilier reference qualite (confiance 1.000)'
),
(
    'WKN_PNUM', 'PNUM', 'WEAKNESS',
    'Indice de faiblesse interne — Numérique',
    'Internal weakness index — Digital',
    'WKN = 1 - AVG(norm(I+)) sur indicateurs positifs alimentes du pilier PNUM. Tous indicateurs a polarite positive'
),
(
    'WKN_PRES', 'PRES', 'WEAKNESS',
    'Indice de faiblesse interne — Ressources',
    'Internal weakness index — Resources',
    'WKN = 1 - AVG(norm(I+)) sur indicateurs positifs alimentes du pilier PRES. PRES_WATER_AGRI pondere (confiance 0.643)'
),
(
    'WKN_PTRA', 'PTRA', 'WEAKNESS',
    'Indice de faiblesse interne — Transport',
    'Internal weakness index — Transport',
    'WKN = 1 - AVG(norm(I+)) sur indicateurs positifs alimentes du pilier PTRA. PTRA_RD_DENSITY et PTRA_RD_PAVED ponderes (confiance < 0.6)'
),

-- ── 10 INDICATEURS THREAT ────────────────────────────────────────
(
    'THR_PECO', 'PECO', 'THREAT',
    'Indice de menace externe — Économique',
    'External threat index — Economic',
    'THR = a*delta_variation + b*sigma_volatilite + c*intensite_externe. Poids pilier STRUCTUREL : a=0.35 b=0.35 c=0.30. Actif a partir de 2021'
),
(
    'THR_PENV', 'PENV', 'THREAT',
    'Indice de menace externe — Environnemental',
    'External threat index — Environmental',
    'THR = a*delta_variation + b*sigma_volatilite + c*intensite_externe. Poids pilier PHYSIQUE : a=0.25 b=0.45 c=0.30. Volatilite anomale = signal fort'
),
(
    'THR_PGEO', 'PGEO', 'THREAT',
    'Indice de menace externe — Géopolitique',
    'External threat index — Geopolitical',
    'THR = a*delta_variation + b*sigma_volatilite + c*intensite_externe. Poids pilier COMPOSITE : a=0.30 b=0.25 c=0.45. Intensite externe dominante'
),
(
    'THR_PHUM', 'PHUM', 'THREAT',
    'Indice de menace externe — Humain',
    'External threat index — Human',
    'THR = a*delta_variation + b*sigma_volatilite + c*intensite_externe. Poids pilier STRUCTUREL : a=0.35 b=0.35 c=0.30'
),
(
    'THR_PMIL', 'PMIL', 'THREAT',
    'Indice de menace externe — Militaire',
    'External threat index — Military',
    'THR = a*delta_variation + b*sigma_volatilite + c*intensite_externe. Poids pilier COMPOSITE : a=0.30 b=0.25 c=0.45'
),
(
    'THR_PMIN', 'PMIN', 'THREAT',
    'Indice de menace externe — Minier',
    'External threat index — Mining',
    'THR = a*delta_variation + b*sigma_volatilite + c*intensite_externe. Poids pilier STRUCTUREL : a=0.35 b=0.35 c=0.30'
),
(
    'THR_PMON', 'PMON', 'THREAT',
    'Indice de menace externe — Monétaire',
    'External threat index — Monetary',
    'THR = a*delta_variation + b*sigma_volatilite + c*intensite_externe. Poids pilier STRUCTUREL : a=0.35 b=0.35 c=0.30'
),
(
    'THR_PNUM', 'PNUM', 'THREAT',
    'Indice de menace externe — Numérique',
    'External threat index — Digital',
    'THR = a*delta_variation + b*sigma_volatilite + c*intensite_externe. Poids pilier COMPOSITE : a=0.30 b=0.25 c=0.45. Dependance indices externes ITU/WGI'
),
(
    'THR_PRES', 'PRES', 'THREAT',
    'Indice de menace externe — Ressources',
    'External threat index — Resources',
    'THR = a*delta_variation + b*sigma_volatilite + c*intensite_externe. Poids pilier PHYSIQUE : a=0.25 b=0.45 c=0.30'
),
(
    'THR_PTRA', 'PTRA', 'THREAT',
    'Indice de menace externe — Transport',
    'External threat index — Transport',
    'THR = a*delta_variation + b*sigma_volatilite + c*intensite_externe. Poids pilier STRUCTUREL : a=0.35 b=0.35 c=0.30'
);

-- ── VERIFICATION ─────────────────────────────────────────────────
SELECT
    ci.pillar_code,
    p.name_fr,
    pt.pillar_type,
    ci.code,
    ci.indicator_type,
    ci.name_fr AS indicateur
FROM ma.computed_indicators ci
JOIN rf.pillars p  ON p.code  = ci.pillar_code
JOIN ma.pillar_type pt ON pt.pillar_code = ci.pillar_code
ORDER BY ci.pillar_code, ci.indicator_type;
