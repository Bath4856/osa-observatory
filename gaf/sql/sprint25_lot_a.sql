-- ============================================================
-- Sprint 25 -- Lot A : AMAR Trigger Engine
-- pub.amar_triggers / pub.v_amar_trigger_log / trigger_classify()
-- 23 juin 2026
-- GAF reference : finding_id = 23
-- ============================================================
-- EXECUTION ORDER :
--   1. trigger_classify()       -- fonction independante
--   2. pub.amar_triggers        -- table (depend de rf.countries si FK)
--   3. pub.v_amar_trigger_log   -- vue (depend de la table)
-- ============================================================

BEGIN;

-- ────────────────────────────────────────────────────────────
-- 1. FONCTION trigger_classify()
--    Implemente la taxonomie 4 classes Option B (finding_id=23)
--    Logique de priorite :
--      1. EXCEPTIONAL  : thr >= 0.40                          (independant de wkn)
--      2. CRITICAL     : thr >= 0.20 ET wkn >= 0.70 ET conf > 0
--      3. INCOMPLETE   : thr >= 0.20 ET thr < 0.40 ET (wkn IS NULL OU conf = 0)
--      4. ACTIVE       : thr >= 0.20 (tous les autres cas)
--      5. NULL         : thr < 0.20  (pas de trigger)
-- ────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION pub.trigger_classify(
    p_thr  NUMERIC,
    p_wkn  NUMERIC,   -- NULL acceptable (Option B)
    p_conf NUMERIC    -- NULL acceptable
)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    -- Pas de trigger sous le seuil minimal
    IF p_thr IS NULL OR p_thr < 0.20 THEN
        RETURN NULL;
    END IF;

    -- Priorite 1 : signal exceptionnel -- independant de wkn
    IF p_thr >= 0.40 THEN
        RETURN 'TRIGGER_EXCEPTIONAL';
    END IF;

    -- p_thr est dans [0.20, 0.40[ a partir d'ici

    -- Priorite 2 : incompletude diagnostique (Option B)
    -- wkn absent OU confiance nulle
    IF p_wkn IS NULL OR COALESCE(p_conf, 0) = 0 THEN
        RETURN 'TRIGGER_DIAGNOSTIC_INCOMPLETE';
    END IF;

    -- Priorite 3 : signal critique (wkn confirme + eleve)
    IF p_wkn >= 0.70 THEN
        RETURN 'TRIGGER_CRITICAL';
    END IF;

    -- Priorite 4 : signal actif
    RETURN 'TRIGGER_ACTIVE';
END;
$$;

COMMENT ON FUNCTION pub.trigger_classify(NUMERIC, NUMERIC, NUMERIC) IS
'Taxonomie 4 classes AMAR Trigger Engine (Option B, Sprint 25).
Entrees : thr_score, wkn_score (nullable), wkn_confidence (nullable).
Retourne : TRIGGER_EXCEPTIONAL | TRIGGER_CRITICAL | TRIGGER_ACTIVE |
           TRIGGER_DIAGNOSTIC_INCOMPLETE | NULL (pas de trigger).
Reference : ops.audit_findings finding_id = 23 (GAF-AMAR-TRIGGER-002).';


-- ────────────────────────────────────────────────────────────
-- 2. TABLE pub.amar_triggers
--    PK composite (country_iso3, year, pillar_code)
--    Convention OSA : ON CONFLICT DO NOTHING au chargement
-- ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS pub.amar_triggers (

    -- Cle naturelle
    country_iso3    CHAR(3)         NOT NULL,
    year            SMALLINT        NOT NULL,
    pillar_code     VARCHAR(10)     NOT NULL,

    -- Classification
    trigger_class   TEXT            NOT NULL
        CONSTRAINT chk_trigger_class CHECK (
            trigger_class IN (
                'TRIGGER_EXCEPTIONAL',
                'TRIGGER_CRITICAL',
                'TRIGGER_ACTIVE',
                'TRIGGER_DIAGNOSTIC_INCOMPLETE'
            )
        ),

    -- Scores sources
    thr_score       NUMERIC(6,4)    NOT NULL,
    wkn_score       NUMERIC(6,4),       -- nullable : Option B
    wkn_confidence  NUMERIC(6,4),       -- nullable : Option B

    -- Attribut qualite donnees (Option B, finding_id=23)
    wkn_missing     BOOLEAN         NOT NULL DEFAULT FALSE,

    -- Traçabilite
    source_view     TEXT            NOT NULL DEFAULT 'ma.v_p7i_risk_source',
    computed_at     TIMESTAMPTZ     NOT NULL DEFAULT now(),

    -- Cle primaire composite
    CONSTRAINT pk_amar_triggers PRIMARY KEY (country_iso3, year, pillar_code)
);

COMMENT ON TABLE pub.amar_triggers IS
'Registre des declenchements AMAR Trigger Engine.
PK composite (country_iso3, year, pillar_code) -- convention OSA ON CONFLICT DO NOTHING.
Taxonomie 4 classes Option B -- reference finding_id=23 (GAF-AMAR-TRIGGER-002).
Backfill 2020-2024 charge en Lot B (18 lignes).';

COMMENT ON COLUMN pub.amar_triggers.wkn_missing IS
'TRUE si wkn_score est NULL au moment du calcul (Option B).
Un trigger EXCEPTIONAL peut avoir wkn_missing=TRUE -- signal valide, incompletude publiee comme attribut qualite.';

COMMENT ON COLUMN pub.amar_triggers.trigger_class IS
'TRIGGER_EXCEPTIONAL          : thr >= 0.40 (independant de wkn)
TRIGGER_CRITICAL              : thr >= 0.20, wkn >= 0.70, conf > 0
TRIGGER_ACTIVE                : thr >= 0.20 (autres cas avec wkn present)
TRIGGER_DIAGNOSTIC_INCOMPLETE : thr in [0.20, 0.40[, wkn absent ou conf = 0';


-- Index complementaires
CREATE INDEX IF NOT EXISTS idx_amar_triggers_year
    ON pub.amar_triggers (year);

CREATE INDEX IF NOT EXISTS idx_amar_triggers_class
    ON pub.amar_triggers (trigger_class);

CREATE INDEX IF NOT EXISTS idx_amar_triggers_country_year
    ON pub.amar_triggers (country_iso3, year);


-- ────────────────────────────────────────────────────────────
-- 3. VUE pub.v_amar_trigger_log
--    Lecture enrichie : libelles pays, piliers, ordre de gravite
-- ────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW pub.v_amar_trigger_log AS
SELECT
    t.country_iso3,
    t.year,
    t.pillar_code,
    t.trigger_class,

    -- Ordre de gravite pour tri (1 = le plus grave)
    CASE t.trigger_class
        WHEN 'TRIGGER_EXCEPTIONAL'           THEN 1
        WHEN 'TRIGGER_CRITICAL'              THEN 2
        WHEN 'TRIGGER_ACTIVE'                THEN 3
        WHEN 'TRIGGER_DIAGNOSTIC_INCOMPLETE' THEN 4
    END                                         AS severity_rank,

    t.thr_score,
    t.wkn_score,
    t.wkn_confidence,
    t.wkn_missing,

    -- Libelle lisible de la classe
    CASE t.trigger_class
        WHEN 'TRIGGER_EXCEPTIONAL'
            THEN 'Exceptional threat signal — immediate review required'
        WHEN 'TRIGGER_CRITICAL'
            THEN 'Critical threat — confirmed structural vulnerability'
        WHEN 'TRIGGER_ACTIVE'
            THEN 'Active threat signal — analytical review recommended'
        WHEN 'TRIGGER_DIAGNOSTIC_INCOMPLETE'
            THEN 'Active signal — structural data incomplete'
    END                                         AS trigger_label,

    -- Note qualite donnees
    CASE
        WHEN t.wkn_missing
            THEN 'Structural context unavailable — classification based on threat signal only'
        WHEN t.wkn_confidence < 0.50
            THEN 'Low structural confidence (conf=' || ROUND(t.wkn_confidence, 3)::TEXT || ')'
        ELSE NULL
    END                                         AS data_quality_note,

    -- Publication policy : masquer les annees non officielles
    pp.status                                         AS publication_status,

    t.source_view,
    t.computed_at

FROM pub.amar_triggers t
LEFT JOIN rf.publication_policy pp
    ON pp.year = t.year
ORDER BY
    t.year DESC,
    severity_rank ASC,
    t.thr_score DESC;

COMMENT ON VIEW pub.v_amar_trigger_log IS
'Vue de lecture enrichie des declenchements AMAR Trigger Engine.
Joints rf.publication_policy pour le statut de publication par annee.
Ordre : annee desc, gravite asc (EXCEPTIONAL en premier), thr_score desc.';


-- ────────────────────────────────────────────────────────────
-- VERIFICATION RAPIDE post-installation
-- ────────────────────────────────────────────────────────────

-- Test unitaire de la fonction sur les 4 classes + cas NULL
SELECT
    'EXCEPTIONAL (thr=1.0, wkn=NULL)'      AS test_case,
    pub.trigger_classify(1.000, NULL, NULL) AS result,
    'TRIGGER_EXCEPTIONAL'                   AS expected
UNION ALL SELECT
    'EXCEPTIONAL (thr=0.40, wkn=0.30)',
    pub.trigger_classify(0.40, 0.30, 0.80),
    'TRIGGER_EXCEPTIONAL'
UNION ALL SELECT
    'INCOMPLETE (thr=0.25, wkn=NULL)',
    pub.trigger_classify(0.25, NULL, NULL),
    'TRIGGER_DIAGNOSTIC_INCOMPLETE'
UNION ALL SELECT
    'INCOMPLETE (thr=0.25, wkn=0.80, conf=0)',
    pub.trigger_classify(0.25, 0.80, 0.00),
    'TRIGGER_DIAGNOSTIC_INCOMPLETE'
UNION ALL SELECT
    'CRITICAL (thr=0.25, wkn=0.80, conf=0.70)',
    pub.trigger_classify(0.25, 0.80, 0.70),
    'TRIGGER_CRITICAL'
UNION ALL SELECT
    'ACTIVE (thr=0.25, wkn=0.50, conf=0.70)',
    pub.trigger_classify(0.25, 0.50, 0.70),
    'TRIGGER_ACTIVE'
UNION ALL SELECT
    'NULL (thr=0.10)',
    pub.trigger_classify(0.10, 0.80, 0.80),
    'NULL'
UNION ALL SELECT
    'NULL (thr=NULL)',
    pub.trigger_classify(NULL, 0.80, 0.80),
    'NULL';

COMMIT;
