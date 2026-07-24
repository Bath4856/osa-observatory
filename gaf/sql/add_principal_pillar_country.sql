-- ============================================================
-- osoa.opportunities -- ajout principal_pillar_code + country_iso3
-- 25 juillet 2026
-- ============================================================
-- Prerequis identifie il y a deux nuits (jamais construit), rendu
-- necessaire aujourd'hui par le projet de convergence P7J <-> OIM/OSOA :
-- pour relier une ligne pub.mv_isa_opportunity_catalog (pays+pilier)
-- a un livrable OIM/OSOA (osoa.strategic_deliverables), il faut que
-- osoa.opportunities porte elle-meme le pays et le pilier principal.
--
-- Aujourd'hui : pour INTERNAL, le pilier est deductible via
-- origin_project_family_id -> mg.project_families (AUCUN pillar_code
-- sur cette table, verifie) ou via une exigence liee -> objective_id
-- -> mg.strategic_objectives.pillar_code -- chemin indirect, pas
-- garanti. Pour EXTERNAL, aucun chemin n'existe du tout vers un
-- pilier. Le pays n'est garanti que cote EXTERNAL (via client_id ->
-- osoa.clients.country_iso3), jamais cote INTERNAL.
--
-- Les deux colonnes sont NULLABLES -- remplies une fois decouvertes
-- (immediatement pour OIM qui connait deja son pilier, apres analyse
-- pour OSOA qui doit le decouvrir -- cf. clarification du 24 juillet
-- 2026 sur l'asymetrie OIM/OSOA). Pas de FK sur country_iso3,
-- coherent avec le reste du schema (osoa.clients.country_iso3 n'en a
-- pas non plus). FK reelle sur principal_pillar_code vers
-- mg.working_groups(pillar_code), meme referentiel que le reste
-- d'OIM.
--
-- A executer DEV -> PREPROD -> PROD.
-- ============================================================

BEGIN;

ALTER TABLE osoa.opportunities
    ADD COLUMN principal_pillar_code character varying(10) REFERENCES mg.working_groups(pillar_code);

ALTER TABLE osoa.opportunities
    ADD COLUMN country_iso3 character varying(3);

COMMIT;

-- Verification post-execution
\d osoa.opportunities
