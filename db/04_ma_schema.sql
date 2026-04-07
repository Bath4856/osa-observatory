-- ============================================================
-- OSA / ISA OBSERVATORY
-- BLOC 04 : SCHEMA MA — MODÈLE ANALYTIQUE (Pipeline L1→L7)
-- Version   : 1.0.0
-- Dépend de  : 01_rf_schema.sql, 02_mm_schema.sql, 03_collect_schema.sql
-- Doctrine  : toutes les valeurs intermédiaires L1→L7 sont conservées
--             auditabilité complète — versionné par method_version_id
-- NOTE PKI  : tables de signature et certificats X.509 désactivées
--             activation prévue Phase 4 (sprint 8)
-- ============================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS ma;
SET search_path TO ma, rf, mm, collect, public;

-- ============================================================
-- 1. INDICATOR_META (métadonnées analytiques des indicateurs)
-- ============================================================

CREATE TABLE IF NOT EXISTS ma.indicator_meta (
    indicator_code  VARCHAR(30)  PRIMARY KEY
        REFERENCES rf.indicators(code),
    label           TEXT         NOT NULL,
    description     TEXT,
    unit_code       VARCHAR(20)  REFERENCES rf.units(code),
    polarity        CHAR(3)      NOT NULL CHECK (polarity IN ('POS','NEG')),
    pillar_code     VARCHAR(10)  NOT NULL REFERENCES rf.pillars(code),
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMP    DEFAULT now()
);

-- Peuplement automatique depuis rf.indicators
INSERT INTO ma.indicator_meta
    (indicator_code, label, description, unit_code, polarity, pillar_code)
SELECT
    i.code,
    i.name_fr,
    i.description,
    i.unit_code,
    CASE WHEN i.direction = '+' THEN 'POS' ELSE 'NEG' END,
    i.pillar_code
FROM rf.indicators i
ON CONFLICT DO NOTHING;

-- ============================================================
-- 2. INDICATOR_METHODS & VERSIONS (méthodes de calcul versionnées)
-- ============================================================

CREATE TABLE IF NOT EXISTS ma.indicator_methods (
    id               SERIAL       PRIMARY KEY,
    code             VARCHAR(50)  UNIQUE NOT NULL,
    method_type      VARCHAR(20)  NOT NULL
        CHECK (method_type IN ('simple','composite','derived')),
    normalize_method VARCHAR(20)  NOT NULL
        CHECK (normalize_method IN ('minmax','zscore','log','invert','none')),
    direction        VARCHAR(10)  NOT NULL
        CHECK (direction IN ('up','down','neutral')),
    description      TEXT,
    is_active        BOOLEAN      DEFAULT TRUE,
    created_at       TIMESTAMP    DEFAULT now()
);

CREATE TABLE IF NOT EXISTS ma.indicator_method_versions (
    id               SERIAL       PRIMARY KEY,
    method_id        INT          NOT NULL
        REFERENCES ma.indicator_methods(id) ON DELETE CASCADE,
    version          INTEGER      NOT NULL DEFAULT 1,
    normalization    VARCHAR(20),
    aggregation      VARCHAR(30),
    weighting        VARCHAR(30)
        CHECK (weighting IN ('equal','entropy','variance','pca','manual')),
    valid_from       DATE         NOT NULL DEFAULT CURRENT_DATE,
    valid_to         DATE,
    is_active        BOOLEAN      DEFAULT TRUE,
    description      TEXT,
    UNIQUE (method_id, version)
);

INSERT INTO ma.indicator_methods
    (code, method_type, normalize_method, direction, description)
VALUES
('MINMAX_UP',     'simple',    'minmax',  'up',      'Min-Max indicateur positif — résultat ∈ [0,1]'),
('MINMAX_DOWN',   'simple',    'minmax',  'down',    'Min-Max indicateur négatif — inversé, résultat ∈ [0,1]'),
('LOG_MINMAX_UP', 'simple',    'log',     'up',      'Log puis Min-Max — pour indicateurs à forte dispersion'),
('ZSCORE_UP',     'simple',    'zscore',  'up',      'Z-score indicateur positif'),
('PILLAR_AGG',    'composite', 'none',    'up',      'Agrégation pondérée des indicateurs d''un pilier → score pilier'),
('ISA_AGG',       'composite', 'none',    'up',      'Agrégation pondérée des piliers → indice ISA final')
ON CONFLICT DO NOTHING;

INSERT INTO ma.indicator_method_versions
    (method_id, version, normalization, aggregation, weighting, valid_from, description)
