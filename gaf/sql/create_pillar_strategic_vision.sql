-- ============================================================
-- mg.pillar_strategic_vision -- vision OIM annuelle
-- 25 juillet 2026
-- ============================================================
-- Reformulation majeure actee avec Theo : OIM n'est pas un simple
-- "chemin interne" symetrique a OSOA -- c'est le mecanisme PARENT
-- qui porte la vision, le schema directeur et le plan d'actions
-- d'un pilier, pour un pays donne, a un cycle de collecte donne.
-- Une seule vision par (pays, pilier, annee) a un instant donne --
-- plusieurs PROJETS (internes automatiques ou externes via
-- AMI/AO/AOI/DP, portes par osoa.opportunities) en derivent.
--
-- Le cycle de generation coincide avec le cycle de validation PV
-- (aout de l'annee Y pour les donnees Y-1, rf.publication_policy) --
-- validation de year contre rf.publication_policy (statut
-- OFFICIAL_CONSOLIDATED ou PRELIMINARY) a faire cote application
-- (API, pas encore construite ce soir) : rf.publication_policy.status
-- evolue dans le temps (PRELIMINARY -> OFFICIAL_CONSOLIDATED), une
-- contrainte FK figee n'aurait pas de sens ici.
--
-- Distincte de osoa.opportunities (qui reste reservee aux PROJETS
-- concrets : demandes AMI/AO/AOI/DP, avec leur propre cycle de
-- negociation independant du cycle de publication ISA) -- une vision
-- n'a ni participation_mode, ni client, ni procurement_stage, elle
-- n'est rien de tout cela.
--
-- A executer DEV -> PREPROD -> PROD.
-- ============================================================

BEGIN;

CREATE TABLE mg.pillar_strategic_vision (
    id             integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    country_iso3   character varying(3) NOT NULL,
    pillar_code    character varying(10) NOT NULL REFERENCES mg.working_groups(pillar_code),
    year           integer NOT NULL,
    status         character varying(20) NOT NULL DEFAULT 'DRAFT'
                       CHECK (status IN ('DRAFT', 'VALIDATED', 'ARCHIVED')),
    created_by     integer REFERENCES mg.affiliates(id),
    created_at     timestamp without time zone NOT NULL DEFAULT now(),
    updated_at     timestamp without time zone NOT NULL DEFAULT now(),
    UNIQUE (country_iso3, pillar_code, year)
);

CREATE INDEX idx_pillar_vision_country_pillar ON mg.pillar_strategic_vision (country_iso3, pillar_code);
CREATE INDEX idx_pillar_vision_year ON mg.pillar_strategic_vision (year);

COMMIT;

-- Verification post-execution
\d mg.pillar_strategic_vision
