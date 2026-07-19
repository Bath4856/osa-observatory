-- ============================================================
-- Mise a jour ADR-005 -- ACCEPTED (schema construit, teste, corrige
-- (COMMENT ON ne supporte pas ||, chaines fusionnees) et deploye sur
-- DEV/PREPROD/PROD le 17 juillet 2026). Aucun livrable reel encore
-- catalogue, aucun controle d'acces implemente -- inchange par
-- rapport a la portee d'origine.
-- ============================================================

UPDATE rf.adr_registry SET
    status = 'ACCEPTED',
    description = description || ' Schéma construit, testé (insertion, vue, contrainte d''unicité code+version) et déployé sur DEV/PREPROD/PROD le 17 juillet 2026 -- bug corrigé au passage (COMMENT ON TABLE/VIEW n''accepte pas la concaténation ||, chaînes fusionnées). Aucun livrable réel encore catalogué, aucun contrôle d''accès implémenté -- inchangé par rapport à la portée d''origine du document.'
WHERE adr_code = 'ADR-005';

SELECT adr_code, status FROM rf.adr_registry WHERE adr_code = 'ADR-005';