SELECT id, 1, normalize_method, 'weighted_sum', 'equal',
       CURRENT_DATE, 'Version 1 — équipondération initiale (sprint 4)'
FROM ma.indicator_methods
ON CONFLICT DO NOTHING;

-- ============================================================
-- 3. INDICATOR_META_LINKS (pondération indicateur → pilier)
-- ============================================================

CREATE TABLE IF NOT EXISTS ma.indicator_meta_links (
    meta_code       VARCHAR(20)   NOT NULL
        REFERENCES rf.meta_indicators(meta_code),
    indicator_code  VARCHAR(30)   NOT NULL
        REFERENCES rf.indicators(code),
    weight          NUMERIC(10,8) NOT NULL DEFAULT 0.06666667,
    is_inverse      BOOLEAN       DEFAULT FALSE,
    ref_year        SMALLINT      NOT NULL DEFAULT 2024,
    is_active       BOOLEAN       DEFAULT TRUE,
    created_at      TIMESTAMP     DEFAULT now(),
    PRIMARY KEY (meta_code, indicator_code, ref_year)
);

INSERT INTO ma.indicator_meta_links
    (meta_code, indicator_code, weight, ref_year)
SELECT
    'SOV_' || i.pillar_code,
    i.code,
    ROUND(1.0 / 15, 8),
    2024
FROM rf.indicators i
ON CONFLICT DO NOTHING;

-- ============================================================
-- 4. INDICATOR_VALUES (table centrale — toutes les couches L1→L7)
--    Partitionnée par year pour les volumes 2010→N
-- ============================================================

CREATE TABLE IF NOT EXISTS ma.indicator_values (
    id                  BIGSERIAL,
    indicator_code      VARCHAR(30)   NOT NULL REFERENCES rf.indicators(code),
    country_iso3        CHAR(3)       NOT NULL REFERENCES rf.countries(iso3),
    year                SMALLINT      NOT NULL CHECK (year >= 2010),
    layer_id            SMALLINT      NOT NULL CHECK (layer_id BETWEEN 1 AND 7),
    raw_value           NUMERIC(20,6),
    processed_value     NUMERIC(20,6),
    method_version_id   INT           REFERENCES ma.indicator_method_versions(id),
    source_id           INT           REFERENCES mm.source_origins(id),
    confidence_score    NUMERIC(4,3)  CHECK (confidence_score BETWEEN 0 AND 1),
    is_estimated        BOOLEAN       DEFAULT FALSE,
    quality_flag        VARCHAR(20)   DEFAULT 'OK'
        CHECK (quality_flag IN ('OK','ESTIMATED','INTERPOLATED','REJECTED','MISSING')),
    created_at          TIMESTAMP     DEFAULT now(),
    PRIMARY KEY (id, year),
    UNIQUE (indicator_code, country_iso3, year, layer_id, method_version_id)
) PARTITION BY RANGE (year);

CREATE INDEX IF NOT EXISTS idx_ma_iv_indicator ON ma.indicator_values(indicator_code);
CREATE INDEX IF NOT EXISTS idx_ma_iv_country   ON ma.indicator_values(country_iso3);
CREATE INDEX IF NOT EXISTS idx_ma_iv_layer     ON ma.indicator_values(layer_id);

-- Partitions 2010 → 2030
DO $$
DECLARE y INT;
BEGIN
    FOR y IN 2010..2030 LOOP
        IF NOT EXISTS (
            SELECT 1 FROM pg_class c
            JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE c.relname = 'indicator_values_' || y
              AND n.nspname = 'ma'
        ) THEN
            EXECUTE format(
                'CREATE TABLE ma.indicator_values_%s
                 PARTITION OF ma.indicator_values
                 FOR VALUES FROM (%s) TO (%s)',
                y, y, y + 1
            );
        END IF;
    END LOOP;
END;
$$;

-- ============================================================
-- 5. PILLAR_SCORES (L5 — scores pilier par pays et par année)
-- ============================================================

CREATE TABLE IF NOT EXISTS ma.pillar_scores (
    id                BIGSERIAL    PRIMARY KEY,
    pillar_code       VARCHAR(10)  NOT NULL REFERENCES rf.pillars(code),
    country_iso3      CHAR(3)      NOT NULL REFERENCES rf.countries(iso3),
    year              SMALLINT     NOT NULL CHECK (year >= 2010),
    score             NUMERIC(8,6) NOT NULL CHECK (score BETWEEN 0 AND 1),
    indicators_used   INT,
    indicators_total  INT          DEFAULT 15,
    coverage_pct      NUMERIC(5,1),
    method_version_id INT          REFERENCES ma.indicator_method_versions(id),
    computed_at       TIMESTAMP    DEFAULT now(),
    UNIQUE (pillar_code, country_iso3, year, method_version_id)
);

