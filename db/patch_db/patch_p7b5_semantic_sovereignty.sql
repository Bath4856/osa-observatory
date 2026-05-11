-- ============================================================
-- OSA / ISA — P7B5
-- Patch: Semantic Sovereignty Engine
-- Objectif:
--   Créer la politique référentielle de souveraineté sémantique.
--
-- Principe:
--   P7B5 ne supprime aucun signal.
--   Il qualifie le niveau de souveraineté porté par chaque famille
--   sémantique et prépare un score transversal exploitable par ISA/ML.
-- ============================================================

BEGIN;

CREATE TABLE IF NOT EXISTS rf.semantic_sovereignty_policy (
    semantic_code VARCHAR(30) PRIMARY KEY,

    sovereignty_floor NUMERIC(5,3) NOT NULL DEFAULT 0.300,
    sovereignty_ceiling NUMERIC(5,3) NOT NULL DEFAULT 0.980,

    base_sovereignty_weight NUMERIC(5,3) NOT NULL DEFAULT 0.700,
    physicality_boost NUMERIC(5,3) NOT NULL DEFAULT 0.000,
    resilience_boost NUMERIC(5,3) NOT NULL DEFAULT 0.000,
    dependency_penalty NUMERIC(5,3) NOT NULL DEFAULT 0.000,
    locked_review_penalty NUMERIC(5,3) NOT NULL DEFAULT 0.120,
    forecast_disabled_penalty NUMERIC(5,3) NOT NULL DEFAULT 0.060,
    weak_confidence_penalty NUMERIC(5,3) NOT NULL DEFAULT 0.050,

    sovereignty_role VARCHAR(40) NOT NULL DEFAULT 'GENERAL_SIGNAL',
    notes TEXT,
    updated_at TIMESTAMP DEFAULT now(),

    CHECK (sovereignty_floor >= 0 AND sovereignty_floor <= 1),
    CHECK (sovereignty_ceiling >= 0 AND sovereignty_ceiling <= 1),
    CHECK (sovereignty_floor <= sovereignty_ceiling)
);

INSERT INTO rf.semantic_sovereignty_policy (
    semantic_code,
    sovereignty_floor,
    sovereignty_ceiling,
    base_sovereignty_weight,
    physicality_boost,
    resilience_boost,
    dependency_penalty,
    locked_review_penalty,
    forecast_disabled_penalty,
    weak_confidence_penalty,
    sovereignty_role,
    notes
)
VALUES
('PHYSICAL',   0.350, 0.980, 0.950, 0.050, 0.000, 0.020, 0.180, 0.080, 0.060, 'RESOURCE_CONTROL',       'Ressources physiques : énergie, eau, minerais, infrastructures critiques.'),
('STOCK',      0.350, 0.970, 0.900, 0.030, 0.000, 0.020, 0.120, 0.060, 0.050, 'STRATEGIC_STOCK',        'Stocks/réserves : capital latent de souveraineté.'),
('STRUCTURAL', 0.350, 0.970, 0.850, 0.000, 0.030, 0.020, 0.100, 0.050, 0.050, 'CAPACITY_CONTROL',       'Capacités structurelles durables.'),
('GOVERNANCE', 0.300, 0.950, 0.830, 0.000, 0.020, 0.030, 0.100, 0.050, 0.050, 'INSTITUTIONAL_CONTROL',  'Contrôle institutionnel et politique publique.'),
('DEPENDENCY', 0.250, 0.930, 0.810, 0.000, 0.000, 0.120, 0.130, 0.060, 0.060, 'DEPENDENCY_EXPOSURE',    'Dépendances stratégiques : signal de vulnérabilité souveraine.'),
('GEO',        0.250, 0.930, 0.800, 0.000, 0.000, 0.080, 0.120, 0.070, 0.060, 'GEOPOLITICAL_CONTROL',   'Contexte géopolitique, influence et exposition externe.'),
('PRESSURE',   0.250, 0.930, 0.790, 0.000, 0.000, 0.090, 0.120, 0.070, 0.060, 'SYSTEMIC_PRESSURE',      'Pressions systémiques pouvant réduire la souveraineté.'),
('RESILIENCE', 0.300, 0.960, 0.770, 0.000, 0.080, 0.020, 0.090, 0.040, 0.050, 'RESILIENCE_CAPACITY',    'Capacité d’absorption et de continuité.'),
('NETWORK',    0.300, 0.950, 0.730, 0.000, 0.020, 0.050, 0.110, 0.050, 0.050, 'NETWORK_CONTROL',        'Réseaux numériques, transport, connectivité.'),
('FLOW',       0.300, 0.940, 0.680, 0.000, 0.000, 0.060, 0.090, 0.050, 0.050, 'FLOW_CONTROL',           'Flux économiques, financiers, logistiques ou informationnels.'),
('EVENT',      0.200, 0.900, 0.660, 0.000, 0.000, 0.070, 0.090, 0.110, 0.060, 'SHOCK_SIGNAL',           'Événement : utile comme signal de choc, faible en projection souveraine.'),
('COMPOSITE',  0.300, 0.930, 0.630, 0.000, 0.000, 0.040, 0.090, 0.050, 0.050, 'MODEL_DEPENDENT_SIGNAL', 'Composite : dépend de la qualité de ses composants.'),
('PERCEPTION', 0.200, 0.880, 0.460, 0.000, 0.000, 0.050, 0.080, 0.060, 0.070, 'PERCEPTION_SIGNAL',      'Perception : signal utile, biais de mesure à documenter.')
ON CONFLICT (semantic_code) DO UPDATE SET
    sovereignty_floor = EXCLUDED.sovereignty_floor,
    sovereignty_ceiling = EXCLUDED.sovereignty_ceiling,
    base_sovereignty_weight = EXCLUDED.base_sovereignty_weight,
    physicality_boost = EXCLUDED.physicality_boost,
    resilience_boost = EXCLUDED.resilience_boost,
    dependency_penalty = EXCLUDED.dependency_penalty,
    locked_review_penalty = EXCLUDED.locked_review_penalty,
    forecast_disabled_penalty = EXCLUDED.forecast_disabled_penalty,
    weak_confidence_penalty = EXCLUDED.weak_confidence_penalty,
    sovereignty_role = EXCLUDED.sovereignty_role,
    notes = EXCLUDED.notes,
    updated_at = now();

CREATE INDEX IF NOT EXISTS idx_semantic_sovereignty_policy_role
    ON rf.semantic_sovereignty_policy(sovereignty_role);

DO $$
BEGIN
    RAISE NOTICE 'P7B5 semantic sovereignty policy lignes : %',
        (SELECT COUNT(*) FROM rf.semantic_sovereignty_policy);
END $$;

COMMIT;
