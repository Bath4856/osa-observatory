-- ============================================================
-- OSA / ISA — P7I-AMAR-GENECO Methodological Notes Patch
-- Sprint 5 — Mai 2026
-- Ajoute les notes de surveillance des sous-classements
-- dans mg.package_registry et mg.risk_taxonomy.
-- Aucune vue modifiée. Aucun score recalculé.
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1. Mise à jour de la description P7I-AMAR-GENECO
--    dans mg.package_registry
-- ------------------------------------------------------------

UPDATE mg.package_registry
SET
    description = 'P7I-AMAR-GENECO measures conflict-economy exposure '
        || 'using five dimensions: resource capture, logistics enabling, '
        || 'institutional capture, civilian exploitation, and narrative weaponization. '
        || 'Score scale: 0.000–1.000. Bands: GREEN < 0.25 / YELLOW < 0.45 / '
        || 'ORANGE < 0.65 / RED < 0.80 / BLACK >= 0.80. '
        || 'METHODOLOGICAL NOTE (Sprint 5): Countries with high resource_capture_risk '
        || '(>= 0.700) but low logistics_enabling_risk may be underclassified. '
        || 'Known affected cases: TCD (2017), MLI (2017–2019), CAF (2019). '
        || 'Root cause: PTRA does not yet capture armed-group movement corridors. '
        || 'Correction expected after UCDP integration (Sprint 6). '
        || 'This module does not create a new ISA pillar and does not attribute legal responsibility.',
    updated_at = NOW()
WHERE package_code = 'P7I-AMAR-GENECO';

-- ------------------------------------------------------------
-- 2. Mise à jour de la description CONFLICT_ECONOMY_EXPOSURE
--    dans mg.risk_taxonomy
-- ------------------------------------------------------------

UPDATE mg.risk_taxonomy
SET
    description = 'Risk that extractive, logistics, institutional, humanitarian '
        || 'or information conditions enable a conflict economy. '
        || 'This is not legal attribution. '
        || 'KNOWN LIMITATION: The logistics_enabling_risk component (PTRA/PMIL) '
        || 'may underestimate conflict-logistics in landlocked or isolated countries '
        || '(ERI, SWZ) and in active Sahel conflict zones (TCD, MLI, CAF) '
        || 'due to insufficient armed-group movement data in current PTRA sources. '
        || 'UCDP integration (Sprint 6) is expected to correct this gap. '
        || 'Users should apply expert judgment for these countries '
        || 'when logistics_enabling_risk < 0.450 and resource_capture_risk >= 0.700.',
    updated_at = NOW()
WHERE risk_code = 'CONFLICT_ECONOMY_EXPOSURE';

-- ------------------------------------------------------------
-- 3. Table de surveillance des sous-classements
--    Créée si elle n'existe pas — permet de persister
--    les cas identifiés pour revue lors de Sprint 6.
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS mg.geneco_underclassification_watch (
    id                  BIGSERIAL PRIMARY KEY,
    country_iso3        VARCHAR(3)    NOT NULL,
    year                INTEGER       NOT NULL,
    geneco_score        NUMERIC(6,3)  NOT NULL,
    confidence          NUMERIC(6,3),
    resource_capture    NUMERIC(6,3)  NOT NULL,
    logistics           NUMERIC(6,3)  NOT NULL,
    capture_gap         NUMERIC(6,3)  NOT NULL,
    watch_reason        TEXT          NOT NULL,
    sprint_identified   VARCHAR(20)   NOT NULL DEFAULT 'Sprint-5',
    expected_correction VARCHAR(100),
    status              VARCHAR(20)   NOT NULL DEFAULT 'OPEN',
    created_at          TIMESTAMP     DEFAULT NOW(),
    updated_at          TIMESTAMP     DEFAULT NOW(),
    UNIQUE(country_iso3, year, sprint_identified)
);

-- ------------------------------------------------------------
-- 4. Insertion des cas identifiés lors de l'investigation
--    Sprint 5 (résultat de la requête underclassification)
-- ------------------------------------------------------------