CREATE INDEX IF NOT EXISTS idx_ps_country_year ON ma.pillar_scores(country_iso3, year);
CREATE INDEX IF NOT EXISTS idx_ps_pillar_year  ON ma.pillar_scores(pillar_code, year);

-- ============================================================
-- 6. ISA_INDEX (L7 — indice ISA final par pays et par année)
-- ============================================================

CREATE TABLE IF NOT EXISTS ma.isa_index (
    id                BIGSERIAL    PRIMARY KEY,
    country_iso3      CHAR(3)      NOT NULL REFERENCES rf.countries(iso3),
    year              SMALLINT     NOT NULL CHECK (year >= 2010),
    isa_score         NUMERIC(6,2) NOT NULL CHECK (isa_score BETWEEN 0 AND 100),
    isa_score_norm    NUMERIC(8,6) GENERATED ALWAYS AS (isa_score / 100.0) STORED,
    pillar_count      SMALLINT     DEFAULT 8,
    method_version_id INT          REFERENCES ma.indicator_method_versions(id),
    is_published      BOOLEAN      DEFAULT FALSE,
    computed_at       TIMESTAMP    DEFAULT now(),
    published_at      TIMESTAMP,
    UNIQUE (country_iso3, year, method_version_id)
);

CREATE INDEX IF NOT EXISTS idx_isa_country_year ON ma.isa_index(country_iso3, year);
CREATE INDEX IF NOT EXISTS idx_isa_published    ON ma.isa_index(is_published, year);

-- ============================================================
-- 7. VUES MATÉRIALISÉES (performances dashboard)
-- ============================================================

-- Vue : scores piliers toutes années
CREATE MATERIALIZED VIEW IF NOT EXISTS ma.mv_pillar_scores_all AS
SELECT
    ps.pillar_code,
    p.name_fr     AS pillar_name,
    ps.country_iso3,
    c.name_fr     AS country_name,
    r.name_fr     AS region_name,
    ps.year,
    ROUND(ps.score * 100, 2) AS score_0_100,
    ps.coverage_pct
