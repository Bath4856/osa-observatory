-- ============================================================
-- OSA / ISA — P7B1
-- Semantic Governance Matrix
-- Objectif : matrice centrale de gouvernance sémantique ISA
-- ============================================================

BEGIN;

CREATE TABLE IF NOT EXISTS rf.semantic_governance_matrix (
    semantic_code           VARCHAR(30) PRIMARY KEY,
    semantic_label          TEXT NOT NULL,
    trust_level             NUMERIC(4,3) NOT NULL CHECK (trust_level BETWEEN 0 AND 1),
    sovereignty_weight      NUMERIC(4,3) NOT NULL CHECK (sovereignty_weight BETWEEN 0 AND 1),
    volatility_class        VARCHAR(20) NOT NULL,
    forecastability         NUMERIC(4,3) NOT NULL CHECK (forecastability BETWEEN 0 AND 1),
    imputation_policy       VARCHAR(30) NOT NULL,
    ml_priority             NUMERIC(4,3) NOT NULL CHECK (ml_priority BETWEEN 0 AND 1),
    risk_profile            VARCHAR(40) NOT NULL,
    physicality_score       NUMERIC(4,3) NOT NULL CHECK (physicality_score BETWEEN 0 AND 1),
    dependency_score        NUMERIC(4,3) NOT NULL CHECK (dependency_score BETWEEN 0 AND 1),
    resilience_score        NUMERIC(4,3) NOT NULL CHECK (resilience_score BETWEEN 0 AND 1),
    strategic_priority      NUMERIC(4,3) NOT NULL CHECK (strategic_priority BETWEEN 0 AND 1),
    governance_mode         VARCHAR(20) NOT NULL,
    recommended_action      TEXT,
    description             TEXT,
    created_at              TIMESTAMP DEFAULT now(),
    updated_at              TIMESTAMP DEFAULT now()
);

