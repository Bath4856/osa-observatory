-- ============================================================
-- ADR-007 (OIM), amendement du second chemin d'entree -- caracterisation
-- de reutilisabilite des Patrons d'Intervention
-- 17 juillet 2026
-- ============================================================
-- "La portabilite d'un patron d'un contexte national a un autre n'est
-- jamais presumee par defaut : elle doit etre documentee, pays par
-- pays ou categorie de contexte par categorie de contexte" -- exige une
-- relation 1:N, pas une colonne unique sur mg.intervention_patterns.
-- Absence de ligne pour un (patron, portee) donne = jamais evalue,
-- jamais presume portable.
-- A executer sur DEV en premier (doctrine du projet).
-- ============================================================
-- EXECUTION :
--   docker exec -i osa-db psql -U postgres -d osa_dev \
--     < pattern_reusability_constraints.sql
-- ============================================================

BEGIN;

CREATE TABLE IF NOT EXISTS mg.pattern_reusability_constraints (
    id                        serial PRIMARY KEY,
    pattern_code              text NOT NULL REFERENCES mg.intervention_patterns(pattern_code),
    scope_type                varchar(20) NOT NULL
                              CHECK (scope_type IN ('COUNTRY', 'CONTEXT_CATEGORY')),
    scope_value               text NOT NULL,
    is_portable               boolean NOT NULL,
    constraint_description_fr text,
    constraint_description_en text,
    documented_by             integer REFERENCES mg.affiliates(id),
    documented_at             timestamp NOT NULL DEFAULT now(),
    UNIQUE (pattern_code, scope_type, scope_value)
);

CREATE INDEX IF NOT EXISTS idx_pattern_reusability_pattern
    ON mg.pattern_reusability_constraints (pattern_code);

COMMENT ON TABLE mg.pattern_reusability_constraints IS
    'Caracterisation explicite des conditions de reutilisation d''un '
    'Patron d''Intervention -- ADR-007, amendement second chemin '
    'd''entree. scope_type=COUNTRY : evaluation propre a un pays '
    '(country_iso3 dans scope_value). scope_type=CONTEXT_CATEGORY : '
    'evaluation par categorie de contexte (ex. "gouvernance '
    'centralisee"), quand une evaluation pays par pays serait '
    'disproportionnee. Absence de ligne = jamais evalue, jamais '
    'presume portable -- ne jamais interpreter un silence comme une '
    'autorisation implicite.';

COMMIT;

-- Verification post-execution
SELECT table_name FROM information_schema.tables
    WHERE table_schema = 'mg' AND table_name = 'pattern_reusability_constraints';
