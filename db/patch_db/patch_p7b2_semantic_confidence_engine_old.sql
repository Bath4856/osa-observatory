-- ============================================================
-- OSA / ISA — P7B2
-- Semantic Confidence Engine Policy
-- Objectif : transformer la confiance sémantique statique en
-- confiance dynamique gouvernée par la matrice P7B1.
-- ============================================================

BEGIN;

CREATE TABLE IF NOT EXISTS rf.semantic_confidence_policy (
    semantic_code           VARCHAR(30) PRIMARY KEY,
    base_confidence_floor   NUMERIC(4,3) NOT NULL DEFAULT 0.500,
    base_confidence_ceiling NUMERIC(4,3) NOT NULL DEFAULT 0.980,
    physical_penalty        NUMERIC(4,3) NOT NULL DEFAULT 0.000,
    event_penalty           NUMERIC(4,3) NOT NULL DEFAULT 0.000,
    critical_review_penalty NUMERIC(4,3) NOT NULL DEFAULT 0.180,
    weak_governance_penalty NUMERIC(4,3) NOT NULL DEFAULT 0.080,
    hybrid_bonus            NUMERIC(4,3) NOT NULL DEFAULT 0.030,
    strategic_bonus         NUMERIC(4,3) NOT NULL DEFAULT 0.040,
    governed_bonus          NUMERIC(4,3) NOT NULL DEFAULT 0.030,
    ml_priority_bonus       NUMERIC(4,3) NOT NULL DEFAULT 0.020,
    volatility_penalty      NUMERIC(4,3) NOT NULL DEFAULT 0.000,
    notes                   TEXT,
    updated_at              TIMESTAMP DEFAULT now(),
    CONSTRAINT semantic_confidence_bounds CHECK (
        base_confidence_floor >= 0 AND base_confidence_floor <= 1 AND
        base_confidence_ceiling >= 0 AND base_confidence_ceiling <= 1 AND
        base_confidence_floor <= base_confidence_ceiling
    )
);

INSERT INTO rf.semantic_confidence_policy (
    semantic_code, base_confidence_floor, base_confidence_ceiling,
    physical_penalty, event_penalty, critical_review_penalty,
    weak_governance_penalty, hybrid_bonus, strategic_bonus,
    governed_bonus, ml_priority_bonus, volatility_penalty, notes
)
VALUES
('PHYSICAL',   0.620, 0.970, 0.060, 0.000, 0.220, 0.090, 0.020, 0.030, 0.030, 0.030, 0.020, 'Données physiques : forte valeur ISA mais prudence stricte si non certifiées.'),
('STOCK',      0.640, 0.960, 0.030, 0.000, 0.180, 0.070, 0.025, 0.035, 0.030, 0.025, 0.010, 'Stocks/réserves : interpolation possible seulement si source stable.'),
('STRUCTURAL', 0.650, 0.970, 0.000, 0.000, 0.140, 0.060, 0.030, 0.045, 0.035, 0.030, 0.020, 'Capacités structurelles : forte utilité ML et projection.'),
('GOVERNANCE', 0.600, 0.950, 0.000, 0.000, 0.150, 0.070, 0.030, 0.040, 0.030, 0.030, 0.030, 'Gouvernance : utile mais parfois composite/perception.'),
('DEPENDENCY', 0.570, 0.940, 0.000, 0.000, 0.180, 0.080, 0.035, 0.035, 0.025, 0.035, 0.050, 'Dépendance stratégique : signal sensible.'),
('GEO',        0.540, 0.930, 0.000, 0.000, 0.200, 0.090, 0.035, 0.035, 0.025, 0.035, 0.060, 'Géopolitique : volatilité élevée.'),
('PRESSURE',   0.560, 0.940, 0.000, 0.000, 0.190, 0.080, 0.030, 0.035, 0.025, 0.035, 0.060, 'Pression systémique : signal de risque.'),
('RESILIENCE', 0.620, 0.960, 0.000, 0.000, 0.140, 0.060, 0.030, 0.045, 0.035, 0.030, 0.020, 'Résilience : signal stratégique positif.'),
('NETWORK',    0.590, 0.950, 0.000, 0.000, 0.170, 0.070, 0.035, 0.040, 0.030, 0.030, 0.030, 'Réseaux : dépendance et connectivité.'),
('FLOW',       0.580, 0.940, 0.000, 0.000, 0.160, 0.070, 0.030, 0.035, 0.025, 0.030, 0.050, 'Flux économiques/logistiques/informationnels.'),
('EVENT',      0.500, 0.900, 0.000, 0.080, 0.220, 0.100, 0.025, 0.025, 0.020, 0.020, 0.070, 'Événements : très faible extrapolation.'),
('COMPOSITE',  0.570, 0.930, 0.000, 0.000, 0.160, 0.070, 0.025, 0.035, 0.025, 0.030, 0.030, 'Composite : dépend de ses composants.'),
('PERCEPTION', 0.480, 0.880, 0.000, 0.000, 0.180, 0.080, 0.020, 0.020, 0.020, 0.015, 0.040, 'Perception : biais de mesure à surveiller.')
ON CONFLICT (semantic_code) DO UPDATE SET
    base_confidence_floor   = EXCLUDED.base_confidence_floor,
    base_confidence_ceiling = EXCLUDED.base_confidence_ceiling,
    physical_penalty        = EXCLUDED.physical_penalty,
    event_penalty           = EXCLUDED.event_penalty,
    critical_review_penalty = EXCLUDED.critical_review_penalty,
    weak_governance_penalty = EXCLUDED.weak_governance_penalty,
    hybrid_bonus            = EXCLUDED.hybrid_bonus,
    strategic_bonus         = EXCLUDED.strategic_bonus,
    governed_bonus          = EXCLUDED.governed_bonus,
    ml_priority_bonus       = EXCLUDED.ml_priority_bonus,
    volatility_penalty      = EXCLUDED.volatility_penalty,
    notes                   = EXCLUDED.notes,
    updated_at              = now();

DO $$
DECLARE n INT;
BEGIN
    SELECT COUNT(*) INTO n FROM rf.semantic_confidence_policy;
    RAISE NOTICE 'P7B2 semantic confidence policy lignes : %', n;
END $$;

COMMIT;
