-- ============================================================
-- OSA / ISA — Patch rf.normalization_bounds
-- Sprint 6 — Mai 2026
--
-- Objectif : geler les bornes min-max de normalisation L3
-- calculées sur la période de référence 2010–2020.
--
-- Principe :
--   - Les bornes 2010–2020 sont la référence stable.
--   - Les années 2021–2025+ sont normalisées contre ces bornes.
--   - Les scores historiques 2010–2020 ne changent plus.
--   - Compatible avec le standard PNUD/Banque mondiale (IDH).
--
-- Impact sur normalize_indicator() :
--   Étape 3 (Sprint 7) modifiera normalize_indicator pour lire
--   rf.normalization_bounds en priorité — si des bornes figées
--   existent pour un indicateur, elles remplacent le calcul
--   dynamique MIN/MAX sur l'ensemble de la table.
--
-- Ce patch ne modifie pas normalize_indicator.
-- Il prépare uniquement la table de référence.
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1. Création de la table rf.normalization_bounds
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS rf.normalization_bounds (
    indicator_code      VARCHAR(60)   NOT NULL,
    reference_from_year INTEGER       NOT NULL DEFAULT 2010,
    reference_to_year   INTEGER       NOT NULL DEFAULT 2020,
    min_value           NUMERIC(18,6) NOT NULL,
    max_value           NUMERIC(18,6) NOT NULL,
    nb_observations     INTEGER       NOT NULL,
    nb_countries        INTEGER       NOT NULL,
    coverage_pct        NUMERIC(5,2),
    freeze_version      VARCHAR(20)   NOT NULL DEFAULT 'v1_2026',
    freeze_reason       TEXT,
    frozen_at           TIMESTAMP     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMP     NOT NULL DEFAULT NOW(),
    is_active           BOOLEAN       NOT NULL DEFAULT TRUE,
    CONSTRAINT pk_normalization_bounds
        PRIMARY KEY (indicator_code, reference_from_year, reference_to_year, freeze_version),
    CONSTRAINT chk_bounds_valid
        CHECK (max_value >= min_value),
    CONSTRAINT chk_years_valid
        CHECK (reference_to_year >= reference_from_year)
);

COMMENT ON TABLE rf.normalization_bounds IS
    'Bornes min-max figées pour la normalisation L3. '
    'Permet la comparabilité temporelle des scores ISA. '
    'Principe : PNUD/Banque mondiale — les bornes de référence ne changent pas '
    'quand une nouvelle année est ajoutée. '
    'Sprint 6 — Mai 2026 — gel sur 2010-2020.';

COMMENT ON COLUMN rf.normalization_bounds.freeze_version IS
    'Version du gel. v1_2026 = premier gel officiel Sprint 6.';
COMMENT ON COLUMN rf.normalization_bounds.coverage_pct IS
    'Pourcentage de pays couverts sur la période de référence (sur 54).';
COMMENT ON COLUMN rf.normalization_bounds.is_active IS
    'TRUE = bornes actives pour normalize_indicator. '
    'FALSE = bornes archivées (ancien gel remplacé).';

-- Index pour normalize_indicator (lecture par indicator_code + is_active)
CREATE INDEX IF NOT EXISTS idx_normalization_bounds_active
    ON rf.normalization_bounds (indicator_code, is_active)
    WHERE is_active = TRUE;

-- ------------------------------------------------------------
-- 2. Calcul et insertion des bornes 2010–2020
--    Source : ma.indicator_values layer_id = 2
--    54 pays OSA × 2010–2020 (11 années max)
-- ------------------------------------------------------------

