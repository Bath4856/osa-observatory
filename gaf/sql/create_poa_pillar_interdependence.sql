-- ============================================================
-- rf.poa_pillar_interdependence -- interdependance POA <-> piliers
-- 22 juillet 2026
-- ============================================================
-- Un indicateur POA (rf.poa_catalog) peut informer PLUSIEURS piliers
-- ISA a la fois, avec un poids (continu, 0-1, libre -- pas de
-- contrainte de somme=1.0) et un type de relation (PRIMAIRE/
-- SECONDAIRE, lecture humaine rapide). Distinct de
-- rf.indicators.pillar_code (rattachement d'origine 1:1, deja
-- existant) -- cette table capture l'influence elargie, pas
-- seulement l'origine doctrinale.
--
-- A executer DEV -> PREPROD -> PROD.
--
-- DOCTRINE -- cadre non ferme (note du 22 juillet 2026) :
-- 1. De nouveaux indicateurs POA pourront s'ajouter a rf.poa_catalog
--    a l'avenir -- deja gere automatiquement via la FK indicator_code,
--    aucune modification de schema necessaire.
-- 2. Un phenomene detecte par un indicateur POA peut se resorber grace
--    aux actions du Moteur de genie scientifique (OIM+OSOA, cf ADR-010) --
--    coherent avec le cadre probabiliste deja acte : POA/AMAR/GENECO
--    detectent, OIM/OSOA recommandent, seule une donnee reellement
--    collectee au cycle suivant confirme une resorption.
--    Le lien entre un phenomene resorbe et l'intervention qui l'a cause
--    N'EST PAS trace dans cette table (doctrinale, generale, sans
--    dimension pays/temps) -- ce serait un melange de granularite avec
--    un fait specifique a un pays et un moment donne. Ce lien devra
--    vivre plus tard dans mg.transformation_requirements (deja
--    l'ancrage reel pays+temps, cote OIM comme OSOA), a concevoir
--    separement avec de vraies donnees, pas ajoute ici par anticipation.
-- ============================================================

BEGIN;

CREATE TABLE rf.poa_pillar_interdependence (
    indicator_code     character varying(30) NOT NULL REFERENCES rf.poa_catalog(indicator_code) ON DELETE CASCADE,
    pillar_code        character varying(10) NOT NULL REFERENCES rf.pillars(code),
    relation_type      character varying(20) NOT NULL CHECK (relation_type IN ('PRIMAIRE', 'SECONDAIRE')),
    weight             numeric(3,2) NOT NULL CHECK (weight > 0 AND weight <= 1),
    -- Tracabilite obligatoire -- aucune ligne ne peut entrer sans source
    -- verifiable (correlation statistique reelle calculee sur ma.indicator_values,
    -- decision du Comite Scientifique avec reference PV, ou estimation
    -- d'IA predictive -- celle-ci jamais promue VALIDATED sans confirmation
    -- reelle ulterieure, cf contrainte chk_ai_estimate_never_validated).
    -- Jamais un jugement narratif non source (P7E : aucun indicateur de
    -- perception -- meme precedent que le rejet de l'imputation MICE
    -- pour TRAJECTOIRE, note du 22 juillet 2026).
    basis_type         character varying(30) NOT NULL CHECK (basis_type IN ('STATISTICAL_CORRELATION', 'COMITE_SCIENTIFIQUE_DECISION', 'AI_PREDICTIVE_ESTIMATE')),
    methodology_note_fr text NOT NULL,
    source_reference    text,  -- ex. PV du Comite Scientifique, parametres du calcul statistique, ou modele/version IA
    status              character varying(20) NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT', 'VALIDATED', 'ARCHIVED')),
    created_by          integer REFERENCES mg.affiliates(id),
    created_at          timestamp without time zone NOT NULL DEFAULT now(),
    PRIMARY KEY (indicator_code, pillar_code),
    -- Une estimation d'IA predictive reste une hypothese, jamais une
    -- observation -- ne peut structurellement jamais devenir VALIDATED
    -- tant qu'elle n'a pas ete reconfirmee par une vraie correlation
    -- statistique ou une decision du Comite Scientifique (basis_type
    -- devrait alors changer, pas seulement le statut).
    CONSTRAINT chk_ai_estimate_never_validated CHECK (
        NOT (basis_type = 'AI_PREDICTIVE_ESTIMATE' AND status = 'VALIDATED')
    )
);

-- DECALAGE TEMPOREL -- note du 22 juillet 2026 : les effets reels
-- d'une intervention OIM/OSOA ne sont visibles que 2 a 5 ans apres
-- l'action, une fois captes par un futur cycle de collecte reel.
-- Consequence directe : un basis_type='STATISTICAL_CORRELATION'
-- calcule sur la MEME annee (indicateur POA vs score pilier annee Y)
-- serait methodologiquement invalide -- il faut une correlation
-- DECALEE (indicateur annee Y vs score pilier annee Y+2 a Y+5).
-- Avec seulement ~5 ans de donnees POA reelles a ce jour (2020-2024,
-- certains indicateurs moins -- serie eparse), la fenetre statistique
-- exploitable est aujourd'hui quasi nulle pour un tel decalage.
-- Cette table restera donc legitimement vide/DRAFT pendant plusieurs
-- annees de collecte supplementaires -- pas un echec de conception,
-- une limite reelle des donnees disponibles a ce stade du projet.

CREATE INDEX idx_poa_pillar_interdep_pillar ON rf.poa_pillar_interdependence (pillar_code);
CREATE INDEX idx_poa_pillar_interdep_type ON rf.poa_pillar_interdependence (relation_type);

COMMIT;

-- Verification post-execution
\d rf.poa_pillar_interdependence
