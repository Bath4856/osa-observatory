-- ============================================================
-- OSA / ISA — P7A1
-- Patch : Semantic Taxonomy Foundation
-- Objet : créer la taxonomie sémantique ISA exploitable par P6/ML
-- ============================================================

BEGIN;

CREATE TABLE IF NOT EXISTS ma.signal_semantic_policy (
    semantic_code        VARCHAR(30) PRIMARY KEY,
    semantic_label       TEXT NOT NULL,
    risk_weight          NUMERIC(5,3) NOT NULL DEFAULT 0.50,
    strategic_weight     NUMERIC(5,3) NOT NULL DEFAULT 0.50,
    volatility_weight    NUMERIC(5,3) NOT NULL DEFAULT 0.50,
    ml_importance        NUMERIC(5,3) NOT NULL DEFAULT 0.50,
    physicality          NUMERIC(5,3) NOT NULL DEFAULT 0.00,
    dependency_factor    NUMERIC(5,3) NOT NULL DEFAULT 0.50,
    resilience_factor    NUMERIC(5,3) NOT NULL DEFAULT 0.50,
    forecastability      NUMERIC(5,3) NOT NULL DEFAULT 0.50,
    description          TEXT,
    is_active            BOOLEAN NOT NULL DEFAULT TRUE,
    created_at           TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at           TIMESTAMP NOT NULL DEFAULT NOW(),

    CONSTRAINT signal_semantic_policy_bounds CHECK (
        risk_weight BETWEEN 0 AND 1
        AND strategic_weight BETWEEN 0 AND 1
        AND volatility_weight BETWEEN 0 AND 1
        AND ml_importance BETWEEN 0 AND 1
        AND physicality BETWEEN 0 AND 1
        AND dependency_factor BETWEEN 0 AND 1
        AND resilience_factor BETWEEN 0 AND 1
        AND forecastability BETWEEN 0 AND 1
    )
);

INSERT INTO ma.signal_semantic_policy
    (semantic_code, semantic_label, risk_weight, strategic_weight, volatility_weight,
     ml_importance, physicality, dependency_factor, resilience_factor, forecastability, description)
VALUES
('PHYSICAL',   'Donnée physique / ressource mesurable',       0.65, 0.85, 0.35, 0.90, 1.00, 0.55, 0.70, 0.70, 'Ressources, productions, volumes physiques. Imputation prudente.'),
('STRUCTURAL', 'Capacité structurelle / infrastructure',      0.55, 0.80, 0.40, 0.85, 0.35, 0.60, 0.75, 0.75, 'Capacités nationales durables : infrastructures, institutions, systèmes.'),
('FLOW',       'Flux économique, logistique ou informationnel',0.50, 0.70, 0.65, 0.80, 0.20, 0.70, 0.55, 0.65, 'Flux annuels : commerce, mobilité, transferts, échanges.'),
('STOCK',      'Stock / réserve / capital accumulé',          0.55, 0.80, 0.30, 0.80, 0.80, 0.60, 0.70, 0.75, 'Stocks souverains : réserves, capacités installées, ressources.'),
('EVENT',      'Événement / choc / incident',                 0.85, 0.75, 0.90, 0.80, 0.05, 0.75, 0.30, 0.45, 'Conflits, violences, ruptures, crises, chocs.'),
('PRESSURE',   'Pression / stress / contrainte',              0.80, 0.75, 0.70, 0.85, 0.10, 0.80, 0.35, 0.55, 'Pressions sur la souveraineté : sécurité, stress environnemental, dépendance.'),
('DEPENDENCY', 'Dépendance externe ou interne critique',      0.85, 0.90, 0.55, 0.90, 0.15, 0.95, 0.25, 0.60, 'Dépendance aux importations, financements, devises, infrastructures critiques.'),
('RESILIENCE', 'Résilience / capacité d’absorption',          0.35, 0.85, 0.35, 0.80, 0.25, 0.45, 0.95, 0.70, 'Capacité à absorber les chocs et maintenir la souveraineté.'),
('GOVERNANCE', 'Gouvernance / contrôle / régulation',         0.55, 0.90, 0.45, 0.85, 0.05, 0.70, 0.70, 0.65, 'Institutions, règles, contrôle, transparence, efficacité publique.'),
('NETWORK',    'Réseau / connectivité / interconnexion',      0.50, 0.75, 0.55, 0.80, 0.20, 0.80, 0.60, 0.65, 'Réseaux logistiques, numériques, diplomatiques, énergétiques.'),
('PERCEPTION', 'Perception / indice externe / opinion',       0.45, 0.55, 0.50, 0.60, 0.00, 0.40, 0.45, 0.50, 'Scores de perception ou classements internationaux.'),
('COMPOSITE',  'Indicateur composite calculé',                0.50, 0.75, 0.45, 0.85, 0.20, 0.60, 0.60, 0.65, 'Agrégation ou indicateur calculé par OSA.'),
('GEO',        'Signal géospatial / géopolitique',            0.80, 0.90, 0.75, 0.90, 0.15, 0.90, 0.35, 0.55, 'Signal spatial, géopolitique, territorial ou conflictuel.'),
('UNCLASSIFIED','Non classé / à qualifier',                   0.70, 0.35, 0.60, 0.30, 0.00, 0.60, 0.25, 0.30, 'Signal non encore classé : doit déclencher une action de gouvernance.')
ON CONFLICT (semantic_code)
DO UPDATE SET
    semantic_label    = EXCLUDED.semantic_label,
    risk_weight       = EXCLUDED.risk_weight,
    strategic_weight  = EXCLUDED.strategic_weight,
    volatility_weight = EXCLUDED.volatility_weight,
    ml_importance     = EXCLUDED.ml_importance,
    physicality       = EXCLUDED.physicality,
    dependency_factor = EXCLUDED.dependency_factor,
    resilience_factor = EXCLUDED.resilience_factor,
    forecastability   = EXCLUDED.forecastability,
    description       = EXCLUDED.description,
    is_active         = TRUE,
    updated_at        = NOW();

COMMIT;