INSERT INTO rf.semantic_governance_matrix (
    semantic_code, semantic_label, trust_level, sovereignty_weight,
    volatility_class, forecastability, imputation_policy, ml_priority,
    risk_profile, physicality_score, dependency_score, resilience_score,
    strategic_priority, governance_mode, recommended_action, description
)
VALUES
('PHYSICAL',   'Signal physique / ressource matérielle',        0.900, 0.950, 'LOW',    0.700, 'STRICT',       0.900, 'RESOURCE_CRITICAL', 0.950, 0.400, 0.600, 0.950, 'STRICT',   'Limiter fortement l’imputation ; privilégier source primaire.', 'Ressources physiques, production, eau, énergie, minerais.'),
('STOCK',      'Stock / réserve / capacité accumulée',          0.850, 0.900, 'LOW',    0.750, 'STRICT',       0.850, 'STOCK_DEPLETION',   0.800, 0.450, 0.650, 0.900, 'STRICT',   'Contrôler cohérence temporelle et ruptures de stock.', 'Réserves, stocks, actifs accumulés.'),
('STRUCTURAL', 'Capacité structurelle / infrastructure',        0.850, 0.850, 'MEDIUM', 0.750, 'MODERATE',     0.900, 'CAPACITY_GAP',      0.500, 0.550, 0.750, 0.900, 'MODERATE', 'Autoriser interpolation courte avec traçabilité.', 'Infrastructure, capacités, systèmes institutionnels durables.'),
('GOVERNANCE', 'Gouvernance / règles / institutions',           0.750, 0.830, 'MEDIUM', 0.650, 'FLEXIBLE',     0.850, 'GOVERNANCE_RISK',   0.200, 0.650, 0.700, 0.850, 'MODERATE', 'Vérifier biais de perception et cohérence institutionnelle.', 'Régulation, contrôle, institutions, politiques publiques.'),
('NETWORK',    'Réseau / connectivité / maillage',              0.760, 0.730, 'MEDIUM', 0.650, 'MODERATE',     0.820, 'CONNECTIVITY_RISK', 0.350, 0.750, 0.650, 0.800, 'MODERATE', 'Analyser dépendances croisées et centralité.', 'Réseaux numériques, transport, influence, organisations.'),
('FLOW',       'Flux économique, informationnel ou logistique', 0.720, 0.680, 'HIGH',   0.650, 'MODERATE',     0.800, 'FLOW_DEPENDENCY',   0.200, 0.800, 0.550, 0.780, 'MODERATE', 'Contrôler volatilité annuelle et dépendances externes.', 'Commerce, passagers, IDE, flux financiers, migration.'),
('PRESSURE',   'Pression / stress / risque systémique',         0.700, 0.790, 'HIGH',   0.550, 'CAUTIOUS',     0.850, 'SYSTEMIC_PRESSURE', 0.300, 0.750, 0.350, 0.900, 'STRICT',   'Éviter imputation longue ; signaler pression souveraine.', 'Pollution, inflation, conflit, stress environnemental.'),
('EVENT',      'Événement / choc / occurrence',                 0.650, 0.660, 'HIGH',   0.450, 'VERY_STRICT',  0.750, 'SHOCK_EVENT',       0.150, 0.700, 0.300, 0.720, 'STRICT',   'Ne pas extrapoler ; privilégier observation ou source événementielle.', 'Événements politiques, militaires, sécuritaires.'),
('DEPENDENCY', 'Dépendance stratégique',                        0.720, 0.810, 'HIGH',   0.600, 'CAUTIOUS',     0.880, 'DEPENDENCY_RISK',   0.250, 0.950, 0.300, 0.920, 'STRICT',   'Identifier dépendance critique et exposition externe.', 'Dépendances minières, monétaires, commerciales, énergétiques.'),
('RESILIENCE', 'Résilience / capacité d’absorption',            0.780, 0.770, 'MEDIUM', 0.700, 'MODERATE',     0.850, 'RESILIENCE_GAP',    0.300, 0.450, 0.950, 0.880, 'MODERATE', 'Évaluer capacité de réponse et robustesse.', 'Éducation, santé, adaptation, stabilité sociale.'),
('GEO',        'Géopolitique / influence / positionnement',     0.700, 0.800, 'HIGH',   0.550, 'CAUTIOUS',     0.850, 'GEOPOLITICAL_RISK', 0.100, 0.850, 0.450, 0.900, 'STRICT',   'Croiser avec PGEO, événements et menaces.', 'Influence, alliances, soft power, stabilité régionale.'),
('COMPOSITE',  'Indicateur composite calculé',                  0.760, 0.630, 'MEDIUM', 0.650, 'DEPENDENT',    0.800, 'MODEL_DEPENDENT',   0.200, 0.600, 0.600, 0.700, 'FLEXIBLE', 'Vérifier les composants et leur confiance.', 'Scores et agrégats calculés par OSA/ISA.'),
('PERCEPTION', 'Perception / enquête / jugement expert',        0.620, 0.460, 'MEDIUM', 0.500, 'FLEXIBLE',     0.650, 'PERCEPTION_BIAS',   0.050, 0.550, 0.500, 0.550, 'FLEXIBLE', 'Documenter biais, méthodologie et source.', 'Perceptions, enquêtes, indices subjectifs.')
ON CONFLICT (semantic_code) DO UPDATE SET
    semantic_label      = EXCLUDED.semantic_label,
    trust_level         = EXCLUDED.trust_level,
    sovereignty_weight  = EXCLUDED.sovereignty_weight,
    volatility_class    = EXCLUDED.volatility_class,
    forecastability     = EXCLUDED.forecastability,
    imputation_policy   = EXCLUDED.imputation_policy,
    ml_priority         = EXCLUDED.ml_priority,
    risk_profile        = EXCLUDED.risk_profile,
    physicality_score   = EXCLUDED.physicality_score,
    dependency_score    = EXCLUDED.dependency_score,
    resilience_score    = EXCLUDED.resilience_score,
    strategic_priority  = EXCLUDED.strategic_priority,
    governance_mode     = EXCLUDED.governance_mode,
    recommended_action  = EXCLUDED.recommended_action,
    description         = EXCLUDED.description,
    updated_at          = now();

DO $$
DECLARE n INT;
BEGIN
    SELECT COUNT(*) INTO n FROM rf.semantic_governance_matrix;
    RAISE NOTICE 'P7B1 semantic governance matrix lignes : %', n;
END $$;

COMMIT;
