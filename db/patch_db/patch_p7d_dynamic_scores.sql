-- ============================================================
-- OSA / ISA — P7D
-- Patch RF: Dynamic Scores Policy
-- Purpose:
--   Create the RF scoring doctrine used by P7D.
--   This patch is intentionally RF-only and does not touch MA data.
-- ============================================================

BEGIN;

CREATE TABLE IF NOT EXISTS rf.dynamic_score_policy (
    semantic_code VARCHAR(30) PRIMARY KEY,
    scoring_mode VARCHAR(40) NOT NULL,
    performance_factor NUMERIC(6,3) NOT NULL DEFAULT 1.000,
    sovereignty_factor NUMERIC(6,3) NOT NULL DEFAULT 1.000,
    vulnerability_factor NUMERIC(6,3) NOT NULL DEFAULT 1.000,
    resilience_factor NUMERIC(6,3) NOT NULL DEFAULT 1.000,
    forecast_factor NUMERIC(6,3) NOT NULL DEFAULT 1.000,
    include_in_dynamic_score BOOLEAN NOT NULL DEFAULT TRUE,
    notes TEXT,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO rf.dynamic_score_policy (
    semantic_code,
    scoring_mode,
    performance_factor,
    sovereignty_factor,
    vulnerability_factor,
    resilience_factor,
    forecast_factor,
    include_in_dynamic_score,
    notes
)
VALUES
('PHYSICAL',   'CERTIFIED_SCORE',        1.120, 1.180, 0.850, 0.950, 0.900, TRUE,  'Score physique : cœur de souveraineté si certifié ; gap si verrouillé.'),
('STOCK',      'RESOURCE_STOCK_SCORE',   1.080, 1.120, 0.850, 0.950, 0.950, TRUE,  'Stocks et réserves : forte valeur ISA si source stable.'),
('STRUCTURAL', 'STRUCTURAL_SCORE',       1.100, 1.100, 0.800, 1.050, 1.000, TRUE,  'Capacité structurelle : socle du score ISA.'),
('GOVERNANCE', 'GOVERNANCE_SCORE',       1.000, 1.050, 0.900, 0.950, 0.850, TRUE,  'Gouvernance : pilotable mais sensible aux biais institutionnels.'),
('RESILIENCE', 'RESILIENCE_SCORE',       1.000, 1.050, 0.750, 1.200, 0.950, TRUE,  'Résilience : renforce le score et amortit la vulnérabilité.'),
('NETWORK',    'NETWORK_SCORE',          0.950, 0.950, 0.950, 0.900, 0.850, TRUE,  'Réseaux : utile si non verrouillé ; dépend fortement de la qualité source.'),
('FLOW',       'FLOW_SCORE',             0.900, 0.850, 1.000, 0.850, 0.800, TRUE,  'Flux : contribution contrôlée, volatilité possible.'),
('COMPOSITE',  'COMPONENT_SCORE',        0.850, 0.850, 0.900, 0.850, 0.750, TRUE,  'Composite : score dépendant de la qualité des composants.'),
('DEPENDENCY', 'VULNERABILITY_SCORE',    0.650, 0.650, 1.300, 0.650, 0.600, FALSE, 'Dépendance : signal de vulnérabilité, pas cœur ISA.'),
('GEO',        'CONTEXT_SCORE',          0.650, 0.650, 1.150, 0.700, 0.600, FALSE, 'Géopolitique : contexte stratégique, souvent non-core.'),
('PRESSURE',   'RISK_SCORE',             0.650, 0.650, 1.250, 0.650, 0.600, FALSE, 'Pression systémique : utile surtout pour vulnérabilité.'),
('EVENT',      'EVENT_RISK_SCORE',       0.300, 0.300, 1.350, 0.500, 0.000, FALSE, 'Événement : anti-souveraineté / choc, pas de forecast.'),
('PERCEPTION', 'CONTEXT_ONLY_SCORE',     0.450, 0.450, 0.900, 0.600, 0.500, FALSE, 'Perception : contexte uniquement, biais possible.')
ON CONFLICT (semantic_code) DO UPDATE SET
    scoring_mode = EXCLUDED.scoring_mode,
    performance_factor = EXCLUDED.performance_factor,
    sovereignty_factor = EXCLUDED.sovereignty_factor,
    vulnerability_factor = EXCLUDED.vulnerability_factor,
    resilience_factor = EXCLUDED.resilience_factor,
    forecast_factor = EXCLUDED.forecast_factor,
    include_in_dynamic_score = EXCLUDED.include_in_dynamic_score,
    notes = EXCLUDED.notes,
    updated_at = CURRENT_TIMESTAMP;

CREATE INDEX IF NOT EXISTS idx_dynamic_score_policy_mode
    ON rf.dynamic_score_policy(scoring_mode);

DO $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM rf.dynamic_score_policy;
    RAISE NOTICE 'P7D dynamic score policy lignes : %', v_count;
END $$;

COMMIT;