INSERT INTO rf.normalization_bounds (
    indicator_code,
    reference_from_year,
    reference_to_year,
    min_value,
    max_value,
    nb_observations,
    nb_countries,
    coverage_pct,
    freeze_version,
    freeze_reason,
    frozen_at,
    updated_at,
    is_active
)
SELECT
    iv.indicator_code,
    2010                                        AS reference_from_year,
    2020                                        AS reference_to_year,
    MIN(iv.raw_value)::numeric(18,6)            AS min_value,
    MAX(iv.raw_value)::numeric(18,6)            AS max_value,
    COUNT(*)::integer                           AS nb_observations,
    COUNT(DISTINCT iv.country_iso3)::integer    AS nb_countries,
    ROUND(
        COUNT(DISTINCT iv.country_iso3) * 100.0 / 54.0,
        2
    )                                           AS coverage_pct,
    'v1_2026'                                   AS freeze_version,
    'First official freeze — Sprint 6 May 2026. '
    'Reference period 2010-2020. '
    'Post full L2 MICE imputation + L3 renormalization. '
    'Aligned with WEAKNESS (from 2020) and THREAT (from 2021) SWOT series.'
                                                AS freeze_reason,
    NOW()                                       AS frozen_at,
    NOW()                                       AS updated_at,
    TRUE                                        AS is_active

FROM ma.indicator_values iv
INNER JOIN rf.indicators i
        ON i.code = iv.indicator_code
       AND i.is_active = TRUE
WHERE iv.layer_id    = 2
  AND iv.year       BETWEEN 2010 AND 2020
  AND iv.raw_value  IS NOT NULL
GROUP BY iv.indicator_code

-- Exclure les indicateurs où min = max (pas normalisables)
HAVING MIN(iv.raw_value) < MAX(iv.raw_value)

ON CONFLICT (indicator_code, reference_from_year, reference_to_year, freeze_version)
DO UPDATE SET
    min_value       = EXCLUDED.min_value,
    max_value       = EXCLUDED.max_value,
    nb_observations = EXCLUDED.nb_observations,
    nb_countries    = EXCLUDED.nb_countries,
    coverage_pct    = EXCLUDED.coverage_pct,
    freeze_reason   = EXCLUDED.freeze_reason,
    updated_at      = NOW();

-- ------------------------------------------------------------
-- 3. Table de suivi des bornes exclues (min = max)
--    Ces indicateurs nécessitent une attention manuelle.
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS rf.normalization_bounds_excluded (
    indicator_code  VARCHAR(60)   NOT NULL PRIMARY KEY,
    pillar_code     VARCHAR(10),
    nb_observations INTEGER,
    unique_value    NUMERIC(18,6),
    exclusion_reason TEXT,
    created_at      TIMESTAMP DEFAULT NOW()
);

INSERT INTO rf.normalization_bounds_excluded (
    indicator_code,
    pillar_code,
    nb_observations,
    unique_value,
    exclusion_reason
)
SELECT
    iv.indicator_code,
    i.pillar_code,
    COUNT(*)::integer,
    MIN(iv.raw_value)::numeric(18,6),
    'min_value = max_value sur 2010-2020 — normalisation min-max impossible. '
    'Indicateur à valeur constante ou quasi-constante sur la période de référence.'
FROM ma.indicator_values iv
INNER JOIN rf.indicators i ON i.code = iv.indicator_code AND i.is_active = TRUE
WHERE iv.layer_id = 2
  AND iv.year BETWEEN 2010 AND 2020
  AND iv.raw_value IS NOT NULL
GROUP BY iv.indicator_code, i.pillar_code
HAVING MIN(iv.raw_value) = MAX(iv.raw_value)
ON CONFLICT (indicator_code) DO UPDATE SET
    nb_observations = EXCLUDED.nb_observations,
    unique_value    = EXCLUDED.unique_value;

-- ------------------------------------------------------------
-- 4. Vue de consultation des bornes actives
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW rf.v_normalization_bounds_active AS
SELECT
    nb.indicator_code,
    i.pillar_code,
    i.direction,
    nb.reference_from_year,
    nb.reference_to_year,
    nb.min_value,
    nb.max_value,
    ROUND((nb.max_value - nb.min_value)::numeric, 6) AS range_value,
    nb.nb_observations,
    nb.nb_countries,
    nb.coverage_pct,
    nb.freeze_version,
    nb.frozen_at
