-- ============================================================
-- Mise a jour ADR-007 -- amendement second chemin d'entree :
-- mg.pattern_reusability_constraints construite et deployee
-- (DEV/PREPROD/PROD) le 17 juillet 2026.
-- ============================================================

UPDATE rf.adr_registry SET
    description = replace(
        description,
        'nouvelle colonne de reutilisabilite sur mg.intervention_patterns non encore construite (a faire)',
        'mg.pattern_reusability_constraints (evaluation 1:N par pays ou categorie de contexte, jamais une colonne unique) construite, testee et deployee le 17 juillet 2026 sur DEV/PREPROD/PROD'
    )
WHERE adr_code = 'ADR-007';

SELECT adr_code, description FROM rf.adr_registry WHERE adr_code = 'ADR-007';
