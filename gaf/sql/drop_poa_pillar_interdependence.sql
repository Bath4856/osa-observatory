-- ============================================================
-- ABANDON de rf.poa_pillar_interdependence
-- 22-23 juillet 2026
-- ============================================================
-- Erreur de conception identifiee la meme soiree que sa creation
-- (create_poa_pillar_interdependence.sql, 22 juillet 2026, commit
-- c1ab08d), AVANT toute donnee reelle inseree (table restee vide
-- sur les 3 environnements -- verifie SELECT COUNT(*) = 0 partout,
-- zero dependance via pg_depend).
--
-- CE QUI CLOCHAIT : la table modelisait l'interdependance POA <->
-- pilier comme un REFERENTIEL GENERAL PANAFRICAIN (rf.*, sans
-- dimension pays) -- une meme relation (ex. PMIN_VALUE_LEAKAGE
-- influence PECO a hauteur de 0.4) aurait ete appliquee de facon
-- identique aux 54 pays. C'est directement contraire au principe
-- fondamental de l'OSA : AUCUN CLASSEMENT, AUCUNE COMPARAISON ENTRE
-- ETATS. Imposer une structure d'interdependance uniforme a tous
-- les pays revient a presupposer qu'ils se comportent de la meme
-- facon -- exactement ce que la doctrine interdit.
--
-- CE QUE THEO A CLARIFIE (22 juillet 2026 au soir) : l'interdependance
-- reelle entre un pilier/POA et d'autres piliers/POA n'a de sens
-- QUE dans le contexte d'un pays specifique etudie, et emerge
-- PENDANT l'application des 9 methodes OIM/OSOA sur ce pays -- ce
-- n'est ni une prediction (qui viendrait apres la mise en oeuvre),
-- ni une doctrine generale prealable. Exemple donne : une
-- intervention PNUM (ex. Systeme Numerique de Certification et de
-- Tracabilite des Minerais) dans UN pays peut avoir des consequences
-- observees sur PMIN/PECO/PRES/PHUM de CE MEME PAYS -- pas une regle
-- universelle.
--
-- OU DEVRA VIVRE LA VRAIE INTERDEPENDANCE (a concevoir separement,
-- session future) : rattachee a l'analyse pays-specifique elle-meme
-- (mg.transformation_requirements, deja pays-specifique via la
-- chaine pilier -> 5 Pourquoi -> objectif ; ou osoa.strategic_analyses,
-- deja rattachee a une opportunite et donc a un pays via le client) --
-- jamais un referentiel general prealable.
--
-- A executer DEV -> PREPROD -> PROD, dans cet ordre.
-- ============================================================

BEGIN;

DROP TABLE IF EXISTS rf.poa_pillar_interdependence;

COMMIT;

-- Verification post-execution -- doit renvoyer 0 ligne (table absente)
SELECT tablename FROM pg_tables WHERE schemaname = 'rf' AND tablename = 'poa_pillar_interdependence';
