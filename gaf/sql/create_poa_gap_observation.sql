-- ============================================================
-- ma.poa_gap_observation -- couche de donnees GAP reelles
-- 27 juillet 2026
-- ============================================================
-- Complete la taxonomie doctrinale (rf.poa_phenomenon_domain /
-- rf.poa_phenomenon_type, meme soiree) avec la couche de DONNEES
-- reelles. Architecture actee par Theo : POA = Pilier + Objet
-- observe + Phenomene observable + Metrique derivee -- le GAP
-- devient un delta calcule, reproductible, auditable, valorisable
-- economiquement, jamais une appreciation qualitative.
--
-- Schema ma. (mesures/analyses) coherent avec ma.indicator_values,
-- ma.v_p7i_risk_source -- c'est la ou vit la donnee reelle mesuree,
-- distincte du referentiel rf.* qui ne fait que definir ce qui PEUT
-- etre observe.
--
-- DOCTRINE APPLIQUEE (reutilisee, pas reinventee) :
-- 1. expected_isa_contribution_note_fr/en est descriptif SEULEMENT --
--    jamais une valeur ISA affirmee a l'avance, meme doctrine que
--    OSOA_DISCLAIMER ("seule une donnee reellement collectee lors
--    d'un cycle futur peut faire evoluer l'ISA") et le basis_type de
--    la methode INTERDEPENDANCE (osoa.strategic_analyses).
-- 2. sovereignty_impact_score est un score INTERNE uniquement --
--    meme precedent que intervention_priority_score de P7J (Sprint
--    31 : "verifie structurellement" qu'aucun score ne sort par
--    l'API publique). A NE JAMAIS exposer sans revision de cette
--    doctrine -- Claude doit le rappeler explicitement au moment de
--    construire l'API sur cette table.
-- 3. methodology_note_fr obligatoire -- meme discipline que partout
--    ailleurs cette session (INTERDEPENDANCE, rf.poa_phenomenon_type) :
--    aucune ligne n'entre sans justification de methode.
--
-- Pas de contrainte d'unicite (plusieurs objets observes distincts
-- possibles pour un meme pays+pilier+phenomene+annee).
--
-- A executer DEV -> PREPROD -> PROD.
-- ============================================================

BEGIN;

CREATE TABLE ma.poa_gap_observation (
    id                              integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    country_iso3                    character varying(3) NOT NULL,
    pillar_code                     character varying(10) NOT NULL REFERENCES mg.working_groups(pillar_code),
    phenomenon_code                 character varying(40) NOT NULL REFERENCES rf.poa_phenomenon_type(phenomenon_code),
    year                            integer NOT NULL,

    -- Objet observe -- le "quoi" concret mesure (ex. "234 conteneurs
    -- au port de Douala, janvier-mars 2025")
    observed_object_fr              text NOT NULL,
    observed_object_en              text NOT NULL,
    primary_observation_value       numeric NOT NULL,
    primary_observation_unit        text NOT NULL,

    -- GAP -- delta calcule, reproductible
    gap_value                       numeric NOT NULL,
    gap_unit                        text NOT NULL,

    -- Valorisation economique (nullable -- pas toujours estimable
    -- immediatement)
    estimated_cost                  numeric,
    cost_currency                   character varying(3),

    -- Impact souverainete -- score INTERNE seulement (cf. doctrine
    -- ci-dessus, jamais expose publiquement sans revision explicite)
    sovereignty_impact_score        numeric(5,3),
    sovereignty_impact_note_fr      text,
    sovereignty_impact_note_en      text,

    -- Contribution ISA -- descriptif seulement, jamais une valeur
    -- affirmee (doctrine OSOA_DISCLAIMER / INTERDEPENDANCE.basis_type)
    expected_isa_contribution_note_fr text,
    expected_isa_contribution_note_en text,

    -- Tracabilite complete (observation initiale -> resultat)
    source_reference                text NOT NULL,
    methodology_note_fr             text NOT NULL,
    methodology_note_en             text,

    created_by                      integer REFERENCES mg.affiliates(id),
    created_at                      timestamp without time zone NOT NULL DEFAULT now(),
    updated_at                      timestamp without time zone NOT NULL DEFAULT now()
);

CREATE INDEX idx_poa_gap_country_pillar ON ma.poa_gap_observation (country_iso3, pillar_code);
CREATE INDEX idx_poa_gap_phenomenon ON ma.poa_gap_observation (phenomenon_code);
CREATE INDEX idx_poa_gap_year ON ma.poa_gap_observation (year);

COMMIT;

-- Verification post-execution
\d ma.poa_gap_observation