FROM ma.pillar_scores ps
JOIN rf.pillars p   ON p.code = ps.pillar_code
JOIN rf.countries c ON c.iso3 = ps.country_iso3
JOIN rf.regions r   ON r.code = c.region_code
WHERE ps.method_version_id = (
    SELECT id FROM ma.indicator_method_versions
    WHERE is_active = TRUE ORDER BY id DESC LIMIT 1
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_pillar_scores
ON ma.mv_pillar_scores_all(pillar_code, country_iso3, year);

-- Vue : ISA toutes années
CREATE MATERIALIZED VIEW IF NOT EXISTS ma.mv_isa_all AS
SELECT
    isa.country_iso3,
    c.name_fr     AS country_name,
    c.iso2,
    r.code        AS region_code,
    r.name_fr     AS region_name,
    isa.year,
    isa.isa_score,
    RANK() OVER (PARTITION BY isa.year ORDER BY isa.isa_score DESC) AS rank_africa
FROM ma.isa_index isa
JOIN rf.countries c ON c.iso3 = isa.country_iso3
JOIN rf.regions r   ON r.code = c.region_code
WHERE isa.is_published = TRUE;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_isa_all
ON ma.mv_isa_all(country_iso3, year);

-- ============================================================
-- 8. FONCTIONS DU PIPELINE
-- ============================================================

-- F1 : Normalisation min-max d'un indicateur pour une année
CREATE OR REPLACE FUNCTION ma.normalize_indicator(
    p_indicator       VARCHAR(30),
    p_year            SMALLINT,
    p_method_version  INT DEFAULT 1
)
RETURNS INT  -- nombre de lignes insérées
LANGUAGE plpgsql AS $$
DECLARE
    v_min       NUMERIC;
    v_max       NUMERIC;
    v_direction CHAR(1);
    v_inserted  INT;
BEGIN
    SELECT direction INTO v_direction
    FROM rf.indicators WHERE code = p_indicator;

    IF v_direction IS NULL THEN
        RAISE EXCEPTION 'Indicateur inconnu : %', p_indicator;
    END IF;

    SELECT MIN(raw_value), MAX(raw_value)
    INTO   v_min, v_max
    FROM   ma.indicator_values
    WHERE  indicator_code = p_indicator
      AND  year = p_year
      AND  layer_id = 1
      AND  raw_value IS NOT NULL;

    IF v_min IS NULL OR v_max = v_min THEN
        RETURN 0;
    END IF;

    INSERT INTO ma.indicator_values
        (indicator_code, country_iso3, year, layer_id,
         raw_value, processed_value,
         method_version_id, quality_flag)
    SELECT
        indicator_code,
        country_iso3,
        year,
        3,  -- L3 = standardisé
        raw_value,
        CASE
            WHEN v_direction = '+'
                THEN (raw_value - v_min) / (v_max - v_min)
            ELSE
                (v_max - raw_value) / (v_max - v_min)
        END,
        p_method_version,
        quality_flag
    FROM ma.indicator_values
    WHERE indicator_code = p_indicator
      AND year = p_year
      AND layer_id = 1
      AND raw_value IS NOT NULL
    ON CONFLICT DO NOTHING;

    GET DIAGNOSTICS v_inserted = ROW_COUNT;
    RETURN v_inserted;
END;
$$;

-- F2 : Calcul du score pilier pour une année
CREATE OR REPLACE FUNCTION ma.compute_pillar_score(
    p_pillar          VARCHAR(10),
    p_year            SMALLINT,
    p_method_version  INT DEFAULT 1
)
RETURNS INT  -- nombre de pays traités
LANGUAGE plpgsql AS $$
DECLARE
    v_inserted INT;
BEGIN
    INSERT INTO ma.pillar_scores
        (pillar_code, country_iso3, year, score,
         indicators_used, indicators_total, coverage_pct,
         method_version_id)
    SELECT
        p_pillar,
        iv.country_iso3,
        p_year,
        SUM(iv.processed_value * ml.weight)     AS score,
        COUNT(DISTINCT iv.indicator_code)        AS indicators_used,
        15                                       AS indicators_total,
        ROUND(COUNT(DISTINCT iv.indicator_code) * 100.0 / 15, 1) AS coverage_pct,
        p_method_version
    FROM ma.indicator_values iv
    JOIN rf.indicators i
        ON i.code = iv.indicator_code
       AND i.pillar_code = p_pillar
    JOIN ma.indicator_meta_links ml
        ON ml.indicator_code = iv.indicator_code
       AND ml.meta_code = 'SOV_' || p_pillar
       AND ml.ref_year = p_year
    WHERE iv.year = p_year
      AND iv.layer_id = 3
      AND iv.processed_value IS NOT NULL
    GROUP BY iv.country_iso3
    HAVING COUNT(DISTINCT iv.indicator_code) >= 8  -- minimum 8/15 indicateurs
    ON CONFLICT (pillar_code, country_iso3, year, method_version_id)
        DO UPDATE SET
            score             = EXCLUDED.score,
            indicators_used   = EXCLUDED.indicators_used,
            coverage_pct      = EXCLUDED.coverage_pct,
            computed_at       = now();

    GET DIAGNOSTICS v_inserted = ROW_COUNT;
    RETURN v_inserted;
END;
$$;

-- F3 : Calcul ISA pour une année
CREATE OR REPLACE FUNCTION ma.compute_isa(
    p_year           SMALLINT,
    p_method_version INT DEFAULT 1
)
RETURNS INT
LANGUAGE plpgsql AS $$
DECLARE
    v_inserted INT;
BEGIN
    INSERT INTO ma.isa_index
        (country_iso3, year, isa_score, pillar_count, method_version_id)
    SELECT
        ps.country_iso3,
        p_year,
        ROUND(AVG(ps.score) * 100, 2),  -- équipondération piliers v1
        COUNT(DISTINCT ps.pillar_code),
        p_method_version
    FROM ma.pillar_scores ps
    WHERE ps.year = p_year
      AND ps.method_version_id = p_method_version
    GROUP BY ps.country_iso3
    HAVING COUNT(DISTINCT ps.pillar_code) >= 6  -- minimum 6/8 piliers
    ON CONFLICT (country_iso3, year, method_version_id)
        DO UPDATE SET
            isa_score    = EXCLUDED.isa_score,
            pillar_count = EXCLUDED.pillar_count,
            computed_at  = now();

    GET DIAGNOSTICS v_inserted = ROW_COUNT;
    RETURN v_inserted;
END;
$$;

-- F4 : Orchestration complète pour une année
CREATE OR REPLACE PROCEDURE ma.run_pipeline_year(
    p_year           SMALLINT,
    p_method_version INT DEFAULT 1
)
LANGUAGE plpgsql AS $$
DECLARE
    r           RECORD;
    v_count     INT;
BEGIN
    RAISE NOTICE 'Pipeline OSA — année % — début', p_year;

    -- L3 : normalisation de tous les indicateurs
    FOR r IN SELECT code FROM rf.indicators WHERE is_active = TRUE LOOP
        v_count := ma.normalize_indicator(r.code, p_year, p_method_version);
    END LOOP;
    RAISE NOTICE 'L3 normalisation terminée';

    -- L5 : scores piliers
    FOR r IN SELECT code FROM rf.pillars LOOP
        v_count := ma.compute_pillar_score(r.code, p_year, p_method_version);
        RAISE NOTICE 'Pilier % : % pays traités', r.code, v_count;
    END LOOP;

    -- L7 : ISA final
    v_count := ma.compute_isa(p_year, p_method_version);
    RAISE NOTICE 'ISA % : % pays calculés', p_year, v_count;

    -- Rafraîchissement vues matérialisées
    REFRESH MATERIALIZED VIEW CONCURRENTLY ma.mv_pillar_scores_all;
    REFRESH MATERIALIZED VIEW CONCURRENTLY ma.mv_isa_all;

    RAISE NOTICE 'Pipeline OSA — année % — terminé', p_year;
END;
$$;

-- F5 : Pipeline historique 2010 → année cible
CREATE OR REPLACE PROCEDURE ma.run_pipeline_historical(
    p_year_from      SMALLINT DEFAULT 2010,
    p_year_to        SMALLINT DEFAULT 2022,
    p_method_version INT      DEFAULT 1
)
LANGUAGE plpgsql AS $$
DECLARE
    y SMALLINT;
    r RECORD;
BEGIN
    -- Boucle principale : calcul sans refresh intermédiaire
    -- run_pipeline_year() est appelé via une version allégée qui n'inclut pas
    -- le REFRESH, évitant 2×N refreshs inutiles sur N années.
    FOR y IN p_year_from..p_year_to LOOP
        RAISE NOTICE 'Pipeline historique — année %', y;

        -- L3 : normalisation
        FOR r IN SELECT code FROM rf.indicators WHERE is_active = TRUE LOOP
            PERFORM ma.normalize_indicator(r.code, y, p_method_version);
        END LOOP;

        -- L5 : scores piliers
        FOR r IN SELECT code FROM rf.pillars LOOP
            PERFORM ma.compute_pillar_score(r.code, y, p_method_version);
        END LOOP;

        -- L7 : ISA
        PERFORM ma.compute_isa(y, p_method_version);
    END LOOP;

    -- Refresh unique en fin de traitement (2 vues × 1 fois, pas × N années)
    RAISE NOTICE 'Rafraîchissement des vues matérialisées...';
    REFRESH MATERIALIZED VIEW CONCURRENTLY ma.mv_pillar_scores_all;
    REFRESH MATERIALIZED VIEW CONCURRENTLY ma.mv_isa_all;

    RAISE NOTICE 'Pipeline historique terminé : % → %', p_year_from, p_year_to;
END;
$$;

-- ============================================================
-- 9. TRIGGER : horodatage automatique sur pillar_scores
-- ============================================================

CREATE OR REPLACE FUNCTION ma.trg_touch_computed_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    NEW.computed_at := now();
    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_pillar_scores_update
BEFORE UPDATE ON ma.pillar_scores
FOR EACH ROW EXECUTE FUNCTION ma.trg_touch_computed_at();

-- ============================================================
-- BLOC PKI / DOUBLE SIGNATURE — ACTIVÉ EN PHASE 4
-- ============================================================
/*
    Tables et procédures de gouvernance à activer en Phase 4 :
    - ma.ma_signing_request   (demandes d'exécution formelles)
    - ma.ma_signatures        (signatures humaines 4-eyes)
    - ma.ma_pki_registry      (certificats X.509 autorisés)
    - ma.orchestrate_ma_secure() (pipeline avec double validation)

    Principe : aucune exécution de run_pipeline_year() en production
    sans deux signatures cryptographiques valides (OPERATOR + CONTROLLER).
    Décommenter et déployer lors du passage en Phase 4.
*/

COMMIT;

-- Vérifications
-- SELECT COUNT(*) FROM ma.indicator_meta;                -- attendu : 120
-- SELECT COUNT(*) FROM ma.indicator_meta_links;          -- attendu : 120
-- SELECT COUNT(*) FROM ma.indicator_method_versions;     -- attendu : 6
-- SELECT tablename FROM pg_tables WHERE schemaname='ma' AND tablename LIKE 'indicator_values_%';
