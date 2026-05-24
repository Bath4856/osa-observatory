CREATE TABLE IF NOT EXISTS rf.amar_known_breaks (
    id           SERIAL PRIMARY KEY,
    year_from    INTEGER NOT NULL,
    year_to      INTEGER NOT NULL,
    risk_band    VARCHAR(20) NOT NULL,
    cause_code   VARCHAR(50) NOT NULL,
    cause_label  TEXT NOT NULL,
    is_artefact  BOOLEAN NOT NULL DEFAULT FALSE,
    sprint       VARCHAR(20) NOT NULL,
    validated_by TEXT,
    created_at   TIMESTAMP DEFAULT NOW()
);

INSERT INTO rf.amar_known_breaks (year_from, year_to, risk_band, cause_code, cause_label, is_artefact, sprint, validated_by)
VALUES (2019, 2020, 'YELLOW', 'SWOT_ENGINE_ACTIVATION',
'Demarrage moteur SWOT P7F en 2020. Avant 2020 : swot_data_status = NO_COMPUTED_SWOT_ATTACHED sur 100% des lignes, weakness_score = 0, strategic_risk_score ≈ 0.05. Apres 2020 : SWOT actif, strategic_risk_score ≈ 0.39. Correction B appliquee Sprint 12A : effective_risk_score conditionnel sur swot_data_status. Rupture residuelle documentee et justifiee.',
TRUE, 'Sprint12A', 'Conseil technique OSA -- Sprint 12A -- 24 mai 2026');

SELECT id, year_from, year_to, risk_band, cause_code, is_artefact, sprint FROM rf.amar_known_breaks;
