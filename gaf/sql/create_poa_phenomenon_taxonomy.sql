-- ============================================================
-- rf.poa_phenomenon_domain / rf.poa_phenomenon_type
-- Taxonomie POA a 3 niveaux : domaine -> phenomene observable ->
-- resultat analytique derive
-- 27 juillet 2026
-- ============================================================
-- Repond au constat que rf.poa_catalog ne porte que du contenu de
-- presentation (libelles/tendances), aucune classification. Les 18
-- projets de rf.sovereign_project_catalog (construits manuellement,
-- HORS DOCTRINE -- ni plan d'actions OIM ni AMI/AO/DP) seront pour
-- la plupart reclassables dans cette taxonomie -- cf.
-- add_legacy_status_sovereign_projects.sql (script separe).
--
-- rf.poa_phenomenon_domain : les 6 domaines racines identifies par
-- Theo (TRACEABILITY, ILLICIT_FLOWS, RESOURCE, FLOW, DATA, SERVICE),
-- chacun avec son observation primaire, son calcul OSA et son
-- resultat analytique derive -- directement le tableau fourni.
--
-- rf.poa_phenomenon_type : le niveau "phenomene observable" (ex.
-- BORDER_CROSSING, DOCUMENT_MISSING). observation_method_fr est
-- NOT NULL et DOIT decrire une methode de verification concrete,
-- sans jugement humain -- filtre structurel contre la "part
-- perceptible hors doctrine" (P7E, aucun indicateur de perception)
-- plutot qu'une liste figee decidee unilateralement par Claude.
--
-- A executer DEV -> PREPROD -> PROD.
-- ============================================================

BEGIN;

CREATE TABLE rf.poa_phenomenon_domain (
    domain_code              character varying(30) PRIMARY KEY,
    label_fr                 text NOT NULL,
    label_en                 text NOT NULL,
    primary_observation_fr   text NOT NULL,
    primary_observation_en   text NOT NULL,
    osa_calculation_fr       text NOT NULL,
    osa_calculation_en       text NOT NULL,
    derived_result_code      character varying(60) NOT NULL,
    derived_result_label_fr  text NOT NULL,
    derived_result_label_en  text NOT NULL,
    created_at                timestamp without time zone NOT NULL DEFAULT now()
);

CREATE TABLE rf.poa_phenomenon_type (
    phenomenon_code       character varying(40) PRIMARY KEY,
    domain_code           character varying(30) NOT NULL REFERENCES rf.poa_phenomenon_domain(domain_code),
    label_fr              text NOT NULL,
    label_en              text NOT NULL,
    -- Justification obligatoire : COMMENT on verifie ce phenomene
    -- concretement (comparaison de 2 sources reelles, seuil mesure,
    -- etc.) -- jamais une simple affirmation de jugement.
    observation_method_fr text NOT NULL,
    observation_method_en text NOT NULL,
    created_by             integer REFERENCES mg.affiliates(id),
    created_at             timestamp without time zone NOT NULL DEFAULT now()
);

CREATE INDEX idx_poa_phenomenon_domain ON rf.poa_phenomenon_type (domain_code);

COMMIT;

-- Verification post-execution
\d rf.poa_phenomenon_domain
\d rf.poa_phenomenon_type