INSERT INTO mg.geneco_underclassification_watch (
    country_iso3, year, geneco_score, confidence,
    resource_capture, logistics, capture_gap,
    watch_reason, sprint_identified, expected_correction, status
)
VALUES
-- Cas critiques : conflit actif, logistics sous-capté
('TCD', 2017, 0.636, 0.680, 0.857, 0.387, 0.221,
 'Active Sahel conflict zone. resource_capture_risk=0.857 but logistics=0.387. PTRA does not capture armed-group corridors.',
 'Sprint-5', 'UCDP integration Sprint-6', 'OPEN'),

('MLI', 2019, 0.623, 0.672, 0.804, 0.334, 0.181,
 'Active Sahel conflict zone. resource_capture_risk=0.804 but logistics=0.334. Likely underestimated.',
 'Sprint-5', 'UCDP integration Sprint-6', 'OPEN'),

('MLI', 2018, 0.636, 0.672, 0.763, 0.392, 0.127,
 'Active Sahel conflict zone. Recurrent underclassification across 2017–2019.',
 'Sprint-5', 'UCDP integration Sprint-6', 'OPEN'),

('MLI', 2017, 0.612, 0.669, 0.715, 0.344, 0.103,
 'Active Sahel conflict zone. Same pattern as 2018–2019.',
 'Sprint-5', 'UCDP integration Sprint-6', 'OPEN'),

('CAF', 2019, 0.616, 0.651, 0.717, 0.362, 0.101,
 'Active conflict context. resource_capture elevated, logistics low due to PTRA coverage gap.',
 'Sprint-5', 'UCDP integration Sprint-6', 'OPEN'),

-- Cas structurels : enclavement géographique (sous-classement analytiquement correct)
('ERI', 2021, 0.542, 0.571, 0.773, 0.487, 0.231,
 'Structurally isolated country. Low logistics consistent with geographic enclavement. Underclassification likely correct.',
 'Sprint-5', 'Monitor post-UCDP — may remain low', 'MONITOR'),

('SWZ', 2014, 0.642, 0.679, 0.840, 0.315, 0.198,
 'Landlocked enclave. High resource_capture (mining) but no conflict logistics. Underclassification analytically justified.',
 'Sprint-5', 'No correction expected — geographic constraint', 'CLOSED'),

('SWZ', 2012, 0.642, 0.679, 0.843, 0.322, 0.201,
 'Same structural pattern as 2014. Recurrent.',
 'Sprint-5', 'No correction expected — geographic constraint', 'CLOSED'),

-- Cas historiques post-conflit
('SLE', 2014, 0.643, 0.678, 0.733, 0.445, 0.090,
 'Post-conflict context (2002). Resource extraction active, conflict logistics reduced. Likely correct.',
 'Sprint-5', 'Monitor — Ebola crisis period may affect data', 'MONITOR'),

('LBR', 2018, 0.645, 0.667, 0.731, 0.586, 0.086,
 'Post-conflict context. Transition period. Underclassification likely correct.',
 'Sprint-5', 'No correction expected — post-conflict stabilization', 'CLOSED'),

-- Cas NER 2010 : confiance élevée mais score bas
('NER', 2010, 0.634, 0.743, 0.835, 0.420, 0.201,
 'High confidence (0.743) but gap of 0.201. resource_capture=0.835 vs logistics=0.420. Early period — data review needed.',
 'Sprint-5', 'UCDP integration Sprint-6', 'OPEN')

ON CONFLICT (country_iso3, year, sprint_identified) DO UPDATE SET
    status     = EXCLUDED.status,
    updated_at = NOW();

-- ------------------------------------------------------------
-- 5. Vue de suivi pour le rapport d'audit
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW mg.v_geneco_underclassification_watch AS
SELECT
    country_iso3,
    year,
    geneco_score,
    confidence,
    resource_capture,
    logistics,
    capture_gap,
    watch_reason,
    sprint_identified,
    expected_correction,
    status,
    created_at
FROM mg.geneco_underclassification_watch
ORDER BY
    CASE status WHEN 'OPEN' THEN 1 WHEN 'MONITOR' THEN 2 ELSE 3 END,
    capture_gap DESC;

COMMIT;