FROM rf.normalization_bounds nb
INNER JOIN rf.indicators i ON i.code = nb.indicator_code
WHERE nb.is_active = TRUE
ORDER BY i.pillar_code, nb.indicator_code;

COMMENT ON VIEW rf.v_normalization_bounds_active IS
    'Bornes de normalisation actives par indicateur. '
    'Utilisées par normalize_indicator() après Sprint 7.';

-- ------------------------------------------------------------
-- 5. Registre de version des gels (traçabilité)
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS rf.normalization_freeze_registry (
    freeze_version      VARCHAR(20)  NOT NULL PRIMARY KEY,
    freeze_label        TEXT         NOT NULL,
    reference_from_year INTEGER      NOT NULL,
    reference_to_year   INTEGER      NOT NULL,
    nb_indicators_frozen INTEGER,
    nb_indicators_excluded INTEGER,
    sprint_id           VARCHAR(20),
    frozen_by           VARCHAR(100) DEFAULT 'OSA_PIPELINE',
    frozen_at           TIMESTAMP    DEFAULT NOW(),
    notes               TEXT
);

INSERT INTO rf.normalization_freeze_registry (
    freeze_version,
    freeze_label,
    reference_from_year,
    reference_to_year,
    nb_indicators_frozen,
    nb_indicators_excluded,
    sprint_id,
    notes
)
SELECT
    'v1_2026',
    'Premier gel officiel OSA/ISA — Sprint 6',
    2010,
    2020,
    (SELECT COUNT(*) FROM rf.normalization_bounds WHERE freeze_version = 'v1_2026' AND is_active = TRUE),
    (SELECT COUNT(*) FROM rf.normalization_bounds_excluded),
    'Sprint-6',
    'Gel post imputation complète MICE (L2) sur 135 indicateurs. '
    'Période de référence 2010-2020 alignée avec : '
    'WEAKNESS (début 2020), THREAT (début 2021 — nécessite t-1=2020). '
    'Distribution AMAR post-gel : médiane 0.562-0.610, écart-type 0.041-0.079. '
    'Seuils AMAR/GENECO recalibrés : GREEN<0.35 / YELLOW<0.45 / ORANGE<0.55 / RED<0.65 / BLACK>=0.65. '
    'Années publiables 2021-2024 normalisées contre ces bornes figées.'
ON CONFLICT (freeze_version) DO UPDATE SET
    nb_indicators_frozen   = EXCLUDED.nb_indicators_frozen,
    nb_indicators_excluded = EXCLUDED.nb_indicators_excluded,
    notes = EXCLUDED.notes;

-- ------------------------------------------------------------
-- 6. Vérification
-- ------------------------------------------------------------

SELECT
    'Bornes figées par pilier' AS rapport,
    i.pillar_code,
    COUNT(*) AS nb_indicateurs_geles,
    ROUND(AVG(nb.coverage_pct), 1) AS couverture_moy_pct,
    ROUND(MIN(nb.min_value)::numeric, 4) AS min_global,
    ROUND(MAX(nb.max_value)::numeric, 4) AS max_global
FROM rf.normalization_bounds nb
INNER JOIN rf.indicators i ON i.code = nb.indicator_code
WHERE nb.is_active = TRUE
GROUP BY i.pillar_code
ORDER BY i.pillar_code;

SELECT
    'Résumé gel v1_2026' AS rapport,
    freeze_version,
    reference_from_year,
    reference_to_year,
    nb_indicators_frozen,
    nb_indicators_excluded,
    frozen_at
FROM rf.normalization_freeze_registry
WHERE freeze_version = 'v1_2026';

SELECT
    'Indicateurs exclus (min=max)' AS rapport,
    pillar_code,
    indicator_code,
    nb_observations,
    unique_value
FROM rf.normalization_bounds_excluded
ORDER BY pillar_code, indicator_code;

COMMIT;
