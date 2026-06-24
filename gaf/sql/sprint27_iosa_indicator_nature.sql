-- ============================================================
-- Sprint 27 -- Activation classe IOSA dans rf.indicator_nature
-- GAF finding #30 IOSA_CLASS_CREATION (ORIENTED)
-- 23 juin 2026
-- ============================================================
-- EXECUTION :
--   docker exec -i osa-db psql -U postgres -d osa_db \
--     < sprint27_iosa_indicator_nature.sql
-- ============================================================

BEGIN;

-- 1. Inserer dans rf.indicator_nature
INSERT INTO rf.indicator_nature (
    indicator_code, nature_code, confidence_policy,
    physical_weight, imputation_allowed, exclusion_threshold, notes
)
VALUES
(
    'PHUM_VALUE_CAPTURE',
    'STRUCTURAL', 'STRICT', 0.70, false, 0.55,
    'Classe IOSA -- Indicateur observation souveraine autonome. '
    'Retention capital humain. Non comparable inter-pays. '
    'Non imputable par doctrine. Source WB primaire.'
),
(
    'PMIN_VALUE_LEAKAGE',
    'STRUCTURAL', 'STRICT', 0.75, false, 0.60,
    'Classe IOSA -- Indicateur observation souveraine autonome. '
    'Fuite valeur ajoutee minerale BACI/CEPII HS92. '
    'Non comparable inter-pays. Non imputable par doctrine.'
),
(
    'PMIN_SMUGGLING_SIGNAL_RANK',
    'STRUCTURAL', 'STRICT', 0.70, false, 0.60,
    'Classe IOSA -- Indicateur observation souveraine autonome. '
    'Signal ordinal contrebande BACI x USGS. '
    'Serie partielle 2016-2021. Non imputable par doctrine.'
)
ON CONFLICT (indicator_code) DO UPDATE SET
    nature_code         = EXCLUDED.nature_code,
    confidence_policy   = EXCLUDED.confidence_policy,
    physical_weight     = EXCLUDED.physical_weight,
    imputation_allowed  = EXCLUDED.imputation_allowed,
    exclusion_threshold = EXCLUDED.exclusion_threshold,
    notes               = EXCLUDED.notes,
    updated_at          = now();

-- 2. Marquer indicator_group = 'IOSA' dans rf.indicators
UPDATE rf.indicators
SET indicator_group = 'IOSA'
WHERE code IN (
    'PHUM_VALUE_CAPTURE',
    'PMIN_VALUE_LEAKAGE',
    'PMIN_SMUGGLING_SIGNAL_RANK'
);

-- 3. Verification
SELECT
    i.code,
    i.pillar_code,
    i.indicator_group,
    n.nature_code,
    n.confidence_policy,
    n.imputation_allowed,
    n.physical_weight,
    n.exclusion_threshold
FROM rf.indicators i
JOIN rf.indicator_nature n ON n.indicator_code = i.code
WHERE i.code IN (
    'PHUM_VALUE_CAPTURE',
    'PMIN_VALUE_LEAKAGE',
    'PMIN_SMUGGLING_SIGNAL_RANK'
)
ORDER BY i.code;

-- 4. Verifier que imputation_allowed = false est bien pose
-- (aucun des 3 ne doit etre dans les candidats a imputation)
SELECT COUNT(*) AS iosa_non_imputables
FROM rf.indicator_nature
WHERE indicator_code IN (
    'PHUM_VALUE_CAPTURE',
    'PMIN_VALUE_LEAKAGE',
    'PMIN_SMUGGLING_SIGNAL_RANK'
)
AND imputation_allowed = false;

COMMIT;
